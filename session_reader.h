/**
 * @file session_reader.h
 * @brief 本地会话历史读取器
 *
 * 负责从本地磁盘读取 OpenClaw 的会话历史文件，提供以下功能：
 *   ① 自动识别 sessions 目录路径（适配 Windows / Linux）
 *   ② 解析 sessions.json，提取当前活跃会话的完整元数据
 *   ③ 扫描目录，列出所有会话文件（活跃 + 归档）
 *   ④ 解析 .jsonl 文件，提取用户 / 助手的聊天消息
 *   ⑤ 提取会话摘要信息（模型、首条消息预览、消息数等）
 *
 * 路径规则：
 *   - Windows: C:\Users\<用户名>\.openclaw\agents\main\sessions
 *   - Linux:   /home/<用户名>/.openclaw/agents/main/sessions
 *   - 统一使用 QDir::homePath() + "/.openclaw/agents/main/sessions"
 *
 * 文件类型：
 *   - sessions.json           — 当前活跃会话的元数据（含所有配置字段）
 *   - {uuid}.jsonl            — 当前活跃会话的消息日志
 *   - {uuid}.jsonl.reset.{ts} — 归档（历史）会话的消息日志（/new 后自动生成）
 *
 * 会话切换说明：
 *   切换查看历史不需要修改 sessions.json。
 *   sessions.json 由 Gateway 维护，客户端只读。
 *   要在某个会话中继续聊天，通过 WebSocket chat.send 指定 sessionKey。
 *   归档的 .reset 会话为只读历史，不可恢复为活跃会话。
 */
#ifndef SESSION_READER_H
#define SESSION_READER_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class SessionReader : public QObject
{
    Q_OBJECT

    /// sessions 目录的绝对路径（自动适配平台）
    Q_PROPERTY(QString sessionsDir READ sessionsDir CONSTANT)

    /// 扫描到的会话文件列表（每项为 QVariantMap）
    Q_PROPERTY(QVariantList sessionList READ sessionList NOTIFY sessionListChanged)

public:
    explicit SessionReader(QObject *parent = nullptr);

    QString sessionsDir() const;
    QVariantList sessionList() const;

    /**
     * @brief 扫描 sessions 目录，列出所有会话文件
     *
     * 每个会话条目包含：
     *   - sessionId    : 会话 UUID
     *   - filePath     : 文件绝对路径
     *   - fileName     : 文件名
     *   - isActive     : 是否为当前活跃会话
     *   - timestamp    : 会话创建时间（ISO 8601）
     *   - displayName  : 显示名称（含时间和活跃/归档标记）
     *   - preview      : 首条用户消息的前 60 个字符（会话预览）
     *   - messageCount : 用户+助手消息总条数
     *   - modelProvider: 模型提供商（如 deepseek）
     *   - modelId      : 模型标识（如 deepseek-chat）
     *   - resetTime    : 归档时间（仅归档会话有值）
     */
    Q_INVOKABLE void scanSessions();

    /**
     * @brief 读取 sessions.json 的完整内容（所有字段无遗漏）
     * @return QVariantMap 包含完整数据结构
     *
     * 返回的 Map 顶层 key 为 sessionKey（如 "agent:main:main"），
     * value 包含所有字段：
     *   sessionId, updatedAt, systemSent, abortedLastRun,
     *   chatType, deliveryContext, lastChannel, origin,
     *   sessionFile, compactionCount, totalTokensFresh,
     *   skillsSnapshot (prompt, skills, resolvedSkills, version),
     *   authProfileOverride, authProfileOverrideSource,
     *   authProfileOverrideCompactionCount,
     *   inputTokens, outputTokens,
     *   modelProvider, model, contextTokens,
     *   systemPromptReport (完整子结构)
     */
    Q_INVOKABLE QVariantMap readSessionsJson();

    /**
     * @brief 读取指定 .jsonl 文件中的聊天消息
     * @param filePath .jsonl 文件的绝对路径
     * @return QVariantList，每项为 QVariantMap
     *
     * 每条消息包含：
     *   - role      : user / assistant / system
     *   - content   : 文本内容（已清理 [message_id] 和时间戳前缀）
     *   - timestamp : ISO 8601 时间
     *   - hasTools  : 该消息是否包含工具调用（bool）
     */
    Q_INVOKABLE QVariantList readSessionMessages(const QString &filePath);

    /**
     * @brief 获取指定会话的摘要信息（无需读取全部消息）
     * @param filePath .jsonl 文件的绝对路径
     * @return QVariantMap 包含会话元信息
     *
     * 返回字段：
     *   - sessionId     : 会话 UUID
     *   - version       : 协议版本
     *   - createdAt     : 创建时间
     *   - cwd           : 工作目录
     *   - modelProvider : 模型提供商
     *   - modelId       : 模型标识
     *   - thinkingLevel : 思考级别
     *   - firstUserMsg  : 首条用户消息预览
     *   - messageCount  : 用户+助手消息总数
     *   - userMsgCount  : 用户消息数
     *   - assistantMsgCount : 助手消息数
     *   - toolCallCount : 工具调用次数
     */
    Q_INVOKABLE QVariantMap readSessionSummary(const QString &filePath);

    /**
     * @brief 解析 messages.list RPC 响应文件（或 WebSocket 抓包数据）
     * @param filePath 包含 JSON 响应的文件路径
     * @return QVariantList，每项为 QVariantMap（同 readSessionMessages 格式）
     *
     * 支持的文件格式：
     *   - 直接的 messages 数组 JSON
     *   - {type:"res", payload:{messages:[...]}} 格式（WebSocket 抓包）
     *   - 多行格式（每行一个响应，取最后一个有效的）
     */
    Q_INVOKABLE QVariantList parseResponseFile(const QString &filePath);

signals:
    void sessionListChanged();

private:
    /// 从 .jsonl 文件的头部几行快速提取摘要（不解析所有消息行）
    QVariantMap quickParseSummary(const QString &filePath);

    QString m_sessionsDir;
    QVariantList m_sessionList;
};

#endif // SESSION_READER_H
