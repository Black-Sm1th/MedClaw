#ifndef CHATMODEL_H
#define CHATMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>

struct ChatMessage {
    QString role;       // "user" | "assistant" | "system"
    QString content;
    QDateTime timestamp;
};

class ChatModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        RoleRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole
    };

    explicit ChatModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addMessage(const QString &role, const QString &content);
    Q_INVOKABLE void appendToLastMessage(const QString &text);
    Q_INVOKABLE void clear();

    void beginStreaming();
    void appendStreamChunk(const QString &chunk);
    void endStreaming();
    bool isStreaming() const;

signals:
    void countChanged();

private:
    QVector<ChatMessage> m_messages;
    bool m_streaming = false;
};

#endif // CHATMODEL_H
