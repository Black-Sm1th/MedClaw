#ifndef CHATMODEL_H
#define CHATMODEL_H

#include <QAbstractListModel>
#include <QDateTime>
#include <QVector>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

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
    /// 工具调用之间的中间助手文本（区别于最终回答）：QML 用斜体渲染。
    /// 在新增 toolCall 时把紧邻之前的助手文本消息标记为中间态。
    bool    isIntermediate = false;
    QVariantList artifacts; ///< Files created or modified during this turn.
};

class ChatModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    /// 网关流式回复进行中（与 C++ m_streaming 一致），供 QML 显示「生成中」等
    Q_PROPERTY(bool isStreaming READ isStreaming NOTIFY isStreamingChanged)

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
        IsStreamingRole,
        IsIntermediateRole,
        ArtifactsRole
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
    Q_INVOKABLE QVariantList messages() const;
    Q_INVOKABLE void setArtifactsForLastAssistant(const QVariantList &artifacts);
    void loadHistory(const QVariantList &messages);

    void beginStreaming();
    void appendStreamChunk(const QString &chunk);
    void endStreaming();
    bool isStreaming() const;

signals:
    void countChanged();
    void isStreamingChanged();
    /// 行数未变但内容/展示高度变化（流式追加、工具结果合并到卡片等），供界面滚到底部
    void messagePayloadChanged();
    /// 流式增量推送：把「自上次 flush 以来累积的 delta 字符串」一次性发给 QML，
    /// QML delegate 监听后调用 TextEdit::insert(length, delta) 增量追加，
    /// 避免每次 flush 都全量 setText / setMarkdown 重排整段消息。
    /// row 是目标 delegate 在 model 中的行号，QML 用 index 比对决定是否处理。
    void streamFlushed(int row, const QString &delta);

private:
    /// 节流刷新：把累积的 delta 通过 streamFlushed(row, delta) 推给 QML，
    /// 让 bubbleText 用 insert() 局部追加；流式期间只发 messagePayloadChanged()
    /// 供粘底滚动感知，ContentRole 等流式结束再一次性刷新。
    void flushStream();

    /// 自适应节流：按当前消息总长度返回下一次 flush 的间隔（毫秒）。
    /// 越长的消息 layout / 度量 / 粘底滚动越贵，间隔随之放宽。
    static int streamFlushIntervalMsFor(int contentLen);

    QVector<ChatMessage> m_messages;
    bool m_streaming = false;

    QTimer m_streamFlushTimer;      ///< 流式节流定时器（单次触发，到点后 flushStream）
    int    m_streamFlushRow = -1;   ///< 当前正在被节流刷新的行号
    bool   m_streamDirty    = false;///< 自上次 flush 后是否有新 chunk 累积
    /// 自上次 streamFlushed() 之后累积的「新增片段」。flushStream() 把它整段发出去并清空。
    /// 注意：m_messages[m_streamFlushRow].content 仍持有完整累积内容，供 delegate 重建 /
    /// 历史加载 / 最终 Markdown 精排时一次性读取。
    QString m_streamPending;
};

#endif // CHATMODEL_H
