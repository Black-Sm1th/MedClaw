#include "chatmodel.h"

ChatModel::ChatModel(QObject *parent)
    : QAbstractListModel(parent)
{}

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
        { IsErrorRole,    "isError"    }
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
    beginResetModel();
    m_messages.clear();
    endResetModel();
    emit countChanged();
}

// ── Streaming ────────────────────────────────────────────────────────

void ChatModel::beginStreaming()
{
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
