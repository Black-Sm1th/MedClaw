#include "chatmodel.h"

static QString chatDisplayContent(const QString &content)
{
    QString display = content;
    const QStringList tags{
        QStringLiteral("knowledge-base-policy"),
        QStringLiteral("workspace-policy"),
        QStringLiteral("template-parameters")
    };
    for (const QString &tag : tags) {
        const QString begin = QStringLiteral("<%1>").arg(tag);
        const QString end = QStringLiteral("</%1>").arg(tag);
        int beginPos = display.indexOf(begin);
        while (beginPos >= 0) {
            const int endPos = display.indexOf(end, beginPos + begin.size());
            display = endPos >= 0
                ? display.left(beginPos) + display.mid(endPos + end.size())
                : display.left(beginPos);
            beginPos = display.indexOf(begin);
        }
    }
    return display.trimmed();
}

ChatModel::ChatModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // 起跳节流 (leading-edge throttle)：
    //   - 第一个 chunk 立刻 flush，并启动一个节流窗口；
    //   - 窗口期间到达的 chunk 累积进 content + m_streamPending，置 m_streamDirty；
    //   - 窗口到期：若 dirty → 再 flush 一次（推送 delta 给 QML insert）并续期；
    //                若空闲 → 定时器停掉，等下一个 chunk 触发立刻 flush。
    m_streamFlushTimer.setSingleShot(true);
    connect(&m_streamFlushTimer, &QTimer::timeout, this, [this]() {
        if (!m_streamDirty) return;
        flushStream();
        if (m_streamFlushRow < 0 || m_streamFlushRow >= m_messages.count()) return;
        // flushStream 已把 pending 合并进 content，长度即为「QML 端当前总文本长度」
        const int len = m_messages[m_streamFlushRow].content.length();
        m_streamFlushTimer.setInterval(streamFlushIntervalMsFor(len));
        m_streamFlushTimer.start();
    });
}

int ChatModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_messages.count();
}

QVariant ChatModel::data(const QModelIndex &index, int role) const
{
    if (index.row() < 0 || index.row() >= m_messages.count())
        return QVariant();

    const ChatMessage &msg = m_messages[index.row()];
    switch (role) {
    case RoleRole:       return msg.role;
    case ContentRole:    return msg.content;
    case TimestampRole:  return msg.timestamp.toString(QStringLiteral("hh:mm:ss"));
    case MsgTypeRole:    return msg.msgType;
    case ToolNameRole:   return msg.toolName;
    case ToolArgsRole:   return msg.toolArgs;
    case ToolCallIdRole: return msg.toolCallId;
    case IsErrorRole:    return msg.isError;
    case ToolResultTextRole: return msg.toolResultText;
    case HasToolResultRole:  return msg.hasToolResult;
    case IsStreamingRole:    return msg.isStreaming;
    case IsIntermediateRole: return msg.isIntermediate;
    case ArtifactsRole:      return msg.artifacts;
    }
    return QVariant();
}

QHash<int, QByteArray> ChatModel::roleNames() const
{
    return {
        { RoleRole,       "msgRole"    },
        { ContentRole,    "content"    },
        { TimestampRole,  "timestamp"  },
        { MsgTypeRole,    "msgType"    },
        { ToolNameRole,   "toolName"   },
        { ToolArgsRole,   "toolArgs"   },
        { ToolCallIdRole, "toolCallId" },
        { IsErrorRole,    "isError"    },
        { ToolResultTextRole, "toolResultText" },
        { HasToolResultRole,  "hasToolResult"  },
        { IsStreamingRole,    "isStreaming"    },
        { IsIntermediateRole, "isIntermediate" },
        { ArtifactsRole,      "artifacts"      }
    };
}

// ── 文本消息 ─────────────────────────────────────────────────────────

void ChatModel::addMessage(const QString &role, const QString &content)
{
    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    ChatMessage msg;
    msg.role      = role;
    msg.content   = role == QLatin1String("user")
        ? chatDisplayContent(content) : content;
    msg.timestamp = QDateTime::currentDateTime();
    msg.msgType   = QStringLiteral("text");
    msg.isError   = false;
    m_messages.append(msg);
    endInsertRows();
    emit countChanged();
}

// ── 工具调用 ─────────────────────────────────────────────────────────

