/**
 * @file ws_scheduled_task.cpp
 * @brief WebSocket 定时任务管理类 —— 实现
 *
 * 对接 OpenClaw Gateway 的 cron.* RPC 方法族：
 *   cron.list / cron.status / cron.add / cron.update /
 *   cron.remove / cron.run / cron.runs
 */
#include "ws_scheduled_task.h"
#include <QHash>
#include <QJsonDocument>
#include <QDebug>

// ═══════════════════════════════════════════════════════════════════════
//  构造
// ═══════════════════════════════════════════════════════════════════════

WsScheduledTask::WsScheduledTask() {}

// ═══════════════════════════════════════════════════════════════════════
//  数据访问器
// ═══════════════════════════════════════════════════════════════════════

QVariantList WsScheduledTask::jobList()    const { return m_jobs; }
int          WsScheduledTask::jobCount()   const { return m_jobs.count(); }
QVariantList WsScheduledTask::runList()    const { return m_runs; }
QVariantMap  WsScheduledTask::cronStatus() const { return m_status; }

QString WsScheduledTask::lastOperatedJobId()              const { return m_lastOperatedJobId; }
void    WsScheduledTask::setLastOperatedJobId(const QString &id) { m_lastOperatedJobId = id; }
void    WsScheduledTask::clearLastOperatedJobId()                { m_lastOperatedJobId.clear(); }

// ═══════════════════════════════════════════════════════════════════════
//  内部：从 JSON 对象提取标准化任务条目
// ═══════════════════════════════════════════════════════════════════════

/**
 * 将 Gateway 返回的 cron job JSON 转为 QVariantMap，字段说明：
 *
 *   id            : 任务唯一 ID
 *   name          : 任务名称
 *   enabled       : 是否启用
 *   scheduleKind  : 调度类型（cron / every / at）
 *   scheduleExpr  : cron 表达式 / 间隔毫秒 / ISO 时间（统一为字符串）
 *   scheduleTz    : 时区（cron 类型时有效）
 *   payloadKind   : 载荷类型（agentTurn / systemEvent）
 *   payloadMessage: 消息内容
 *   sessionTarget : 会话目标
 *   nextRunAt     : 下次执行时间（ISO 字符串）
 *   lastRunAt     : 上次执行时间
 *   lastRunStatus : 上次执行状态
 *   deleteAfterRun: 执行后自动删除
 *   createdAt     : 创建时间
 *   updatedAt     : 更新时间
 */
