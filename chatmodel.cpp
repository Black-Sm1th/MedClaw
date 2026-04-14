#include "chatmodel.h"

ChatModel::ChatModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_typingTimer.setInterval(400);
    connect(&m_typingTimer, &QTimer::timeout,
            this, &ChatModel::advanceTypingDots);
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
        { HasToolResultRole,  "hasToolResult"  }
    };
}

// ── 文本消息 ─────────────────────────────────────────────────────────

void ChatModel::addMessage(const QString &role, const QString &content)
{
    if (role != QStringLiteral("user"))
        hideTypingIndicator();

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
    hideTypingIndicator();

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
}

void ChatModel::clear()
{
    m_typingTimer.stop();
    beginResetModel();
    m_messages.clear();
    endResetModel();
    emit countChanged();
}

bool ChatModel::hasToolCallId(const QString &toolCallId) const
{
    for (int i = m_messages.count() - 1; i >= 0; --i) {
        if (m_messages[i].toolCallId == toolCallId)
            return true;
    }
    return false;
}

// ── 发送后等待提示 ───────────────────────────────────────────────────

void ChatModel::showTypingIndicator()
{
    hideTypingIndicator();

    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    ChatMessage msg;
    msg.role       = QStringLiteral("assistant");
    msg.content    = QStringLiteral(".");
    msg.timestamp  = QDateTime::currentDateTime();
    msg.msgType    = QStringLiteral("typing");
    msg.isError    = false;
    m_messages.append(msg);
    endInsertRows();
    emit countChanged();

    m_typingPhase = 0;
    m_typingTimer.start();
}

void ChatModel::hideTypingIndicator()
{
    m_typingTimer.stop();
    if (m_messages.isEmpty())
        return;
    if (m_messages.last().msgType != QStringLiteral("typing"))
        return;
    const int row = m_messages.count() - 1;
    beginRemoveRows(QModelIndex(), row, row);
    m_messages.removeLast();
    endRemoveRows();
    emit countChanged();
}

void ChatModel::advanceTypingDots()
{
    if (m_messages.isEmpty()
        || m_messages.last().msgType != QStringLiteral("typing")) {
        m_typingTimer.stop();
        return;
    }
    m_typingPhase = (m_typingPhase + 1) % 3;
    QString dots;
    switch (m_typingPhase) {
    case 0: dots = QStringLiteral("."); break;
    case 1: dots = QStringLiteral(".."); break;
    default: dots = QStringLiteral("..."); break;
    }
    const int row = m_messages.count() - 1;
    m_messages[row].content = dots;
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx, { ContentRole });
}

// ── Streaming ────────────────────────────────────────────────────────

void ChatModel::beginStreaming()
{
    hideTypingIndicator();
    if (!m_streaming) {
        m_streaming = true;
        addMessage(QStringLiteral("assistant"), QString());
    }
}

void ChatModel::appendStreamChunk(const QString &chunk)
{
    if (!m_streaming)
        beginStreaming();
    if (m_messages.isEmpty()
        || m_messages.last().role != QLatin1String("assistant")
        || m_messages.last().msgType != QLatin1String("text")) {
        addMessage(QStringLiteral("assistant"), QString());
    }
    appendToLastMessage(chunk);
}

void ChatModel::endStreaming()
{
    m_streaming = false;
}

bool ChatModel::isStreaming() const
{
    return m_streaming;
}
