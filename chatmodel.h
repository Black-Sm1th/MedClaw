#ifndef CHATMODEL_H
#define CHATMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>
#include <QTimer>

/**
 * 聊天消息数据结构
 *
 * msgType 取值：
 *   "text"       — 普通文本消息（用户 / 助手 / 系统）
 *   "toolCall"   — 工具调用（助手发起的 function call）
 *   "toolResult" — 工具执行结果
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
    /// 当前消息是否处于流式接收态（用于 QML 切换 textFormat / 走增量追加路径）
    bool    isStreaming = false;
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
        HasToolResultRole,
        IsStreamingRole
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

    void beginStreaming();
    void appendStreamChunk(const QString &chunk);
    void endStreaming();
    bool isStreaming() const;

signals:
    void countChanged();
    /// 行数未变但内容/展示高度变化（流式追加、工具结果合并到卡片等），供界面滚到底部
    void messagePayloadChanged();

private:
    /// 节流刷新：仅在节流间隔到期时把当前累积的 content 发一次 dataChanged(ContentRole)，
    /// 让 QML 中 textFormat=MarkdownText 的 TextEdit 进行一次重渲染。
    void flushStream();

    QVector<ChatMessage> m_messages;
    bool m_streaming = false;

    QTimer m_streamFlushTimer;      ///< 流式节流定时器（单次触发，到点后 flushStream）
    int    m_streamFlushRow = -1;   ///< 当前正在被节流刷新的行号
    bool   m_streamDirty    = false;///< 自上次 flush 后是否有新 chunk 累积
};

#endif // CHATMODEL_H
