#include "chatmodel.h"

ChatModel::ChatModel(QObject *parent)
    : QAbstractListModel(parent)
{
    // 起跳节流 (leading-edge throttle)：
    //   - 第一个 chunk 立刻 flush，并启动一个节流窗口；
    //   - 窗口期间到达的 chunk 累积进 content，置 m_streamDirty；
    //   - 窗口到期：若 dirty → 再 flush 一次并续期；若空闲 → 定时器停掉，
    //                等下一个 chunk 触发立刻 flush（保证下一次响应是即时的）。
    m_streamFlushTimer.setSingleShot(true);
    connect(&m_streamFlushTimer, &QTimer::timeout, this, [this]() {
        if (!m_streamDirty) return;
        flushStream();
        if (m_streamFlushRow < 0 || m_streamFlushRow >= m_messages.count()) return;
        const int len = m_messages[m_streamFlushRow].content.length();
        m_streamFlushTimer.setInterval(qBound(30, len / 250, 500));
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
        { IsIntermediateRole, "isIntermediate" }
    };
}

// ── 文本消息 ─────────────────────────────────────────────────────────

void ChatModel::addMessage(const QString &role, const QString &content)
{
    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    ChatMessage msg;
    msg.role      = role;
    msg.content   = content;
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

void ChatModel::addToolResult(const QString &toolName,
                               const QString &content,
                               const QString &toolCallId,
                               bool isError)
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages[i].msgType == QStringLiteral("toolCall")
            && m_messages[i].toolCallId == toolCallId) {
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
        if (m_messages[i].toolCallId == toolCallId)
            return true;
    }
    return false;
}

// ── Streaming ────────────────────────────────────────────────────────
//
// 设计要点（既要 Markdown 实时渲染、又要避免长文本时卡死）：
//   - 每个 chunk 都全量 set + Markdown 重排 ⇒ O(N²) 卡死
//   - 完全不 set、只 insert() ⇒ 流式中无法看到 Markdown 样式
//   - 折中：保留 `text: content` + `textFormat: MarkdownText` 的简单 QML 绑定，
//     在 C++ 侧用单次触发的 QTimer 把多个 chunk 合并成一次 dataChanged(ContentRole) 通知，
//     节流间隔随内容长度自适应增长，单位时间内的重排次数被限制在常数级。

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
        return;
    }
    const QModelIndex idx = index(m_streamFlushRow);
    emit dataChanged(idx, idx, { ContentRole });
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
    m_messages[last].content += chunk;
    m_streamFlushRow = last;
    m_streamDirty = true;

    // 节流间隔随内容长度自适应增长：
    //   < ~7KB   → 30ms  （≈33Hz，逐字打字感）
    //   7K~125K  → 线性放宽
    //   ≥ 125KB  → 500ms （封顶，避免长文重排吃掉整帧）
    if (!m_streamFlushTimer.isActive()) {
        // 起跳节流：定时器空闲时第一个 chunk 立即可见，再开始节流窗口
        flushStream();
        const int len = m_messages[last].content.length();
        m_streamFlushTimer.setInterval(qBound(30, len / 250, 500));
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
        return;
    }
    const int last = m_messages.count() - 1;
    if (m_messages[last].isStreaming)
        m_messages[last].isStreaming = false;
    // 最终强制 flush 一次，确保 QML 拿到完整内容并最后一次完成 Markdown 渲染。
    const QModelIndex idx = index(last);
    emit dataChanged(idx, idx, { ContentRole, IsStreamingRole });
    emit messagePayloadChanged();
    m_streamFlushRow = -1;
}

bool ChatModel::isStreaming() const
{
    return m_streaming;
}
