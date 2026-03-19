/**
 * @file session_reader.cpp
 * @brief 本地会话历史读取器 —— 实现
 */
#include "session_reader.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>
#include <algorithm>

// ═══════════════════════════════════════════════════════════════════════
//  构造
// ═══════════════════════════════════════════════════════════════════════

SessionReader::SessionReader(QObject *parent)
    : QObject(parent)
{
    m_openclawDir = QDir::homePath() + QStringLiteral("/.openclaw");
    m_sessionsDir = m_openclawDir + QStringLiteral("/agents/main/sessions");

    qDebug() << "[SessionReader] openclaw dir:" << m_openclawDir;
    qDebug() << "[SessionReader] sessions dir:" << m_sessionsDir;
}

// ═══════════════════════════════════════════════════════════════════════
//  属性访问器
// ═══════════════════════════════════════════════════════════════════════

QString SessionReader::sessionsDir() const { return m_sessionsDir; }

QVariantList SessionReader::sessionList() const { return m_sessionList; }

// ═══════════════════════════════════════════════════════════════════════
//  从 .jsonl 头部快速提取摘要
// ═══════════════════════════════════════════════════════════════════════

QVariantMap SessionReader::quickParseSummary(const QString &filePath)
{
    QVariantMap info;
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly))
        return info;

    int msgCount     = 0;
    int userCount    = 0;
    int asstCount    = 0;
    int toolCount    = 0;
    QString firstUserMsg;

    while (!file.atEnd()) {
        const QByteArray line = file.readLine().trimmed();
        if (line.isEmpty()) continue;

        const QJsonObject obj = QJsonDocument::fromJson(line).object();
        const QString type = obj.value(QStringLiteral("type")).toString();

        // 第一行：会话头信息
        if (type == QLatin1String("session")) {
            info[QStringLiteral("sessionId")] =
                obj.value(QStringLiteral("id")).toString();
            info[QStringLiteral("version")] =
                obj.value(QStringLiteral("version")).toInt();
            info[QStringLiteral("createdAt")] =
                obj.value(QStringLiteral("timestamp")).toString();
            info[QStringLiteral("cwd")] =
                obj.value(QStringLiteral("cwd")).toString();
        }
        // 模型变更记录
        else if (type == QLatin1String("model_change")) {
            info[QStringLiteral("modelProvider")] =
                obj.value(QStringLiteral("provider")).toString();
            info[QStringLiteral("modelId")] =
                obj.value(QStringLiteral("modelId")).toString();
        }
        // 思考级别
        else if (type == QLatin1String("thinking_level_change")) {
            info[QStringLiteral("thinkingLevel")] =
                obj.value(QStringLiteral("thinkingLevel")).toString();
        }
        // 消息：统计并提取首条用户消息
        else if (type == QLatin1String("message")) {
            const QJsonObject msg = obj.value(QStringLiteral("message")).toObject();
            const QString role = msg.value(QStringLiteral("role")).toString();

            if (role == QLatin1String("user")) {
                ++userCount;
                ++msgCount;
                if (firstUserMsg.isEmpty()) {
                    const QJsonArray arr = msg.value(QStringLiteral("content")).toArray();
                    for (const QJsonValue &cv : arr) {
                        const QJsonObject co = cv.toObject();
                        if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                            QString t = co.value(QStringLiteral("text")).toString();
                            // 清理时间戳前缀
                            int bracket = t.indexOf(QLatin1Char(']'));
                            if (bracket >= 0 && bracket < 40
                                && t.contains(QStringLiteral("GMT")))
                                t = t.mid(bracket + 1).trimmed();
                            // 清理 [message_id: ...]
                            int msgIdIdx = t.indexOf(QStringLiteral("\n[message_id:"));
                            if (msgIdIdx >= 0)
                                t = t.left(msgIdIdx).trimmed();
                            firstUserMsg = t;
                            break;
                        }
                    }
                }
            } else if (role == QLatin1String("assistant")) {
                ++asstCount;
                ++msgCount;
                // 检查是否含工具调用
                const QJsonArray arr = msg.value(QStringLiteral("content")).toArray();
                for (const QJsonValue &cv : arr) {
                    if (cv.toObject().value(QStringLiteral("type")).toString()
                        == QLatin1String("toolCall")) {
                        ++toolCount;
                        break;
                    }
                }
            }
        }
    }
    file.close();

    // 首条用户消息截取 60 字符作为预览
    if (firstUserMsg.length() > 60)
        firstUserMsg = firstUserMsg.left(60) + QStringLiteral("...");

    info[QStringLiteral("firstUserMsg")]      = firstUserMsg;
    info[QStringLiteral("messageCount")]       = msgCount;
    info[QStringLiteral("userMsgCount")]       = userCount;
    info[QStringLiteral("assistantMsgCount")]  = asstCount;
    info[QStringLiteral("toolCallCount")]      = toolCount;

    return info;
}

