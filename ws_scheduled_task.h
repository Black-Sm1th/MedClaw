/**
 * @file ws_scheduled_task.h
 * @brief WebSocket 定时任务管理类（子类之一）
 *
 * 负责 OpenClaw 定时任务（Cron）的完整生命周期管理：
 *   ① 查询任务列表（cron.list）与服务状态（cron.status）
 *   ② 添加定时任务（cron.add）：支持三种调度模式
 *      - cron 表达式（标准五段式 / 六段式）
 *      - 固定间隔（every N 毫秒）
 *      - 一次性定时（at 指定时间）
 *   ③ 更新任务（cron.update）与删除任务（cron.remove）
 *   ④ 手动触发（cron.run）
 *   ⑤ 查询执行记录（cron.runs）
 *
 * 设计说明：
 *   本类为纯数据 + 逻辑类，不继承 QObject，无信号/槽。
 *   由 GatewayClient 持有，遵循与 WsSkill / WsSession 相同的模式：
 *     - build*Params() 构建 RPC 请求参数
 *     - parse*Response() 解析 RPC 响应并更新本地缓存
 *     - 访问器方法供 QML 绑定
 */
#ifndef WS_SCHEDULED_TASK_H
#define WS_SCHEDULED_TASK_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>

class WsScheduledTask
{
public:
    WsScheduledTask();

    // ═══════════════════════════════════════════════════════════════
    //  调度类型枚举
    // ═══════════════════════════════════════════════════════════════

    enum ScheduleKind {
        Cron,       ///< cron 表达式（如 "0 9 * * 1-5"）
        Every,      ///< 固定间隔（毫秒）
        At          ///< 一次性定时（ISO 8601 时间）
    };

    // ═══════════════════════════════════════════════════════════════
    //  数据访问器
    // ═══════════════════════════════════════════════════════════════

    /// 获取缓存的任务列表（每项为 QVariantMap）
    QVariantList jobList() const;

    /// 任务总数
    int jobCount() const;

    /// 获取缓存的执行记录列表
    QVariantList runList() const;

    /// 获取 cron 服务状态快照
    QVariantMap cronStatus() const;

    // ═══════════════════════════════════════════════════════════════
    //  解析 RPC 响应
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 解析 cron.list 响应
     * @param payload 响应 payload
     * @return 解析到的任务数量
     *
     * payload 结构：
     *   { jobs: [ { id, name, enabled, schedule, payload, ... } ] }
     * 或分页格式：
     *   { items: [...], total, hasMore }
     */
    int parseJobListResponse(const QJsonObject &payload);

    /**
     * @brief 解析 cron.status 响应
     * @param payload 响应 payload
     *
     * payload 结构：
     *   { enabled, storePath, jobs, nextWakeAtMs }
     */
    void parseCronStatusResponse(const QJsonObject &payload);

    /**
     * @brief 解析 cron.add 响应，将新任务追加到本地缓存
     * @param payload 响应 payload（单个 job 对象）
     * @return 新任务的 ID（空表示解析失败）
     */
    QString parseJobAddResponse(const QJsonObject &payload);

    /**
     * @brief 解析 cron.update 响应，更新本地缓存中对应任务
     * @param payload 响应 payload
     * @return 被更新的任务 ID
     */
    QString parseJobUpdateResponse(const QJsonObject &payload);

    /**
     * @brief 解析 cron.remove 响应，从本地缓存中移除任务
     * @param jobId 被删除的任务 ID
     * @param payload 响应 payload
     * @return true 表示移除成功
     */
    bool parseJobRemoveResponse(const QString &jobId,
                                const QJsonObject &payload);

    /**
     * @brief 解析 cron.runs 响应
     * @param payload 响应 payload
     * @return 解析到的执行记录数量
     *
     * payload 结构：
     *   { items: [ { id, jobId, status, startedAt, ... } ], total }
     */
    int parseRunsResponse(const QJsonObject &payload);

    /**
     * @brief 解析 cron.run 响应（手动触发的执行结果）
     * @param payload 响应 payload
     * @return 运行 ID
     */
    QString parseRunResponse(const QJsonObject &payload);

