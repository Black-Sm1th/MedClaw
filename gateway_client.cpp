/**
 * @file gateway_client.cpp
 * @brief WebSocket 主类（总大类） —— 实现
 *
 * 本文件实现 GatewayClient 的完整逻辑，按职责划分为以下区域：
 *   1. 构造 / 析构
 *   2. 属性访问器
 *   3. 连接生命周期（连接、断开、错误处理）
 *   4. 协议握手（challenge → connect → hello-ok）
 *   5. 入站消息分发（事件 / 响应路由）
 *   6. 出站请求发送（统一 RPC 接口）
 *   7. 业务方法（会话管理、历史加载、聊天发送）
 */
#include "gateway_client.h"
#include <QDebug>
#include <QUuid>

/// 帧类型常量：事件帧
static const QLatin1String T_EVENT("event");
/// 帧类型常量：请求帧
static const QLatin1String T_REQ("req");
/// 帧类型常量：响应帧
static const QLatin1String T_RES("res");

// ═══════════════════════════════════════════════════════════════════════
//  1. 构造 / 析构
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 构造函数
 *
 * 执行以下初始化步骤：
 *   1. 创建 QWebSocket 实例（子对象，自动随父对象销毁）
 *   2. 将 QWebSocket 的 4 个核心信号连接到本类的槽函数：
 *      - connected             → onConnected()         连接建立
 *      - disconnected          → onDisconnected()      连接断开
 *      - textMessageReceived   → onTextMessageReceived() 文本消息
 *      - error                 → onSocketError()       底层错误
 *   3. WsConfig 在自身构造时已自动生成 Ed25519 密钥对
 *   4. WsSession 在自身构造时已设置默认 sessionKey
 */
GatewayClient::GatewayClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(),
                              QWebSocketProtocol::VersionLatest, this))
    , m_state(Disconnected)
    // m_config、m_session、m_skill、m_scheduledTask 由各自默认构造函数初始化
{
    // ── 连接 QWebSocket 信号到本类槽函数 ──
    connect(m_socket, &QWebSocket::connected,
            this, &GatewayClient::onConnected);
    connect(m_socket, &QWebSocket::disconnected,
            this, &GatewayClient::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived,
            this, &GatewayClient::onTextMessageReceived);
    connect(m_socket,
            QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
            this, &GatewayClient::onSocketError);
}

/**
 * @brief 析构函数 —— 关闭 WebSocket 连接并释放资源
 *
 * QWebSocket 作为本对象的子对象，会在 QObject 树销毁时自动 delete。
 * 此处显式 close() 确保 WebSocket 正常关闭握手。
 */
GatewayClient::~GatewayClient()
{
    m_socket->close();
}

// ═══════════════════════════════════════════════════════════════════════
//  2. 属性访问器
// ═══════════════════════════════════════════════════════════════════════

int GatewayClient::connectionState() const { return m_state; }

/// 将连接状态枚举转换为用户可读的中文描述
QString GatewayClient::statusText() const
{
    switch (m_state) {
    case Disconnected: return QStringLiteral("\u5df2\u65ad\u5f00");     // 已断开
    case Connecting:   return QStringLiteral("\u8fde\u63a5\u4e2d...");   // 连接中...
    case Handshaking:  return QStringLiteral("\u63e1\u624b\u4e2d...");   // 握手中...
    case Connected:    return QStringLiteral("\u5df2\u8fde\u63a5");     // 已连接
    }
    return QStringLiteral("\u672a\u77e5"); // 未知
}

/// 委托给 WsSession 获取会话列表
QVariantList GatewayClient::sessions() const
{
    return m_session.sessions();
}

/// 委托给 WsSession 获取当前会话 key
QString GatewayClient::currentSessionKey() const
{
    return m_session.currentSessionKey();
}

/// 设置连接状态并通知 QML 属性绑定系统
void GatewayClient::setState(ConnectionState state)
{
    if (m_state != state) {
        m_state = state;
        emit connectionStateChanged();
    }
}

/// 委托给 WsSession 切换会话，成功则发射信号
void GatewayClient::setCurrentSessionKey(const QString &key)
{
    if (m_session.setCurrentSessionKey(key))
        emit currentSessionChanged();
}

// ═══════════════════════════════════════════════════════════════════════
//  3. 连接生命周期
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 发起 WebSocket 连接
 *
 * 完整流程：
 *   1. 如果当前非 Disconnected，先关闭旧连接
 *   2. 清空握手 nonce 和所有 pending 请求（防止旧请求干扰新连接）
 *   3. 状态切换到 Connecting
 *   4. 调用 QWebSocket::open(url) 发起 TCP 连接 + WebSocket 升级
 *
 * 后续流程在 onConnected() 中继续。
 */
