/**
 * @file ws_session.cpp
 * @brief WebSocket 会话管理类 —— 实现
 */
#include "ws_session.h"
#include <QUuid>
#include <QDebug>
#include <QJsonDocument>

// ═══════════════════════════════════════════════════════════════════════
//  构造
// ═══════════════════════════════════════════════════════════════════════

WsSession::WsSession()
    : m_currentSessionKey(QStringLiteral("agent:main:main"))
    , m_isStreaming(false)
{
}

// ═══════════════════════════════════════════════════════════════════════
//  当前会话管理
// ═══════════════════════════════════════════════════════════════════════

QString WsSession::currentSessionKey() const
{
    return m_currentSessionKey;
}

bool WsSession::setCurrentSessionKey(const QString &key)
{
    if (m_currentSessionKey == key)
        return false;
    m_currentSessionKey = key;
    return true; // 通知调用方：确实发生了切换
}

// ═══════════════════════════════════════════════════════════════════════
//  会话列表
// ═══════════════════════════════════════════════════════════════════════

QVariantList WsSession::sessions() const
{
    return m_sessions;
}

int WsSession::parseSessionsResponse(const QJsonObject &payload)
{
    m_sessions.clear();

    // 优先读 "sessions" 数组，兼容读 "items" 数组
    QJsonArray arr = payload.value(QStringLiteral("sessions")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("items")).toArray();

    for (const QJsonValue &v : arr) {
        const QJsonObject s = v.toObject();

        // 会话标识：优先 "key"，兼容 "sessionKey"
        const QString key = s.value(QStringLiteral("key")).toString(
            s.value(QStringLiteral("sessionKey")).toString());
        if (key.isEmpty()) continue;

        // 显示名称：优先 "title"，兼容 "name"，回退到 key 中间段
        QString name = s.value(QStringLiteral("title")).toString(
            s.value(QStringLiteral("name")).toString());
        if (name.isEmpty()) {
            const QStringList parts = key.split(QLatin1Char(':'));
            name = (parts.size() >= 2) ? parts[1] : key;
        }

        // 附加模型信息（如 deepseek-chat）
        const QString model = s.value(QStringLiteral("model")).toString();
        if (!model.isEmpty())
            name += QStringLiteral(" (%1)").arg(model);

        QVariantMap entry;
        entry[QStringLiteral("sessionKey")]  = key;
        entry[QStringLiteral("displayName")] = name;
        m_sessions.append(entry);
    }

    // 保底：如果服务器返回空列表，插入默认会话
    if (m_sessions.isEmpty()) {
        QVariantMap def;
        def[QStringLiteral("sessionKey")]  = QStringLiteral("agent:main:main");
        def[QStringLiteral("displayName")] = QStringLiteral("Main Agent");
        m_sessions.append(def);
    }

    qDebug() << "[WsSession] sessions loaded:" << m_sessions.count();
    return m_sessions.count();
}

// ═══════════════════════════════════════════════════════════════════════
//  历史消息解析
// ═══════════════════════════════════════════════════════════════════════

QVariantList WsSession::parseHistoryResponse(const QJsonObject &payload)
{
    QVariantList history;

    // 尝试多种可能的数组字段名
    QJsonArray arr = payload.value(QStringLiteral("messages")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("items")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("data")).toArray();

    for (const QJsonValue &v : arr) {
        const QJsonObject m = v.toObject();

        const QString role = m.value(QStringLiteral("role")).toString();

        // 内容字段：优先 "content"，兼容 "text" → "message"
        QString text = m.value(QStringLiteral("content")).toString();
        if (text.isEmpty())
            text = m.value(QStringLiteral("text")).toString();
        if (text.isEmpty())
            text = m.value(QStringLiteral("message")).toString();

        if (role.isEmpty() || text.isEmpty())
            continue;

        QVariantMap entry;
        entry[QStringLiteral("role")]    = role;
        entry[QStringLiteral("content")] = text;
        history.append(entry);
    }

    qDebug() << "[WsSession] history loaded:" << history.count() << "messages";
    return history;
}

// ═══════════════════════════════════════════════════════════════════════
//  流式响应状态
// ═══════════════════════════════════════════════════════════════════════

bool WsSession::isStreaming() const       { return m_isStreaming; }
void WsSession::setStreaming(bool s)      { m_isStreaming = s; }

// ═══════════════════════════════════════════════════════════════════════
//  新会话请求跟踪
// ═══════════════════════════════════════════════════════════════════════