void ChatModel::addToolCall(const QString &toolName,
                             const QString &toolArgs,
                             const QString &toolCallId)
{
    // 工具调用之前的助手文本属于「工具间中间输出」，标记为斜体显示。
    // 跳过相邻的 toolCall / toolResult 行（并行工具调用），只标记紧邻的那条助手文本。
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        const ChatMessage &m = m_messages[i];
        if (m.msgType == QStringLiteral("toolCall")
            || m.msgType == QStringLiteral("toolResult")) {
            continue;
        }
        if (m.msgType == QStringLiteral("text")
            && m.role == QStringLiteral("assistant")
            && !m.isIntermediate) {
            m_messages[i].isIntermediate = true;
            const QModelIndex midx = index(i);
            emit dataChanged(midx, midx, { IsIntermediateRole });
        }
        break;
    }

    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    ChatMessage msg;
    msg.role       = QStringLiteral("assistant");
    msg.content    = QString();
    msg.timestamp  = QDateTime::currentDateTime();
    msg.msgType    = QStringLiteral("toolCall");
    msg.toolName   = toolName;
    msg.toolArgs   = toolArgs;
    msg.toolCallId = toolCallId;
    msg.isError    = false;
    msg.hasToolResult = false;
    msg.toolResultText.clear();
    m_messages.append(msg);
    endInsertRows();
    emit countChanged();
}

// ── 工具结果 ─────────────────────────────────────────────────────────

void ChatModel::appendToolResult(const QString &toolName,
                                  const QString &content,
                                  const QString &toolCallId)
{
    if (content.isEmpty()) return;

    for (int i = m_messages.count() - 1; i >= 0; --i) {
        ChatMessage &msg = m_messages[i];
        const bool idMatches = !toolCallId.isEmpty()
            && msg.toolCallId == toolCallId;
        const bool fallbackMatches = toolCallId.isEmpty()
            && !toolName.isEmpty()
            && msg.toolName == toolName
            && !msg.hasToolResult;
        if (msg.msgType != QStringLiteral("toolCall")
            || (!idMatches && !fallbackMatches)) {
            continue;
        }

        // 网关可能发送 delta，也可能发送不断增长的完整快照。
        QString delta;
        if (content.startsWith(msg.toolResultText)) {
            delta = content.mid(msg.toolResultText.length());
            msg.toolResultText = content;
        } else if (!msg.toolResultText.endsWith(content)) {
            delta = content;
            msg.toolResultText += content;
        }

        if (!delta.isEmpty())
            emit toolResultFlushed(i, delta);
        emit messagePayloadChanged();
        return;
    }

    if (toolCallId.isEmpty() && toolName.isEmpty())
        return;

    // 少数网关不发 start，首个 update 也应立即创建执行中卡片。
    addToolCall(toolName, QString(), toolCallId);
    appendToolResult(toolName, content, toolCallId);
}

void ChatModel::addToolResult(const QString &toolName,
                               const QString &content,
                               const QString &toolCallId,
                               bool isError)
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages[i].msgType == QStringLiteral("toolCall")
            && !toolCallId.isEmpty()
            && m_messages[i].toolCallId == toolCallId) {
            if (!content.isEmpty())
                m_messages[i].toolResultText = content;
            m_messages[i].hasToolResult = true;
            m_messages[i].isError = isError;
            const QModelIndex idx = index(i);
            emit dataChanged(
                idx,
                idx,
                { IsErrorRole, ToolResultTextRole, HasToolResultRole });
            emit messagePayloadChanged();
            return;
        }
    }

    // 某些子 agent 的完成事件没有回传 toolCallId。此时仅回退匹配
    // 最近一个同名且尚未完成的调用，避免原卡片永久停留在“执行中”。
    if (toolCallId.isEmpty() && !toolName.isEmpty()) {
        for (int i = m_messages.count() - 1; i >= 0; --i) {
            if (m_messages[i].msgType != QStringLiteral("toolCall")
                || m_messages[i].hasToolResult
                || m_messages[i].toolName != toolName) {
                continue;
            }
            if (!content.isEmpty())
                m_messages[i].toolResultText = content;
            m_messages[i].hasToolResult = true;
            m_messages[i].isError = isError;
            const QModelIndex idx = index(i);
            emit dataChanged(
                idx,
                idx,
                { IsErrorRole, ToolResultTextRole, HasToolResultRole });
            emit messagePayloadChanged();
            return;
        }
    }

    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    ChatMessage msg;
    msg.role       = QStringLiteral("tool");
    msg.content    = content;
    msg.timestamp  = QDateTime::currentDateTime();
    msg.msgType    = QStringLiteral("toolResult");
    msg.toolName   = toolName;
    msg.toolCallId = toolCallId;
    msg.isError    = isError;
    m_messages.append(msg);
    endInsertRows();
    emit countChanged();
}

// ── 追加/修改 ────────────────────────────────────────────────────────

