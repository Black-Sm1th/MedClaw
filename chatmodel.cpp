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
    case RoleRole:      return msg.role;
    case ContentRole:   return msg.content;
    case TimestampRole: return msg.timestamp.toString(QStringLiteral("hh:mm:ss"));
    }
    return QVariant();
}

QHash<int, QByteArray> ChatModel::roleNames() const
{
    return {
        { RoleRole,      "msgRole"    },
        { ContentRole,   "content"    },
        { TimestampRole, "timestamp"  }
    };
}

// ── Public API ────────────────────────────────────────────────────────

void ChatModel::addMessage(const QString &role, const QString &content)
{
    const int idx = m_messages.count();
    beginInsertRows(QModelIndex(), idx, idx);
    m_messages.append({ role, content, QDateTime::currentDateTime() });
    endInsertRows();
    emit countChanged();
}

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

// ── Streaming helpers ─────────────────────────────────────────────────

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
        || m_messages.last().role != QLatin1String("assistant")) {
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