void GatewayClient::connectToServer(const QString &url)
{
    if (m_state != Disconnected)
        m_socket->close();

    m_challengeNonce.clear();
    m_pendingRequests.clear();
    setState(Connecting);

    m_socket->open(QUrl(url));
}

/**
 * @brief 主动断开连接
 *
 * 触发 QWebSocket 的正常关闭握手（发送 Close 帧）。
 * 关闭完成后 QWebSocket 会发射 disconnected 信号，
 * 由 onDisconnected() 完成状态清理。
 */
void GatewayClient::disconnectFromServer()
{
    m_socket->close();
}

/**
 * @brief WebSocket 连接建立成功回调
 *
 * 此时 TCP 连接和 WebSocket 协议升级均已完成。
 * 状态切换到 Handshaking，等待服务器下发 connect.challenge 事件。
 */
void GatewayClient::onConnected()
{
    qDebug() << "[Gateway] WebSocket transport open, waiting for challenge...";
    setState(Handshaking);
}

/**
 * @brief WebSocket 连接断开回调（主动或被动断开均触发）
 *
 * 清理工作：
 *   1. 重置流式状态（WsSession）
 *   2. 清空所有 pending 请求（不再等待响应）
 *   3. 状态切换到 Disconnected
 */
void GatewayClient::onDisconnected()
{
    qDebug() << "[Gateway] WebSocket disconnected";
    m_session.setStreaming(false);
    m_pendingRequests.clear();
    setState(Disconnected);
}

/**
 * @brief WebSocket 底层错误回调
 *
 * 可能的错误场景：
 *   - 目标地址不可达（服务器未启动）
 *   - DNS 解析失败
 *   - TLS 握手失败（如果使用 wss://）
 *   - 连接超时
 */
void GatewayClient::onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    qWarning() << "[Gateway] Socket error:" << m_socket->errorString();
    emit errorOccurred(m_socket->errorString());
    setState(Disconnected);
}

// ═══════════════════════════════════════════════════════════════════════
//  4. 协议握手（challenge → connect → hello-ok）
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 发送 connect 握手请求
 *
 * 握手协议时序：
 *   ┌────────┐                    ┌─────────┐
 *   │ Client │                    │ Gateway │
 *   └───┬────┘                    └────┬────┘
 *       │     ──── WebSocket ────→     │  TCP + 升级
 *       │     ←── connect.challenge ── │  下发 nonce
 *       │     ──── connect req ────→   │  携带签名 device
 *       │     ←── res {ok:true} ─────  │  hello-ok
 *       │                              │
 *
 * 本方法在收到 connect.challenge 后被调用：
 *   1. 生成唯一 requestId
 *   2. 委托 WsConfig 构建含 Ed25519 签名的完整 params
 *   3. 组装 {type:"req", method:"connect"} 帧并发送
 */
void GatewayClient::sendConnectRequest()
{
    m_connectRequestId = nextRequestId();

    // 由配置类构建包含设备签名的完整握手参数
    const QJsonObject params = m_config.buildConnectParams(m_challengeNonce);

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = m_connectRequestId;
    request[QStringLiteral("method")] = QStringLiteral("connect");
    request[QStringLiteral("params")] = params;

    const QByteArray json =
        QJsonDocument(request).toJson(QJsonDocument::Compact);
    qDebug().noquote() << "[Gateway] >> connect"
                       << QString::fromUtf8(json);
    m_socket->sendTextMessage(QString::fromUtf8(json));
}

// ═══════════════════════════════════════════════════════════════════════
//  5. 入站消息分发
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 入站消息总入口 —— 解析 JSON 并分发到对应处理函数
 *
 * OpenClaw 协议帧类型：
 *   - "event"  事件帧（服务器推送）→ handleEvent()
 *   - "res"    响应帧（RPC 应答）  → handleResponse()
 *   - 某些帧 type 为 "req" 但含 "ok" 字段 → 也视为响应
 *   - 无 "type" 但含 "event" 字段 → 视为事件（兼容处理）
 */
void GatewayClient::onTextMessageReceived(const QString &message)
{
    // ── 1. JSON 解析 ──
    QJsonParseError err;
    const QJsonDocument doc =
        QJsonDocument::fromJson(message.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Gateway] bad JSON:" << err.errorString();
        return;
    }

    const QJsonObject msg  = doc.object();
    const QString     type = msg.value(QStringLiteral("type")).toString();

    // ── 2. 按帧类型分发 ──
    if (type == T_EVENT) {
        handleEvent(msg);
        return;
    }
    if (type == T_RES
        || (type == T_REQ && msg.contains(QStringLiteral("ok")))) {
        handleResponse(msg);
        return;
    }
    // 兼容：某些帧没有 type 但有 event 字段
    if (msg.contains(QStringLiteral("event"))) {
        handleEvent(msg);
        return;
    }

    qDebug() << "[Gateway] unrecognised frame:" << message.left(400);
}