QString WsSession::newSessionReqId() const   { return m_newSessionReqId; }
void    WsSession::setNewSessionReqId(const QString &id) { m_newSessionReqId = id; }
void    WsSession::clearNewSessionReqId()    { m_newSessionReqId.clear(); }

// ═══════════════════════════════════════════════════════════════════════
//  构建 RPC 请求参数
// ═══════════════════════════════════════════════════════════════════════

QJsonObject WsSession::buildChatSendParams(const QString &message,
                                            const QString &sessionKey) const
{
    const QString key = sessionKey.isEmpty() ? m_currentSessionKey : sessionKey;

    QJsonObject params;
    params[QStringLiteral("sessionKey")]     = key;
    params[QStringLiteral("message")]        = message;
    params[QStringLiteral("deliver")]        = false;
    params[QStringLiteral("idempotencyKey")] =
        QUuid::createUuid().toString(QUuid::WithoutBraces);
    return params;
}

QJsonObject WsSession::buildNewSessionParams() const
{
    QJsonObject params;
    params[QStringLiteral("sessionKey")]     = m_currentSessionKey;
    params[QStringLiteral("message")]        = QStringLiteral("/new");
    params[QStringLiteral("deliver")]        = false;
    params[QStringLiteral("idempotencyKey")] =
        QUuid::createUuid().toString(QUuid::WithoutBraces);
    return params;
}

QJsonObject WsSession::buildListSessionsParams() const
{
    QJsonObject params;
    params[QStringLiteral("includeGlobal")]  = true;
    params[QStringLiteral("includeUnknown")] = false;
    params[QStringLiteral("limit")]          = 120;
    return params;
}

QJsonObject WsSession::buildDeleteSessionParams(const QString &sessionKey) const
{
    QJsonObject params;
    params[QStringLiteral("sessionKey")] = sessionKey;
    return params;
}

QJsonObject WsSession::buildLoadHistoryParams() const
{
    QJsonObject params;
    params[QStringLiteral("sessionKey")] = m_currentSessionKey;
    params[QStringLiteral("limit")]      = 100;
    return params;
}

// ═══════════════════════════════════════════════════════════════════════
//  服务器推送事件解析
// ═══════════════════════════════════════════════════════════════════════

WsEventResult WsSession::parseEvent(const QString &event,
                                     const QJsonObject &payload) const
{
    WsEventResult result;
    result.isStart    = false;
    result.isDelta    = false;
    result.isComplete = false;
    result.ignore     = false;

    // ── 解构 payload 二级结构 ──
    const QString     subEvent = payload.value(QStringLiteral("event")).toString();
    const QJsonObject data     = payload.value(QStringLiteral("data")).toObject();

    // ── 从 data 字段检测事件语义 ──
    const QString phase    = data.value(QStringLiteral("phase")).toString();
    const bool    hasDelta = data.contains(QStringLiteral("delta"));
    const QString delta    = data.value(QStringLiteral("delta")).toString();

    // 综合 data.phase 和 subEvent 名称判定事件类型
    result.isDelta = hasDelta
                  || subEvent.contains(QLatin1String("delta"))
                  || subEvent.contains(QLatin1String("chunk"));

    result.isStart = (phase == QLatin1String("start"))
                  || subEvent.contains(QLatin1String("start"));

    result.isComplete = (phase == QLatin1String("complete"))
                     || (phase == QLatin1String("done"))
                     || subEvent.contains(QLatin1String("complete"))
                     || subEvent.contains(QLatin1String("done"))
                     || subEvent.contains(QLatin1String("finish"));

    // ── 提取文本内容（优先级：delta > content > text） ──
    result.content = delta;
    if (result.content.isEmpty())
        result.content = data.value(QStringLiteral("content")).toString();
    if (result.content.isEmpty())
        result.content = data.value(QStringLiteral("text")).toString();
    if (result.content.isEmpty())
        result.content = payload.value(QStringLiteral("content")).toString();

    // ── 提取消息角色 ──
    result.role = data.value(QStringLiteral("role")).toString(
        payload.value(QStringLiteral("role")).toString(QStringLiteral("assistant")));

    // ── 根据事件类型决定是否忽略 ──
    // 空的 chat 状态更新事件（data 为空）应忽略
    if (event == QLatin1String("chat")
        && !result.isDelta && !result.isStart && !result.isComplete
        && result.content.isEmpty()) {
        result.ignore = true;
    }

    return result;
}
