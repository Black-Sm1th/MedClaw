/**
 * @file gateway_client.h
 * @brief WebSocket 主类（总大类） —— Gateway 客户端
 *
 * 本类是 WebSocket 通信的顶层控制器，封装了与 Gateway 交互的完整生命周期：
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │  GatewayClient（总大类 / 主类）                               │
 * │                                                             │
 * │  职责：                                                      │
 * │    ① QWebSocket 实例管理（创建、连接、断开、销毁）              │
 * │    ② 连接生命周期控制（状态机：断开→连接中→握手中→已连接）       │
 * │    ③ 协议握手（challenge → connect → hello-ok）               │
 * │    ④ 入站消息分发（event / response → 子类处理）              │
 * │    ⑤ 出站请求发送（统一的 RPC 请求发送 + 请求追踪）            │
 * │    ⑥ Qt 信号发射（供 QML / 上层业务监听）                     │
 * │                                                             │
 * │  组合子类：                                                   │
 * │    ├── WsConfig            配置类（连接参数、设备密钥）         │
 * │    ├── WsSession           会话类（会话管理、消息收发）         │
 * │    ├── WsSkill             技能类（skills.status / update）   │
 * │    ├── WsTools             工具类（tools.catalog + deny/allow）│
 * │    └── WsScheduledTask     定时任务类                         │
 * └─────────────────────────────────────────────────────────────┘
 *
 * 连接流程概述：
 *   1. 调用 connectToServer(url)，QWebSocket 发起 TCP + WebSocket 升级
 *   2. WebSocket 连接成功 → onConnected() → 状态切换为 Handshaking
 *   3. 收到服务器 connect.challenge 事件 → 取得 nonce
 *   4. 调用 sendConnectRequest()：
 *      - 由 WsConfig 构建含 Ed25519 签名的 params
 *      - 发送 {type:"req", method:"connect", params:{...}}
 *   5. 收到 {type:"res", ok:true} → 握手完成 → 状态切换为 Connected
 *   6. 自动刷新 agents / sessions / models（不预加载聊天历史；需用户选择 agent）
 *
 * 断开流程：
 *   - 主动断开：调用 disconnectFromServer() → socket.close()
 *   - 被动断开：服务器关闭连接 → onDisconnected()
 *   - 异常断开：网络错误 → onSocketError() → errorOccurred 信号
 *   - 所有情况最终都进入 Disconnected 状态并清理资源
 */
#ifndef GATEWAY_CLIENT_H
#define GATEWAY_CLIENT_H

#include <QObject>
#include <QTimer>
#include <QWebSocket>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QDateTime>
#include <QHash>
#include <QMap>
#include <QSet>
#include <QSqlDatabase>

#include "ws_config.h"
#include "ws_session.h"
#include "ws_skill.h"
#include "ws_tools.h"
#include "ws_scheduled_task.h"

class GatewayClient : public QObject
{
    Q_OBJECT

    // ── QML 可绑定属性 ──
    Q_PROPERTY(int connectionState READ connectionState
               NOTIFY connectionStateChanged)
    Q_PROPERTY(bool chatRunning READ chatRunning NOTIFY chatRunningChanged)
    Q_PROPERTY(QString statusText READ statusText
               NOTIFY connectionStateChanged)
    Q_PROPERTY(QVariantList sessions READ sessions
               NOTIFY sessionsChanged)
    Q_PROPERTY(QString currentSessionKey READ currentSessionKey
               WRITE setCurrentSessionKey NOTIFY currentSessionChanged)
    Q_PROPERTY(QString currentTaskSessionKey READ currentTaskSessionKey
               NOTIFY currentTaskSessionChanged)
    Q_PROPERTY(QString currentTaskWorkspace READ currentTaskWorkspace
               NOTIFY currentTaskWorkspaceChanged)
    Q_PROPERTY(QString currentViewSessionKey READ currentViewSessionKey
               NOTIFY currentViewSessionChanged)
    Q_PROPERTY(QVariantList collaborationParticipants READ collaborationParticipants
               NOTIFY collaborationParticipantsChanged)
    Q_PROPERTY(QVariantList skillList READ skillList
               NOTIFY skillListChanged)
    Q_PROPERTY(QVariantList cronJobs READ cronJobs
               NOTIFY cronJobsChanged)
    Q_PROPERTY(QVariantMap cronServiceStatus READ cronServiceStatus
               NOTIFY cronStatusChanged)
    Q_PROPERTY(QVariantMap agentIdentity READ agentIdentity
               NOTIFY agentIdentityChanged)
    Q_PROPERTY(QVariantList agentList READ agentList
               NOTIFY agentListChanged)
    Q_PROPERTY(QVariantList taskSessionList READ taskSessionList
               NOTIFY taskSessionListChanged)
    Q_PROPERTY(QVariantList projectList READ projectList
               NOTIFY projectListChanged)
    Q_PROPERTY(QString currentProjectId READ currentProjectId
               NOTIFY currentProjectChanged)
    Q_PROPERTY(QString currentProjectTitle READ currentProjectTitle
               NOTIFY currentProjectChanged)
    Q_PROPERTY(QString currentProjectWorkspace READ currentProjectWorkspace
               NOTIFY currentProjectChanged)
    Q_PROPERTY(QString defaultAgentId READ defaultAgentId
               NOTIFY agentListChanged)
    Q_PROPERTY(QVariantList modelList READ modelList
               NOTIFY modelListChanged)
    Q_PROPERTY(QVariantMap currentModel READ currentModel
               NOTIFY currentModelChanged)
    /// 无会话时用户选择的模型 id，首条消息创建会话后会通过 sessions.patch 应用
    Q_PROPERTY(QString pendingSessionModelId READ pendingSessionModelId
               NOTIFY pendingSessionModelIdChanged)
    /// OpenClaw 配置中的 mcp.servers（来自 config.get）
    Q_PROPERTY(QVariantList mcpList READ mcpList
               NOTIFY mcpListChanged)
    /// tools.catalog 展平后的工具列表（含 enabled，与 config 中 deny 对齐）
    Q_PROPERTY(QVariantList toolList READ toolList
               NOTIFY toolListChanged)
    Q_PROPERTY(QVariantList docxTemplates READ docxTemplates
               NOTIFY docxTemplatesChanged)
    Q_PROPERTY(bool docxTemplatesLoading READ docxTemplatesLoading
               NOTIFY docxTemplatesLoadStateChanged)
    Q_PROPERTY(bool toolInstallBusy READ toolInstallBusy
               NOTIFY toolInstallStateChanged)
    Q_PROPERTY(int toolInstallProgress READ toolInstallProgress
               NOTIFY toolInstallStateChanged)
    Q_PROPERTY(QString toolInstallMessage READ toolInstallMessage
               NOTIFY toolInstallStateChanged)
    Q_PROPERTY(QString toolInstallingId READ toolInstallingId
               NOTIFY toolInstallStateChanged)
    Q_PROPERTY(bool agentInstallBusy READ agentInstallBusy
               NOTIFY agentInstallStateChanged)
    Q_PROPERTY(int agentInstallProgress READ agentInstallProgress
               NOTIFY agentInstallStateChanged)
    Q_PROPERTY(QString agentInstallMessage READ agentInstallMessage
               NOTIFY agentInstallStateChanged)
    Q_PROPERTY(QString agentInstallingId READ agentInstallingId
               NOTIFY agentInstallStateChanged)
    /// 尚无侧栏 agent 时用户在聊天栏勾选技能后的暂存（待新建 agent 后写入 config）
    Q_PROPERTY(bool pendingNewAgentSkillPolicySet READ pendingNewAgentSkillPolicySet
               NOTIFY pendingNewAgentSkillPolicyChanged)
    /// 与 AppData/config.json 中 serverUrl 一致（握手 token/clientId 亦来自该文件）
    Q_PROPERTY(QString serverUrl READ serverUrl CONSTANT)
    /// 将 serverUrl 的 ws/wss 转为 http/https、去掉 path，用于 POST /tools/invoke 等 Gateway HTTP API
    Q_PROPERTY(QString gatewayHttpBaseUrl READ gatewayHttpBaseUrl CONSTANT)
    /// config.json 中的 gateway 认证 token（与 WebSocket 握手一致）
    Q_PROPERTY(QString gatewayAuthToken READ gatewayAuthToken CONSTANT)
    Q_PROPERTY(bool knowledgeBaseDataDirReady READ knowledgeBaseDataDirReady
               NOTIFY knowledgeBaseDataDirStateChanged)
    Q_PROPERTY(QString knowledgeBaseDataDirMessage READ knowledgeBaseDataDirMessage
               NOTIFY knowledgeBaseDataDirStateChanged)
    /// 技能市场列表；新数据源接入前保持为空
    Q_PROPERTY(QVariantList skillMarketFolders READ skillMarketFolders
               NOTIFY skillMarketFoldersChanged)
    /// 正在安装技能（复制 + 请求网关重启）
    Q_PROPERTY(bool skillInstallBusy READ skillInstallBusy NOTIFY skillInstallBusyChanged)