void ChatModel::appendToLastMessage(const QString &text)
{
    if (m_messages.isEmpty()) return;
    const int last = m_messages.count() - 1;
    m_messages[last].content += text;
    const QModelIndex idx = index(last);
    emit dataChanged(idx, idx, { ContentRole });
    emit messagePayloadChanged();
}

void ChatModel::clear()
{
    m_streamFlushTimer.stop();
    m_streamFlushRow = -1;
    m_streamDirty = false;
    m_streamPending.clear();
    const bool wasStreaming = m_streaming;
    m_streaming = false;
    beginResetModel();
    m_messages.clear();
    endResetModel();
    emit countChanged();
    if (wasStreaming)
        emit isStreamingChanged();
}

bool ChatModel::hasToolCallId(const QString &toolCallId) const
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages[i].msgType == QStringLiteral("toolCall")
            && m_messages[i].toolCallId == toolCallId) {
            return true;
        }
    }
    return false;
}

QVariantList ChatModel::messages() const
{
    QVariantList out;
    out.reserve(m_messages.count());
    for (const ChatMessage &msg : m_messages) {
        QVariantMap item;
        item.insert(QStringLiteral("msgRole"), msg.role);
        item.insert(QStringLiteral("content"), msg.content);
        item.insert(QStringLiteral("timestamp"), msg.timestamp.toString(QStringLiteral("hh:mm:ss")));
        item.insert(QStringLiteral("msgType"), msg.msgType);
        item.insert(QStringLiteral("toolName"), msg.toolName);
        item.insert(QStringLiteral("toolArgs"), msg.toolArgs);
        item.insert(QStringLiteral("toolCallId"), msg.toolCallId);
        item.insert(QStringLiteral("isError"), msg.isError);
        item.insert(QStringLiteral("toolResultText"), msg.toolResultText);
        item.insert(QStringLiteral("hasToolResult"), msg.hasToolResult);
        item.insert(QStringLiteral("isStreaming"), msg.isStreaming);
        item.insert(QStringLiteral("isIntermediate"), msg.isIntermediate);
        item.insert(QStringLiteral("artifacts"), msg.artifacts);
        out.append(item);
    }
    return out;
}

void ChatModel::setArtifactsForLastAssistant(const QVariantList &artifacts)
{
    if (artifacts.isEmpty())
        return;

    for (int i = m_messages.count() - 1; i >= 0; --i) {
        ChatMessage &msg = m_messages[i];
        if (msg.role != QLatin1String("assistant")
            || msg.msgType != QLatin1String("text")
            || msg.isIntermediate || msg.isStreaming) {
            continue;
        }
        msg.artifacts = artifacts;
        const QModelIndex idx = index(i);
        emit dataChanged(idx, idx, { ArtifactsRole });
        emit messagePayloadChanged();
        return;
    }
}

void ChatModel::loadHistory(const QVariantList &messages)
{
    m_streamFlushTimer.stop();
    m_streamFlushRow = -1;
    m_streamDirty = false;
    m_streamPending.clear();
    const bool wasStreaming = m_streaming;
    m_streaming = false;

    beginResetModel();
    m_messages.clear();
    m_messages.reserve(messages.count());

    for (const QVariant &v : messages) {
        const QVariantMap m = v.toMap();
        const QString mtype = m.value(QStringLiteral("msgType")).toString();

        if (mtype == QLatin1String("toolCall")) {
            for (int i = m_messages.count() - 1; i >= 0; --i) {
                const ChatMessage &prev = m_messages[i];
                if (prev.msgType == QStringLiteral("toolCall")
                    || prev.msgType == QStringLiteral("toolResult")) {
                    continue;
                }
                if (prev.msgType == QStringLiteral("text")
                    && prev.role == QStringLiteral("assistant")
                    && !prev.isIntermediate) {
                    m_messages[i].isIntermediate = true;
                }
                break;
            }

            ChatMessage msg;
            msg.role = QStringLiteral("assistant");
            msg.timestamp = QDateTime::currentDateTime();
            msg.msgType = QStringLiteral("toolCall");
            msg.toolName = m.value(QStringLiteral("toolName")).toString();
            msg.toolArgs = m.value(QStringLiteral("toolArgs")).toString();
            msg.toolCallId = m.value(QStringLiteral("toolCallId")).toString();
            msg.isError = false;
            msg.hasToolResult = false;
            m_messages.append(msg);
            continue;
        }

        if (mtype == QLatin1String("toolResult")) {
            const QString toolCallId = m.value(QStringLiteral("toolCallId")).toString();
            bool merged = false;
            for (int i = m_messages.count() - 1; i >= 0; --i) {
                if (m_messages[i].msgType == QStringLiteral("toolCall")
                    && m_messages[i].toolCallId == toolCallId) {
                    m_messages[i].toolResultText = m.value(QStringLiteral("content")).toString();
                    m_messages[i].hasToolResult = true;
                    m_messages[i].isError = m.value(QStringLiteral("isError")).toBool();
                    merged = true;
                    break;
                }
            }
            if (merged)
                continue;

            ChatMessage msg;
            msg.role = QStringLiteral("tool");
            msg.content = m.value(QStringLiteral("content")).toString();
            msg.timestamp = QDateTime::currentDateTime();
            msg.msgType = QStringLiteral("toolResult");
            msg.toolName = m.value(QStringLiteral("toolName")).toString();
            msg.toolCallId = toolCallId;
            msg.isError = m.value(QStringLiteral("isError")).toBool();
            m_messages.append(msg);
            continue;
        }

        ChatMessage msg;
        msg.role = m.value(QStringLiteral("role")).toString();
        msg.content = msg.role == QLatin1String("user")
            ? chatDisplayContent(m.value(QStringLiteral("content")).toString())
            : m.value(QStringLiteral("content")).toString();
        msg.timestamp = QDateTime::currentDateTime();
        msg.msgType = QStringLiteral("text");
        msg.isError = false;
        msg.artifacts = m.value(QStringLiteral("artifacts")).toList();
        m_messages.append(msg);
    }

    endResetModel();
    emit countChanged();
    if (wasStreaming)
        emit isStreamingChanged();
    emit messagePayloadChanged();
}

