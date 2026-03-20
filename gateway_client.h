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
 * │    ├── WsSkill             技能类（预留）                     │
 * │    └── WsScheduledTask     定时任务类（预留）                  │
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
 *   6. 自动获取会话列表 + 加载当前会话历史
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
#include <QWebSocket>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMap>

#include "ws_config.h"
#include "ws_session.h"
#include "ws_skill.h"
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
    Q_PROPERTY(QVariantMap agentIdentity READ agentIdentity
               NOTIFY agentIdentityChanged)
    Q_PROPERTY(QVariantList agentList READ agentList
               NOTIFY agentListChanged)
    Q_PROPERTY(QString defaultAgentId READ defaultAgentId
               NOTIFY agentListChanged)

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
    /// 获取当前 agent 身份信息
    QVariantMap agentIdentity() const;
    /// 获取 agent 列表（通过 agents.list RPC 获取）
    QVariantList agentList() const;
    /// 获取默认 agent ID
    QString defaultAgentId() const;

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
     */
    Q_INVOKABLE void sendChatMessage(const QString &message,
                                     const QString &sessionKey = QString());

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

    /**
     * @brief 切换 Agent（依次发送 agent.identity.get + chat.history + sessions.list）
     * @param agentId agent ID（如 "main"、"coder"）
     *
     * 自动构造 sessionKey = "agent:<agentId>:main"，
     * 切换 currentSessionKey 并发送三个 RPC 请求。
     */
    Q_INVOKABLE void switchAgent(const QString &agentId);

    /// 获取指定会话的 agent 身份信息（发送 agent.identity.get RPC）
    Q_INVOKABLE void getAgentIdentity(const QString &sessionKey = QString());

    /// 加载指定会话的聊天历史（发送 chat.history RPC）
    Q_INVOKABLE void loadChatHistory(const QString &sessionKey = QString(),
                                      int limit = 200);

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

    // ── Agent 管理 ──
    void agentIdentityChanged();     ///< Agent 身份信息更新
    void agentListChanged();         ///< Agent 列表更新
    void agentCreated(const QString &agentId, bool success,
                      const QString &message); ///< 新 Agent 创建结果
    void agentDeleted(const QString &agentId, bool success,
                      const QString &message); ///< Agent 删除结果

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
     *   2. tick / heartbeat → 忽略（后续可转发给 WsScheduledTask）
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
     */
    void handleResponse(const QJsonObject &msg);

    /**
     * @brief 发送 connect 握手请求
     *
     * 由 handleEvent 在收到 connect.challenge 后调用。
     * 参数由 WsConfig::buildConnectParams() 构建。
     */
    void sendConnectRequest();

    /// 生成唯一的请求 ID（UUID v4，不含花括号）
    QString nextRequestId();

    /**
     * @brief 发送 RPC 请求的统一入口
     * @param method RPC 方法名（如 sessions.list、chat.send）
     * @param params 请求参数对象
     * @return 生成的 requestId，用于追踪响应
     */
    QString sendRequest(const QString &method, const QJsonObject &params);

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
    QString m_pendingDeleteId;         ///< agents.delete 待确认 ID
};

#endif // GATEWAY_CLIENT_H