    /// 设置 — 记忆开关（来自 agents.defaults.memorySearch.enabled）
    Q_PROPERTY(bool memoryEnabled READ memoryEnabled NOTIFY memoryEnabledChanged)
    /// 设置 — LLM 二级判定开关（本地存储）
    Q_PROPERTY(bool llmJudgmentEnabled READ llmJudgmentEnabled NOTIFY llmJudgmentEnabledChanged)
    /// 设置 — 沙箱模式 0=auto 1=local(off) 2=sandbox-only(all)
    Q_PROPERTY(int sandboxMode READ sandboxMode NOTIFY sandboxModeChanged)
    /// 设置 — 记忆条目列表（本地 JSON）
    Q_PROPERTY(QVariantList memoryEntries READ memoryEntries NOTIFY memoryEntriesChanged)

public:
    /**
     * @brief 连接状态枚举
     *
     * 状态转换图：
     *   Disconnected ──connectToServer()──→ Connecting
     *   Connecting ──onConnected()──→ Handshaking
     *   Handshaking ──hello-ok──→ Connected
     *   任意状态 ──断开/错误──→ Disconnected
     */
    enum ConnectionState {
        Disconnected = 0,   ///< 未连接（初始状态 / 断开后）
        Connecting,         ///< TCP 连接中（WebSocket 升级尚未完成）
        Handshaking,        ///< 协议握手中（等待 challenge / 等待 hello-ok）
        Connected           ///< 已连接且握手成功，可正常通信
    };
    Q_ENUM(ConnectionState)

    explicit GatewayClient(QObject *parent = nullptr);
    ~GatewayClient();

    // ═══════════════════════════════════════════════════════════════
    //  属性访问器（供 QML 绑定）
    // ═══════════════════════════════════════════════════════════════

    /// WebSocket 服务器地址（来自 config.json）
    QString serverUrl() const;
    QString gatewayHttpBaseUrl() const;
    QString gatewayAuthToken() const;
    bool knowledgeBaseDataDirReady() const { return m_knowledgeBaseDataDirReady; }
    QString knowledgeBaseDataDirMessage() const { return m_knowledgeBaseDataDirMessage; }
    /// 切换本地任务会话所属用户；列表和后续写入均按该用户隔离。
    void setTaskSessionUserId(const QString &userId);

    /// 获取当前连接状态（枚举值）
    int connectionState() const;
    /// 当前聊天运行是否仍在服务端执行
    bool chatRunning() const { return m_chatRunning; }
    /// 获取当前连接状态的中文描述文本
    QString statusText() const;
    /// 获取会话列表（委托给 WsSession）
    QVariantList sessions() const;
    /// 获取当前活跃会话 key（委托给 WsSession）
    QString currentSessionKey() const;
    /// 当前任务的主控 sessionKey（发送消息始终优先走它）
    QString currentTaskSessionKey() const;
    /// 当前任务对应的业务 workspace（来自本地 task_sessions）
    QString currentTaskWorkspace() const;
    /// 当前聊天区正在查看的 sessionKey
    QString currentViewSessionKey() const;
    /// 当前任务的主控/子 agent 参与者列表
    QVariantList collaborationParticipants() const;
    /// 获取技能列表（委托给 WsSkill）
    QVariantList skillList() const;
    /// 获取定时任务列表（委托给 WsScheduledTask）
    QVariantList cronJobs() const;
    /// 获取 cron 服务状态（委托给 WsScheduledTask）
    QVariantMap cronServiceStatus() const;
    /// 获取当前 agent 身份信息
    QVariantMap agentIdentity() const;
    /// 获取 agent 列表（通过 agents.list RPC 获取）
    QVariantList agentList() const;
    /// 获取本地 SQLite 任务会话列表
    QVariantList taskSessionList() const;
    /// 获取本地项目列表；每个项目包含同一 workspace 下的 sessions。
    QVariantList projectList() const;
    QString currentProjectId() const;
    QString currentProjectTitle() const;
    QString currentProjectWorkspace() const;
    /// 获取默认 agent ID
    QString defaultAgentId() const;
    /// 获取可用模型列表
    QVariantList modelList() const;
    /// 获取当前会话的模型信息
    QVariantMap currentModel() const;
    /// 无会话时待应用的模型 id（与 pendingSessionModelId 属性同源）
    QString pendingSessionModelId() const;

    /// 已配置的 MCP 服务器列表（展示用）
    QVariantList mcpList() const;
    /// 运行时工具目录（tools.catalog + deny 状态）
    QVariantList toolList() const;
    QVariantList docxTemplates() const;
    bool docxTemplatesLoading() const;
    bool toolInstallBusy() const;
    int toolInstallProgress() const;
    QString toolInstallMessage() const;
    QString toolInstallingId() const;
    bool agentInstallBusy() const;
    int agentInstallProgress() const;
    QString agentInstallMessage() const;
    QString agentInstallingId() const;

    QVariantList skillMarketFolders() const;
    bool skillInstallBusy() const;

    // ═══════════════════════════════════════════════════════════════
    //  QML 可调用方法（Q_INVOKABLE）
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 发起 WebSocket 连接
     * @param url 服务器地址，默认 ws://127.0.0.1:18789
     *
     * 流程：
     *   1. 如果已连接，先关闭旧连接
     *   2. 清空握手状态和 pending 请求
     *   3. 切换到 Connecting 状态
     *   4. 调用 QWebSocket::open() 发起连接
     */
    Q_INVOKABLE void connectToServer(
        const QString &url = QStringLiteral("ws://127.0.0.1:18789"));

    /// 主动断开 WebSocket 连接
    Q_INVOKABLE void disconnectFromServer();

    /// 中止当前会话正在执行的聊天运行（服务端仍保持连接）
    Q_INVOKABLE void abortChat(const QString &sessionKey = QString());