// ── Streaming ────────────────────────────────────────────────────────
//
// 设计要点（既要保留 Markdown 渲染、又要避免长文本流式时卡死）：
//
//   - 朴素 `text: content` + `textFormat: MarkdownText` 绑定：每次 dataChanged
//     都会触发 QTextDocument::setMarkdown(整段)，O(N) 全量 reparse + 全量 block layout，
//     长文本下单次重排就能在主线程同步阻塞数百毫秒到几秒，整窗 UI 卡死。
//
//   - 当前方案（增量 insert + 终态精排）：
//       * 流式期间：QML 端 textFormat = PlainText，且 bubbleText.text 不再 binding
//         到 content；ChatModel 在 flush 时通过 streamFlushed(row, delta) signal
//         把「自上次 flush 以来的新增片段」推给 QML，delegate 调用
//         TextEdit::insert(length, delta) 局部追加，QTextDocument 只对追加段做
//         增量 layout，不重排已有内容。
//       * 流式结束：emit dataChanged(ContentRole, IsStreamingRole) 让 QML 组件拿到
//         完整文本；组件会延迟做最终 Markdown 精排，超长内容则继续保留纯文本。
//       * m_messages[row].content 仍持有完整累积副本，便于 delegate 滚出滚回重建、
//         或之后 historyLoaded / 重新查看会话时一次性 onCompleted 注入完整文本。

int ChatModel::streamFlushIntervalMsFor(int contentLen)
{
    // 自适应节流：内容越长，单次 layout / 度量 / 粘底滚动越贵，间隔越宽。
    //   < ~7.5KB        → 30ms   （≈33Hz，逐字打字感）
    //   7.5KB ~ 250KB   → 线性放宽
    //   ≥ 250KB         → 1000ms （封顶，避免超长文本度量吃掉整帧）
    const int v = contentLen / 250;
    if (v < 30)   return 30;
    if (v > 1000) return 1000;
    return v;
}

void ChatModel::beginStreaming()
{
    if (!m_streaming) {
        m_streaming = true;
        emit isStreamingChanged();
        const int idx = m_messages.count();
        beginInsertRows(QModelIndex(), idx, idx);
        ChatMessage msg;
        msg.role        = QStringLiteral("assistant");
        msg.content     = QString();
        msg.timestamp   = QDateTime::currentDateTime();
        msg.msgType     = QStringLiteral("text");
        msg.isError     = false;
        msg.isStreaming = true;
        m_messages.append(msg);
        endInsertRows();
        emit countChanged();
    }
}