// ═══════════════════════════════════════════════════════════════════════
//  扫描 sessions 目录
// ═══════════════════════════════════════════════════════════════════════

void SessionReader::scanSessions()
{
    m_sessionList.clear();

    QDir dir(m_sessionsDir);
    if (!dir.exists()) {
        qWarning() << "[SessionReader] sessions dir not found:" << m_sessionsDir;
        emit sessionListChanged();
        return;
    }

    // ── 读 sessions.json 获取活跃会话 ID ──
    QString activeSessionId;
    {
        QFile sjFile(dir.filePath(QStringLiteral("sessions.json")));
        if (sjFile.open(QIODevice::ReadOnly)) {
            const QJsonObject root =
                QJsonDocument::fromJson(sjFile.readAll()).object();
            sjFile.close();
            for (auto it = root.begin(); it != root.end(); ++it) {
                activeSessionId = it.value().toObject()
                    .value(QStringLiteral("sessionId")).toString();
                if (!activeSessionId.isEmpty()) break;
            }
        }
    }

    // ── 列出所有 .jsonl 相关文件 ──
    const QStringList allFiles = dir.entryList(QDir::Files, QDir::Time);
    for (const QString &fn : allFiles) {
        // 只处理包含 .jsonl 的文件，跳过 sessions.json
        if (!fn.contains(QStringLiteral(".jsonl")))
            continue;

        const QString fullPath = dir.absoluteFilePath(fn);

        // 快速提取摘要
        QVariantMap summary = quickParseSummary(fullPath);
        const QString sessionId =
            summary.value(QStringLiteral("sessionId")).toString();
        if (sessionId.isEmpty()) continue;

        const bool isActive = (sessionId == activeSessionId)
                              && fn.endsWith(QStringLiteral(".jsonl"))
                              && !fn.contains(QStringLiteral(".reset."));

        // ── 提取归档时间 ──
        QString resetTime;
        int resetIdx = fn.indexOf(QStringLiteral(".reset."));
        if (resetIdx >= 0) {
            resetTime = fn.mid(resetIdx + 7);     // "2026-03-13T02-35-37.199Z"
            resetTime.replace(QLatin1Char('T'), QLatin1Char(' '));
            // 把 "02-35-37" 格式的时分秒中的连字符还原为冒号
            // 格式: "2026-03-13 02-35-37.199Z" → "2026-03-13 02:35:37"
            int spaceIdx = resetTime.indexOf(QLatin1Char(' '));
            if (spaceIdx >= 0) {
                QString datePart = resetTime.left(spaceIdx);
                QString timePart = resetTime.mid(spaceIdx + 1);
                // 时间部分 "02-35-37.199Z" → "02:35:37"
                timePart.remove(QLatin1Char('Z'));
                int dotIdx = timePart.indexOf(QLatin1Char('.'));
                if (dotIdx >= 0) timePart = timePart.left(dotIdx);
                timePart.replace(QLatin1Char('-'), QLatin1Char(':'));
                resetTime = datePart + QStringLiteral(" ") + timePart;
            }
        }

        // ── 构建显示名称 ──
        QString displayName;
        const QString preview =
            summary.value(QStringLiteral("firstUserMsg")).toString();
        const int msgCnt =
            summary.value(QStringLiteral("messageCount")).toInt();
        const QString model =
            summary.value(QStringLiteral("modelId")).toString();

        if (isActive) {
            displayName = QStringLiteral("[活跃] ");
        } else if (!resetTime.isEmpty()) {
            displayName = QStringLiteral("[归档 %1] ").arg(resetTime.left(10));
        } else {
            displayName = QStringLiteral("[历史] ");
        }

        if (!preview.isEmpty()) {
            displayName += preview.left(20);
        } else {
            displayName += sessionId.left(8);
        }
        displayName += QStringLiteral(" (%1条)").arg(msgCnt);

        // ── 组装条目 ──
        QVariantMap entry;
        entry[QStringLiteral("sessionId")]      = sessionId;
        entry[QStringLiteral("filePath")]        = fullPath;
        entry[QStringLiteral("fileName")]        = fn;
        entry[QStringLiteral("isActive")]        = isActive;
        entry[QStringLiteral("timestamp")]       =
            summary.value(QStringLiteral("createdAt"));
        entry[QStringLiteral("displayName")]     = displayName;
        entry[QStringLiteral("preview")]         = preview;
        entry[QStringLiteral("messageCount")]    = msgCnt;
        entry[QStringLiteral("modelProvider")]   =
            summary.value(QStringLiteral("modelProvider"));
        entry[QStringLiteral("modelId")]         = model;
        entry[QStringLiteral("resetTime")]       = resetTime;
        entry[QStringLiteral("userMsgCount")]    =
            summary.value(QStringLiteral("userMsgCount"));
        entry[QStringLiteral("assistantMsgCount")] =
            summary.value(QStringLiteral("assistantMsgCount"));
        entry[QStringLiteral("toolCallCount")]   =
            summary.value(QStringLiteral("toolCallCount"));
        entry[QStringLiteral("cwd")]             =
            summary.value(QStringLiteral("cwd"));
        entry[QStringLiteral("thinkingLevel")]   =
            summary.value(QStringLiteral("thinkingLevel"));

        m_sessionList.append(entry);
    }

    qDebug() << "[SessionReader] found" << m_sessionList.count() << "session files";
    emit sessionListChanged();
}