    /**
     * @brief 发送聊天消息
     * @param message    用户输入的消息文本
     * @param sessionKey 目标会话 key（空则使用当前会话）
     * @param workspaceForNewAgent 兼容旧 QML 参数；当前无会话时会在默认/当前 agent 下创建 session
     */
    Q_INVOKABLE void sendChatMessage(const QString &message,
                                     const QString &sessionKey = QString(),
                                     const QString &workspaceForNewAgent = QString());

    /// 确保任务工作目录存在；空路径时使用安装目录下的按日期默认目录。
    Q_INVOKABLE QString prepareTaskWorkspace(const QString &workspace = QString());

    /// Persist and restore files supplied by the user for the active task session.
    Q_INVOKABLE void rememberCurrentSessionInputFiles(const QVariantList &files);
    Q_INVOKABLE QVariantList currentSessionInputFiles();
    void rememberInputFilesFromHistory(const QVariantList &history);

    void persistSessionArtifacts(const QString &sessionKey,
                                 const QVariantList &messages);
    void persistDetectedArtifacts(const QString &sessionKey,
                                  const QVariantList &artifacts);
    QVariantList restoreSessionArtifacts(const QString &sessionKey,
                                          const QVariantList &history);
    /// True when artifact results for artifactSessionKey should be shown on
    /// the currently viewed Q&A session (same task, including a switched
    /// collaboration expert).
    bool artifactResultsBelongToView(const QString &artifactSessionKey,
                                     const QString &viewSessionKey) const;

    /// 刷新会话列表（发送 sessions.list RPC）
    Q_INVOKABLE void refreshSessions();

    /// 创建新会话（发送 sessions.create RPC，在当前 agent 下新增 session）
    Q_INVOKABLE void createNewSession();

    /// 删除指定会话（发送 sessions.delete RPC）
    Q_INVOKABLE void deleteSession(const QString &sessionKey);
    /// 从本地任务列表软删除任务会话（不删除 agent）
    Q_INVOKABLE void deleteTaskSession(const QString &sessionKey);
    /// 更新本地任务会话的置顶状态。
    Q_INVOKABLE void setTaskSessionPinned(const QString &sessionKey, bool pinned);
    /// 更新本地任务会话标题。
    Q_INVOKABLE void renameTaskSession(const QString &sessionKey, const QString &title);
    /// 在系统文件管理器中打开任务会话的工作空间。
    Q_INVOKABLE bool openTaskSessionFolder(const QString &sessionKey) const;
    /// 创建项目；workspace 为空时在默认项目目录中创建独立工作空间。
    Q_INVOKABLE QString createProject(const QString &title,
                                      const QString &workspace = QString());
    /// 软删除项目及其本地会话记录，不删除磁盘中的项目文件。
    Q_INVOKABLE void deleteProject(const QString &projectId);
    Q_INVOKABLE bool openProjectFolder(const QString &projectId) const;
    /// 清空当前会话并将下一条新会话固定到指定项目 workspace。
    Q_INVOKABLE void beginProjectChat(const QString &projectId);
    Q_INVOKABLE void clearProjectSelection();

    /// 切换当前活跃会话
    Q_INVOKABLE void setCurrentSessionKey(const QString &key);
    /// 新建任务前设置协作 agent；第一个为主控，其余由主控通过 sessions_spawn 拉起
    Q_INVOKABLE void setPendingCollaborationAgents(const QVariantList &agentIds);
    Q_INVOKABLE QVariantList pendingCollaborationAgentIds() const;
    /// 点击协作参与者时，只切换聊天记录展示，不改变主控发送目标
    Q_INVOKABLE void switchCollaborationViewSession(const QString &sessionKey);

    /// 加载当前会话的历史消息（发送 messages.list RPC）
    Q_INVOKABLE void loadHistory();

    /// 获取所有 Agent 列表（发送 agents.list RPC）
    Q_INVOKABLE void refreshAgents();

    /// 安装所选专家的运行环境；完成后由 agentInstallFinished 通知界面。
    Q_INVOKABLE void summonAgent(const QString &agentId);

    /**
     * @brief 创建新 Agent（agents.create RPC）
     * @param name      agent 名称（服务端自动 normalizeAgentId 生成 ID）
     * @param workspace 工作空间路径
     */
    Q_INVOKABLE void createAgent(const QString &name,
                                  const QString &workspace,
                                  bool applyPendingToolSelection = true,
                                  const QString &identityMarkdown = QString());

    /**
     * @brief 更新 Agent 基本信息（agents.update RPC）
     * @param agentId 要更新的 agent ID
     * @param name 新显示名，空则不修改
     * @param workspace 新身份 workspace，空则不修改
     * @param model 新模型，空则不修改
     */
    Q_INVOKABLE void updateAgent(const QString &agentId,
                                  const QString &name = QString(),
                                  const QString &workspace = QString(),
                                  const QString &model = QString());

    /**
     * @brief 更新 Agent 固定身份目录中的 IDENTITY.md（本地文件写入）
     * @param agentId 要更新的 agent ID
     * @param identityMarkdown 新的 IDENTITY.md 内容
     */
    Q_INVOKABLE void updateAgentIdentity(const QString &agentId,
                                          const QString &identityMarkdown);

    /**
     * @brief 尚无 agent 时用户在工具弹窗点「保存」：记录将启用的 toolId，待首个 agent 创建后与 profile=full 一并写入 config
     */
    Q_INVOKABLE void setPendingNewAgentToolSelection(const QVariantList &enabledToolIds);

    /**
     * @brief 尚无 agent 时在聊天栏勾选技能：暂存白名单，待新建 agent 后与工具策略一并 config.set
     */
    Q_INVOKABLE void setPendingNewAgentSkillSelection(const QVariantList &skillNames);
    Q_INVOKABLE QVariantList pendingNewAgentSkillNames() const;
    bool pendingNewAgentSkillPolicySet() const { return m_pendingNewAgentSkillPolicySet; }

    /**
     * @brief 删除 Agent（agents.delete RPC）
     * @param agentId    要删除的 agent ID
     * @param deleteFiles 是否同时删除 workspace/sessions 文件，默认 true
     */
    Q_INVOKABLE void deleteAgent(const QString &agentId,
                                  bool deleteFiles = true);

    /// 获取所有技能状态（发送 skills.status RPC）
    Q_INVOKABLE void refreshSkills();

    /// 启用/禁用指定技能（发送 skills.update RPC，修改全局 skills.entries）
    Q_INVOKABLE void setSkillEnabled(const QString &skillKey, bool enabled);

    /**
     * @brief 按 agents.list[].skills 更新当前 Agent 技能白名单（config.set 全量写入）
     *
     * 与聊天输入栏技能开关、工具批量保存、OpenClaw Web「Agents → Skills」一致；agentId 为空时用 defaultAgentId。
     */
    Q_INVOKABLE void setAgentSkillEnabled(const QString &agentId, const QString &skillName,
                                          bool enabled);
    /// 配置中该 Agent 已选技能名；无 skills 键时返回 skills.status 中的全部技能名
    Q_INVOKABLE QStringList selectedSkillNamesForAgent(const QString &agentId) const;

    /// 新技能市场数据源接入前清空 skillMarketFolders
    Q_INVOKABLE void refreshSkillMarketFolders();

    /**
     * @brief 将技能市场某文件夹复制到 skillsStoragePath；本地完成后刷新 skills.status，不重启网关
     */
    Q_INVOKABLE void installSkillFromMarket(const QString &folderName);

