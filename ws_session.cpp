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

    QJsonArray arr = payload.value(QStringLiteral("messages")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("items")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("data")).toArray();

    for (const QJsonValue &v : arr) {
        const QJsonObject m = v.toObject();
        const QString role = m.value(QStringLiteral("role")).toString();
        if (role.isEmpty()) continue;

        // ── toolResult 消息 → 独立条目 ──
        if (role == QLatin1String("toolResult")) {
            const QString tcId  = m.value(QStringLiteral("toolCallId")).toString();
            const QString tName = m.value(QStringLiteral("toolName")).toString();
            const bool isErr    = m.value(QStringLiteral("isError")).toBool(false);

            QString resultText;
            const QJsonArray cArr = m.value(QStringLiteral("content")).toArray();
            if (!cArr.isEmpty()) {
                for (const QJsonValue &cv : cArr) {
                    const QJsonObject co = cv.toObject();
                    if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                        if (!resultText.isEmpty()) resultText += QLatin1Char('\n');
                        resultText += co.value(QStringLiteral("text")).toString();
                    }
                }
            } else {
                resultText = m.value(QStringLiteral("content")).toString();
            }
            if (resultText.length() > 2000)
                resultText = resultText.left(2000) + QStringLiteral("\n... (truncated)");

            QVariantMap entry;
            entry[QStringLiteral("role")]       = QStringLiteral("tool");
            entry[QStringLiteral("content")]    = resultText;
            entry[QStringLiteral("msgType")]    = QStringLiteral("toolResult");
            entry[QStringLiteral("toolName")]   = tName;
            entry[QStringLiteral("toolCallId")] = tcId;
            entry[QStringLiteral("isError")]    = isErr;
            history.append(entry);
            continue;
        }

        // ── user / assistant / system 消息 ──
        // content 可能是字符串或结构化数组
        const QJsonValue contentVal = m.value(QStringLiteral("content"));

        if (contentVal.isArray()) {
            // 结构化内容数组：拆分 text 和 toolCall
            const QJsonArray cArr = contentVal.toArray();
            for (const QJsonValue &cv : cArr) {
                const QJsonObject co = cv.toObject();
                const QString ctype = co.value(QStringLiteral("type")).toString();

                if (ctype == QLatin1String("text")) {
                    QString t = co.value(QStringLiteral("text")).toString();
                    // 清理系统注入的 message_id 尾缀
                    int midx = t.indexOf(QStringLiteral("\n[message_id:"));
                    if (midx >= 0) t = t.left(midx).trimmed();
                    // 清理用户消息的时间戳前缀
                    if (role == QLatin1String("user") && t.startsWith(QLatin1Char('['))) {
                        int rBracket = t.indexOf(QLatin1String("] "));
                        if (rBracket > 0 && rBracket < 60)
                            t = t.mid(rBracket + 2);
                    }
                    if (t.isEmpty()) continue;

                    QVariantMap entry;
                    entry[QStringLiteral("role")]    = role;
                    entry[QStringLiteral("content")] = t;
                    entry[QStringLiteral("msgType")] = QStringLiteral("text");
                    history.append(entry);

                } else if (ctype == QLatin1String("toolCall")) {
                    const QString tcId  = co.value(QStringLiteral("id")).toString();
                    const QString tName = co.value(QStringLiteral("name")).toString();
                    const QJsonObject args = co.value(QStringLiteral("arguments")).toObject();
                    QString argsStr = QString::fromUtf8(
                        QJsonDocument(args).toJson(QJsonDocument::Compact));
                    if (argsStr.length() > 1000)
                        argsStr = argsStr.left(1000) + QStringLiteral("...");

                    QVariantMap entry;
                    entry[QStringLiteral("role")]       = QStringLiteral("assistant");
                    entry[QStringLiteral("content")]    = QString();
                    entry[QStringLiteral("msgType")]    = QStringLiteral("toolCall");
                    entry[QStringLiteral("toolName")]   = tName;
                    entry[QStringLiteral("toolArgs")]   = argsStr;
                    entry[QStringLiteral("toolCallId")] = tcId;
                    history.append(entry);
                }
            }
        } else {
            // 纯字符串内容
            QString text = contentVal.toString();
            if (text.isEmpty())
                text = m.value(QStringLiteral("text")).toString();
            if (text.isEmpty())
                text = m.value(QStringLiteral("message")).toString();
            if (text.isEmpty()) continue;

            QVariantMap entry;
            entry[QStringLiteral("role")]    = role;
            entry[QStringLiteral("content")] = text;
            entry[QStringLiteral("msgType")] = QStringLiteral("text");
            history.append(entry);
        }
    }

    qDebug() << "[WsSession] history loaded:" << history.count() << "entries";
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
    params[QStringLiteral("limit")]      = 500;
    return params;
}

// ═══════════════════════════════════════════════════════════════════════
//  服务器推送事件解析
// ═══════════════════════════════════════════════════════════════════════

