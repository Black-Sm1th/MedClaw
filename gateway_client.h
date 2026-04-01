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
    Q_PROPERTY(QString statusText READ statusText
               NOTIFY connectionStateChanged)
    Q_PROPERTY(QVariantList sessions READ sessions
               NOTIFY sessionsChanged)
    Q_PROPERTY(QString currentSessionKey READ currentSessionKey
               WRITE setCurrentSessionKey NOTIFY currentSessionChanged)
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
    /// 与 AppData/config.json 中 serverUrl 一致（握手 token/clientId 亦来自该文件）
    Q_PROPERTY(QString serverUrl READ serverUrl CONSTANT)
    /// 技能市场：skillMarketPath 下每个子文件夹一项 { folderName, installed }
    Q_PROPERTY(QVariantList skillMarketFolders READ skillMarketFolders
               NOTIFY skillMarketFoldersChanged)
    /// 正在安装技能（复制 + 请求网关重启）
    Q_PROPERTY(bool skillInstallBusy READ skillInstallBusy NOTIFY skillInstallBusyChanged)

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

    /// 获取当前连接状态（枚举值）
    int connectionState() const;
    /// 获取当前连接状态的中文描述文本
    QString statusText() const;
    /// 获取会话列表（委托给 WsSession）
    QVariantList sessions() const;
    /// 获取当前活跃会话 key（委托给 WsSession）
    QString currentSessionKey() const;
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

    /**
     * @brief 发送聊天消息
     * @param message    用户输入的消息文本
     * @param sessionKey 目标会话 key（空则使用当前会话）
     * @param workspaceForNewAgent 当前无会话、将触发 agents.create 时使用的 workspace（空则服务端默认路径）
     */
    Q_INVOKABLE void sendChatMessage(const QString &message,
                                     const QString &sessionKey = QString(),
                                     const QString &workspaceForNewAgent = QString());

    void setPendingChatFiles(const QVariantList &files);
    void resolveAndCopyFiles(const QVariantList &files, const QString &workspace);

    /// 刷新会话列表（发送 sessions.list RPC）
    Q_INVOKABLE void refreshSessions();

    /// 创建新会话（发送 chat.send /new 命令）
    Q_INVOKABLE void createNewSession();

    /// 删除指定会话（发送 session.delete RPC）
    Q_INVOKABLE void deleteSession(const QString &sessionKey);

    /// 切换当前活跃会话
    Q_INVOKABLE void setCurrentSessionKey(const QString &key);

    /// 加载当前会话的历史消息（发送 messages.list RPC）
    Q_INVOKABLE void loadHistory();

    /// 获取所有 Agent 列表（发送 agents.list RPC）
    Q_INVOKABLE void refreshAgents();

    /**
     * @brief 创建新 Agent（agents.create RPC）
     * @param name      agent 名称（服务端自动 normalizeAgentId 生成 ID）
     * @param workspace 工作空间路径
     */
    Q_INVOKABLE void createAgent(const QString &name,
                                  const QString &workspace);

    /**
     * @brief 删除 Agent（agents.delete RPC）
     * @param agentId    要删除的 agent ID
     * @param deleteFiles 是否同时删除 workspace/sessions 文件，默认 true
     */
    Q_INVOKABLE void deleteAgent(const QString &agentId,
                                  bool deleteFiles = true);

    /// 获取所有技能状态（发送 skills.status RPC）
    Q_INVOKABLE void refreshSkills();

    /// 启用/禁用指定技能（发送 skills.update RPC）
    Q_INVOKABLE void setSkillEnabled(const QString &skillKey, bool enabled);

    /// 扫描配置中 skillMarketPath 子文件夹并刷新 skillMarketFolders
    Q_INVOKABLE void refreshSkillMarketFolders();

    /**
     * @brief 将技能市场某文件夹复制到 skillsStoragePath，并通过 config.patch 触发网关重启
     * @note 重启会导致断线；客户端会在短暂延迟后自动重连
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
     * @brief 暂存定时任务参数，在 createAgent 成功后再发 cron.add
     * @param scheduleKind 1=cron 表达式 2=固定间隔(秒) 3=一次性 ISO 时间
     * @note 调用顺序应为：先 createAgent(cronDedicatedAgentDisplayName(title), workspace)，再本方法
     */
    Q_INVOKABLE void prepareCronJobWithDedicatedAgent(int scheduleKind,
                                                       const QString &jobName,
                                                       const QString &message,
                                                       const QString &cronExpr,
                                                       const QString &tz,
                                                       int intervalSec,
                                                       const QString &isoDateTime);

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

    /**
     * @brief 清除当前选中的 agent 会话（不加载任何历史）
     *
     * 用于「新建任务」入口：回到主聊天区但尚未绑定具体 agent。
     */
    Q_INVOKABLE void clearActiveAgentContext();

    /// 获取指定会话的 agent 身份信息（发送 agent.identity.get RPC）
    Q_INVOKABLE void getAgentIdentity(const QString &sessionKey = QString());

    /// 加载指定会话的聊天历史（发送 chat.history RPC）
    Q_INVOKABLE void loadChatHistory(const QString &sessionKey = QString(),
                                      int limit = 200);

    /// 获取可用模型列表（发送 models.list RPC）
    Q_INVOKABLE void refreshModels();

    /**
     * @brief 查询或设置当前会话的模型（发送 sessions.patch RPC）
     * @param modelId 为空时查询当前模型（model:null），非空时切换到指定模型
     */
    Q_INVOKABLE void patchSessionModel(const QString &modelId = QString());

    /// 拉取配置快照并解析 mcp.servers（config.get）
    Q_INVOKABLE void refreshMcpList();

    /// 拉取 tools.catalog（agentId 空则用 defaultAgentId）
    Q_INVOKABLE void refreshToolsCatalog(const QString &agentId = QString());

    /**
     * @brief 通过 agents.list[].tools.deny 启用/禁用工具（config.patch）
     */
    Q_INVOKABLE void setAgentToolEnabled(const QString &agentId, const QString &toolId,
                                         bool enabled);

    /**
     * @brief 批量设置工具启用状态，生成单次 config.patch
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
                                     const QString &description);

    /// 从配置中删除 mcp.servers 某键（merge patch null）
    Q_INVOKABLE void removeMcpServer(const QString &serverName);

signals:
    // ── 连接状态 ──
    void connectionStateChanged();  ///< 连接状态发生变化

    // ── 聊天消息 ──
    void chatMessageReceived(const QString &role,
                             const QString &content,
                             bool isDelta);      ///< 收到聊天消息（完整或增量）
    void streamingStarted();                     ///< 流式输出开始
    void streamingFinished();                    ///< 流式输出结束

    // ── 工具调用 ──
    void toolCallReceived(const QString &toolName,
                          const QString &toolArgs,
                          const QString &toolCallId);    ///< Agent 发起工具调用
    void toolResultReceived(const QString &toolName,
                            const QString &content,
                            const QString &toolCallId,
                            bool isError);               ///< 工具执行结果返回

    // ── 错误 ──
    void errorOccurred(const QString &message);  ///< 发生错误

    // ── 会话管理 ──
    void sessionsChanged();          ///< 会话列表更新
    void currentSessionChanged();    ///< 当前活跃会话切换
    void sessionCreated();           ///< 新会话创建成功
    void historyLoaded(const QVariantList &messages); ///< 历史消息加载完成

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

    // ── Agent 管理 ──
    void agentIdentityChanged();     ///< Agent 身份信息更新
    void agentListChanged();         ///< Agent 列表更新
    void agentCreated(const QString &agentId, bool success,
                      const QString &message,
                      bool forChat); ///< 新 Agent 创建结果
    void agentDeleted(const QString &agentId, bool success,
                      const QString &message); ///< Agent 删除结果

    // ── 模型管理 ──
    void modelListChanged();              ///< 可用模型列表更新
    void currentModelChanged();           ///< 当前会话模型信息变更
    void pendingSessionModelIdChanged();  ///< 无会话时待选模型变更
    void skillMarketFoldersChanged();     ///< 技能市场目录列表更新
    void skillInstallBusyChanged();       ///< 技能安装进行中状态变更
    void mcpListChanged();                ///< MCP 服务器列表更新
    void toolListChanged();               ///< 工具目录列表更新

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
     *   4. chat.send（/new）→ 刷新列表，发射 sessionCreated
     *   5. session.delete → 刷新列表
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
    /// 仅刷新一个 agent 的侧栏首句（避免每次 sessions.list 全量 chat.history）
    void refreshSidebarFirstUserTitleForAgent(const QString &agentId);
    static QString firstUserMessageFromHistoryList(const QVariantList &history);
    void setAgentListSidebarTitle(const QString &agentId, const QString &text);

    /// 聊天/历史/身份使用的 sessionKey（agent 行上可有 chatSessionKey）
    QString resolveChatSessionKeyForAgentId(const QString &agentId) const;

    /**
     * @brief 解析 config.get 的 payload，更新 m_configSnapshotHash、m_mcpList
     *
     * 将 config 根对象写入 m_lastConfigSnapshot（优先 config，其次 resolved，再次 parsed）；
     * 并解析 agents.list[].workspace 供界面展示（agent.identity.get 不含 workspace）。
     */
    void applyMcpListFromConfigGetPayload(const QJsonObject &payload);
    /// 从完整 config 对象填充 m_mcpList（按名称排序）
    void rebuildMcpListFromConfigObject(const QJsonObject &config);
    /// 从 config 根对象重建 agentId → workspace（及 agents.defaults.workspace）
    void rebuildAgentWorkspaceMapFromConfigObject(const QJsonObject &configRoot);
    QString resolveWorkspacePathForAgentId(const QString &agentId) const;
    /// 用当前 workspace 映射补全 m_agentIdentity["workspace"] 并 notify
    void mergeWorkspaceIntoAgentIdentity();

    /// 定时任务专用：先 agents.create 再 cron.add 时使用的显示名
    static QString makeCronDedicatedAgentName(const QString &taskTitle);
    void clearPendingCronDedicatedAgent();
    void sendPendingCronAddWithAgentId(const QString &agentId);

    /// 生成唯一的请求 ID（UUID v4，不含花括号）
    QString nextRequestId();

    /**
     * @brief 发送 RPC 请求的统一入口
     * @param method RPC 方法名（如 sessions.list、chat.send）
     * @param params 请求参数对象
     * @return 生成的 requestId，用于追踪响应
     */
    QString sendRequest(const QString &method, const QJsonObject &params);

    /// 从事件 payload 提取 sessionKey（兼容 data / agentId）
    QString extractPayloadSessionKey(const QJsonObject &payload) const;
    /// 当前 UI 是否应展示该会话的推送（无选中会话则一律不展示）
    bool eventAppliesToCurrentUiSession(const QJsonObject &payload) const;

    // ═══════════════════════════════════════════════════════════════
    //  成员变量
    // ═══════════════════════════════════════════════════════════════

    // ── WebSocket 实例 ──
    QWebSocket     *m_socket;           ///< Qt WebSocket 客户端实例

    // ── 连接状态 ──
    ConnectionState m_state;            ///< 当前连接状态
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
    QString          m_defaultAgentId;  ///< 默认 agent ID

    QString m_pendingCreateName;       ///< agents.create 待确认名称
    QString m_pendingCreateWorkspace;  ///< agents.create 使用的 workspace 路径
    QString m_pendingDeleteId;         ///< agents.delete 待确认 ID
    QString m_pendingProfileFullAgentId; ///< agents.create 后待设置 tools.profile="full" 的 agentId

    /// 当前无选中 agent 时，首条聊天触发的 agents.create 完成后要发送的文本
    QString m_pendingFirstChatMessage;
    bool m_pendingAgentCreateForChat = false;
    QVariantList m_pendingChatFiles;

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
    QString m_cronPendingTz;
    int m_cronPendingEveryMs = 0;
    QDateTime m_cronPendingAt;
    bool m_cronPendingDeleteAfterRun = true;

    /// 侧栏「首句问话」：chat.history 请求 id → agentId / 批次号（与切换会话的历史请求区分）
    QMap<QString, QString> m_sidebarTitleHistReqAgent;
    QMap<QString, quint64> m_sidebarTitleHistReqBatch;
    quint64 m_sidebarTitleBatchGen = 0;
    QTimer m_agentFirstUserTitleDebounce;

    // ── 模型管理 ──
    QVariantList m_modelList;          ///< 可用模型列表缓存（models.list 响应）
    QVariantMap  m_currentModel;       ///< 当前会话模型信息（sessions.patch 响应）
    QString m_pendingSessionModelId;   ///< 尚无 session 时用户选择的模型，有 session 后 patch

    QString m_lastConnectedWsUrl;      ///< 最近一次 connectToServer 的 URL（用于安装技能后自动重连）
    /// 收到 shutdown 事件时由 restartExpectedMs + 余量 写入；断线重连前消费
    int m_pendingReconnectDelayMs = 0;
    bool m_pendingReconnectAfterDisconnect = false; ///< config.patch 触发网关重启后等待断线重连
    /// 自动重连：非用户主动断开时尝试恢复；失败后间隔 1s 再试，累计失败达上限后停止
    static constexpr int kMaxAutoReconnectFailures = 10;
    bool m_userRequestedDisconnect = false;         ///< disconnectFromServer() 触发的断开，不自动重连
    bool m_skipAutoReconnectOnNextDisconnect = false; ///< connectToServer 为换新连接而 close 旧 socket
    bool m_connectFromAutoReconnect = false;        ///< 当前 connectToServer 由自动重连定时器发起
    int m_autoReconnectFailureCount = 0;            ///< 本轮自动重连已连续失败次数（成功或手动连接时清零）
    bool m_skillInstallBusy = false; ///< 技能安装流程进行中
    QVariantList m_skillMarketFolders; ///< 技能市场子文件夹列表

    QString        m_configSnapshotHash; ///< config.get / config.patch 乐观锁 baseHash
    QVariantList   m_mcpList;          ///< mcp.servers 展示列表

    WsTools        m_tools;            ///< tools.catalog 与 tools 策略展平
    QJsonObject    m_lastConfigSnapshot; ///< config.get 解析出的配置根对象（供 tools / patch）

    QHash<QString, QString> m_agentWorkspaceById; ///< agents.list[].id → workspace
    QString                 m_agentsDefaultWorkspace; ///< agents.defaults.workspace

    void requestGatewayRestartViaConfigPatch();
    void scheduleAutoReconnectConnect(const QString &url, int delayMs);
    static QString expandTildePath(const QString &path);
    static bool copyDirectoryRecursive(const QString &srcDir, const QString &dstDir);
};

#endif // GATEWAY_CLIENT_H