    /// 将 ZIP 复制到 skillsStoragePath 后解压到同名子目录（本地操作，无需已连接网关）
    Q_INVOKABLE void addSkillFromZip(const QString &zipFilePath);
    /// 将所选文件夹递归复制到 skillsStoragePath（与文件夹同名）
    Q_INVOKABLE void addSkillFromFolder(const QString &folderPath);
    /// 在 skillsStoragePath 下执行 git clone（需系统已安装 git）
    Q_INVOKABLE void addSkillFromGit(const QString &cloneUrl);

    // ── 定时任务管理 ──

    /// 刷新定时任务列表（发送 cron.list RPC）
    Q_INVOKABLE void refreshCronJobs(bool includeDisabled = false);

    /// 获取 cron 服务状态（发送 cron.status RPC）
    Q_INVOKABLE void refreshCronStatus();

    /**
     * @brief 专用 agent 定时任务：显示名（与 createAgent 的 name 一致）
     */
    Q_INVOKABLE QString cronDedicatedAgentDisplayName(const QString &taskTitle) const;

    /**
     * @brief 暂存定时任务参数，在当前 agent 下创建专用 session 后再发 cron.add
     * @param scheduleKind 1=cron 表达式 2=固定间隔(秒) 3=一次性 ISO 时间
     */
    Q_INVOKABLE void prepareCronJobWithDedicatedAgent(int scheduleKind,
                                                       const QString &jobName,
                                                       const QString &message,
                                                       const QString &cronExpr,
                                                       const QString &tz,
                                                       int intervalSec,
                                                       const QString &isoDateTime,
                                                       const QString &workspace = QString());

    /**
     * @brief 添加 cron 表达式定时任务
     * @param name      任务名称
     * @param cronExpr  cron 表达式（如 "0 9 * * 1-5"）
     * @param message   触发时发送给 agent 的消息
     * @param tz        时区（默认 Asia/Shanghai）
     */
    Q_INVOKABLE void addCronJob(const QString &name,
                                const QString &cronExpr,
                                const QString &message,
                                const QString &tz = QStringLiteral("Asia/Shanghai"));

    /**
     * @brief 添加固定间隔定时任务
     * @param name      任务名称
     * @param intervalSec 执行间隔（秒）
     * @param message   触发时发送给 agent 的消息
     */
    Q_INVOKABLE void addIntervalJob(const QString &name,
                                    int intervalSec,
                                    const QString &message);

    /**
     * @brief 添加一次性定时任务
     * @param name      任务名称
     * @param dateTime  执行时间（ISO 格式字符串或 QML Date）
     * @param message   触发时发送给 agent 的消息
     */
    Q_INVOKABLE void addOneTimeJob(const QString &name,
                                   const QString &dateTime,
                                   const QString &message);

    /// 启用/禁用定时任务
    Q_INVOKABLE void setCronJobEnabled(const QString &jobId, bool enabled);

    /// 更新当前用户定时任务的本地置顶状态。
    Q_INVOKABLE void setCronJobPinned(const QString &jobId, bool pinned);

    /// 删除定时任务
    Q_INVOKABLE void removeCronJob(const QString &jobId);

    /// 手动触发定时任务
    Q_INVOKABLE void runCronJobNow(const QString &jobId);

    /**
     * @brief 更新定时任务名称与载荷文案（cron.update patch）
     * @param payloadKind 与任务一致：agentTurn 用 message；systemEvent 用 text
     */
    Q_INVOKABLE void updateCronJobContent(const QString &jobId,
                                          const QString &name,
                                          const QString &content,
                                          const QString &payloadKind,
                                          int scheduleKind = 0,
                                          const QString &scheduleExpr = QString(),
                                          const QString &scheduleTz = QString());

    /// 查询执行记录（空 jobId 查全部）
    Q_INVOKABLE void loadCronRuns(const QString &jobId = QString());

    /**
     * @brief 切换 Agent（依次发送 agent.identity.get + chat.history + sessions.list）
     * @param agentId agent ID（如 "main"、"coder"）
     *
     * 默认 sessionKey = "agent:<agentId>:main"；定时任务专用 agent（名称以「定时-」开头）
     * 且存在 cron 会话时，使用 "agent:<agentId>:cron:<uuid>"，
     * 切换 currentSessionKey 并发送三个 RPC 请求。
     */
    Q_INVOKABLE void switchAgent(const QString &agentId);
    /// 切换左侧任务会话：任务列表基于 SQLite，不再等价于 agent 列表
    Q_INVOKABLE void switchTaskSession(const QString &sessionKey);

    /**
     * @brief 清除当前选中的 agent 会话（不加载任何历史）
     *
     * 用于「新建任务」入口：回到主聊天区但尚未绑定具体 agent。
     */
    /// 清除当前会话上下文；新建任务发送前可保留待应用的模型选择。
    Q_INVOKABLE void clearActiveAgentContext(bool clearModelSelection = true);

    /// 获取指定会话的 agent 身份信息（发送 agent.identity.get RPC）
    Q_INVOKABLE void getAgentIdentity(const QString &sessionKey = QString());

    /// 加载指定会话的聊天历史（发送 chat.history RPC）
    Q_INVOKABLE void loadChatHistory(const QString &sessionKey = QString(),
                                      int limit = 200);

    /// 获取可用模型列表（发送 models.list RPC）
    Q_INVOKABLE void refreshModels();

    /**
     * @brief 查询或设置当前会话的模型（发送 sessions.patch RPC）
     * @param modelId 为空时查询当前模型（model:null）；非空时切换到指定模型。
     *                可以是裸 id（如 "deepseek-v4-pro"），内部会查 m_modelList
     *                自动拼成 "provider/id" 全限定 ref；也可以直接传入
     *                "provider/id" 全限定形式。
     */
    Q_INVOKABLE void patchSessionModel(const QString &modelId = QString());

    /// 拉取配置快照并解析 mcp.servers（config.get）
    Q_INVOKABLE void refreshMcpList();

    /// 按登录用户通过 config.set 更新 KB 插件 dataDir，不主动重启 Gateway。
    Q_INVOKABLE void configureKnowledgeBaseForUser(const QString &userId);

    /// 拉取 tools.catalog（agentId 空则用 defaultAgentId）
    Q_INVOKABLE void refreshToolsCatalog(const QString &agentId = QString());

    /// 拉取 docx-generator 内置模板目录。
    Q_INVOKABLE void refreshDocxTemplates();

    /**
     * @brief 通过 agents.list[].tools.deny 启用/禁用工具（config.set，不重启 Gateway）
     */
    Q_INVOKABLE void setAgentToolEnabled(const QString &agentId, const QString &toolId,
                                         bool enabled,
                                         const QString &pluginId = QString());

    /**
     * @brief 批量设置工具启用状态，单次 config.set 写入完整配置
     */
    Q_INVOKABLE void batchSetAgentToolsEnabled(const QString &agentId,
                                                const QVariantList &enabledToolIds);

    /**
     * @brief 通过 config.patch 写入 mcp.servers 条目
     * @param isEdit 是否编辑已有条目（名称变更时会删除旧键）
     * @param originalServerName 编辑前的服务名（新建时为空）
     * @param useHttp true=HTTP/SSE（用 httpUrl），false=stdio（command + 参数行）
     */
    Q_INVOKABLE void applyMcpServer(bool isEdit,
                                     const QString &originalServerName,
                                     const QString &serverName,
                                     bool useHttp,
                                     const QString &stdioCommand,
                                     const QString &stdioArgsMultiline,
                                     const QString &httpUrl,
                                     const QString &description,
                                     const QString &envJson = QString());