WsEventResult WsSession::parseEvent(const QString &event,
                                     const QJsonObject &payload) const
{
    WsEventResult result;
    result.isStart      = false;
    result.isDelta      = false;
    result.isComplete   = false;
    result.ignore       = false;
    result.isToolCall   = false;
    result.isToolResult = false;
    result.toolIsError  = false;

    // ── 解构 payload 二级结构 ──
    const QString     subEvent = payload.value(QStringLiteral("event")).toString();
    const QJsonObject data     = payload.value(QStringLiteral("data")).toObject();

    // ── 工具调用检测 ──
    // 兼容两种格式：
    //  1) data.type = tool_use / toolCall / toolResult
    //  2) payload.stream = tool + data.phase = start/result/update
    const QString dataType = data.value(QStringLiteral("type")).toString();
    const QString stream   = payload.value(QStringLiteral("stream")).toString();
    const QString phase    = data.value(QStringLiteral("phase")).toString();
    const bool isToolStream = (stream == QLatin1String("tool"));

    if (isToolStream && phase == QLatin1String("start")) {
        result.isToolCall = true;
        result.toolName   = data.value(QStringLiteral("name")).toString(
            data.value(QStringLiteral("toolName")).toString());
        result.toolCallId = data.value(QStringLiteral("toolCallId")).toString(
            data.value(QStringLiteral("id")).toString());
        QJsonObject args = data.value(QStringLiteral("args")).toObject();
        if (args.isEmpty())
            args = data.value(QStringLiteral("input")).toObject();
        if (args.isEmpty())
            args = data.value(QStringLiteral("arguments")).toObject();
        result.toolArgs = QString::fromUtf8(
            QJsonDocument(args).toJson(QJsonDocument::Compact));
        return result;
    }

    if (isToolStream
        && (phase == QLatin1String("result")
            || phase == QLatin1String("done")
            || phase == QLatin1String("complete"))) {
        result.isToolResult = true;
        result.toolName     = data.value(QStringLiteral("name")).toString(
            data.value(QStringLiteral("toolName")).toString());
        result.toolCallId   = data.value(QStringLiteral("toolCallId")).toString(
            data.value(QStringLiteral("id")).toString());
        result.toolIsError  = data.value(QStringLiteral("isError")).toBool(false);
        result.content      = data.value(QStringLiteral("content")).toString(
            data.value(QStringLiteral("text")).toString());
        if (result.content.isEmpty())
            result.content = data.value(QStringLiteral("meta")).toString();
        return result;
    }

    if (dataType == QLatin1String("tool_use")
        || dataType == QLatin1String("toolCall")
        || subEvent.contains(QLatin1String("tool-call"))
        || subEvent.contains(QLatin1String("tool_call"))
        || subEvent.contains(QLatin1String("tool-use"))) {
        result.isToolCall = true;
        result.toolName   = data.value(QStringLiteral("name")).toString(
            data.value(QStringLiteral("toolName")).toString());
        result.toolCallId = data.value(QStringLiteral("id")).toString(
            data.value(QStringLiteral("toolCallId")).toString());
        // 参数可能在 args / input / arguments 字段
        QJsonObject args = data.value(QStringLiteral("args")).toObject();
        if (args.isEmpty())
            args = data.value(QStringLiteral("input")).toObject();
        if (args.isEmpty())
            args = data.value(QStringLiteral("arguments")).toObject();
        result.toolArgs = QString::fromUtf8(
            QJsonDocument(args).toJson(QJsonDocument::Compact));
        return result;
    }

    if (dataType == QLatin1String("tool_result")
        || dataType == QLatin1String("toolResult")
        || subEvent.contains(QLatin1String("tool-result"))
        || subEvent.contains(QLatin1String("tool_result"))) {
        result.isToolResult = true;
        result.toolName     = data.value(QStringLiteral("name")).toString(
            data.value(QStringLiteral("toolName")).toString());
        result.toolCallId   = data.value(QStringLiteral("toolCallId")).toString(
            data.value(QStringLiteral("id")).toString());
        result.toolIsError  = data.value(QStringLiteral("isError")).toBool(false);
        result.content      = data.value(QStringLiteral("content")).toString(
            data.value(QStringLiteral("text")).toString());
        if (result.content.isEmpty())
            result.content = data.value(QStringLiteral("meta")).toString();
        // content 可能是数组
        if (result.content.isEmpty()) {
            const QJsonArray cArr = data.value(QStringLiteral("content")).toArray();
            for (const QJsonValue &cv : cArr) {
                const QJsonObject co = cv.toObject();
                if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                    if (!result.content.isEmpty()) result.content += QLatin1Char('\n');
                    result.content += co.value(QStringLiteral("text")).toString();
                }
            }
        }
        return result;
    }

    // ── 从 data 字段检测事件语义 ──
    const bool    hasDelta = data.contains(QStringLiteral("delta"));
    const QString delta    = data.value(QStringLiteral("delta")).toString();

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

    // ── 空的 chat 状态更新事件应忽略 ──
    if (event == QLatin1String("chat")
        && !result.isDelta && !result.isStart && !result.isComplete
        && result.content.isEmpty()) {
        result.ignore = true;
    }

    return result;
}
