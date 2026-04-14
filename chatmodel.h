#ifndef CHATMODEL_H
#define CHATMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>

/**
 * 聊天消息数据结构
 *
 * msgType 取值：
 *   "text"       — 普通文本消息（用户 / 助手 / 系统）
 *   "toolCall"     — 工具调用（助手发起的 function call）
 *   "toolResult"   — 工具执行结果
 *   "replyWaiting" — 已发送、等待助手首条回复（UI 省略号动画）
 */
struct ChatMessage {
    QString role;         // "user" | "assistant" | "system" | "tool"
    QString content;      // 文本内容 或 工具结果文本
    QDateTime timestamp;
    QString msgType;      // "text" | "toolCall" | "toolResult"
    QString toolName;     // 工具名称
    QString toolArgs;     // 工具参数（JSON 字符串）
    QString toolCallId;   // 工具调用 ID（关联 call 和 result）
    bool    isError;      // 工具结果是否为错误（独立 toolResult 行或合并后）
    /// 合并到 toolCall 行：收到 toolResult 后写入，不再单独插入一行
    QString toolResultText;
    bool    hasToolResult = false;
};

class ChatModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        RoleRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole,
        MsgTypeRole,
        ToolNameRole,
        ToolArgsRole,
        ToolCallIdRole,
        IsErrorRole,
        ToolResultTextRole,
        HasToolResultRole
    };

    explicit ChatModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void addMessage(const QString &role, const QString &content);
    Q_INVOKABLE void addToolCall(const QString &toolName,
                                  const QString &toolArgs,
                                  const QString &toolCallId);
    Q_INVOKABLE void addToolResult(const QString &toolName,
                                    const QString &content,
                                    const QString &toolCallId,
                                    bool isError = false);
    Q_INVOKABLE void appendToLastMessage(const QString &text);
    Q_INVOKABLE void clear();
    Q_INVOKABLE bool hasToolCallId(const QString &toolCallId) const;

    /// 发送成功后显示「等待回复」占位（会先移除已有的 replyWaiting）
    Q_INVOKABLE void showReplyWaiting();
    /// 收到助手流式/文本/工具调用等首条反馈时移除占位
    Q_INVOKABLE void clearReplyWaiting();

    void beginStreaming();
    void appendStreamChunk(const QString &chunk);
    void endStreaming();
    bool isStreaming() const;

signals:
    void countChanged();

private:
    void removeAllReplyWaiting();

    QVector<ChatMessage> m_messages;
    bool m_streaming = false;
};

#endif // CHATMODEL_H