    /// 从配置中删除 mcp.servers 某键（merge patch null）
    Q_INVOKABLE void removeMcpServer(const QString &serverName);

    /// 将 UTF-8 文本写入本地文件（测试页导出技能列表等）
    Q_INVOKABLE bool saveTextToFile(const QString &localPath, const QString &content);

    // ── 设置：记忆 / 沙箱 ──
    bool memoryEnabled() const { return m_memoryEnabled; }
    bool llmJudgmentEnabled() const { return m_llmJudgmentEnabled; }
    int  sandboxMode() const { return m_sandboxMode; }
    QVariantList memoryEntries() const { return m_memoryEntries; }

    /// 保存通用设置（记忆开关 + LLM 判定 + 沙箱模式）→ config.patch
    Q_INVOKABLE void saveGeneralSettings(bool memoryEnabled, bool llmJudgment, int sandboxMode);
    /// 刷新本地记忆条目列表
    Q_INVOKABLE void loadMemoryEntries();
    Q_INVOKABLE void addMemoryEntry(const QString &title, const QString &content);
    Q_INVOKABLE void updateMemoryEntry(const QString &id, const QString &title, const QString &content);
    Q_INVOKABLE void deleteMemoryEntry(const QString &id);

signals:
    // ── 连接状态 ──
    void connectionStateChanged();  ///< 连接状态发生变化
    void knowledgeBaseDataDirStateChanged();

    // ── 聊天消息 ──
    void chatMessageReceived(const QString &role,
                             const QString &content,
                             bool isDelta);      ///< 收到聊天消息（完整或增量）
    void streamingStarted();                     ///< 流式输出开始
    void streamingFinished();                    ///< 流式输出结束
    void chatRunningChanged();                   ///< 当前聊天运行状态变化

    // ── 工具调用 ──
    void artifactsDetected(const QString &sessionKey,
                           const QVariantList &artifacts);
    void toolCallReceived(const QString &toolName,
                          const QString &toolArgs,
                          const QString &toolCallId);    ///< Agent 发起工具调用
    void toolUpdateReceived(const QString &toolName,
                            const QString &content,
                            const QString &toolCallId);  ///< 工具执行中的增量输出
    void toolResultReceived(const QString &toolName,
                            const QString &content,
                            const QString &toolCallId,
                            bool isError);               ///< 工具执行结果返回

    // ── 错误 ──
    void errorOccurred(const QString &message);  ///< 发生错误

    // ── 会话管理 ──
    void sessionsChanged();          ///< 会话列表更新
    void currentSessionChanged();    ///< 当前活跃会话切换
    void currentTaskSessionChanged(); ///< 当前任务主控会话切换
    void currentTaskWorkspaceChanged(); ///< 当前任务 workspace 变化
    void currentViewSessionChanged(); ///< 当前查看会话切换
    void collaborationParticipantsChanged(); ///< 协作参与者列表更新
    void sessionCreated();           ///< 新会话创建成功
    void historyLoaded(const QVariantList &messages); ///< 历史消息加载完成
    void toolResultsRefreshed(const QVariantList &messages); ///< 工具结果补拉完成（原地合并）

    // ── 技能管理 ──
    void skillListChanged();         ///< 技能列表更新
    void skillUpdated(const QString &skillKey, bool enabled); ///< 技能状态变更

    // ── 定时任务管理 ──
    void cronJobsChanged();          ///< 任务列表更新
    void cronStatusChanged();        ///< cron 服务状态更新
    void cronJobAdded(const QString &jobId);   ///< 新任务添加成功
    void cronJobRemoved(const QString &jobId); ///< 任务删除成功
    void cronJobUpdated(const QString &jobId); ///< 任务更新成功
    void cronRunTriggered(const QString &jobId); ///< 手动触发成功
    void cronRunsLoaded(const QVariantList &runs); ///< 执行记录加载完成

    // ── 设置 ──
    void memoryEnabledChanged();
    void llmJudgmentEnabledChanged();
    void sandboxModeChanged();
    void memoryEntriesChanged();
    void settingsSaved();

    // ── Agent 管理 ──
    void agentIdentityChanged();     ///< Agent 身份信息更新
    void agentListChanged();         ///< Agent 列表更新
    void taskSessionListChanged();   ///< 本地任务会话列表更新
    void projectListChanged();       ///< 本地项目及其会话列表更新
    void currentProjectChanged();    ///< 当前/待创建会话所属项目变化
    void agentCreated(const QString &agentId, bool success,
                      const QString &message,
                      bool forChat); ///< 新 Agent 创建结果
    void agentDeleted(const QString &agentId, bool success,
                      const QString &message); ///< Agent 删除结果
    void agentInstallStateChanged();
    void agentInstallFinished(const QString &agentId, bool success,
                              const QString &message);

    // ── 模型管理 ──
    void modelListChanged();              ///< 可用模型列表更新
    void currentModelChanged();           ///< 当前会话模型信息变更
    void pendingSessionModelIdChanged();  ///< 无会话时待选模型变更
    void skillMarketFoldersChanged();     ///< 技能市场目录列表更新
    void skillInstallBusyChanged();       ///< 技能安装进行中状态变更
    void mcpListChanged();                ///< MCP 服务器列表更新
    void toolListChanged();               ///< 工具目录列表更新
    void docxTemplatesChanged();          ///< DOCX 预设模板目录更新
    void docxTemplatesLoadStateChanged(); ///< DOCX 模板目录加载状态更新
    void toolInstallStateChanged();       ///< 工具安装进度或状态更新
    void pendingNewAgentSkillPolicyChanged(); ///< 新建 agent 前技能暂存变更

private slots:
    // ── WebSocket 事件槽函数 ──

    /// WebSocket 连接建立成功（TCP + 协议升级完成）
    void onConnected();
    /// WebSocket 连接断开（主动或被动）
    void onDisconnected();
    /// 收到服务器文本消息（所有入站 JSON 帧的入口）
    void onTextMessageReceived(const QString &message);
    /// WebSocket 底层错误
    void onSocketError(QAbstractSocket::SocketError error);

private:
    // ═══════════════════════════════════════════════════════════════
    //  内部方法
    // ═══════════════════════════════════════════════════════════════

    /// 设置连接状态并发射 connectionStateChanged 信号
    void setState(ConnectionState state);
    void setChatRunning(bool running);
    void updateChatRunningForCurrentSession();

    /**
     * @brief 处理入站事件帧（type: "event"）
     * @param msg 完整的 JSON 对象
     *
     * 处理流程：
     *   1. connect.challenge → 提取 nonce，发送 connect 请求
     *   2. tick / heartbeat → 忽略
     *   2.5 cron → 定时任务状态推送，刷新任务列表
     *   3. agent / chat 事件 → 委托给 WsSession::parseEvent()
     *      根据返回的 WsEventResult 发射对应信号
     */
    void handleEvent(const QJsonObject &msg);

    /**
     * @brief 解析 chat 事件中的结构化消息
     * @param payload chat 事件的 payload 对象
     * @return true 表示已处理（含 toolCall / toolResult），false 表示需走常规流程
     *
     * OpenClaw chat 事件的 payload.data 可能包含完整消息对象：
     *   - role: "assistant" + content 数组含 toolCall → 发射 toolCallReceived
     *   - role: "toolResult" → 发射 toolResultReceived
     *   - content 数组含 text → 发射 chatMessageReceived（非 delta）
     */
    bool handleStructuredChatEvent(const QJsonObject &payload);