// ═══════════════════════════════════════════════════════════════════════
//  读取 sessions.json（完整字段，无遗漏）
// ═══════════════════════════════════════════════════════════════════════

QVariantMap SessionReader::readSessionsJson()
{
    const QString path = m_sessionsDir + QStringLiteral("/sessions.json");

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[SessionReader] cannot open sessions.json:" << path;
        return QVariantMap();
    }

    const QByteArray data = file.readAll();
    file.close();

    // toVariantMap() 会完整保留所有字段和嵌套结构：
    //   sessionId, updatedAt, systemSent, abortedLastRun,
    //   chatType, deliveryContext, lastChannel, origin,
    //   sessionFile, compactionCount, totalTokensFresh,
    //   skillsSnapshot { prompt, skills[], resolvedSkills[], version },
    //   authProfileOverride, authProfileOverrideSource,
    //   authProfileOverrideCompactionCount,
    //   inputTokens, outputTokens,
    //   modelProvider, model, contextTokens,
    //   systemPromptReport { source, generatedAt, ... 完整子结构 }
    return QJsonDocument::fromJson(data).object().toVariantMap();
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 .jsonl 文件中的聊天消息
// ═══════════════════════════════════════════════════════════════════════

QVariantList SessionReader::readSessionMessages(const QString &filePath)
{
    QVariantList messages;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[SessionReader] cannot open:" << filePath;
        return messages;
    }

    while (!file.atEnd()) {
        const QByteArray line = file.readLine().trimmed();
        if (line.isEmpty()) continue;

        const QJsonObject obj = QJsonDocument::fromJson(line).object();
        if (obj.value(QStringLiteral("type")).toString() != QLatin1String("message"))
            continue;

        const QJsonObject msg = obj.value(QStringLiteral("message")).toObject();
        const QString role = msg.value(QStringLiteral("role")).toString();
        const QString ts   = obj.value(QStringLiteral("timestamp")).toString();

        // ── toolResult → 独立的工具结果条目 ──
        if (role == QLatin1String("toolResult")) {
            const QString tcId = msg.value(QStringLiteral("toolCallId")).toString();
            const QString tName = msg.value(QStringLiteral("toolName")).toString();
            const bool isErr = msg.value(QStringLiteral("isError")).toBool(false);
            // 拼接 content 数组中的所有文本
            QString resultText;
            const QJsonArray cArr = msg.value(QStringLiteral("content")).toArray();
            for (const QJsonValue &cv : cArr) {
                const QJsonObject co = cv.toObject();
                if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                    if (!resultText.isEmpty()) resultText += QLatin1Char('\n');
                    resultText += co.value(QStringLiteral("text")).toString();
                }
            }
            // 截断过长的工具结果（防止 QML 渲染卡顿）
            if (resultText.length() > 2000)
                resultText = resultText.left(2000) + QStringLiteral("\n... (截断)");

            QVariantMap entry;
            entry[QStringLiteral("role")]       = QStringLiteral("tool");
            entry[QStringLiteral("content")]    = resultText;
            entry[QStringLiteral("timestamp")]  = ts;
            entry[QStringLiteral("msgType")]    = QStringLiteral("toolResult");
            entry[QStringLiteral("toolName")]   = tName;
            entry[QStringLiteral("toolCallId")] = tcId;
            entry[QStringLiteral("isError")]    = isErr;
            messages.append(entry);
            continue;
        }

        // ── user / assistant 消息 ──
        const QJsonArray contentArr = msg.value(QStringLiteral("content")).toArray();

        for (const QJsonValue &cv : contentArr) {
            const QJsonObject co = cv.toObject();
            const QString ctype = co.value(QStringLiteral("type")).toString();

            if (ctype == QLatin1String("text")) {
                QString t = co.value(QStringLiteral("text")).toString();

                // 清理 [message_id: ...] 尾缀
                int msgIdIdx = t.indexOf(QStringLiteral("\n[message_id:"));
                if (msgIdIdx >= 0)
                    t = t.left(msgIdIdx).trimmed();

                // 清理用户消息中的时间戳前缀 [Sat 2026-03-14 11:13 GMT+8]
                if (role == QLatin1String("user")) {
                    QRegExp tsRegex(QStringLiteral("^\\[.*?GMT[+-]\\d+\\]\\s*"));
                    t.replace(tsRegex, QString());
                }

                if (t.isEmpty()) continue;

                QVariantMap entry;
                entry[QStringLiteral("role")]      = role;
                entry[QStringLiteral("content")]   = t;
                entry[QStringLiteral("timestamp")] = ts;
                entry[QStringLiteral("msgType")]   = QStringLiteral("text");
                messages.append(entry);

            } else if (ctype == QLatin1String("toolCall")) {
                // 每个 toolCall 作为独立条目
                const QString tcId   = co.value(QStringLiteral("id")).toString();
                const QString tName  = co.value(QStringLiteral("name")).toString();
                const QJsonObject args = co.value(QStringLiteral("arguments")).toObject();
                QString argsStr = QString::fromUtf8(
                    QJsonDocument(args).toJson(QJsonDocument::Compact));
                if (argsStr.length() > 1000)
                    argsStr = argsStr.left(1000) + QStringLiteral("...");

                QVariantMap entry;
                entry[QStringLiteral("role")]       = QStringLiteral("assistant");
                entry[QStringLiteral("content")]    = QString();
                entry[QStringLiteral("timestamp")]  = ts;
                entry[QStringLiteral("msgType")]    = QStringLiteral("toolCall");
                entry[QStringLiteral("toolName")]   = tName;
                entry[QStringLiteral("toolArgs")]   = argsStr;
                entry[QStringLiteral("toolCallId")] = tcId;
                messages.append(entry);
            }
        }
    }

    file.close();
    qDebug() << "[SessionReader] parsed" << messages.count()
             << "entries from" << QFileInfo(filePath).fileName();
    return messages;
}