/**
 * @brief 处理入站事件帧
 *
 * 事件分类：
 *   ① connect.challenge：握手阶段，提取 nonce 后发送 connect 请求
 *   ② tick / heartbeat：心跳事件，当前直接忽略（预留给 WsScheduledTask）
 *   ③ agent / chat：业务事件，委托 WsSession::parseEvent() 解析
 *      并根据解析结果发射对应的 Qt 信号（streaming / chatMessage）
 *   ④ 其他：如有文本内容，作为完整消息发射
 */
void GatewayClient::handleEvent(const QJsonObject &msg)
{
    const QString     event   = msg.value(QStringLiteral("event")).toString();
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();

    // ── ① connect.challenge：握手阶段 ──
    if (event == QLatin1String("connect.challenge")) {
        m_challengeNonce = payload.value(QStringLiteral("nonce")).toString();
        qDebug() << "[Gateway] challenge nonce:" << m_challengeNonce;
        sendConnectRequest();
        return;
    }

    // ── ② tick / heartbeat：心跳（当前忽略） ──
    if (event == QLatin1String("tick")
        || event == QLatin1String("heartbeat")) {
        // 预留：可转发给 m_scheduledTask.handleTick()
        return;
    }

    // ── 调试日志（前 15 条 agent/chat 事件） ──
    static int debugCount = 0;
    if (debugCount < 15
        && (event == QLatin1String("agent")
            || event == QLatin1String("chat"))) {
        ++debugCount;
        const QJsonObject data =
            payload.value(QStringLiteral("data")).toObject();
        const QString subEvent =
            payload.value(QStringLiteral("event")).toString();
        qDebug().noquote()
            << "[Gateway] EVT" << event << "|" << subEvent
            << "data:" << QString::fromUtf8(
                   QJsonDocument(data).toJson(QJsonDocument::Compact))
                   .left(300);
    }

    // ── ③ 委托 WsSession 解析事件语义 ──
    const WsEventResult r = m_session.parseEvent(event, payload);

    if (r.ignore)
        return;

    // ── 根据解析结果处理 agent 事件 ──
    if (event == QLatin1String("agent")) {
        if (r.isStart) {
            // 流式输出开始
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            return;
        }
        if (r.isDelta && !r.content.isEmpty()) {
            // 流式增量内容
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
            return;
        }
        if (r.isComplete) {
            // 流式输出完成
            if (m_session.isStreaming()) {
                m_session.setStreaming(false);
                emit streamingFinished();
            } else if (!r.content.isEmpty()) {
                emit chatMessageReceived(r.role, r.content, false);
            }
            return;
        }
        // 非 delta/start/complete 但有内容 → 视为流式增量
        if (!r.content.isEmpty()) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
        }
        return;
    }

    // ── 根据解析结果处理 chat 事件 ──
    if (event == QLatin1String("chat")) {
        if (r.isDelta && !r.content.isEmpty()) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
            return;
        }
        if (r.isComplete) {
            if (m_session.isStreaming()) {
                m_session.setStreaming(false);
                emit streamingFinished();
            } else if (!r.content.isEmpty()) {
                emit chatMessageReceived(r.role, r.content, false);
            }
            return;
        }
        return; // 空的 chat 状态更新，忽略
    }

    // ── ④ 其他事件：如有内容，作为完整消息发射 ──
    if (!r.content.isEmpty())
        emit chatMessageReceived(r.role, r.content, false);
}

/**
 * @brief 处理入站响应帧
 *
 * 响应路由机制：
 *   - 每个出站请求的 requestId 在发送时记录到 m_pendingRequests
 *   - 响应到达时，通过 id 查找原始方法名（take = 查找 + 移除）
 *   - 根据方法名将 payload 分发给对应的子类解析方法
 */