QVariantMap WsScheduledTask::jobFromJson(const QJsonObject &obj) const
{
    QVariantMap entry;

    entry[QStringLiteral("id")] =
        obj.value(QStringLiteral("id")).toString(
            obj.value(QStringLiteral("jobId")).toString());

    entry[QStringLiteral("name")] =
        obj.value(QStringLiteral("name")).toString();

    entry[QStringLiteral("enabled")] =
        obj.value(QStringLiteral("enabled")).toBool(true);

    // ── 调度信息 ──
    const QJsonObject schedule = obj.value(QStringLiteral("schedule")).toObject();
    const QString kind = schedule.value(QStringLiteral("kind")).toString();
    entry[QStringLiteral("scheduleKind")] = kind;

    if (kind == QLatin1String("cron")) {
        entry[QStringLiteral("scheduleExpr")] =
            schedule.value(QStringLiteral("expr")).toString();
        entry[QStringLiteral("scheduleTz")] =
            schedule.value(QStringLiteral("tz")).toString();
    } else if (kind == QLatin1String("every")) {
        entry[QStringLiteral("scheduleExpr")] =
            QString::number(schedule.value(QStringLiteral("everyMs")).toInt());
    } else if (kind == QLatin1String("at")) {
        entry[QStringLiteral("scheduleExpr")] =
            schedule.value(QStringLiteral("at")).toString();
    }

    // ── 载荷信息 ──
    const QJsonObject payload = obj.value(QStringLiteral("payload")).toObject();
    const QString payloadKind = payload.value(QStringLiteral("kind")).toString();
    entry[QStringLiteral("payloadKind")] = payloadKind;
    entry[QStringLiteral("payloadMessage")] =
        payload.value(QStringLiteral("message")).toString(
            payload.value(QStringLiteral("text")).toString());

    // ── 会话与投递 ──
    entry[QStringLiteral("sessionTarget")] =
        obj.value(QStringLiteral("sessionTarget")).toString();
    entry[QStringLiteral("deleteAfterRun")] =
        obj.value(QStringLiteral("deleteAfterRun")).toBool(false);

    // ── 绑定的 Agent（"定时-" 专用 agent）：用于级联删除 ──
    // 兼容多种 Gateway 响应布局：顶层 agentId / payload.agentId / runtime.agentId
    QString boundAgentId = obj.value(QStringLiteral("agentId")).toString();
    if (boundAgentId.isEmpty())
        boundAgentId = payload.value(QStringLiteral("agentId")).toString();
    if (boundAgentId.isEmpty()) {
        const QJsonObject runtime = obj.value(QStringLiteral("runtime")).toObject();
        boundAgentId = runtime.value(QStringLiteral("agentId")).toString();
    }
    entry[QStringLiteral("agentId")] = boundAgentId;

    // ── 时间戳 ──
    const double nextMs = obj.value(QStringLiteral("nextRunAtMs")).toDouble(0);
    if (nextMs > 0) {
        entry[QStringLiteral("nextRunAt")] =
            QDateTime::fromMSecsSinceEpoch(
                static_cast<qint64>(nextMs)).toString(Qt::ISODate);
    } else {
        entry[QStringLiteral("nextRunAt")] = QString();
    }

    const double lastMs = obj.value(QStringLiteral("lastRunAtMs")).toDouble(0);
    if (lastMs > 0) {
        entry[QStringLiteral("lastRunAt")] =
            QDateTime::fromMSecsSinceEpoch(
                static_cast<qint64>(lastMs)).toString(Qt::ISODate);
    } else {
        entry[QStringLiteral("lastRunAt")] = QString();
    }

    entry[QStringLiteral("lastRunStatus")] =
        obj.value(QStringLiteral("lastRunStatus")).toString();

    entry[QStringLiteral("createdAt")] =
        obj.value(QStringLiteral("createdAt")).toString();
    entry[QStringLiteral("updatedAt")] =
        obj.value(QStringLiteral("updatedAt")).toString();

    return entry;
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.list 响应
// ═══════════════════════════════════════════════════════════════════════

int WsScheduledTask::parseJobListResponse(const QJsonObject &payload)
{
    m_jobs.clear();

    QJsonArray arr = payload.value(QStringLiteral("jobs")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("items")).toArray();

    for (const QJsonValue &v : arr) {
        const QJsonObject obj = v.toObject();
        const QVariantMap entry = jobFromJson(obj);
        if (entry.value(QStringLiteral("id")).toString().isEmpty())
            continue;
        m_jobs.append(entry);
    }

    qDebug() << "[WsScheduledTask] loaded" << m_jobs.count() << "jobs";
    return m_jobs.count();
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.status 响应
// ═══════════════════════════════════════════════════════════════════════

void WsScheduledTask::parseCronStatusResponse(const QJsonObject &payload)
{
    m_status.clear();
    m_status[QStringLiteral("enabled")] =
        payload.value(QStringLiteral("enabled")).toBool(false);
    m_status[QStringLiteral("storePath")] =
        payload.value(QStringLiteral("storePath")).toString();
    m_status[QStringLiteral("jobCount")] =
        payload.value(QStringLiteral("jobs")).toInt(0);

    const double nextMs =
        payload.value(QStringLiteral("nextWakeAtMs")).toDouble(0);
    if (nextMs > 0) {
        m_status[QStringLiteral("nextWakeAt")] =
            QDateTime::fromMSecsSinceEpoch(
                static_cast<qint64>(nextMs)).toString(Qt::ISODate);
    }

    qDebug() << "[WsScheduledTask] cron status:"
             << "enabled=" << m_status.value(QStringLiteral("enabled")).toBool()
             << "jobs=" << m_status.value(QStringLiteral("jobCount")).toInt();
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.add 响应
// ═══════════════════════════════════════════════════════════════════════

QString WsScheduledTask::parseJobAddResponse(const QJsonObject &payload)
{
    const QVariantMap entry = jobFromJson(payload);
    const QString id = entry.value(QStringLiteral("id")).toString();
    if (id.isEmpty()) return QString();

    m_jobs.append(entry);
    qDebug() << "[WsScheduledTask] added job:" << id
             << entry.value(QStringLiteral("name")).toString();
    return id;
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.update 响应
// ═══════════════════════════════════════════════════════════════════════

QString WsScheduledTask::parseJobUpdateResponse(const QJsonObject &payload)
{
    const QVariantMap updated = jobFromJson(payload);
    const QString id = updated.value(QStringLiteral("id")).toString();
    if (id.isEmpty()) return QString();

    for (int i = 0; i < m_jobs.count(); ++i) {
        if (m_jobs[i].toMap().value(QStringLiteral("id")).toString() == id) {
            m_jobs[i] = updated;
            qDebug() << "[WsScheduledTask] updated job:" << id;
            return id;
        }
    }

    // 未找到则追加（可能是并发创建的）
    m_jobs.append(updated);
    qDebug() << "[WsScheduledTask] updated (appended) job:" << id;
    return id;
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.remove 响应
// ═══════════════════════════════════════════════════════════════════════

bool WsScheduledTask::parseJobRemoveResponse(const QString &jobId,
                                             const QJsonObject &payload)
{
    const bool removed = payload.value(QStringLiteral("removed")).toBool(
        payload.value(QStringLiteral("ok")).toBool(false));
    if (!removed) return false;

    for (int i = 0; i < m_jobs.count(); ++i) {
        if (m_jobs[i].toMap().value(QStringLiteral("id")).toString() == jobId) {
            m_jobs.removeAt(i);
            break;
        }
    }

    qDebug() << "[WsScheduledTask] removed job:" << jobId;
    return true;
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.runs 响应
// ═══════════════════════════════════════════════════════════════════════

int WsScheduledTask::parseRunsResponse(const QJsonObject &payload)
{
    m_runs.clear();

    QJsonArray arr = payload.value(QStringLiteral("entries")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("items")).toArray();
    if (arr.isEmpty())
        arr = payload.value(QStringLiteral("runs")).toArray();

    QHash<QString, QString> jobNameLookup;
    for (const QVariant &jv : m_jobs) {
        const QVariantMap jm = jv.toMap();
        const QString jid = jm.value(QStringLiteral("id")).toString();
        const QString jname = jm.value(QStringLiteral("name")).toString();
        if (!jid.isEmpty() && !jname.isEmpty())
            jobNameLookup.insert(jid, jname);
    }

    for (const QJsonValue &v : arr) {
        const QJsonObject r = v.toObject();

        const QString jobId = r.value(QStringLiteral("jobId")).toString();

        QVariantMap entry;
        entry[QStringLiteral("jobId")] = jobId;
        entry[QStringLiteral("jobName")] = jobNameLookup.value(jobId, jobId);
        entry[QStringLiteral("status")] =
            r.value(QStringLiteral("status")).toString();
        entry[QStringLiteral("deliveryStatus")] =
            r.value(QStringLiteral("deliveryStatus")).toString();
        entry[QStringLiteral("error")] =
            r.value(QStringLiteral("error")).toString();
        entry[QStringLiteral("summary")] =
            r.value(QStringLiteral("summary")).toString();
        entry[QStringLiteral("durationMs")] =
            r.value(QStringLiteral("durationMs")).toInt(0);

        const auto tsMs = static_cast<qint64>(r.value(QStringLiteral("ts")).toDouble(0));
        if (tsMs > 0) {
            entry[QStringLiteral("startedAt")] =
                QDateTime::fromMSecsSinceEpoch(tsMs).toString(Qt::ISODate);
        } else {
            const auto runAtMs = static_cast<qint64>(
                r.value(QStringLiteral("runAtMs")).toDouble(0));
            if (runAtMs > 0)
                entry[QStringLiteral("startedAt")] =
                    QDateTime::fromMSecsSinceEpoch(runAtMs).toString(Qt::ISODate);
            else
                entry[QStringLiteral("startedAt")] = QString();
        }

        m_runs.append(entry);
    }

    qDebug() << "[WsScheduledTask] loaded" << m_runs.count() << "run records";
    return m_runs.count();
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 cron.run 响应（手动触发）
// ═══════════════════════════════════════════════════════════════════════

QString WsScheduledTask::parseRunResponse(const QJsonObject &payload)
{
    const QString runId = payload.value(QStringLiteral("runId")).toString(
        payload.value(QStringLiteral("id")).toString());
    const QString status = payload.value(QStringLiteral("status")).toString();
    qDebug() << "[WsScheduledTask] manual run:" << runId
             << "status:" << status;
    return runId;
}

// ═══════════════════════════════════════════════════════════════════════
//  构建 RPC 请求参数
// ═══════════════════════════════════════════════════════════════════════

QJsonObject WsScheduledTask::buildListParams(bool includeDisabled,
                                             int limit,
                                             int offset) const
{
    QJsonObject params;
    params[QStringLiteral("includeDisabled")] = includeDisabled;
    params[QStringLiteral("limit")]           = limit;
    if (offset > 0)
        params[QStringLiteral("offset")] = offset;
    return params;
}

QJsonObject WsScheduledTask::buildStatusParams() const
{
    return QJsonObject();
}

QJsonObject WsScheduledTask::buildAddCronJobParams(
    const QString &name,
    const QString &cronExpr,
    const QString &message,
    const QString &tz,
    const QString &sessionTarget,
    bool deliver,
    const QString &agentId) const
{
    QJsonObject schedule;
    schedule[QStringLiteral("kind")] = QStringLiteral("cron");
    schedule[QStringLiteral("expr")] = cronExpr;
    schedule[QStringLiteral("tz")]   = tz;

    QJsonObject payload;
    payload[QStringLiteral("kind")]    = QStringLiteral("agentTurn");
    payload[QStringLiteral("message")] = message;
    payload[QStringLiteral("deliver")] = deliver;

    QJsonObject delivery;
    delivery[QStringLiteral("mode")] = deliver
        ? QStringLiteral("announce")
        : QStringLiteral("none");

    QJsonObject params;
    params[QStringLiteral("name")]          = name;
    params[QStringLiteral("schedule")]      = schedule;
    params[QStringLiteral("payload")]       = payload;
    params[QStringLiteral("delivery")]      = delivery;
    params[QStringLiteral("sessionTarget")] = sessionTarget;
    params[QStringLiteral("wakeMode")]      = QStringLiteral("now");
    params[QStringLiteral("enabled")]       = true;
    if (!agentId.isEmpty())
        params[QStringLiteral("agentId")] = agentId;
    return params;
}

QJsonObject WsScheduledTask::buildAddIntervalJobParams(
    const QString &name,
    int everyMs,
    const QString &message,
    const QString &sessionTarget,
    bool deliver,
    const QString &agentId) const
{
    QJsonObject schedule;
    schedule[QStringLiteral("kind")]    = QStringLiteral("every");
    schedule[QStringLiteral("everyMs")] = everyMs;

    QJsonObject payload;
    payload[QStringLiteral("kind")]    = QStringLiteral("agentTurn");
    payload[QStringLiteral("message")] = message;
    payload[QStringLiteral("deliver")] = deliver;

    QJsonObject delivery;
    delivery[QStringLiteral("mode")] = deliver
        ? QStringLiteral("announce")
        : QStringLiteral("none");

    QJsonObject params;
    params[QStringLiteral("name")]          = name;
    params[QStringLiteral("schedule")]      = schedule;
    params[QStringLiteral("payload")]       = payload;
    params[QStringLiteral("delivery")]      = delivery;
    params[QStringLiteral("sessionTarget")] = sessionTarget;
    params[QStringLiteral("wakeMode")]      = QStringLiteral("now");
    params[QStringLiteral("enabled")]       = true;
    if (!agentId.isEmpty())
        params[QStringLiteral("agentId")] = agentId;
    return params;
}

QJsonObject WsScheduledTask::buildAddOneTimeJobParams(
    const QString &name,
    const QDateTime &at,
    const QString &message,
    bool deleteAfterRun,
    const QString &sessionTarget,
    const QString &agentId) const
{
    QJsonObject schedule;
    schedule[QStringLiteral("kind")] = QStringLiteral("at");
    schedule[QStringLiteral("at")]   = at.toUTC().toString(Qt::ISODate);

    QJsonObject payload;
    payload[QStringLiteral("kind")]    = QStringLiteral("agentTurn");
    payload[QStringLiteral("message")] = message;

    QJsonObject delivery;
    delivery[QStringLiteral("mode")] = QStringLiteral("none");

    QJsonObject params;
    params[QStringLiteral("name")]           = name;
    params[QStringLiteral("schedule")]       = schedule;
    params[QStringLiteral("payload")]        = payload;
    params[QStringLiteral("delivery")]       = delivery;
    params[QStringLiteral("sessionTarget")]  = sessionTarget;
    params[QStringLiteral("wakeMode")]       = QStringLiteral("now");
    params[QStringLiteral("enabled")]        = true;
    params[QStringLiteral("deleteAfterRun")] = deleteAfterRun;
    if (!agentId.isEmpty())
        params[QStringLiteral("agentId")] = agentId;
    return params;
}

QJsonObject WsScheduledTask::buildAddSystemEventJobParams(
    const QString &name,
    const QString &cronExpr,
    const QString &eventText,
    const QString &tz) const
{
    QJsonObject schedule;
    schedule[QStringLiteral("kind")] = QStringLiteral("cron");
    schedule[QStringLiteral("expr")] = cronExpr;
    schedule[QStringLiteral("tz")]   = tz;

    QJsonObject payload;
    payload[QStringLiteral("kind")] = QStringLiteral("systemEvent");
    payload[QStringLiteral("text")] = eventText;

    QJsonObject params;
    params[QStringLiteral("name")]          = name;
    params[QStringLiteral("schedule")]      = schedule;
    params[QStringLiteral("payload")]       = payload;
    params[QStringLiteral("sessionTarget")] = QStringLiteral("main");
    params[QStringLiteral("wakeMode")]      = QStringLiteral("now");
    params[QStringLiteral("enabled")]       = true;
    return params;
}

QJsonObject WsScheduledTask::buildUpdateParams(const QString &jobId,
                                               const QJsonObject &patch) const
{
    QJsonObject params;
    params[QStringLiteral("jobId")] = jobId;
    params[QStringLiteral("patch")] = patch;
    return params;
}

QJsonObject WsScheduledTask::buildToggleEnabledParams(const QString &jobId,
                                                      bool enabled) const
{
    QJsonObject patch;
    patch[QStringLiteral("enabled")] = enabled;

    QJsonObject params;
    params[QStringLiteral("jobId")] = jobId;
    params[QStringLiteral("patch")] = patch;
    return params;
}

QJsonObject WsScheduledTask::buildRemoveParams(const QString &jobId) const
{
    QJsonObject params;
    params[QStringLiteral("jobId")] = jobId;
    return params;
}

QJsonObject WsScheduledTask::buildRunParams(const QString &jobId,
                                            const QString &mode) const
{
    QJsonObject params;
    params[QStringLiteral("jobId")] = jobId;
    params[QStringLiteral("mode")]  = mode;
    return params;
}

QJsonObject WsScheduledTask::buildRunsParams(const QString &jobId,
                                             int limit,
                                             int offset) const
{
    QJsonObject params;
    params[QStringLiteral("limit")] = limit;
    if (offset > 0)
        params[QStringLiteral("offset")] = offset;

    if (!jobId.isEmpty()) {
        params[QStringLiteral("jobId")] = jobId;
        params[QStringLiteral("scope")] = QStringLiteral("job");
    } else {
        params[QStringLiteral("scope")] = QStringLiteral("all");
    }
    return params;
}