// ═══════════════════════════════════════════════════════════════════════
//  获取会话摘要（公开接口，复用 quickParseSummary）
// ═══════════════════════════════════════════════════════════════════════

QVariantMap SessionReader::readSessionSummary(const QString &filePath)
{
    return quickParseSummary(filePath);
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 messages.list RPC 响应文件
// ═══════════════════════════════════════════════════════════════════════

QVariantList SessionReader::parseResponseFile(const QString &filePath)
{
    QVariantList result;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[SessionReader] parseResponseFile: cannot open" << filePath;
        return result;
    }

    const QByteArray raw = file.readAll();
    file.close();

    // 抓包文件格式可能是：
    //   - 单行或多行的一大坨，中间夹杂时间戳和制表符
    //   - 需要从中提取所有 JSON 对象
    // 策略：找到所有 {"type":"res" 开头的 JSON 块，逐个解析
    QJsonArray messagesArr;
    int searchFrom = 0;
    const QByteArray marker("{\"type\":\"res\"");
    while (searchFrom < raw.size()) {
        int start = raw.indexOf(marker, searchFrom);
        if (start < 0) break;

        // 找到匹配的 JSON 对象结尾（花括号配对）
        int depth = 0;
        int end = -1;
        bool inStr = false;
        bool escape = false;
        for (int i = start; i < raw.size(); ++i) {
            char c = raw.at(i);
            if (escape) { escape = false; continue; }
            if (c == '\\' && inStr) { escape = true; continue; }
            if (c == '"') { inStr = !inStr; continue; }
            if (inStr) continue;
            if (c == '{') ++depth;
            else if (c == '}') {
                --depth;
                if (depth == 0) { end = i; break; }
            }
        }
        if (end < 0) break;

        const QByteArray jsonBlock = raw.mid(start, end - start + 1);
        searchFrom = end + 1;

        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(jsonBlock, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            continue;

        const QJsonObject obj = doc.object();
        QJsonArray arr = obj.value(QStringLiteral("payload")).toObject()
                             .value(QStringLiteral("messages")).toArray();
        if (arr.isEmpty())
            arr = obj.value(QStringLiteral("messages")).toArray();

        if (!arr.isEmpty()) {
            qDebug() << "[SessionReader] found messages block with"
                     << arr.count() << "messages";
            messagesArr = arr; // 取最长的（最后一个通常最完整）
        }
    }

    // 如果上面找不到，尝试直接当单个 JSON 解析
    if (messagesArr.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(raw);
        if (doc.isObject()) {
            messagesArr = doc.object()
                .value(QStringLiteral("payload")).toObject()
                .value(QStringLiteral("messages")).toArray();
            if (messagesArr.isEmpty())
                messagesArr = doc.object()
                    .value(QStringLiteral("messages")).toArray();
        }
    }

    if (messagesArr.isEmpty()) {
        qWarning() << "[SessionReader] parseResponseFile: no messages found in"
                   << filePath;
        return result;
    }

    qDebug() << "[SessionReader] parseResponseFile: found"
             << messagesArr.count() << "raw messages";

    // 复用与 readSessionMessages 相同的解析逻辑
    for (const QJsonValue &v : messagesArr) {
        const QJsonObject m = v.toObject();
        const QString role  = m.value(QStringLiteral("role")).toString();
        if (role.isEmpty()) continue;

        const qint64 tsMs = static_cast<qint64>(
            m.value(QStringLiteral("timestamp")).toDouble());
        const QString ts = QDateTime::fromMSecsSinceEpoch(tsMs)
                               .toString(QStringLiteral("hh:mm:ss"));

        // ── toolResult ──
        if (role == QLatin1String("toolResult")) {
            const QString tcId  = m.value(QStringLiteral("toolCallId")).toString();
            const QString tName = m.value(QStringLiteral("toolName")).toString();
            const bool isErr    = m.value(QStringLiteral("isError")).toBool(false);

            QString resultText;
            const QJsonValue cv = m.value(QStringLiteral("content"));
            if (cv.isArray()) {
                for (const QJsonValue &item : cv.toArray()) {
                    const QJsonObject co = item.toObject();
                    if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                        if (!resultText.isEmpty()) resultText += QLatin1Char('\n');
                        resultText += co.value(QStringLiteral("text")).toString();
                    }
                }
            } else {
                resultText = cv.toString();
            }
            if (resultText.length() > 2000)
                resultText = resultText.left(2000) + QStringLiteral("\n...(truncated)");

            QVariantMap entry;
            entry[QStringLiteral("role")]       = QStringLiteral("tool");
            entry[QStringLiteral("content")]    = resultText;
            entry[QStringLiteral("timestamp")]  = ts;
            entry[QStringLiteral("msgType")]    = QStringLiteral("toolResult");
            entry[QStringLiteral("toolName")]   = tName;
            entry[QStringLiteral("toolCallId")] = tcId;
            entry[QStringLiteral("isError")]    = isErr;
            result.append(entry);
            continue;
        }

        // ── user / assistant 消息 ──
        const QJsonValue contentVal = m.value(QStringLiteral("content"));
        if (contentVal.isArray()) {
            for (const QJsonValue &item : contentVal.toArray()) {
                const QJsonObject co = item.toObject();
                const QString ctype = co.value(QStringLiteral("type")).toString();

                if (ctype == QLatin1String("text")) {
                    QString t = co.value(QStringLiteral("text")).toString();
                    // 清理系统注入的 message_id
                    int mi = t.indexOf(QStringLiteral("\n[message_id:"));
                    if (mi >= 0) t = t.left(mi).trimmed();
                    // 清理用户消息的时间戳前缀
                    if (role == QLatin1String("user") && t.startsWith(QLatin1Char('['))) {
                        int rb = t.indexOf(QStringLiteral("] "));
                        if (rb > 0 && rb < 60) t = t.mid(rb + 2);
                    }
                    // 跳过 /new /reset 系统指令
                    if (role == QLatin1String("user")
                        && t.startsWith(QLatin1String("A new session was started")))
                        continue;
                    if (t.isEmpty()) continue;

                    QVariantMap entry;
                    entry[QStringLiteral("role")]      = role;
                    entry[QStringLiteral("content")]   = t;
                    entry[QStringLiteral("timestamp")] = ts;
                    entry[QStringLiteral("msgType")]   = QStringLiteral("text");
                    result.append(entry);

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
                    entry[QStringLiteral("timestamp")]  = ts;
                    entry[QStringLiteral("msgType")]    = QStringLiteral("toolCall");
                    entry[QStringLiteral("toolName")]   = tName;
                    entry[QStringLiteral("toolArgs")]   = argsStr;
                    entry[QStringLiteral("toolCallId")] = tcId;
                    result.append(entry);
                }
            }
        } else {
            QString t = contentVal.toString();
            if (t.isEmpty()) continue;

            QVariantMap entry;
            entry[QStringLiteral("role")]      = role;
            entry[QStringLiteral("content")]   = t;
            entry[QStringLiteral("timestamp")] = ts;
            entry[QStringLiteral("msgType")]   = QStringLiteral("text");
            result.append(entry);
        }
    }

    qDebug() << "[SessionReader] parseResponseFile: parsed"
             << result.count() << "display entries";
    return result;
}