void GatewayClient::handleResponse(const QJsonObject &msg)
{
    const QString     id      = msg.value(QStringLiteral("id")).toString();
    const bool        ok      = msg.value(QStringLiteral("ok")).toBool(false);
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();
    const QJsonValue  errVal  = msg.value(QStringLiteral("error"));

    // 从 pending 映射中取出并移除此请求的方法名
    const QString method = m_pendingRequests.take(id);

    // ── 非 connect 请求的错误处理 ──
    if (!ok && id != m_connectRequestId) {
        QString errMsg;
        if (errVal.isObject())
            errMsg = errVal.toObject()
                         .value(QStringLiteral("message")).toString();
        if (errMsg.isEmpty() && errVal.isString())
            errMsg = errVal.toString();
        if (errMsg.isEmpty())
            errMsg = QStringLiteral("Request failed (ok=false)");
        qWarning() << "[Gateway] error" << method << "id=" << id << errMsg;
        emit errorOccurred(errMsg);
        return;
    }

    // ── connect 握手响应 ──
    if (id == m_connectRequestId) {
        if (!ok) {
            QString errMsg;
            if (errVal.isObject())
                errMsg = errVal.toObject()
                             .value(QStringLiteral("message")).toString();
            if (errMsg.isEmpty() && errVal.isString())
                errMsg = errVal.toString();
            qWarning() << "[Gateway] connect failed:" << errMsg;
            emit errorOccurred(errMsg);
            return;
        }
        // 握手成功：切换到 Connected，自动加载会话列表和历史
        qDebug() << "[Gateway] handshake complete!";
        setState(Connected);
        refreshSessions();
        loadHistory();
        return;
    }

    // ── 业务响应路由 ──
    qDebug().noquote()
        << "[Gateway] <<" << method << "id=" << id
        << QString::fromUtf8(
               QJsonDocument(payload).toJson(QJsonDocument::Compact))
               .left(500);

    // sessions.list 响应 → 委托 WsSession 解析
    if (method == QLatin1String("sessions.list")) {
        m_session.parseSessionsResponse(payload);
        emit sessionsChanged();
        return;
    }

    // chat.send 响应（如果是 /new 命令）→ 刷新列表 + 通知
    if (method == QLatin1String("chat.send")
        && id == m_session.newSessionReqId()) {
        m_session.clearNewSessionReqId();
        qDebug() << "[Gateway] /new session response, refreshing list...";
        refreshSessions();
        emit sessionCreated();
        return;
    }

    // session.delete 响应 → 刷新列表
    if (method == QLatin1String("session.delete")) {
        qDebug() << "[Gateway] session deleted, refreshing list...";
        refreshSessions();
        return;
    }

    // messages.list 响应 → 委托 WsSession 解析 + 发射历史加载信号
    if (method == QLatin1String("messages.list")) {
        const QVariantList history =
            m_session.parseHistoryResponse(payload);
        emit historyLoaded(history);
        return;
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  6. 出站请求发送
// ═══════════════════════════════════════════════════════════════════════

QString GatewayClient::nextRequestId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

/**
 * @brief 统一的 RPC 请求发送接口
 *
 * 帧格式：
 *   {
 *     "type": "req",
 *     "id": "<uuid>",
 *     "method": "<rpc-method>",
 *     "params": { ... }
 *   }
 */
QString GatewayClient::sendRequest(const QString &method,
                                    const QJsonObject &params)
{
    const QString reqId = nextRequestId();

    // 记录到 pending 映射，响应到达时通过 id 回查方法名
    m_pendingRequests.insert(reqId, method);

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = reqId;
    request[QStringLiteral("method")] = method;
    request[QStringLiteral("params")] = params;

    const QByteArray json =
        QJsonDocument(request).toJson(QJsonDocument::Compact);
    qDebug().noquote() << "[Gateway] >>" << method
                       << QString::fromUtf8(json);
    m_socket->sendTextMessage(QString::fromUtf8(json));

    return reqId;
}

// ═══════════════════════════════════════════════════════════════════════
//  7. 业务方法（QML 调用入口）
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 加载当前会话的历史消息
 *
 * 前置条件：已连接（Connected）。
 * 请求参数由 WsSession::buildLoadHistoryParams() 构建。
 */
void GatewayClient::loadHistory()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("messages.list"),
                m_session.buildLoadHistoryParams());
}

/**
 * @brief 刷新会话列表
 *
 * 前置条件：已连接。
 */
void GatewayClient::refreshSessions()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("sessions.list"),
                m_session.buildListSessionsParams());
}

/**
 * @brief 创建新会话（/new 命令）
 *
 * 向当前 sessionKey 发送 message="/new" 的 chat.send 请求。
 * 响应到达后自动刷新会话列表并发射 sessionCreated 信号。
 */
void GatewayClient::createNewSession()
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString reqId = sendRequest(
        QStringLiteral("chat.send"), m_session.buildNewSessionParams());
    m_session.setNewSessionReqId(reqId);
}

/**
 * @brief 删除指定会话
 * @param sessionKey 要删除的会话 key
 */
void GatewayClient::deleteSession(const QString &sessionKey)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    sendRequest(QStringLiteral("session.delete"),
                m_session.buildDeleteSessionParams(sessionKey));
}

/**
 * @brief 发送聊天消息
 * @param message    用户输入的消息文本
 * @param sessionKey 目标会话 key（空则使用当前会话）
 *
 * 消息发送后，服务器会通过 event 帧推送 agent 的流式回复，
 * 由 handleEvent() → WsSession::parseEvent() 链路处理。
 */
void GatewayClient::sendChatMessage(const QString &message,
                                     const QString &sessionKey)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    sendRequest(QStringLiteral("chat.send"),
                m_session.buildChatSendParams(message, sessionKey));
}
