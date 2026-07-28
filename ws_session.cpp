/**
 * @file ws_session.cpp
 * @brief WebSocket 会话管理类 —— 实现
 */
#include "ws_session.h"
#include <QUuid>
#include <QDebug>
#include <QJsonDocument>

namespace {

QString textFromContentArray(const QJsonArray &cArr)
{
    QString out;
    for (const QJsonValue &cv : cArr) {
        const QJsonObject co = cv.toObject();
        if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
            if (!out.isEmpty())
                out += QLatin1Char('\n');
            out += co.value(QStringLiteral("text")).toString();
        }
    }
    return out;
}

QString userVisibleText(const QString &text)
{
    const QString marker = QStringLiteral("\n用户任务：\n");
    const int markerIndex = text.indexOf(marker);
    if (markerIndex < 0)
        return text;

    const QString prefix = text.left(markerIndex);
    const bool isInjectedPrompt =
        prefix.contains(QStringLiteral("本任务的工作目录（也是输出文件目录）："))
        || prefix.startsWith(QStringLiteral("你是这个协作任务的主控 agent。"));
    if (!isInjectedPrompt)
        return text;

    return text.mid(markerIndex + marker.length()).trimmed();
}

/**
 * OpenClaw agent 流里 phase=result 时正文在 data.result（常为 { content:[{type,text}] }），
 * 而不是顶层的 content/text；网关在非 full verbose 下会删掉 result，此时仍可能为空。
 */
QString extractToolOutputFromDataObject(const QJsonObject &data)
{
    const QJsonValue contentTop = data.value(QStringLiteral("content"));
    if (contentTop.isString() && !contentTop.toString().isEmpty())
        return contentTop.toString();
    if (contentTop.isArray()) {
        const QString fromArr = textFromContentArray(contentTop.toArray());
        if (!fromArr.isEmpty())
            return fromArr;
    }

    const QString text = data.value(QStringLiteral("text")).toString();
    if (!text.isEmpty())
        return text;

    const QJsonValue outputVal = data.value(QStringLiteral("output"));
    if (!outputVal.isNull()) {
        if (outputVal.isString() && !outputVal.toString().isEmpty())
            return outputVal.toString();
        if (outputVal.isArray()) {
            const QString fromArr = textFromContentArray(outputVal.toArray());
            if (!fromArr.isEmpty())
                return fromArr;
        }
        if (outputVal.isObject())
            return QString::fromUtf8(QJsonDocument(outputVal.toObject()).toJson(QJsonDocument::Compact));
    }

    const QJsonValue resultVal = data.value(QStringLiteral("result"));
    if (!resultVal.isNull()) {
        if (resultVal.isString())
            return resultVal.toString();
        if (resultVal.isObject()) {
            const QJsonObject ro = resultVal.toObject();
            const QString fromRc = textFromContentArray(ro.value(QStringLiteral("content")).toArray());
            if (!fromRc.isEmpty())
                return fromRc;
            return QString::fromUtf8(QJsonDocument(ro).toJson(QJsonDocument::Compact));
        }
    }

    const QJsonValue partialVal = data.value(QStringLiteral("partialResult"));
    if (!partialVal.isNull()) {
        if (partialVal.isString())
            return partialVal.toString();
        if (partialVal.isObject()) {
            const QJsonObject ro = partialVal.toObject();
            const QString fromRc = textFromContentArray(ro.value(QStringLiteral("content")).toArray());
            if (!fromRc.isEmpty())
                return fromRc;
        }
    }

    const QJsonValue metaVal = data.value(QStringLiteral("meta"));
    if (metaVal.isString() && !metaVal.toString().isEmpty())
        return metaVal.toString();
    if (metaVal.isObject())
        return QString::fromUtf8(QJsonDocument(metaVal.toObject()).toJson(QJsonDocument::Compact));

    return QString();
}

} // namespace

// ═══════════════════════════════════════════════════════════════════════
//  构造
// ═══════════════════════════════════════════════════════════════════════