    /**
     * @brief 处理入站响应帧（type: "res"）
     * @param msg 完整的 JSON 对象
     *
     * 处理流程：
     *   1. 通过 requestId 从 m_pendingRequests 查找原始方法名
     *   2. connect 响应 → 完成握手，进入 Connected
     *   3. sessions.list → 委托 WsSession 解析，发射 sessionsChanged
     *   4. sessions.create → 刷新列表，发射 sessionCreated
     *   5. sessions.delete → 刷新列表
     *   6. messages.list → 委托 WsSession 解析，发射 historyLoaded
     *   7. cron.list / cron.status / cron.add / cron.update /
     *      cron.remove / cron.run / cron.runs → 委托 WsScheduledTask 解析
     */
    void handleResponse(const QJsonObject &msg);

    /**
     * @brief 发送 connect 握手请求
     *
     * 由 handleEvent 在收到 connect.challenge 后调用。
     * 参数由 WsConfig::buildConnectParams() 构建。
     */
    void sendConnectRequest();

    /// 根据 sessions.list 缓存，为每个 agent 填入最近活跃会话的标题与时间；有改动返回 true
    bool mergeSessionHintsIntoAgentList();

    /**
     * @brief 绑定 sessionKey 并拉取身份 / 可选历史 / 会话列表 / 模型
     * @param shouldLoadHistory 为 false 时不请求 chat.history（首条消息 bootstrap 时避免空历史清空 UI）
     */
    void applyAgentSwitch(const QString &agentId, bool shouldLoadHistory);

    /// agent 回复结束后，刷新侧栏标题 + 会话列表（异步延迟，等 transcript 落盘）
    void schedulePostStreamSidebarRefresh();

    /// 合并 agents / sessions 后防抖拉取各 agent 首条用户消息，作为侧栏标题
    void scheduleAgentListFirstUserTitles();
    void flushAgentListFirstUserTitles();
    /// 拉取 session 列表中每个 session 的首条用户消息，作为任务标题
    void scheduleSessionListFirstUserTitles();
    void flushSessionListFirstUserTitles();
    void refreshSessionFirstUserTitle(const QString &sessionKey);
    /// 仅刷新一个 agent 的侧栏首句（避免每次 sessions.list 全量 chat.history）
    void refreshSidebarFirstUserTitleForAgent(const QString &agentId);
    static QString firstUserMessageFromHistoryList(const QVariantList &history);
    void setAgentListSidebarTitle(const QString &agentId, const QString &text);
    void setCurrentTaskSessionKeyInternal(const QString &key);
    void setCurrentViewSessionKeyInternal(const QString &key);
    QVariantMap agentInfoById(const QString &agentId) const;
    QVariantMap sessionInfoByKey(const QString &sessionKey) const;
    QString displayNameForSession(const QVariantMap &session) const;
    QString agentIdFromSessionKey(const QString &sessionKey) const;
    bool sessionBelongsToTask(const QVariantMap &session, const QString &taskKey) const;
    QString normalizeWorkspacePath(const QString &workspace) const;
    QString prepareCronWorkspace(const QString &workspace);
    QString buildCollaborationPrompt(const QString &userMessage,
                                      const QStringList &participantAgentIds) const;
    QJsonObject buildConfigWithSubagentAllowAgents(const QJsonObject &fullConfig,
                                                   const QString &controllerAgentId,
                                                   const QStringList &participantAgentIds,
                                                   bool *changed) const;
    void stashPendingCollaborationSend(const QString &controllerSessionKey,
                                       const QString &controllerAgentId,
                                       const QStringList &participantAgentIds,
                                       const QString &userMessage,
                                       const QString &businessWorkspace);
    void clearPendingCollaborationSend();
    bool maybeConfigureSubagentAllowAgents(const QString &controllerSessionKey,
                                           const QString &controllerAgentId,
                                           const QStringList &participantAgentIds,
                                           const QString &userMessage,
                                           const QString &businessWorkspace = QString());
    void sendPendingCollaborationChatNow();
    QJsonObject buildSessionsCreateParams(const QString &sessionKey,
                                           const QString &agentId,
                                           const QString &label,
                                           const QString &task = QString(),
                                           const QString &model = QString()) const;
    void patchSessionOutputDirBeforeSend(const QString &sessionKey,
                                         const QString &sessionOutputDir,
                                         const QString &message);
    void sendChatMessageNow(const QString &sessionKey,
                            const QString &message);
    struct WorkspaceFileState {
        qint64 size = 0;
        qint64 modifiedMs = 0;
        QString absolutePath;
    };
    typedef QHash<QString, WorkspaceFileState> WorkspaceSnapshot;
    struct ArtifactTrackingState {
        QString workspace;
        WorkspaceSnapshot before;
        quint64 generation = 0;
    };
    WorkspaceSnapshot snapshotWorkspace(const QString &workspace) const;
    QString resolveArtifactTrackingKey(const QString &sessionKey) const;
    QString workspaceForArtifactSession(const QString &sessionKey) const;
    void beginArtifactTracking(const QString &sessionKey, bool resetSnapshot = false);
    void finishArtifactTracking(const QString &sessionKey);
    static bool shouldIgnoreArtifactPath(const QString &relativePath);

    bool initTaskSessionDb();
    void loadTaskSessionListFromDb();
    void loadProjectListFromDb();
    void upsertTaskSessionLocal(const QString &sessionKey,
                                const QString &workspace,
                                const QString &title,
                                const QStringList &agentIds,
                                qint64 createdAt,
                                qint64 updatedAt,
                                const QString &projectId = QString());
    void touchTaskSessionLocal(const QString &sessionKey);
    void softDeleteTaskSessionLocal(const QString &sessionKey);
    QVariantMap taskSessionInfoByKey(const QString &sessionKey) const;
    QVariantMap projectInfoById(const QString &projectId) const;
    void setCurrentProjectIdInternal(const QString &projectId);
    QStringList taskSessionAgentIds(const QVariantMap &row) const;
    void setTaskSessionRunning(const QString &sessionKey, bool running);
    void updateTaskSessionRuntimeFromEvent(const QJsonObject &payload);
    bool isLocalOnlyCronTaskSession(const QString &sessionKey) const;
    QString cronJobIdFromSessionKey(const QString &sessionKey) const;
    void softDeleteCronTaskSessionsForJob(const QString &jobId);
    void reconcileCronTaskSessionsWithJobs();
    void loadCronJobOwnershipFromDb();
    void upsertCronJobOwnershipLocal(const QString &jobId,
                                     const QString &userId = QString());
    void setCronJobPinnedLocal(const QString &jobId, bool pinned);
    void softDeleteCronJobOwnershipLocal(const QString &jobId);
    bool isCronJobOwnedByCurrentUser(const QString &jobId) const;
    static QString taskTitleFromFirstMessage(const QString &message);
    static QString agentsJsonFromList(const QStringList &agentIds);
    static QStringList agentListFromJson(const QString &json);

    /// 聊天/历史/身份使用的 sessionKey（agent 行上可有 chatSessionKey）
    QString resolveChatSessionKeyForAgentId(const QString &agentId) const;

    /// 把模型 id 解析为 "provider/id" 全限定 ref，用于 sessions.patch
    QString qualifyModelRef(const QString &modelId) const;