    // ═══════════════════════════════════════════════════════════════
    //  构建 RPC 请求参数
    // ═══════════════════════════════════════════════════════════════

    /// 构建 cron.list 请求参数
    QJsonObject buildListParams(bool includeDisabled = false,
                                int limit = 100,
                                int offset = 0) const;

    /// 构建 cron.status 请求参数
    QJsonObject buildStatusParams() const;

    /**
     * @brief 构建 cron.add 请求参数 —— cron 表达式调度
     * @param name      任务名称
     * @param cronExpr  cron 表达式（如 "0 9 * * 1-5"）
     * @param message   触发时发送给 agent 的消息
     * @param tz        时区（默认 "Asia/Shanghai"）
     * @param sessionTarget  会话目标：main / isolated / current
     * @param deliver   是否投递到通道
     */
    QJsonObject buildAddCronJobParams(
        const QString &name,
        const QString &cronExpr,
        const QString &message,
        const QString &tz = QStringLiteral("Asia/Shanghai"),
        const QString &sessionTarget = QStringLiteral("main"),
        bool deliver = false) const;

    /**
     * @brief 构建 cron.add 请求参数 —— 固定间隔调度
     * @param name      任务名称
     * @param everyMs   执行间隔（毫秒）
     * @param message   触发时发送给 agent 的消息
     */
    QJsonObject buildAddIntervalJobParams(
        const QString &name,
        int everyMs,
        const QString &message,
        const QString &sessionTarget = QStringLiteral("main"),
        bool deliver = false) const;

    /**
     * @brief 构建 cron.add 请求参数 —— 一次性定时
     * @param name      任务名称
     * @param at        执行时间（ISO 8601 格式）
     * @param message   触发时发送给 agent 的消息
     * @param deleteAfterRun  执行后自动删除
     */
    QJsonObject buildAddOneTimeJobParams(
        const QString &name,
        const QDateTime &at,
        const QString &message,
        bool deleteAfterRun = true,
        const QString &sessionTarget = QStringLiteral("isolated")) const;

    /**
     * @brief 构建 cron.add 请求参数 —— 系统事件（非 agent 对话）
     * @param name      任务名称
     * @param cronExpr  cron 表达式
     * @param eventText 系统事件文本
     */
    QJsonObject buildAddSystemEventJobParams(
        const QString &name,
        const QString &cronExpr,
        const QString &eventText,
        const QString &tz = QStringLiteral("Asia/Shanghai")) const;

    /// 构建 cron.update 请求参数
    QJsonObject buildUpdateParams(const QString &jobId,
                                  const QJsonObject &patch) const;

    /// 构建 cron.update 请求参数 —— 仅切换启用/禁用
    QJsonObject buildToggleEnabledParams(const QString &jobId,
                                         bool enabled) const;

    /// 构建 cron.remove 请求参数
    QJsonObject buildRemoveParams(const QString &jobId) const;

    /// 构建 cron.run 请求参数（手动触发）
    QJsonObject buildRunParams(const QString &jobId,
                               const QString &mode = QStringLiteral("force")) const;

    /// 构建 cron.runs 请求参数（查询执行记录）
    QJsonObject buildRunsParams(const QString &jobId = QString(),
                                int limit = 50,
                                int offset = 0) const;

    // ═══════════════════════════════════════════════════════════════
    //  辅助：跟踪最近操作的 jobId（用于响应匹配）
    // ═══════════════════════════════════════════════════════════════

    QString lastOperatedJobId() const;
    void setLastOperatedJobId(const QString &id);
    void clearLastOperatedJobId();

private:
    /// 从 JSON 对象中提取标准化的任务 QVariantMap
    QVariantMap jobFromJson(const QJsonObject &obj) const;

    QVariantList m_jobs;              ///< 缓存的任务列表
    QVariantList m_runs;              ///< 缓存的执行记录
    QVariantMap  m_status;            ///< cron 服务状态快照
    QString      m_lastOperatedJobId; ///< 最近操作的任务 ID
};

#endif // WS_SCHEDULED_TASK_H