WsSession::WsSession()
    : m_currentSessionKey(QString())
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

        // 网关返回的 displayName 优先（与 sessions.list 一致）
        QString name = s.value(QStringLiteral("displayName")).toString();
        if (name.isEmpty()) {
            name = s.value(QStringLiteral("title")).toString(
                s.value(QStringLiteral("name")).toString());
        }
        if (name.isEmpty()) {
            const QStringList parts = key.split(QLatin1Char(':'));
            name = (parts.size() >= 2) ? parts[1] : key;
        }

        // 模型名单独存放；侧栏标题用 derivedTitle/label/displayName，不再把模型拼进 displayName
        const QString model = s.value(QStringLiteral("model")).toString();
        const QString modelProvider =
            s.value(QStringLiteral("modelProvider")).toString();

        qint64 updatedAt = 0;
        const QJsonValue uVal = s.value(QStringLiteral("updatedAt"));
        if (!uVal.isNull()) {
            if (uVal.isDouble())
                updatedAt = static_cast<qint64>(uVal.toDouble());
            else if (uVal.isString())
                updatedAt = uVal.toString().toLongLong();
        }

        qint64 startedAt = 0;
        const QJsonValue sVal = s.value(QStringLiteral("startedAt"));
        if (!sVal.isNull()) {
            if (sVal.isDouble())
                startedAt = static_cast<qint64>(sVal.toDouble());
            else if (sVal.isString())
                startedAt = sVal.toString().toLongLong();
        }

        const QString derivedTitle = s.value(QStringLiteral("derivedTitle")).toString();
        const QString label = s.value(QStringLiteral("label")).toString();
        const QString spawnedBy = s.value(QStringLiteral("spawnedBy")).toString();
        const QString parentSessionKey =
            s.value(QStringLiteral("parentSessionKey")).toString();
        const QString subagentRole = s.value(QStringLiteral("subagentRole")).toString();
        const QString kind = s.value(QStringLiteral("kind")).toString();
        const QString agentId = s.value(QStringLiteral("agentId")).toString();

        QVariantMap entry;
        entry[QStringLiteral("sessionKey")]   = key;
        entry[QStringLiteral("displayName")]  = name;
        entry[QStringLiteral("updatedAt")]    = QVariant(static_cast<qlonglong>(updatedAt));
        entry[QStringLiteral("startedAt")]    = QVariant(static_cast<qlonglong>(startedAt));
        if (!derivedTitle.isEmpty())
            entry[QStringLiteral("derivedTitle")] = derivedTitle;
        if (!label.isEmpty())
            entry[QStringLiteral("label")] = label;
        if (!model.isEmpty())
            entry[QStringLiteral("model")] = model;
        if (!modelProvider.isEmpty())
            entry[QStringLiteral("modelProvider")] = modelProvider;
        if (!spawnedBy.isEmpty())
            entry[QStringLiteral("spawnedBy")] = spawnedBy;
        if (!parentSessionKey.isEmpty())
            entry[QStringLiteral("parentSessionKey")] = parentSessionKey;
        if (!subagentRole.isEmpty())
            entry[QStringLiteral("subagentRole")] = subagentRole;
        if (!kind.isEmpty())
            entry[QStringLiteral("kind")] = kind;
        if (!agentId.isEmpty())
            entry[QStringLiteral("agentId")] = agentId;
        if (s.contains(QStringLiteral("spawnDepth"))) {
            const QJsonValue dVal = s.value(QStringLiteral("spawnDepth"));
            if (dVal.isDouble())
                entry[QStringLiteral("spawnDepth")] = dVal.toInt();
            else if (dVal.isString()) {
                bool ok = false;
                const int depth = dVal.toString().toInt(&ok);
                if (ok)
                    entry[QStringLiteral("spawnDepth")] = depth;
            }
        }
        m_sessions.append(entry);
    }

    // 保底：如果服务器返回空列表，插入默认会话
    if (m_sessions.isEmpty()) {
        QVariantMap def;
        def[QStringLiteral("sessionKey")]  = QStringLiteral("agent:main:main");
        def[QStringLiteral("displayName")] = QStringLiteral("Main Agent");
        def[QStringLiteral("updatedAt")]   = QVariant(static_cast<qlonglong>(0));
        def[QStringLiteral("startedAt")]  = QVariant(static_cast<qlonglong>(0));
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
            if (resultText.length() > 50000)
                resultText = resultText.left(50000) + QStringLiteral("\n... (truncated)");

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
                    if (role == QLatin1String("user"))
                        t = userVisibleText(t);
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
            if (role == QLatin1String("user"))
                text = userVisibleText(text);
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
    // 便于侧栏显示最近会话标题（服务端会从 transcript 推导）
    params[QStringLiteral("includeDerivedTitles")] = true;
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

QJsonObject WsSession::buildChatHistoryParams(const QString &sessionKey,
                                               int limit) const
{
    const QString key = sessionKey.isEmpty() ? m_currentSessionKey : sessionKey;
    QJsonObject params;
    params[QStringLiteral("sessionKey")] = key;
    params[QStringLiteral("limit")]      = limit;
    return params;
}

QJsonObject WsSession::buildAgentIdentityParams(const QString &sessionKey) const
{
    const QString key = sessionKey.isEmpty() ? m_currentSessionKey : sessionKey;
    QJsonObject params;
    params[QStringLiteral("sessionKey")] = key;
    return params;
}

QVariantMap WsSession::parseAgentIdentityResponse(const QJsonObject &payload) const
{
    QVariantMap identity;

    auto extract = [&](const QString &field) {
        if (payload.contains(field))
            identity[field] = payload.value(field).toVariant();
    };

    extract(QStringLiteral("name"));
    extract(QStringLiteral("emoji"));
    extract(QStringLiteral("avatar"));
    extract(QStringLiteral("model"));
    extract(QStringLiteral("provider"));
    extract(QStringLiteral("sessionKey"));
    extract(QStringLiteral("sessionId"));
    extract(QStringLiteral("agentId"));
    extract(QStringLiteral("workspace"));

    qDebug() << "[WsSession] agent identity:"
             << identity.value(QStringLiteral("name")).toString()
             << identity.value(QStringLiteral("emoji")).toString();
    return identity;
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
        result.content      = extractToolOutputFromDataObject(data);
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
        result.content      = extractToolOutputFromDataObject(data);
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
                     || (phase == QLatin1String("end"))
                     || subEvent.contains(QLatin1String("complete"))
                     || subEvent.contains(QLatin1String("done"))
                     || subEvent.contains(QLatin1String("finish"))
                     || subEvent.contains(QLatin1String("end"));

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