    /**
     * @brief 解析 config.get 的 payload，更新 m_configSnapshotHash、m_mcpList
     *
     * 将 config 根对象写入 m_lastConfigSnapshot（优先 config，其次 resolved，再次 parsed）；
     * 并解析 agents.list[].workspace 供界面展示（agent.identity.get 不含 workspace）。
     */
    void applyMcpListFromConfigGetPayload(const QJsonObject &payload);
    void applyPendingKnowledgeBaseDataDir();
    void setKnowledgeBaseDataDirState(bool ready, const QString &message);
    static QString knowledgeBaseDataDirForUser(const QString &userId,
                                                const QString &baseDataDir);
    /// 从完整 config 对象填充 m_mcpList（按名称排序）
    void rebuildMcpListFromConfigObject(const QJsonObject &config);
    /// 从 config 根对象重建 agentId → workspace（及 agents.defaults.workspace）
    void rebuildAgentWorkspaceMapFromConfigObject(const QJsonObject &configRoot);
    QString resolveWorkspacePathForAgentId(const QString &agentId) const;
    /// 用当前 workspace 映射补全 m_agentIdentity["workspace"] 并 notify
    void mergeWorkspaceIntoAgentIdentity();

    QStringList allSkillNamesFromStatus() const;

    /// 定时任务专用：先 agents.create 再 cron.add 时使用的显示名
    static QString makeCronDedicatedAgentName(const QString &taskTitle);
    void clearPendingCronDedicatedAgent();
    void sendPendingCronAddWithAgentId(const QString &agentId);
    void createCronTaskSessionLocal(const QString &jobId,
                                    const QString &agentId,
                                    const QString &jobName,
                                    const QString &workspace);

    /// 生成唯一的请求 ID（UUID v4，不含花括号）
    QString nextRequestId();

    /**
     * @brief 发送 RPC 请求的统一入口
     * @param method RPC 方法名（如 sessions.list、chat.send）
     * @param params 请求参数对象
     * @return 生成的 requestId，用于追踪响应
     */
    QString sendRequest(const QString &method, const QJsonObject &params);

    /// 发送 config.set / config.patch，并暂存参数供 baseHash 过期时自动 config.get 后重试一次
    QString sendConfigMutation(const QString &method, const QJsonObject &params);
    void maybeRetryStashedConfigMutationAfterGet();
    static bool looksLikeConfigHashStaleError(const QString &errMsg);
    void applyPendingInstalledToolPolicy();
    void finishToolInstall(const QString &errorMessage = QString());
    void consumeToolInstallOutput(const QByteArray &bytes, bool flush = false);
    bool pluginNeedsProvisioning(const QString &pluginId,
                                 const QString &backendRoot) const;
    void consumeAgentInstallOutput(const QByteArray &bytes, bool flush = false);
    void finishAgentInstall(bool success, const QString &message);

    /// 从事件 payload 提取 sessionKey（兼容 data / agentId）
    QString extractPayloadSessionKey(const QJsonObject &payload) const;
    void rememberCollaborationChildSessionHint(const QJsonObject &payload);
    void refreshCollaborationSessionsAfterSpawn(const QString &toolName,
                                                const QString &toolResult);
    QVariantMap collaborationChildHintForAgent(const QString &agentId,
                                               const QString &taskKey) const;
    /// 当前 UI 是否应展示该会话的推送
    /// @param allowIfKeyMissing  若 payload 中无 sessionKey，是否默认允许
    bool eventAppliesToCurrentUiSession(
        const QJsonObject &payload,
        bool allowIfKeyMissing = false) const;

    // ═══════════════════════════════════════════════════════════════
    //  成员变量
    // ═══════════════════════════════════════════════════════════════

    // ── WebSocket 实例 ──
    QWebSocket     *m_socket;           ///< Qt WebSocket 客户端实例

    // ── 连接状态 ──
    ConnectionState m_state;            ///< 当前连接状态
    bool            m_chatRunning = false; ///< 当前聊天运行是否仍在服务端执行
    QSet<QString>   m_chatRunningSessionKeys; ///< 服务端仍在执行的聊天会话
    QString         m_connectRequestId; ///< connect 握手请求的 ID（用于匹配响应）
    QString         m_challengeNonce;   ///< 服务器下发的 challenge nonce

    // ── 请求追踪 ──
    QMap<QString, QString> m_pendingRequests; ///< 待处理请求映射（requestId → 方法名）

    // ── 子类实例 ──
    WsConfig         m_config;          ///< 配置类：连接参数、设备密钥
    WsSession        m_session;         ///< 会话类：会话管理、消息收发
    WsSkill          m_skill;           ///< 技能类
    WsScheduledTask  m_scheduledTask;   ///< 定时任务类：预留
    QVariantMap      m_agentIdentity;   ///< 当前 agent 身份缓存
    QVariantList     m_agentList;       ///< agents.list 缓存
    QVariantList     m_taskSessionList; ///< SQLite 任务会话缓存
    QVariantList     m_projectList;     ///< SQLite 项目缓存（含项目会话）
    QSqlDatabase     m_taskSessionDb;   ///< 本地任务会话 SQLite
    bool             m_taskSessionDbReady = false;
    QSet<QString>    m_runningTaskSessionKeys;
    QString          m_taskSessionUserId;
    QSet<QString>    m_currentUserCronJobIds; ///< 当前登录用户拥有的 cron job ID
    QSet<QString>    m_currentUserPinnedCronJobIds; ///< 当前用户置顶的 cron job ID
    QString          m_defaultAgentId;  ///< 默认 agent ID
    QString          m_currentTaskSessionKey; ///< 主控任务 sessionKey
    QString          m_currentViewSessionKey; ///< 聊天区当前查看 sessionKey
    QString          m_currentProjectId; ///< 当前任务或待新建会话所属项目
    QVariantList     m_collaborationChildSessionHints; ///< 实时发现的子 agent 会话（等待 sessions.list 落盘前）
    QStringList      m_pendingCollaborationAgentIds; ///< 新建任务前选择的协作 agent
    QString          m_pendingCollabControllerSessionKey;
    QString          m_pendingCollabControllerAgentId;
    QStringList      m_pendingCollabParticipantAgentIds;
    QString          m_pendingCollabUserMessage;
    QString          m_pendingCollabBusinessWorkspace;
    bool             m_pendingCollabAwaitingConfigGet = false;
    QSet<QString>    m_collabAllowConfigSetReqIds;
    QSet<QString>    m_localOnlyTaskSessionKeys; ///< 已入本地库但尚未 sessions.create 的任务
    QMap<QString, QString> m_pendingSessionsCreateReqSession; ///< reqId -> sessionKey
    QMap<QString, QString> m_pendingCreatedSessionMessages; ///< sessionKey -> create 后待发送消息
    struct PendingSessionOutputPatch {
        QString sessionKey;
        QString message;
    };
    QMap<QString, PendingSessionOutputPatch> m_pendingSessionOutputPatches; ///< patch reqId -> 后续发送

    QString m_pendingCreateName;       ///< agents.create 待确认名称
    QString m_pendingCreateWorkspace;  ///< agents.create 使用的 workspace 路径
    QString m_pendingCreateIdentityMarkdown; ///< agents.create 成功后写入 workspace/IDENTITY.md
    QString m_pendingDeleteId;         ///< agents.delete 待确认 ID
    QString m_pendingProfileFullAgentId; ///< agents.create 后待设置 tools.profile=full + deny 的 agentId
    QStringList m_pendingNewAgentEnabledToolIds; ///< 新建 agent 前用户在弹窗中选中的工具（空且未 set 表示用「全选」）
    bool m_pendingNewAgentToolPolicySet = false; ///< 用户是否已点过保存（无 agent 时）
    QStringList m_pendingNewAgentSkillNames;     ///< 新建 agent 前聊天栏选中的技能名（agents.list[].skills）
    bool m_pendingNewAgentSkillPolicySet = false; ///< 用户是否在无 agent 时改过技能勾选
    /// 刚创建完 agent、config.get 尚未写入 deny 前，切到该 agent 时不要清空待应用的 tool 选择
    QString m_expectingToolPolicyApplyForAgentId;