// ═══════════════════════════════════════════════════════════════════════
//  读取 openclaw.json 中的 agent 列表
// ═══════════════════════════════════════════════════════════════════════

QVariantList SessionReader::readAgentList()
{
    QVariantList agents;

    const QString configPath = m_openclawDir + QStringLiteral("/openclaw.json");
    QFile file(configPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[SessionReader] readAgentList: cannot open" << configPath;
        return agents;
    }

    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    file.close();

    const QJsonObject agentsObj = root.value(QStringLiteral("agents")).toObject();
    const QJsonArray  list      = agentsObj.value(QStringLiteral("list")).toArray();

    for (const QJsonValue &v : list) {
        const QJsonObject a = v.toObject();
        const QString id = a.value(QStringLiteral("id")).toString();
        if (id.isEmpty()) continue;

        QString name = a.value(QStringLiteral("name")).toString();
        if (name.isEmpty()) name = id;

        QVariantMap entry;
        entry[QStringLiteral("id")]         = id;
        entry[QStringLiteral("name")]       = name;
        entry[QStringLiteral("sessionKey")] =
            QStringLiteral("agent:%1:main").arg(id);
        entry[QStringLiteral("isDefault")]  =
            a.value(QStringLiteral("default")).toBool(false);
        entry[QStringLiteral("workspace")]  =
            a.value(QStringLiteral("workspace")).toString();
        entry[QStringLiteral("agentDir")]   =
            a.value(QStringLiteral("agentDir")).toString();

        agents.append(entry);
    }

    qDebug() << "[SessionReader] readAgentList: found" << agents.count() << "agents";
    return agents;
}
