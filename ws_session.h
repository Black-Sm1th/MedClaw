/**
 * @file ws_session.h
 * @brief WebSocket 会话管理类（会话类 / 子类之一）
 *
 * 本类负责管理所有与 OpenClaw 会话相关的业务逻辑：
 *   - 会话列表的获取、解析与维护
 *   - 当前活跃会话的切换
 *   - 聊天消息的参数组装（chat.send）
 *   - 新会话创建（/new 命令）与旧会话删除
 *   - 历史消息的加载与解析
 *   - 流式响应（Streaming）状态管理
 *   - 服务器推送事件（agent / chat）的语义解析
 *
 * 设计说明：
 *   本类为纯数据 + 逻辑类，不继承 QObject，无信号/槽。
 *   由 WebSocket 主类（GatewayClient）持有。
 *   本类只负责「数据处理」，不直接操作 WebSocket 通信。
 *   需要发送请求时，由主类调用本类的 build*Params() 方法获取参数后发送。
 */
#ifndef WS_SESSION_H
#define WS_SESSION_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>

/**
 * @brief 事件解析结果结构体
 *
 * 由 WsSession::parseEvent() 返回，告知主类应如何处理此事件。
 * 主类根据各标志位决定发射哪些 Qt 信号。
 */
struct WsEventResult
{
    QString content;      ///< 提取到的文本内容（delta 增量或完整内容）
    QString role;         ///< 消息角色（user / assistant / system）
    bool isStart;         ///< 是否为流式输出的「开始」事件
    bool isDelta;         ///< 是否为流式输出的「增量内容」事件
    bool isComplete;      ///< 是否为流式输出的「完成」事件
    bool ignore;          ///< 是否应忽略此事件（如空的 chat 状态更新）
    // ── 工具调用相关 ──
    bool isToolCall;      ///< 事件中包含工具调用
    bool isToolUpdate;    ///< 工具执行中的增量输出
    bool isToolResult;    ///< 事件中包含工具结果
    QString toolName;     ///< 工具名称
    QString toolArgs;     ///< 工具参数（JSON 字符串）
    QString toolCallId;   ///< 工具调用 ID
    bool toolIsError;     ///< 工具结果是否为错误
};

class WsSession
{
public:
    WsSession();

    // ═══════════════════════════════════════════════════════════════
    //  当前会话管理
    // ═══════════════════════════════════════════════════════════════

    /// 获取当前活跃会话的 sessionKey（如 agent:main:main）
    QString currentSessionKey() const;
    /// 切换当前活跃会话（返回 true 表示确实发生了切换）
    bool setCurrentSessionKey(const QString &key);

    // ═══════════════════════════════════════════════════════════════
    //  会话列表
    // ═══════════════════════════════════════════════════════════════

    /// 获取当前缓存的会话列表（每项为 QVariantMap：sessionKey + displayName）
    QVariantList sessions() const;

    /**
     * @brief 解析 sessions.list RPC 响应，更新内部会话列表
     * @param payload  响应的 payload 对象
     * @return 解析到的会话数量
     *
     * 支持两种响应格式：
     *   - payload.sessions[] （OpenClaw 实际格式）
     *   - payload.items[]    （兼容备选格式）
     * 每个会话对象中提取 key、title/name、model 等字段。
     */
    int parseSessionsResponse(const QJsonObject &payload);

    // ═══════════════════════════════════════════════════════════════
    //  历史消息
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 解析 messages.list RPC 响应，返回历史消息列表
     * @param payload  响应的 payload 对象
     * @return QVariantList，每项为 QVariantMap {role, content}
     */
    QVariantList parseHistoryResponse(const QJsonObject &payload);

    // ═══════════════════════════════════════════════════════════════
    //  流式响应状态
    // ═══════════════════════════════════════════════════════════════

    /// 当前是否正在接收流式响应
    bool isStreaming() const;
    /// 设置流式响应状态
    void setStreaming(bool streaming);

    // ═══════════════════════════════════════════════════════════════
    //  新会话请求跟踪
    // ═══════════════════════════════════════════════════════════════

    /// 获取当前 /new 命令对应的 requestId（用于响应匹配）
    QString newSessionReqId() const;
    /// 记录 /new 命令的 requestId
    void setNewSessionReqId(const QString &id);
    /// 清除 /new 命令的 requestId（响应处理完毕后调用）
    void clearNewSessionReqId();

    // ═══════════════════════════════════════════════════════════════
    //  构建 RPC 请求参数
    // ═══════════════════════════════════════════════════════════════

    /// 构建 chat.send 请求参数（发送聊天消息）
    QJsonObject buildChatSendParams(const QString &message,
                                    const QString &sessionKey = QString()) const;
    /// 构建 chat.send /new 请求参数（创建新会话）
    QJsonObject buildNewSessionParams() const;
    /// 构建 sessions.list 请求参数（获取会话列表）
    QJsonObject buildListSessionsParams() const;
    /// 构建 session.delete 请求参数（删除指定会话）
    QJsonObject buildDeleteSessionParams(const QString &sessionKey) const;
    /// 构建 messages.list 请求参数（加载历史消息）
    QJsonObject buildLoadHistoryParams() const;

    /// 构建 chat.history 请求参数（切换 agent 时加载历史）
    QJsonObject buildChatHistoryParams(const QString &sessionKey,
                                        int limit = 200) const;
    /// 构建 agent.identity.get 请求参数
    QJsonObject buildAgentIdentityParams(const QString &sessionKey) const;

    /**
     * @brief 解析 agent.identity.get 响应
     * @param payload 响应 payload
     * @return QVariantMap 包含 name, emoji, model 等
     */
    QVariantMap parseAgentIdentityResponse(const QJsonObject &payload) const;

    // ═══════════════════════════════════════════════════════════════
    //  服务器推送事件解析
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 解析 agent / chat 类型的服务器推送事件
     * @param event    顶层事件名（如 "agent"、"chat"）
     * @param payload  事件的 payload 对象
     * @return WsEventResult 包含解析结果，主类据此决定发射哪些信号
     *
     * 解析策略：
     *   1. 从 payload.data 中检测 phase 字段（start / complete）
     *   2. 从 payload.data.delta 提取流式增量内容
     *   3. 从 payload.event（子事件名）中辅助判断语义
     *   4. 优先使用 delta，回退到 content → text
     */
    WsEventResult parseEvent(const QString &event,
                             const QJsonObject &payload) const;

private:
    QString      m_currentSessionKey;   ///< 当前活跃会话的 key
    QVariantList m_sessions;            ///< 缓存的会话列表
    bool         m_isStreaming;         ///< 是否正在接收流式响应
    QString      m_newSessionReqId;     ///< /new 命令对应的 requestId
};

#endif // WS_SESSION_H