    /// 当前无选中会话时，首条聊天触发的 sessions.create 完成后要发送的文本
    QString m_pendingFirstChatMessage;
    bool m_pendingAgentCreateForChat = false;
    QString m_pendingFirstChatSessionCreateReqId;

    /// 新建 agent 并应用 config.set（deny 列表）后才发出的首条消息（兼容旧流程）
    QString m_pendingBootstrapChatMessage;

    /// 新建 agent 时暂存首句 + 时间，agents.list 回来后注入侧栏
    QString m_newAgentSidebarId;
    QString m_newAgentSidebarTitle;
    qint64  m_newAgentSidebarTs = 0;

    /// 创建定时任务时先建专用 agent：1=cron 2=interval 3=oneTime
    bool m_cronAwaitingDedicatedAgent = false;
    int m_cronPendingScheduleKind = 0;
    QString m_cronPendingJobName;
    QString m_cronPendingCronExpr;
    QString m_cronPendingMessage;
    QString m_cronPendingWorkspace;
    QString m_cronPendingTz;
    int m_cronPendingEveryMs = 0;
    QDateTime m_cronPendingAt;
    bool m_cronPendingDeleteAfterRun = false;
    struct PendingCronTaskSession {
        QString agentId;
        QString jobName;
        QString workspace;
        QString userId;
    };
    QMap<QString, PendingCronTaskSession> m_pendingCronTaskSessions; ///< cron.add reqId -> task row info

    /// 侧栏「首句问话」：chat.history 请求 id → agentId / 批次号（与切换会话的历史请求区分）
    QMap<QString, QString> m_sidebarTitleHistReqAgent;
    QMap<QString, quint64> m_sidebarTitleHistReqBatch;
    QMap<QString, QString> m_sessionTitleHistReqSession;
    QMap<QString, quint64> m_sessionTitleHistReqBatch;
    QMap<QString, QString> m_chatSendReqSession;
    QMap<QString, QString> m_chatSendReqMessage;
    QMap<QString, QString> m_chatAbortReqSession; ///< chat.abort requestId -> sessionKey
    QString m_activeChatRunId;                    ///< 当前聊天运行的服务端 runId
    QString m_activeChatSessionKey;               ///< 当前聊天运行所属 sessionKey
    QString m_recentlyAbortedChatSessionKey;      ///< 中止后用于过滤迟到的 complete 事件
    QHash<QString, ArtifactTrackingState> m_artifactTrackingBySession;
    quint64 m_sidebarTitleBatchGen = 0;
    quint64 m_sessionTitleBatchGen = 0;
    QTimer m_agentFirstUserTitleDebounce;
    QTimer m_sessionFirstUserTitleDebounce;

    /// 收到 toolResult 后防抖补拉历史；仅更新 toolResult 文本，不清空聊天模型
    QTimer m_toolResultRefreshTimer;
    QMap<QString, QString> m_toolResultRefreshReqSessions; ///< requestId -> view sessionKey

    // ── 模型管理 ──
    QVariantList m_modelList;          ///< 可用模型列表缓存（models.list 响应）
    QVariantMap  m_currentModel;       ///< 当前会话模型信息（sessions.patch 响应）
    QString m_pendingSessionModelId;   ///< 尚无 session 时用户选择的模型，有 session 后 patch
    QVariantList m_docxTemplates;      ///< docxTemplates.list 响应
    bool m_docxTemplatesLoading = false;

    QString m_lastConnectedWsUrl;      ///< 最近一次 connectToServer 的 URL（自动重连用）
    /// 收到 shutdown 事件时由 restartExpectedMs + 余量 写入；断线重连前消费
    int m_pendingReconnectDelayMs = 0;
    /// 自动重连：非用户主动断开时持续尝试恢复，退避间隔最大 5 秒
    bool m_userRequestedDisconnect = false;         ///< disconnectFromServer() 触发的断开，不自动重连
    bool m_skipAutoReconnectOnNextDisconnect = false; ///< connectToServer 为换新连接而 close 旧 socket
    bool m_connectFromAutoReconnect = false;        ///< 当前 connectToServer 由自动重连定时器发起
    int m_autoReconnectFailureCount = 0;            ///< 本轮自动重连已连续失败次数（成功或手动连接时清零）
    bool m_skillInstallBusy = false; ///< 技能安装流程进行中
    bool m_toolInstallBusy = false;
    int m_toolInstallProgress = 0;
    QString m_toolInstallMessage;
    QString m_toolInstallingId;
    QString m_pendingToolInstallAgentId;
    QString m_pendingToolInstallConfigGetReqId;
    QString m_pendingToolInstallMutationReqId;
    QByteArray m_toolInstallStdoutBuffer;
    bool m_toolInstallScriptFinished = false;
    bool m_agentInstallBusy = false;
    int m_agentInstallProgress = 0;
    QString m_agentInstallMessage;
    QString m_agentInstallingId;
    QByteArray m_agentInstallStdoutBuffer;
    QVariantList m_skillMarketFolders; ///< 技能市场子文件夹列表

    // ── 设置状态 ──
    bool m_memoryEnabled = true;
    bool m_llmJudgmentEnabled = false;
    int  m_sandboxMode = 0;
    QVariantList m_memoryEntries;
    void parseSettingsFromConfig();
    void saveMemoryEntriesToDisk();

    QString        m_configSnapshotHash; ///< config.get / config.patch 乐观锁 baseHash
    /// baseHash 不匹配时：暂存最后一次 config.set/patch 参数，先 refresh(config.get) 再重发一次
    QString        m_stashedConfigMutationMethod;
    QJsonObject    m_stashedConfigMutationParams;
    bool           m_configHashRetryAfterGet = false;
    bool           m_configHashRetryInFlight = false;
    QString        m_knowledgeBaseDataDirUserId;
    QString        m_knowledgeBaseDesiredDataDir;
    QString        m_pendingKnowledgeBaseConfigMutationReqId;
    bool           m_knowledgeBaseConfigMutationAwaitingRetry = false;
    bool           m_knowledgeBaseAwaitingRestart = false;
    bool           m_knowledgeBaseRestartObserved = false;
    bool           m_knowledgeBaseDataDirReady = false;
    QString        m_knowledgeBaseDataDirMessage;
    QVariantList   m_mcpList;          ///< mcp.servers 展示列表

    WsTools        m_tools;            ///< tools.catalog 与 tools 策略展平
    QJsonObject    m_lastConfigSnapshot; ///< config.get 解析出的配置根对象（供 tools / patch）

    QHash<QString, QString> m_agentWorkspaceById; ///< agents.list[].id → workspace
    QString                 m_agentsDefaultWorkspace; ///< agents.defaults.workspace

    QHash<QString, QStringList> m_agentSubagentsById;

    void scheduleAutoReconnectConnect(const QString &url, int delayMs);
    static QString expandTildePath(const QString &path);
    static bool copyDirectoryRecursive(const QString &srcDir, const QString &dstDir);
};

#endif // GATEWAY_CLIENT_H