void ChatModel::flushStream()
{
    m_streamDirty = false;
    if (m_streamFlushRow < 0 || m_streamFlushRow >= m_messages.count()) {
        m_streamFlushRow = -1;
        m_streamPending.clear();
        return;
    }
    if (!m_streamPending.isEmpty()) {
        // 关键不变量：m_messages[row].content 始终等于「已经 emit 给 QML 的累积」，
        // 即 QML 端 bubbleText 应当已经显示的内容。pending 是「未 emit 的尾部」。
        // 这里先把 pending 合并进 content，再 emit；之后 onCompleted 用 content
        // 注入新建/回收重建的 delegate 时，与后续 streamFlushed 不会有重复区段。
        m_messages[m_streamFlushRow].content += m_streamPending;
        emit streamFlushed(m_streamFlushRow, m_streamPending);
        m_streamPending.clear();
    }
    // 流式期间不再广播 ContentRole：可见 delegate 已通过 streamFlushed(delta)
    // 命令式追加，滚出后重建的 delegate 会直接读取 model 中最新 content。
    // 等流式结束再一次性 emit ContentRole，避免 QML 每个 flush 都重新评估整段文本。
    emit messagePayloadChanged();
}

void ChatModel::appendStreamChunk(const QString &chunk)
{
    if (chunk.isEmpty()) return;
    if (!m_streaming)
        beginStreaming();
    if (m_messages.isEmpty()
        || m_messages.last().role != QLatin1String("assistant")
        || m_messages.last().msgType != QLatin1String("text")) {
        const int idx = m_messages.count();
        beginInsertRows(QModelIndex(), idx, idx);
        ChatMessage msg;
        msg.role        = QStringLiteral("assistant");
        msg.content     = QString();
        msg.timestamp   = QDateTime::currentDateTime();
        msg.msgType     = QStringLiteral("text");
        msg.isError     = false;
        msg.isStreaming = true;
        m_messages.append(msg);
        endInsertRows();
        emit countChanged();
    } else if (!m_messages.last().isStreaming) {
        m_messages.last().isStreaming = true;
        const QModelIndex idx = index(m_messages.count() - 1);
        emit dataChanged(idx, idx, { IsStreamingRole });
    }

    const int last = m_messages.count() - 1;
    if (m_streamFlushRow >= 0
        && m_streamFlushRow != last
        && m_streamFlushRow < m_messages.count()
        && !m_streamPending.isEmpty()) {
        // 切到新一行（如 toolCall 后又开始流式）：先把上一行尚未 emit 的残余 delta
        // 合并进上一行 content 并推送出去，否则 QML 端那一行末尾会缺最后一小段文字。
        m_messages[m_streamFlushRow].content += m_streamPending;
        emit streamFlushed(m_streamFlushRow, m_streamPending);
        const QModelIndex prevIdx = index(m_streamFlushRow);
        emit dataChanged(prevIdx, prevIdx, { ContentRole });
    }
    if (m_streamFlushRow != last) {
        m_streamPending.clear();
    }
    // 注意：content 不在这里追加，只在 flushStream / endStreaming 把 pending
    // 合并进去时才推进，确保 content == 「已 emit 给 QML 的累积」不变量。
    m_streamPending += chunk;
    m_streamFlushRow = last;
    m_streamDirty = true;

    // 节流间隔随内容长度自适应放宽，详见 streamFlushIntervalMsFor()。
    if (!m_streamFlushTimer.isActive()) {
        // 起跳节流：定时器空闲时第一个 chunk 立即可见，再开始节流窗口
        flushStream();
        // flushStream 已把 pending 合并进 content
        const int len = m_messages[last].content.length();
        m_streamFlushTimer.setInterval(streamFlushIntervalMsFor(len));
        m_streamFlushTimer.start();
    }
    // 定时器正在跑：仅累积，timeout 回调里会续期。
}

void ChatModel::endStreaming()
{
    if (!m_streaming) return;
    m_streaming = false;
    emit isStreamingChanged();
    m_streamFlushTimer.stop();
    m_streamDirty = false;
    if (m_messages.isEmpty()) {
        m_streamFlushRow = -1;
        m_streamPending.clear();
        return;
    }
    const int last = m_messages.count() - 1;
    // 关键顺序：先把残留 delta 合并进 content + 推给 QML，让 bubbleText insert 到末尾；
    // 之后再翻 IsStreamingRole：QML 端单 WebEngine 聊天区会用完整 content
    // 做最终 Markdown 渲染；流式阶段只追加纯文本 delta。
    if (m_streamFlushRow == last && !m_streamPending.isEmpty()) {
        m_messages[last].content += m_streamPending;
        emit streamFlushed(last, m_streamPending);
        m_streamPending.clear();
    }
    if (m_messages[last].isStreaming)
        m_messages[last].isStreaming = false;
    const QModelIndex idx = index(last);
    emit dataChanged(idx, idx, { ContentRole, IsStreamingRole });
    emit messagePayloadChanged();
    m_streamFlushRow = -1;
    m_streamPending.clear();
}

bool ChatModel::isStreaming() const
{
    return m_streaming;
}
