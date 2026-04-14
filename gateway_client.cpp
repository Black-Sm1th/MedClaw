/**
 * @file gateway_client.cpp
 * @brief WebSocket 主类（总大类） —— 实现
 *
 * 本文件实现 GatewayClient 的完整逻辑，按职责划分为以下区域：
 *   1. 构造 / 析构
 *   2. 属性访问器
 *   3. 连接生命周期（连接、断开、错误处理）
 *   4. 协议握手（challenge → connect → hello-ok）
 *   5. 入站消息分发（事件 / 响应路由）
 *   6. 出站请求发送（统一 RPC 接口）
 *   7. 业务方法（会话管理、历史加载、聊天发送）
 */
#include "gateway_client.h"
#include <QAbstractSocket>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <QNetworkRequest>
#include <QProcess>
#include <algorithm>
#include <limits>

namespace {

QString escapePowerShellSingleQuoted(const QString &s)
{
    QString out = s;
    out.replace(QLatin1Char('\''), QLatin1String("''"));
    return out;
}

QString normalizeGitCloneUrl(QString raw)
{
    raw = raw.trimmed();
    if (raw.isEmpty())
        return raw;
    if (raw.startsWith(QStringLiteral("git@")))
        return raw;
    if (!raw.toLower().contains(QStringLiteral("github.com")))
        return raw;
    const QUrl u(raw);
    if (!u.isValid())
        return raw;
    QString path = u.path();
    const int treePos = path.indexOf(QStringLiteral("/tree/"));
    if (treePos > 0)
        path = path.left(treePos);
    const int blobPos = path.indexOf(QStringLiteral("/blob/"));
    if (blobPos > 0)
        path = path.left(blobPos);
    QUrl clean = u;
    clean.setPath(path);
    clean.setQuery(QString());
    clean.setFragment(QString());
    return clean.toString();
}

} // namespace

/// 帧类型常量：事件帧
static const QLatin1String T_EVENT("event");
/// 帧类型常量：请求帧
static const QLatin1String T_REQ("req");
/// 帧类型常量：响应帧
static const QLatin1String T_RES("res");

// ═══════════════════════════════════════════════════════════════════════
//  1. 构造 / 析构
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 构造函数
 *
 * 执行以下初始化步骤：
 *   1. 创建 QWebSocket 实例（子对象，自动随父对象销毁）
 *   2. 将 QWebSocket 的 4 个核心信号连接到本类的槽函数：
 *      - connected             → onConnected()         连接建立
 *      - disconnected          → onDisconnected()      连接断开
 *      - textMessageReceived   → onTextMessageReceived() 文本消息
 *      - error                 → onSocketError()       底层错误
 *   3. WsConfig 在自身构造时已自动生成 Ed25519 密钥对
 *   4. WsSession 初始无选中会话，仅在用户选择 agent 或首条消息自动建 agent 后才有 sessionKey
 */
GatewayClient::GatewayClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(),
                              QWebSocketProtocol::VersionLatest, this))
    , m_state(Disconnected)
    , m_agentFirstUserTitleDebounce(this)
    // m_config、m_session、m_skill、m_scheduledTask 由各自默认构造函数初始化
{
    m_agentFirstUserTitleDebounce.setSingleShot(true);
    m_agentFirstUserTitleDebounce.setInterval(400);
    connect(&m_agentFirstUserTitleDebounce, &QTimer::timeout, this,
            &GatewayClient::flushAgentListFirstUserTitles);

    m_toolResultRefreshTimer.setSingleShot(true);
    m_toolResultRefreshTimer.setInterval(300);
    connect(&m_toolResultRefreshTimer, &QTimer::timeout, this, [this]() {
        if (m_state != Connected) return;
        const QString reqId = sendRequest(
            QStringLiteral("chat.history"),
            m_session.buildChatHistoryParams(m_session.currentSessionKey(), 500));
        m_toolResultRefreshReqIds.insert(reqId);
    });

    m_socket->setMaxAllowedIncomingFrameSize(std::numeric_limits<quint64>::max());
    m_socket->setMaxAllowedIncomingMessageSize(std::numeric_limits<quint64>::max());

    // ── 连接 QWebSocket 信号到本类槽函数 ──
    connect(m_socket, &QWebSocket::connected,
            this, &GatewayClient::onConnected);
    connect(m_socket, &QWebSocket::disconnected,
            this, &GatewayClient::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived,
            this, &GatewayClient::onTextMessageReceived);
    connect(m_socket,
            QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
            this, &GatewayClient::onSocketError);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, [=](const QByteArray &data) {
        QString json = QString::fromUtf8(data);
        qDebug() << "收到完整二进制消息，字节数：" << data.size();
    });
    connect(m_socket, &QWebSocket::textFrameReceived, this, [=](const QString &frame, bool isLastFrame) {
        qDebug() << "收到文本分片，长度：" << frame.size() << "是否最后一片：" << isLastFrame;
    });
    connect(m_socket, &QWebSocket::binaryFrameReceived, this, [=](const QByteArray &frame, bool isLastFrame) {
        qDebug() << "收到二进制分片，长度：" << frame.size() << "是否最后一片：" << isLastFrame;
    });
}

/**
 * @brief 析构函数 —— 关闭 WebSocket 连接并释放资源
 *
 * QWebSocket 作为本对象的子对象，会在 QObject 树销毁时自动 delete。
 * 此处显式 close() 确保 WebSocket 正常关闭握手。
 */
GatewayClient::~GatewayClient()
{
    m_userRequestedDisconnect = true;
    m_autoReconnectFailureCount = 0;
    m_socket->close();
}

// ═══════════════════════════════════════════════════════════════════════
//  2. 属性访问器
// ═══════════════════════════════════════════════════════════════════════

int GatewayClient::connectionState() const { return m_state; }

QString GatewayClient::serverUrl() const { return m_config.serverUrl(); }

/// 将连接状态枚举转换为用户可读的中文描述
QString GatewayClient::statusText() const
{
    switch (m_state) {
    case Disconnected: return QStringLiteral("\u5df2\u65ad\u5f00");     // 已断开
    case Connecting:   return QStringLiteral("\u8fde\u63a5\u4e2d...");   // 连接中...
    case Handshaking:  return QStringLiteral("\u63e1\u624b\u4e2d...");   // 握手中...
    case Connected:    return QStringLiteral("\u5df2\u8fde\u63a5");     // 已连接
    }
    return QStringLiteral("\u672a\u77e5"); // 未知
}

/// 委托给 WsSession 获取会话列表
QVariantList GatewayClient::sessions() const
{
    return m_session.sessions();
}

/// 委托给 WsSession 获取当前会话 key
QString GatewayClient::currentSessionKey() const
{
    return m_session.currentSessionKey();
}

/// 委托给 WsSkill 获取技能列表
QVariantList GatewayClient::skillList() const
{
    return m_skill.skillList();
}

/// 委托给 WsScheduledTask 获取任务列表
QVariantList GatewayClient::cronJobs() const
{
    return m_scheduledTask.jobList();
}

/// 委托给 WsScheduledTask 获取 cron 服务状态
QVariantMap GatewayClient::cronServiceStatus() const
{
    return m_scheduledTask.cronStatus();
}

/// 获取当前 agent 身份信息
QVariantMap GatewayClient::agentIdentity() const
{
    return m_agentIdentity;
}

/// 获取 agent 列表
QVariantList GatewayClient::agentList() const
{
    return m_agentList;
}

/// 获取默认 agent ID
QString GatewayClient::defaultAgentId() const
{
    return m_defaultAgentId;
}

/// 获取可用模型列表
QVariantList GatewayClient::modelList() const { return m_modelList; }

QVariantList GatewayClient::skillMarketFolders() const { return m_skillMarketFolders; }

bool GatewayClient::skillInstallBusy() const { return m_skillInstallBusy; }

/// 获取当前会话的模型信息
QVariantMap GatewayClient::currentModel() const { return m_currentModel; }

QString GatewayClient::pendingSessionModelId() const
{
    return m_pendingSessionModelId;
}

QVariantList GatewayClient::mcpList() const
{
    return m_mcpList;
}

QVariantList GatewayClient::toolList() const
{
    return m_tools.toolList();
}

/// 设置连接状态并通知 QML 属性绑定系统
void GatewayClient::setState(ConnectionState state)
{
    if (m_state != state) {
        m_state = state;
        emit connectionStateChanged();
    }
}

/// 委托给 WsSession 切换会话；若已连接且会话非空，查询该会话当前模型（sessions.patch model:null）
void GatewayClient::setCurrentSessionKey(const QString &key)
{
    if (!m_session.setCurrentSessionKey(key))
        return;
    if (m_state == Connected && !m_session.currentSessionKey().trimmed().isEmpty()) {
        if (!m_pendingSessionModelId.isEmpty())
            patchSessionModel(m_pendingSessionModelId);
        else
            patchSessionModel(QString());
    }
    emit currentSessionChanged();
}

void GatewayClient::clearActiveAgentContext()
{
    m_pendingAgentCreateForChat = false;
    m_pendingFirstChatMessage.clear();
    m_pendingBootstrapChatMessage.clear();
    if (!m_pendingSessionModelId.isEmpty()) {
        m_pendingSessionModelId.clear();
        emit pendingSessionModelIdChanged();
    }
    if (m_session.setCurrentSessionKey(QString()))
        emit currentSessionChanged();
}

bool GatewayClient::mergeSessionHintsIntoAgentList()
{
    struct Best {
        qint64 updated = 0;   // 挑选该 agent 下最近活跃的会话（用于 startedAt / task- 时间）
        qint64 startedAt = 0; // 会话开始时间，侧栏展示（不用 updatedAt）
    };
    struct CronPick {
        qint64 updated = -1;
        qint64 startedAt = 0;
        QString sessionKey;
    };
    QHash<QString, Best> bestByAgent;
    QHash<QString, CronPick> bestCronByAgent;

    const QVariantList sess = m_session.sessions();
    for (const QVariant &v : sess) {
        const QVariantMap m = v.toMap();
        const QString key = m.value(QStringLiteral("sessionKey")).toString();
        if (!key.startsWith(QLatin1String("agent:")))
            continue;
        const QStringList parts = key.split(QLatin1Char(':'));
        if (parts.size() < 3)
            continue;
        const QString agentId = parts[1];
        if (agentId.isEmpty())
            continue;

        const qint64 updated =
            m.value(QStringLiteral("updatedAt")).toLongLong();
        const qint64 startedAt =
            m.value(QStringLiteral("startedAt")).toLongLong();

        Best &slot = bestByAgent[agentId];
        if (updated >= slot.updated) {
            slot.updated = updated;
            slot.startedAt = startedAt;
        }

        // agent:<id>:cron:<uuid> — 定时任务会话
        if (parts.size() >= 4 && parts[2] == QLatin1String("cron")) {
            CronPick &cp = bestCronByAgent[agentId];
            if (updated >= cp.updated) {
                cp.updated = updated;
                cp.startedAt = startedAt;
                cp.sessionKey = key;
            }
        }
    }

    QVariantList next = m_agentList;
    bool changed = false;
    for (int i = 0; i < next.size(); ++i) {
        QVariantMap row = next.at(i).toMap();
        const QString id = row.value(QStringLiteral("id")).toString();
        const QString name = row.value(QStringLiteral("name")).toString();
        // 与 makeCronDedicatedAgentName 一致：「定时-」前缀的专用 agent 走 cron 会话
        const bool cronDedicatedAgent =
            name.startsWith(QStringLiteral("\u5b9a\u65f6-"));
        const CronPick cronPick = bestCronByAgent.value(id);
        const Best b = bestByAgent.value(id);

        const QString oldChatSk =
            row.value(QStringLiteral("chatSessionKey")).toString();
        const qint64 oldDisplayAt =
            row.value(QStringLiteral("activeSessionDisplayAt")).toLongLong();
        const QString oldTitle =
            row.value(QStringLiteral("activeSessionTitle")).toString();

        if (cronDedicatedAgent && !cronPick.sessionKey.isEmpty()) {
            row[QStringLiteral("chatSessionKey")] = cronPick.sessionKey;
            qint64 displayAt = cronPick.startedAt;
            if (displayAt <= 0)
                displayAt = cronPick.updated;
            if (displayAt <= 0 && id.startsWith(QLatin1String("task-"))) {
                bool ok = false;
                const qint64 parsed = id.mid(5).toLongLong(&ok);
                if (ok && parsed > Q_INT64_C(1000000000000))
                    displayAt = parsed;
            }
            if (cronPick.updated >= 0) {
                row[QStringLiteral("activeSessionDisplayAt")] =
                    QVariant(static_cast<qlonglong>(displayAt));
            }
        } else {
            row.remove(QStringLiteral("chatSessionKey"));
            qint64 displayAt = b.startedAt;
            if (displayAt <= 0 && id.startsWith(QLatin1String("task-"))) {
                bool ok = false;
                const qint64 parsed = id.mid(5).toLongLong(&ok);
                if (ok && parsed > Q_INT64_C(1000000000000))
                    displayAt = parsed;
            }
            if (b.updated == 0) {
                if (displayAt > 0) {
                    row[QStringLiteral("activeSessionDisplayAt")] =
                        QVariant(static_cast<qlonglong>(displayAt));
                } else {
                    row.remove(QStringLiteral("activeSessionDisplayAt"));
                }
            } else {
                row[QStringLiteral("activeSessionDisplayAt")] =
                    QVariant(static_cast<qlonglong>(displayAt));
            }
        }

        const QString newChatSk =
            row.value(QStringLiteral("chatSessionKey")).toString();
        const QString primarySk = newChatSk.trimmed().isEmpty()
            ? QStringLiteral("agent:%1:main").arg(id)
            : newChatSk.trimmed();
        const QString oldRowSk = row.value(QStringLiteral("sessionKey")).toString();
        row[QStringLiteral("sessionKey")] = primarySk;
        if (oldRowSk != primarySk)
            changed = true;

        if (oldChatSk != newChatSk
            || oldDisplayAt
                != row.value(QStringLiteral("activeSessionDisplayAt")).toLongLong()
            || oldTitle
                != row.value(QStringLiteral("activeSessionTitle")).toString()) {
            changed = true;
        }
        next[i] = row;
    }

    if (!changed)
        return false;
    m_agentList = next;
    return true;
}

void GatewayClient::schedulePostStreamSidebarRefresh()
{
    if (m_state != Connected)
        return;
    const QString key = m_session.currentSessionKey();
    if (key.isEmpty())
        return;
    QTimer::singleShot(500, this, [this, key]() {
        if (m_state != Connected)
            return;
        refreshSessions();
        if (key.startsWith(QLatin1String("agent:"))) {
            const QStringList parts = key.split(QLatin1Char(':'));
            if (parts.size() >= 2 && !parts[1].isEmpty())
                refreshSidebarFirstUserTitleForAgent(parts[1]);
        }
    });
}

void GatewayClient::scheduleAgentListFirstUserTitles()
{
    if (m_state != Connected)
        return;
    m_agentFirstUserTitleDebounce.start();
}

void GatewayClient::flushAgentListFirstUserTitles()
{
    if (m_state != Connected)
        return;
    if (m_agentList.isEmpty())
        return;

    ++m_sidebarTitleBatchGen;
    const quint64 batch = m_sidebarTitleBatchGen;

    for (const QVariant &v : m_agentList) {
        const QVariantMap row = v.toMap();
        const QString aid = row.value(QStringLiteral("id")).toString();
        if (aid.isEmpty())
            continue;
        const QString sk = resolveChatSessionKeyForAgentId(aid);
        const QString reqId =
            sendRequest(QStringLiteral("chat.history"),
                        m_session.buildChatHistoryParams(sk, 1000));
        m_sidebarTitleHistReqAgent.insert(reqId, aid);
        m_sidebarTitleHistReqBatch.insert(reqId, batch);
    }

    qDebug().noquote() << "[Gateway] sidebar first-user titles batch" << batch
                       << "agents=" << m_agentList.size();
}

void GatewayClient::refreshSidebarFirstUserTitleForAgent(const QString &agentId)
{
    if (m_state != Connected)
        return;
    const QString aid = agentId.trimmed();
    if (aid.isEmpty())
        return;

    ++m_sidebarTitleBatchGen;
    const quint64 batch = m_sidebarTitleBatchGen;
    const QString sk = resolveChatSessionKeyForAgentId(aid);
    const QString reqId =
        sendRequest(QStringLiteral("chat.history"),
                    m_session.buildChatHistoryParams(sk, 1000));
    m_sidebarTitleHistReqAgent.insert(reqId, aid);
    m_sidebarTitleHistReqBatch.insert(reqId, batch);
}

QString GatewayClient::firstUserMessageFromHistoryList(const QVariantList &history)
{
    for (const QVariant &v : history) {
        const QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("role")).toString() != QLatin1String("user"))
            continue;
        const QString mt = m.value(QStringLiteral("msgType")).toString();
        if (mt == QLatin1String("toolCall") || mt == QLatin1String("toolResult"))
            continue;
        const QString t = m.value(QStringLiteral("content")).toString().trimmed();
        if (!t.isEmpty())
            return t;
    }
    return QString();
}

void GatewayClient::setAgentListSidebarTitle(const QString &agentId, const QString &text)
{
    QString t = text;
    if (t.length() > 120)
        t = t.left(117) + QStringLiteral("...");

    QVariantList next = m_agentList;
    bool changed = false;
    for (int i = 0; i < next.size(); ++i) {
        QVariantMap row = next.at(i).toMap();
        if (row.value(QStringLiteral("id")).toString() != agentId)
            continue;
        const QString name = row.value(QStringLiteral("name")).toString();
        if (name.startsWith(QStringLiteral("\u5b9a\u65f6-")))
            return;
        const QString old = row.value(QStringLiteral("activeSessionTitle")).toString();
        if (old == t)
            return;
        row[QStringLiteral("activeSessionTitle")] = t;
        next[i] = row;
        changed = true;
        break;
    }
    if (changed) {
        m_agentList = next;
        emit agentListChanged();
    }
}

QString GatewayClient::resolveChatSessionKeyForAgentId(const QString &agentId) const
{
    const QString aid = agentId.trimmed();
    if (aid.isEmpty())
        return QString();
    for (const QVariant &v : m_agentList) {
        const QVariantMap row = v.toMap();
        if (row.value(QStringLiteral("id")).toString() != aid)
            continue;
        const QString csk =
            row.value(QStringLiteral("chatSessionKey")).toString().trimmed();
        if (!csk.isEmpty())
            return csk;
        break;
    }
    return QStringLiteral("agent:%1:main").arg(aid);
}

QString GatewayClient::makeCronDedicatedAgentName(const QString &taskTitle)
{
    QString t = taskTitle.trimmed();
    if (t.isEmpty())
        t = QStringLiteral("task");
    if (t.length() > 28)
        t = t.left(28);
    return QStringLiteral("\u5b9a\u65f6-%1-%2")
        .arg(t)
        .arg(QDateTime::currentMSecsSinceEpoch());
}

QString GatewayClient::cronDedicatedAgentDisplayName(const QString &taskTitle) const
{
    return makeCronDedicatedAgentName(taskTitle);
}

void GatewayClient::prepareCronJobWithDedicatedAgent(
    int scheduleKind,
    const QString &jobName,
    const QString &message,
    const QString &cronExpr,
    const QString &tz,
    int intervalSec,
    const QString &isoDateTime)
{
    if (m_state != Connected) {
        clearPendingCronDedicatedAgent();
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }

    clearPendingCronDedicatedAgent();
    m_cronAwaitingDedicatedAgent = true;
    m_cronPendingScheduleKind = scheduleKind;
    m_cronPendingJobName = jobName;
    m_cronPendingMessage = message;

    switch (scheduleKind) {
    case 1:
        m_cronPendingCronExpr = cronExpr;
        m_cronPendingTz = tz.isEmpty() ? QStringLiteral("Asia/Shanghai") : tz;
        return;
    case 2:
        if (intervalSec <= 0) {
            clearPendingCronDedicatedAgent();
            emit errorOccurred(
                QStringLiteral("\u95f4\u9694\u5fc5\u987b\u5927\u4e8e 0 \u79d2"));
            return;
        }
        m_cronPendingEveryMs = intervalSec * 1000;
        return;
    case 3: {
        const QDateTime at = QDateTime::fromString(isoDateTime, Qt::ISODate);
        if (!at.isValid()) {
            clearPendingCronDedicatedAgent();
            emit errorOccurred(
                QStringLiteral("\u65e0\u6548\u7684\u65f6\u95f4\u683c\u5f0f: %1")
                    .arg(isoDateTime));
            return;
        }
        m_cronPendingAt = at;
        m_cronPendingDeleteAfterRun = true;
        return;
    }
    default:
        clearPendingCronDedicatedAgent();
        emit errorOccurred(
            QStringLiteral("\u65e0\u6548\u7684\u5b9a\u65f6\u7c7b\u578b"));
        return;
    }
}

void GatewayClient::clearPendingCronDedicatedAgent()
{
    m_cronAwaitingDedicatedAgent = false;
    m_cronPendingScheduleKind = 0;
    m_cronPendingJobName.clear();
    m_cronPendingCronExpr.clear();
    m_cronPendingMessage.clear();
    m_cronPendingTz.clear();
    m_cronPendingEveryMs = 0;
    m_cronPendingAt = QDateTime();
    m_cronPendingDeleteAfterRun = true;
}

void GatewayClient::sendPendingCronAddWithAgentId(const QString &agentId)
{
    if (agentId.isEmpty() || !m_cronAwaitingDedicatedAgent
        || m_cronPendingScheduleKind <= 0) {
        return;
    }

    const int kind = m_cronPendingScheduleKind;
    const QString jobName = m_cronPendingJobName;
    const QString cronExpr = m_cronPendingCronExpr;
    const QString message = m_cronPendingMessage;
    const QString tz = m_cronPendingTz.isEmpty() ? QStringLiteral("Asia/Shanghai")
                                                  : m_cronPendingTz;
    const int everyMs = m_cronPendingEveryMs;
    const QDateTime at = m_cronPendingAt;
    const bool deleteAfterRun = m_cronPendingDeleteAfterRun;

    clearPendingCronDedicatedAgent();

    // OpenClaw：sessionTarget "main" 仅允许 payload.kind=systemEvent；
    // agentTurn + 指定 agentId 须用 isolated（见 src/cron/service/jobs.ts assertSupportedJobSpec）
    const QString sessionIsolated = QStringLiteral("isolated");

    QJsonObject cronParams;
    switch (kind) {
    case 1:
        cronParams = m_scheduledTask.buildAddCronJobParams(
            jobName, cronExpr, message, tz, sessionIsolated, false, agentId);
        break;
    case 2:
        if (everyMs > 0) {
            cronParams = m_scheduledTask.buildAddIntervalJobParams(
                jobName, everyMs, message, sessionIsolated, false, agentId);
        }
        break;
    case 3:
        if (at.isValid()) {
            cronParams = m_scheduledTask.buildAddOneTimeJobParams(
                jobName, at, message, deleteAfterRun, sessionIsolated, agentId);
        }
        break;
    default:
        break;
    }

    if (!cronParams.isEmpty()) {
        qDebug().noquote() << "[Gateway] cron.add bound to dedicated agent" << agentId
                           << "scheduleKind=" << kind;
        sendRequest(QStringLiteral("cron.add"), cronParams);
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  3. 连接生命周期
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 发起 WebSocket 连接
 *
 * 完整流程：
 *   1. 如果当前非 Disconnected，先关闭旧连接
 *   2. 清空握手 nonce 和所有 pending 请求（防止旧请求干扰新连接）
 *   3. 状态切换到 Connecting
 *   4. 调用 QWebSocket::open(url) 发起 TCP 连接 + WebSocket 升级
 *
 * 后续流程在 onConnected() 中继续。
 */
void GatewayClient::connectToServer(const QString &url)
{
    const bool fromAuto = m_connectFromAutoReconnect;
    m_connectFromAutoReconnect = false;

    m_userRequestedDisconnect = false;
    m_lastConnectedWsUrl = url;
    if (!fromAuto)
        m_autoReconnectFailureCount = 0;

    if (m_state != Disconnected) {
        m_skipAutoReconnectOnNextDisconnect = true;
        m_socket->close();
    }

    m_challengeNonce.clear();
    m_pendingRequests.clear();
    m_pendingAgentCreateForChat = false;
    m_pendingFirstChatMessage.clear();
    m_pendingBootstrapChatMessage.clear();
    clearPendingCronDedicatedAgent();
    m_sidebarTitleHistReqAgent.clear();
    m_sidebarTitleHistReqBatch.clear();
    m_agentFirstUserTitleDebounce.stop();
    setState(Connecting);

    // ── 构造带 Origin 头的请求 ──
    // Gateway 会校验 Origin 是否在 controlUi.allowedOrigins 白名单中。
    // 将 ws:// → http://、wss:// → https://，拼接为 Origin 值。
    QUrl wsUrl(url);
    const QString scheme = (wsUrl.scheme() == QStringLiteral("wss"))
                           ? QStringLiteral("https") : QStringLiteral("http");
    const QString origin = QStringLiteral("%1://%2:%3")
                           .arg(scheme, wsUrl.host())
                           .arg(wsUrl.port(18789));

    QNetworkRequest request(wsUrl);
    request.setRawHeader("Origin", origin.toUtf8());

    qDebug() << "[Gateway][TRACE][OPEN]"
             << "socket=" << reinterpret_cast<quintptr>(m_socket)
             << "url=" << url
             << "origin=" << origin
             << "pendingBeforeOpen=" << m_pendingRequests.size();
    m_socket->open(request);
}

/**
 * @brief 主动断开连接
 *
 * 触发 QWebSocket 的正常关闭握手（发送 Close 帧）。
 * 关闭完成后 QWebSocket 会发射 disconnected 信号，
 * 由 onDisconnected() 完成状态清理。
 */
void GatewayClient::disconnectFromServer()
{
    m_userRequestedDisconnect = true;
    m_autoReconnectFailureCount = 0;
    m_pendingReconnectDelayMs = 0;
    m_toolResultRefreshTimer.stop();
    m_toolResultRefreshReqIds.clear();
    if (m_skillInstallBusy) {
        m_skillInstallBusy = false;
        emit skillInstallBusyChanged();
    }
    m_socket->close();
}

/**
 * @brief WebSocket 连接建立成功回调
 *
 * 此时 TCP 连接和 WebSocket 协议升级均已完成。
 * 状态切换到 Handshaking，等待服务器下发 connect.challenge 事件。
 */
void GatewayClient::onConnected()
{
    qDebug() << "[Gateway][TRACE][CONNECTED]"
             << "socket=" << reinterpret_cast<quintptr>(m_socket)
             << "pending=" << m_pendingRequests.size();
    setState(Handshaking);
}

/**
 * @brief WebSocket 连接断开回调（主动或被动断开均触发）
 *
 * 清理工作：
 *   1. 重置流式状态（WsSession）
 *   2. 清空所有 pending 请求（不再等待响应）
 *   3. 状态切换到 Disconnected
 */
void GatewayClient::scheduleAutoReconnectConnect(const QString &url, int delayMs)
{
    QTimer::singleShot(delayMs, this, [this, url]() {
        if (m_state != Disconnected)
            return;
        if (m_userRequestedDisconnect)
            return;
        m_connectFromAutoReconnect = true;
        connectToServer(url);
    });
}

void GatewayClient::onDisconnected()
{
    qDebug() << "[Gateway][TRACE][DISCONNECTED]"
             << "socket=" << reinterpret_cast<quintptr>(m_socket)
             << "pendingBeforeClear=" << m_pendingRequests.size();
    const ConnectionState prevState = m_state;

    m_session.setStreaming(false);
    m_pendingRequests.clear();
    if (!m_pendingSessionModelId.isEmpty()) {
        m_pendingSessionModelId.clear();
        emit pendingSessionModelIdChanged();
    }
    clearPendingCronDedicatedAgent();
    m_sidebarTitleHistReqAgent.clear();
    m_sidebarTitleHistReqBatch.clear();
    m_agentFirstUserTitleDebounce.stop();

    setState(Disconnected);

    if (m_skipAutoReconnectOnNextDisconnect) {
        m_skipAutoReconnectOnNextDisconnect = false;
        return;
    }

    if (m_userRequestedDisconnect) {
        m_userRequestedDisconnect = false;
        m_autoReconnectFailureCount = 0;
        if (m_skillInstallBusy) {
            m_skillInstallBusy = false;
            emit skillInstallBusyChanged();
        }
        return;
    }

    const QString url = m_lastConnectedWsUrl.isEmpty()
        ? m_config.serverUrl() : m_lastConnectedWsUrl;
    if (url.trimmed().isEmpty()) {
        if (m_skillInstallBusy) {
            m_skillInstallBusy = false;
            emit skillInstallBusyChanged();
        }
        return;
    }

    int delayMs = 0;
    bool pendingDelayed = false;
    if (m_pendingReconnectDelayMs > 0) {
        delayMs = m_pendingReconnectDelayMs;
        m_pendingReconnectDelayMs = 0;
        pendingDelayed = true;
        qDebug().noquote() << "[Gateway] auto-reconnect (post shutdown delay) scheduled in"
                           << delayMs << "ms" << url;
    }

    if (prevState == Connected || pendingDelayed) {
        m_autoReconnectFailureCount = 0;
        if (!pendingDelayed)
            delayMs = 0;
        scheduleAutoReconnectConnect(url, delayMs);
        return;
    }

    if (prevState == Connecting || prevState == Handshaking) {
        m_autoReconnectFailureCount += 1;
        if (m_autoReconnectFailureCount >= kMaxAutoReconnectFailures) {
            qWarning().noquote()
                << "[Gateway] auto-reconnect gave up after"
                << kMaxAutoReconnectFailures << "failed attempts" << url;
            if (m_skillInstallBusy) {
                m_skillInstallBusy = false;
                emit skillInstallBusyChanged();
            }
            return;
        }
        qDebug().noquote() << "[Gateway] auto-reconnect retry in 1000ms (fail"
                           << m_autoReconnectFailureCount << "/" << kMaxAutoReconnectFailures << ")"
                           << url;
        scheduleAutoReconnectConnect(url, 1000);
        return;
    }

    if (m_skillInstallBusy) {
        m_skillInstallBusy = false;
        emit skillInstallBusyChanged();
    }
}

/**
 * @brief WebSocket 底层错误回调
 *
 * 可能的错误场景：
 *   - 目标地址不可达（服务器未启动）
 *   - DNS 解析失败
 *   - TLS 握手失败（如果使用 wss://）
 *   - 连接超时
 */
void GatewayClient::onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    qWarning() << "[Gateway][TRACE][SOCKET_ERROR]"
               << "socket=" << reinterpret_cast<quintptr>(m_socket)
               << "pending=" << m_pendingRequests.size()
               << "error=" << m_socket->errorString();
    emit errorOccurred(m_socket->errorString());
    // 不在此处 setState(Disconnected)，保留 Connecting/Handshaking/Connected
    // 供 onDisconnected 判断断线前阶段并走自动重连逻辑。
    // 少数情况下仅 error 不触发 disconnected，强制 abort 以统一进入 onDisconnected。
    if (m_socket->state() != QAbstractSocket::UnconnectedState)
        m_socket->abort();
}

// ═══════════════════════════════════════════════════════════════════════
//  4. 协议握手（challenge → connect → hello-ok）
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 发送 connect 握手请求
 *
 * 握手协议时序：
 *   ┌────────┐                    ┌─────────┐
 *   │ Client │                    │ Gateway │
 *   └───┬────┘                    └────┬────┘
 *       │     ──── WebSocket ────→     │  TCP + 升级
 *       │     ←── connect.challenge ── │  下发 nonce
 *       │     ──── connect req ────→   │  携带签名 device
 *       │     ←── res {ok:true} ─────  │  hello-ok
 *       │                              │
 *
 * 本方法在收到 connect.challenge 后被调用：
 *   1. 生成唯一 requestId
 *   2. 委托 WsConfig 构建含 Ed25519 签名的完整 params
 *   3. 组装 {type:"req", method:"connect"} 帧并发送
 */
void GatewayClient::sendConnectRequest()
{
    m_connectRequestId = nextRequestId();
    m_pendingRequests.insert(m_connectRequestId, QStringLiteral("connect"));

    // 由配置类构建包含设备签名的完整握手参数
    const QJsonObject params = m_config.buildConnectParams(m_challengeNonce);

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = m_connectRequestId;
    request[QStringLiteral("method")] = QStringLiteral("connect");
    request[QStringLiteral("params")] = params;

    // 为了调试方便，使用缩进格式打印
    const QByteArray debugJson =
        QJsonDocument(request).toJson(QJsonDocument::Indented);
    qDebug().noquote() << "=== 发送握手请求 (CONNECT) ===";
    qDebug().noquote() << QString::fromUtf8(debugJson);

    // 发送时使用压缩格式以节省带宽
    const QByteArray json =
        QJsonDocument(request).toJson(QJsonDocument::Compact);
    m_socket->sendTextMessage(QString::fromUtf8(json));
}

// ═══════════════════════════════════════════════════════════════════════
//  5. 入站消息分发
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 入站消息总入口 —— 解析 JSON 并分发到对应处理函数
 *
 * OpenClaw 协议帧类型：
 *   - "event"  事件帧（服务器推送）→ handleEvent()
 *   - "res"    响应帧（RPC 应答）  → handleResponse()
 *   - 某些帧 type 为 "req" 但含 "ok" 字段 → 也视为响应
 *   - 无 "type" 但含 "event" 字段 → 视为事件（兼容处理）
 */
void GatewayClient::onTextMessageReceived(const QString &message)
{

    qDebug() << "=== 收到文本消息 ===";
    qDebug() << "长度 (字符数):" << message.length();
    qDebug() << "前 200 字符预览:" << message.left(20000);
    // ── 1. JSON 解析 ──
    QJsonParseError err;
     const QJsonDocument doc =
        QJsonDocument::fromJson(message.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[Gateway] bad JSON:" << err.errorString();
        return;
    }

    const QJsonObject msg  = doc.object();
    const QString     type = msg.value(QStringLiteral("type")).toString();

    // ── 2. 按帧类型分发 ──
    if (type == T_EVENT) {
        handleEvent(msg);
        return;
    }
    if (type == T_RES
        || (type == T_REQ && msg.contains(QStringLiteral("ok")))) {
        handleResponse(msg);
        return;
    }
    // 兼容：某些帧没有 type 但有 event 字段
    if (msg.contains(QStringLiteral("event"))) {
        handleEvent(msg);
        return;
    }

    qDebug() << "[Gateway] unrecognised frame:" << message.left(400);
}

/**
 * @brief 处理入站事件帧
 *
 * 事件分类：
 *   ① connect.challenge：握手阶段，提取 nonce 后发送 connect 请求
 *   ② tick / heartbeat：心跳事件，当前直接忽略（预留给 WsScheduledTask）
 *   ③ agent / chat：业务事件，委托 WsSession::parseEvent() 解析
 *      并根据解析结果发射对应的 Qt 信号（streaming / chatMessage）
 *   ④ 其他：如有文本内容，作为完整消息发射
 */
void GatewayClient::handleEvent(const QJsonObject &msg)
{
    const QString     event   = msg.value(QStringLiteral("event")).toString();
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();

    // ── ① connect.challenge：握手阶段 ──
    if (event == QLatin1String("connect.challenge")) {
        m_challengeNonce = payload.value(QStringLiteral("nonce")).toString();
        qDebug() << "[Gateway] challenge nonce:" << m_challengeNonce;
        sendConnectRequest();
        return;
    }

    // ── ② tick / heartbeat：心跳（当前忽略） ──
    if (event == QLatin1String("tick")
        || event == QLatin1String("heartbeat")) {
        return;
    }

    // 网关即将重启：payload.restartExpectedMs 为大致恢复时间，用于断线后延迟重连
    if (event == QLatin1String("shutdown")) {
        const int expected =
            payload.value(QStringLiteral("restartExpectedMs")).toInt(0);
        if (expected > 0) {
            m_pendingReconnectDelayMs = expected + 8000;
            qDebug().noquote() << "[Gateway] shutdown event restartExpectedMs=" << expected
                               << "→ reconnect delay" << m_pendingReconnectDelayMs << "ms";
        }
        return;
    }

    // ── ②.5 cron 事件：定时任务状态变更推送 ──
    if (event == QLatin1String("cron")) {
        qDebug() << "[Gateway] cron event:" << payload;
        emit cronStatusChanged();
        refreshCronJobs(true);
        return;
    }

    // ── 调试日志（前 50 条 agent/chat 事件） ──
    static int debugCount = 0;
    if (event == QLatin1String("agent")
        || event == QLatin1String("chat")
        || event == QLatin1String("session.tool")) {
        ++debugCount;
        const QJsonObject data =
            payload.value(QStringLiteral("data")).toObject();
        const bool hasPayloadMessage =
            payload.value(QStringLiteral("message")).isObject();
        const QString subEvent =
            payload.value(QStringLiteral("event")).toString();
        const QString dataType =
            data.value(QStringLiteral("type")).toString();
        const bool toolRelated =
            subEvent.contains(QLatin1String("tool"), Qt::CaseInsensitive)
            || dataType.contains(QLatin1String("tool"), Qt::CaseInsensitive);
        if (debugCount <= 50 || toolRelated) {
            qDebug().noquote()
                << "[Gateway] EVT#" << debugCount << event << "|" << subEvent
                << "hasPayloadMessage=" << hasPayloadMessage
                << "data:" << QString::fromUtf8(
                       QJsonDocument(data).toJson(QJsonDocument::Compact))
                       .left(500);
        } else if (debugCount % 100 == 0) {
            qDebug().noquote()
                << "[Gateway] EVT#" << debugCount << event << "|" << subEvent
                << "hasPayloadMessage=" << hasPayloadMessage
                << "data: <suppressed>";
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  session.tool 事件单独处理（用 stream=tool 格式，无 role 字段）
    //  直接走 parseEvent，跳过 handleStructuredChatEvent（永远不匹配）
    //  session key 检查用宽松模式：payload 无 key 时默认通过
    // ══════════════════════════════════════════════════════════════
    if (event == QLatin1String("session.tool")) {
        if (!eventAppliesToCurrentUiSession(payload, true))
            return;

        const WsEventResult tr = m_session.parseEvent(event, payload);
        if (tr.ignore) return;

        if (tr.isToolCall) {
            qDebug().noquote() << "[Gateway] session.tool → call:" << tr.toolName
                               << "id:" << tr.toolCallId;
            emit toolCallReceived(tr.toolName, tr.toolArgs, tr.toolCallId);
            return;
        }
        if (tr.isToolResult) {
            qDebug().noquote() << "[Gateway] session.tool → result:" << tr.toolName
                               << "error:" << tr.toolIsError
                               << "contentLen:" << tr.content.length();
            emit toolResultReceived(tr.toolName, tr.content,
                                    tr.toolCallId, tr.toolIsError);
            m_toolResultRefreshTimer.start();
            return;
        }
        return;
    }

    // ══════════════════════════════════════════════════════════════
    //  agent/chat 事件优先做结构化消息解析
    //  有些模型 / 网关会在 agent 事件里直接附带完整 message 对象，
    //  其中 content 数组包含 text / toolCall / toolResult。
    //  为了兼容这两种情况，agent / chat 都先走一遍结构化解析，
    //  如果检测到工具调用/结果则直接返回，不再走流式 delta 逻辑。
    // ══════════════════════════════════════════════════════════════
    if (event == QLatin1String("chat") || event == QLatin1String("agent")) {
        if (!eventAppliesToCurrentUiSession(payload))
            return;
        if (handleStructuredChatEvent(payload))
            return;
    }

    // ── ③ 委托 WsSession 解析事件语义（流式 delta / phase） ──
    const WsEventResult r = m_session.parseEvent(event, payload);

    if (r.ignore)
        return;

    // ── 工具调用事件（由 parseEvent 从 data.type 检测到） ──
    if (r.isToolCall) {
        qDebug().noquote() << "[Gateway] tool call:" << r.toolName
                           << "id:" << r.toolCallId;
        emit toolCallReceived(r.toolName, r.toolArgs, r.toolCallId);
        return;
    }
    if (r.isToolResult) {
        qDebug().noquote() << "[Gateway] tool result:" << r.toolName
                           << "error:" << r.toolIsError
                           << "contentLen:" << r.content.length();
        emit toolResultReceived(r.toolName, r.content,
                                r.toolCallId, r.toolIsError);
        m_toolResultRefreshTimer.start();
        return;
    }

    // ── 根据解析结果处理 agent 事件 ──
    if (event == QLatin1String("agent")) {
        if (r.isStart) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            return;
        }
        if (r.isDelta && !r.content.isEmpty()) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
            return;
        }
        if (r.isComplete) {
            if (m_session.isStreaming()) {
                m_session.setStreaming(false);
                emit streamingFinished();
            } else if (!r.content.isEmpty()) {
                emit chatMessageReceived(r.role, r.content, false);
            }
            schedulePostStreamSidebarRefresh();
            return;
        }
        if (!r.content.isEmpty()) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
        }
        return;
    }

    // ── 处理 chat 事件（parseEvent 检测到的 delta/complete） ──
    if (event == QLatin1String("chat")) {
        if (r.isDelta && !r.content.isEmpty()) {
            if (!m_session.isStreaming()) {
                m_session.setStreaming(true);
                emit streamingStarted();
            }
            emit chatMessageReceived(
                QStringLiteral("assistant"), r.content, true);
            return;
        }
        if (r.isComplete) {
            if (m_session.isStreaming()) {
                m_session.setStreaming(false);
                emit streamingFinished();
            } else if (!r.content.isEmpty()) {
                emit chatMessageReceived(r.role, r.content, false);
            }
            schedulePostStreamSidebarRefresh();
            return;
        }
        return;
    }

    // ── ④ 其他事件：如有内容，作为完整消息发射 ──
    if (!r.content.isEmpty())
        emit chatMessageReceived(r.role, r.content, false);
}

/**
 * @brief 处理入站响应帧
 *
 * 响应路由机制：
 *   - 每个出站请求的 requestId 在发送时记录到 m_pendingRequests
 *   - 响应到达时，通过 id 查找原始方法名（take = 查找 + 移除）
 *   - 根据方法名将 payload 分发给对应的子类解析方法
 */
void GatewayClient::handleResponse(const QJsonObject &msg)
{
    const QString     id      = msg.value(QStringLiteral("id")).toString();
    const bool        ok      = msg.value(QStringLiteral("ok")).toBool(false);
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();
    const QJsonValue  errVal  = msg.value(QStringLiteral("error"));
    const int pendingBeforeTake = m_pendingRequests.size();
    const QString methodInMap = m_pendingRequests.value(id);

    // 从 pending 映射中取出并移除此请求的方法名
    const QString method = m_pendingRequests.take(id);
    qDebug() << "[Gateway][TRACE][RECV]"
             << "socket=" << reinterpret_cast<quintptr>(m_socket)
             << "id=" << id
             << "ok=" << ok
             << "methodMatched=" << (methodInMap.isEmpty() ? QStringLiteral("<MISS>") : methodInMap)
             << "pendingBefore=" << pendingBeforeTake
             << "pendingAfter=" << m_pendingRequests.size();
    if (method.isEmpty()) {
        qWarning() << "[Gateway] response id not found in pending map:" << id
                   << "payload size:" << QJsonDocument(payload).toJson(QJsonDocument::Compact).size();
    }

    // ── 非 connect 请求的错误处理 ──
    if (!ok && id != m_connectRequestId) {
        QString errMsg;
        if (errVal.isObject())
            errMsg = errVal.toObject()
                         .value(QStringLiteral("message")).toString();
        if (errMsg.isEmpty() && errVal.isString())
            errMsg = errVal.toString();
        if (errMsg.isEmpty())
            errMsg = QStringLiteral("Request failed (ok=false)");
        qWarning() << "[Gateway] error" << method << "id=" << id << errMsg;

        if (method == QLatin1String("agents.create") && !m_pendingCreateName.isEmpty()) {
            emit agentCreated(m_pendingCreateName, false, errMsg, false);
            m_pendingCreateName.clear();
            m_pendingCreateWorkspace.clear();
            m_pendingAgentCreateForChat = false;
            m_pendingFirstChatMessage.clear();
            m_pendingBootstrapChatMessage.clear();
            m_pendingChatFiles.clear();
            clearPendingCronDedicatedAgent();
        }
        if (method == QLatin1String("agents.delete") && !m_pendingDeleteId.isEmpty()) {
            emit agentDeleted(m_pendingDeleteId, false, errMsg);
            m_pendingDeleteId.clear();
        }

        m_sidebarTitleHistReqAgent.remove(id);
        m_sidebarTitleHistReqBatch.remove(id);

        if (method == QLatin1String("config.patch")) {
            if (m_skillInstallBusy) {
                m_skillInstallBusy = false;
                emit skillInstallBusyChanged();
            }
        }

        emit errorOccurred(errMsg);
        return;
    }

    // ── connect 握手响应 ──
    if (id == m_connectRequestId) {
        if (!ok) {
            QString errMsg;
            if (errVal.isObject())
                errMsg = errVal.toObject()
                             .value(QStringLiteral("message")).toString();
            if (errMsg.isEmpty() && errVal.isString())
                errMsg = errVal.toString();
            qWarning() << "[Gateway] connect failed:" << errMsg;
            emit errorOccurred(errMsg);
            m_socket->abort();
            return;
        }
        // 握手成功：切换到 Connected，自动加载所有初始数据
        qDebug() << "[Gateway] handshake complete!";
        m_autoReconnectFailureCount = 0;
        setState(Connected);
        if (m_skillInstallBusy) {
            m_skillInstallBusy = false;
            emit skillInstallBusyChanged();
        }
        refreshAgents();
        refreshSessions();
        refreshModels();
        refreshMcpList();
        refreshToolsCatalog(QString());
        refreshSkillMarketFolders();
        if (!m_session.currentSessionKey().trimmed().isEmpty())
            patchSessionModel(QString());
        return;
    }

    // ── 业务响应路由 ──
    qDebug().noquote()
        << "[Gateway] <<" << method << "id=" << id
        << QString::fromUtf8(
               QJsonDocument(payload).toJson(QJsonDocument::Compact))
               .left(500);

    // sessions.list 响应 → 委托 WsSession 解析
    if (method == QLatin1String("sessions.list")) {
        m_session.parseSessionsResponse(payload);
        emit sessionsChanged();
        if (mergeSessionHintsIntoAgentList())
            emit agentListChanged();
        // 不在此处拉侧栏首句：点击任务会 refreshSessions → 若这里全量 chat.history
        // 会对每个 agent 发请求并多次 agentListChanged，列表会像「每次刷新」。
        return;
    }

    // chat.send 响应（如果是 /new 命令）→ 刷新列表 + 通知
    if (method == QLatin1String("chat.send")
        && id == m_session.newSessionReqId()) {
        m_session.clearNewSessionReqId();
        qDebug() << "[Gateway] /new session response, refreshing list...";
        refreshSessions();
        emit sessionCreated();
        return;
    }

    // session.delete 响应 → 刷新列表
    if (method == QLatin1String("session.delete")) {
        qDebug() << "[Gateway] session deleted, refreshing list...";
        refreshSessions();
        return;
    }

    // messages.list 响应 → 委托 WsSession 解析 + 发射历史加载信号
    if (method == QLatin1String("messages.list")) {
        int messageCount = payload.value(QStringLiteral("messages")).toArray().size();
        if (messageCount == 0)
            messageCount = payload.value(QStringLiteral("items")).toArray().size();
        if (messageCount == 0)
            messageCount = payload.value(QStringLiteral("data")).toArray().size();
        qDebug() << "[Gateway][TRACE][HISTORY]"
                 << "sessionKey=" << payload.value(QStringLiteral("sessionKey")).toString()
                 << "messages=" << messageCount
                 << "hasMore=" << payload.value(QStringLiteral("hasMore")).toBool(false)
                 << "nextCursor=" << payload.value(QStringLiteral("nextCursor")).toString();
        const QVariantList history =
            m_session.parseHistoryResponse(payload);
        emit historyLoaded(history);
        return;
    }

    // agents.create 响应 → 创建成功，刷新列表
    if (method == QLatin1String("agents.create")) {
        const QString agentId = payload.value(QStringLiteral("agentId")).toString();

        m_pendingCreateName.clear();

        QString bootstrapMsg;
        if (m_pendingAgentCreateForChat) {
            m_pendingAgentCreateForChat = false;
            bootstrapMsg = m_pendingFirstChatMessage;
            m_pendingFirstChatMessage.clear();
        }

        const bool doBootstrap = !bootstrapMsg.isEmpty() && !agentId.isEmpty();

        if (!agentId.isEmpty()) {
            m_pendingProfileFullAgentId = agentId;
            m_expectingToolPolicyApplyForAgentId = agentId;
            refreshMcpList();
        }

        if (doBootstrap) {
            m_newAgentSidebarId    = agentId;
            m_newAgentSidebarTitle = bootstrapMsg.left(120);
            m_newAgentSidebarTs    = QDateTime::currentMSecsSinceEpoch();
            applyAgentSwitch(agentId, false);
        }

        qDebug() << "[Gateway] agents.create ok:" << agentId;
        emit agentCreated(agentId, true,
            QStringLiteral("agent \"%1\" \u521b\u5efa\u6210\u529f").arg(agentId),
            doBootstrap);
        refreshAgents();
        refreshSessions();

        if (doBootstrap) {
            if (!m_pendingChatFiles.isEmpty()) {
                const QString ws = m_pendingCreateWorkspace.isEmpty()
                    ? resolveWorkspacePathForAgentId(agentId)
                    : m_pendingCreateWorkspace;
                resolveAndCopyFiles(m_pendingChatFiles, ws);
                m_pendingChatFiles.clear();
            }
            // 延迟到 config.set（deny 列表）发送后再发 chat.send，
            // 否则首条消息处理时 deny 列表尚未生效
            m_pendingBootstrapChatMessage = bootstrapMsg;
        }
        m_pendingCreateWorkspace.clear();

        // 在日志与 agentCreated 之后再发 cron.add，避免控制台顺序像「定时任务先于 agent」
        if (m_cronAwaitingDedicatedAgent) {
            if (!agentId.isEmpty())
                sendPendingCronAddWithAgentId(agentId);
            else
                clearPendingCronDedicatedAgent();
        }
        return;
    }

    // agents.delete 响应 → 删除成功，刷新列表
    if (method == QLatin1String("agents.delete")) {
        const QString agentId = payload.value(QStringLiteral("agentId")).toString();
        const int removedBindings =
            payload.value(QStringLiteral("removedBindings")).toInt(0);
        m_pendingDeleteId.clear();

        qDebug() << "[Gateway] agents.delete ok:" << agentId
                 << "removedBindings:" << removedBindings;
        emit agentDeleted(agentId, true,
            QStringLiteral("agent \"%1\" \u5df2\u5220\u9664").arg(agentId));
        refreshAgents();
        return;
    }

    // agents.list 响应 → 解析 agent 列表
    if (method == QLatin1String("agents.list")) {
        m_agentList.clear();
        m_defaultAgentId = payload.value(QStringLiteral("defaultId")).toString();
        const QString mainKey = payload.value(QStringLiteral("mainKey")).toString();

        const QJsonArray agents = payload.value(QStringLiteral("agents")).toArray();
        for (const QJsonValue &v : agents) {
            const QJsonObject a = v.toObject();
            const QString id = a.value(QStringLiteral("id")).toString();
            if (id.isEmpty()) continue;

            QString name = a.value(QStringLiteral("name")).toString();
            if (name.isEmpty()) name = id;

            QVariantMap entry;
            entry[QStringLiteral("id")]         = id;
            entry[QStringLiteral("name")]       = name;
            entry[QStringLiteral("sessionKey")] =
                QStringLiteral("agent:%1:main").arg(id);
            entry[QStringLiteral("isDefault")]  = (id == m_defaultAgentId);

            m_agentList.append(entry);
        }

        qDebug() << "[Gateway] agents.list: found" << m_agentList.count()
                 << "agents, default:" << m_defaultAgentId
                 << "mainKey:" << mainKey;
        mergeSessionHintsIntoAgentList();

        if (!m_newAgentSidebarId.isEmpty()) {
            for (int i = 0; i < m_agentList.size(); ++i) {
                QVariantMap row = m_agentList[i].toMap();
                if (row.value(QStringLiteral("id")).toString() == m_newAgentSidebarId) {
                    if (!m_newAgentSidebarTitle.isEmpty())
                        row[QStringLiteral("activeSessionTitle")] = m_newAgentSidebarTitle;
                    if (m_newAgentSidebarTs > 0)
                        row[QStringLiteral("activeSessionDisplayAt")] =
                            QVariant(static_cast<qlonglong>(m_newAgentSidebarTs));
                    m_agentList[i] = row;
                    break;
                }
            }
            m_newAgentSidebarId.clear();
            m_newAgentSidebarTitle.clear();
            m_newAgentSidebarTs = 0;
        }

        emit agentListChanged();
        scheduleAgentListFirstUserTitles();
        return;
    }

    // agent.identity.get 响应 → 解析身份并通知
    // 服务端 identity 不含 workspace，从 config.get 缓存的 agents.list 补全
    if (method == QLatin1String("agent.identity.get")) {
        m_agentIdentity = m_session.parseAgentIdentityResponse(payload);
        const QString aid =
            m_agentIdentity.value(QStringLiteral("agentId")).toString().trimmed();
        const QString ws = resolveWorkspacePathForAgentId(aid);
        if (!ws.isEmpty())
            m_agentIdentity.insert(QStringLiteral("workspace"), ws);
        emit agentIdentityChanged();
        return;
    }

    // chat.history 响应 → 侧栏首句预取 / 工具结果补拉 / 当前会话历史
    if (method == QLatin1String("chat.history")) {
        const QVariantList history =
            m_session.parseHistoryResponse(payload);

        const QString sidebarAgent = m_sidebarTitleHistReqAgent.take(id);
        const quint64 reqBatch = m_sidebarTitleHistReqBatch.take(id);

        if (!sidebarAgent.isEmpty()) {
            if (reqBatch == m_sidebarTitleBatchGen) {
                const QString first = firstUserMessageFromHistoryList(history);
                if (!first.isEmpty())
                    setAgentListSidebarTitle(sidebarAgent, first);
            }
            return;
        }

        // 工具结果补拉：仅原地合并 toolResult 文本，不清空聊天模型
        if (m_toolResultRefreshReqIds.remove(id)) {
            emit toolResultsRefreshed(history);
            return;
        }

        emit historyLoaded(history);
        return;
    }

    // skills.status 响应 → 委托 WsSkill 解析
    if (method == QLatin1String("skills.status")) {
        m_skill.parseSkillsStatusResponse(payload);
        emit skillListChanged();
        return;
    }

    // skills.update 响应 → 更新本地缓存并通知
    if (method == QLatin1String("skills.update")) {
        const QString key = m_skill.parseSkillUpdateResponse(payload);
        if (!key.isEmpty()) {
            emit skillListChanged();
            // 查找更新后的状态
            const QVariantList skills = m_skill.skillList();
            for (const QVariant &v : skills) {
                const QVariantMap s = v.toMap();
                if (s.value(QStringLiteral("skillKey")).toString() == key) {
                    emit skillUpdated(key,
                        s.value(QStringLiteral("enabled")).toBool());
                    break;
                }
            }
        }
        return;
    }

    // ── 定时任务相关响应 ──

    // cron.list 响应 → 委托 WsScheduledTask 解析
    if (method == QLatin1String("cron.list")) {
        m_scheduledTask.parseJobListResponse(payload);
        emit cronJobsChanged();
        return;
    }

    // cron.status 响应
    if (method == QLatin1String("cron.status")) {
        m_scheduledTask.parseCronStatusResponse(payload);
        emit cronStatusChanged();
        return;
    }

    // cron.add 响应 → 新任务入缓存
    if (method == QLatin1String("cron.add")) {
        const QString jobId = m_scheduledTask.parseJobAddResponse(payload);
        if (!jobId.isEmpty()) {
            emit cronJobsChanged();
            emit cronJobAdded(jobId);
        }
        return;
    }

    // cron.update 响应 → 更新缓存
    if (method == QLatin1String("cron.update")) {
        const QString jobId = m_scheduledTask.parseJobUpdateResponse(payload);
        if (!jobId.isEmpty()) {
            emit cronJobsChanged();
            emit cronJobUpdated(jobId);
        }
        return;
    }

    // cron.remove 响应 → 从缓存移除
    if (method == QLatin1String("cron.remove")) {
        const QString jobId = m_scheduledTask.lastOperatedJobId();
        if (m_scheduledTask.parseJobRemoveResponse(jobId, payload)) {
            emit cronJobsChanged();
            emit cronJobRemoved(jobId);
        }
        m_scheduledTask.clearLastOperatedJobId();
        return;
    }

    // cron.run 响应 → 手动触发结果
    if (method == QLatin1String("cron.run")) {
        m_scheduledTask.parseRunResponse(payload);
        const QString jobId = m_scheduledTask.lastOperatedJobId();
        if (!jobId.isEmpty())
            emit cronRunTriggered(jobId);
        m_scheduledTask.clearLastOperatedJobId();
        return;
    }

    // cron.runs 响应 → 执行记录
    if (method == QLatin1String("cron.runs")) {
        m_scheduledTask.parseRunsResponse(payload);
        emit cronRunsLoaded(m_scheduledTask.runList());
        return;
    }

    // tools.catalog → 展平工具组，并按当前 config 快照应用 tools 策略
    if (method == QLatin1String("tools.catalog")) {
        m_tools.parseToolsCatalogResponse(payload);
        if (!m_lastConfigSnapshot.isEmpty()) {
            QString aid = m_tools.catalogAgentId().trimmed();
            if (aid.isEmpty())
                aid = m_defaultAgentId;
            m_tools.applyToolPolicyFromConfig(m_lastConfigSnapshot, aid);
        }
        emit toolListChanged();
        return;
    }

    // config.get → 更新 baseHash 与 mcp.servers 列表
    if (method == QLatin1String("config.get")) {
        applyMcpListFromConfigGetPayload(payload);
        emit mcpListChanged();
        return;
    }

    // config.set → 全量写入成功（不触发重启），刷新配置快照
    if (method == QLatin1String("config.set")) {
        qDebug() << "[Gateway] config.set ok, follow-up config.get";

        // config.set 已被服务端处理完毕，deny 列表已生效，
        // 此时可以安全地发出新 agent 的首条消息
        if (!m_pendingBootstrapChatMessage.isEmpty()) {
            const QString msg = m_pendingBootstrapChatMessage;
            m_pendingBootstrapChatMessage.clear();
            sendChatMessage(msg);
        }

        refreshMcpList();
        return;
    }

    // config.patch → Gateway 可能重启，再拉一次快照以刷新 hash / 列表
    if (method == QLatin1String("config.patch")) {
        qDebug() << "[Gateway] config.patch ok, follow-up config.get";
        refreshMcpList();
        return;
    }

    // models.list 响应 → 解析可用模型列表
    if (method == QLatin1String("models.list")) {
        m_modelList.clear();

        // 支持多种 payload 格式：payload.models[] / payload 自身为数组 / payload.items[]
        QJsonArray arr = payload.value(QStringLiteral("models")).toArray();
        if (arr.isEmpty())
            arr = msg.value(QStringLiteral("payload")).toArray();
        if (arr.isEmpty())
            arr = payload.value(QStringLiteral("items")).toArray();
        if (arr.isEmpty())
            arr = payload.value(QStringLiteral("data")).toArray();

        for (const QJsonValue &v : arr) {
            const QJsonObject m = v.toObject();
            const QString id = m.value(QStringLiteral("id")).toString();
            if (id.isEmpty()) continue;

            QVariantMap entry;
            entry[QStringLiteral("id")]            = id;
            entry[QStringLiteral("name")]          = m.value(QStringLiteral("name")).toString(id);
            entry[QStringLiteral("provider")]      = m.value(QStringLiteral("provider")).toString();
            entry[QStringLiteral("contextWindow")] = m.value(QStringLiteral("contextWindow")).toInt();
            m_modelList.append(entry);
        }

        qDebug() << "[Gateway] models.list:" << m_modelList.count() << "models";
        emit modelListChanged();
        return;
    }

    // sessions.patch 响应 → 更新当前会话模型信息
    if (method == QLatin1String("sessions.patch")) {
        m_currentModel.clear();
        m_currentModel[QStringLiteral("model")]         =
            payload.value(QStringLiteral("model")).toString();
        m_currentModel[QStringLiteral("modelProvider")] =
            payload.value(QStringLiteral("modelProvider")).toString();

        qDebug() << "[Gateway] sessions.patch →"
                 << m_currentModel.value(QStringLiteral("modelProvider")).toString()
                 << "/" << m_currentModel.value(QStringLiteral("model")).toString();
        emit currentModelChanged();
        return;
    }

    // 其余 chat.send（非 /new，且前面未 return）：只更新当前 agent 侧栏首句标题
    if (method == QLatin1String("chat.send")) {
        const QString key = m_session.currentSessionKey();
        if (key.startsWith(QLatin1String("agent:"))) {
            const QStringList parts = key.split(QLatin1Char(':'));
            if (parts.size() >= 2 && !parts[1].isEmpty())
                refreshSidebarFirstUserTitleForAgent(parts[1]);
        }
        return;
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  5.5 结构化 chat 消息解析
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 解析 chat 事件中的结构化消息（含 toolCall / toolResult）
 *
 * OpenClaw 在实时会话中，chat 事件的 payload.data 可能是：
 *
 *  情况A — 助手消息（可能含工具调用）:
 *    data.message.role = "assistant"
 *    data.message.content = [{type:"text", text:"..."}, {type:"toolCall", ...}]
 *  或直接：
 *    data.role = "assistant"
 *    data.content = [...]
 *
 *  情况B — 工具结果：
 *    data.message.role = "toolResult"
 *    data.message.toolCallId / toolName / content
 *  或直接：
 *    data.role = "toolResult"
 *
 * @return true 如果检测到并处理了结构化内容（toolCall 或 toolResult）
 */
bool GatewayClient::handleStructuredChatEvent(const QJsonObject &payload)
{
    const QJsonObject data = payload.value(QStringLiteral("data")).toObject();

    QJsonObject msg = data.value(QStringLiteral("message")).toObject();
    if (msg.isEmpty()) msg = data;
    if (msg.isEmpty()) msg = payload.value(QStringLiteral("message")).toObject();
    if (msg.isEmpty()) {
        const QJsonArray messages = payload.value(QStringLiteral("messages")).toArray();
        if (!messages.isEmpty())
            msg = messages.last().toObject();
    }

    QString role = msg.value(QStringLiteral("role")).toString();
    const QString roleNorm = role.trimmed().toLower();
    if (roleNorm.isEmpty()) return false;

    // ── toolResult 消息 ──
    if (roleNorm == QLatin1String("toolresult")
        || roleNorm == QLatin1String("tool_result")) {
        const QString tcId  = msg.value(QStringLiteral("toolCallId")).toString();
        const QString tName = msg.value(QStringLiteral("toolName")).toString();
        const bool isErr    = msg.value(QStringLiteral("isError")).toBool(false);

        QString resultText;
        const QJsonValue contentVal = msg.value(QStringLiteral("content"));
        if (contentVal.isArray()) {
            const QJsonArray cArr = contentVal.toArray();
            for (const QJsonValue &cv : cArr) {
                const QJsonObject co = cv.toObject();
                if (co.value(QStringLiteral("type")).toString() == QLatin1String("text")) {
                    if (!resultText.isEmpty()) resultText += QLatin1Char('\n');
                    resultText += co.value(QStringLiteral("text")).toString();
                }
            }
        } else {
            resultText = contentVal.toString();
        }

        // content 为空时尝试 output / result 等备选字段
        if (resultText.isEmpty()) {
            const QJsonValue outVal = msg.value(QStringLiteral("output"));
            if (outVal.isString())
                resultText = outVal.toString();
            else if (outVal.isObject())
                resultText = QString::fromUtf8(
                    QJsonDocument(outVal.toObject()).toJson(QJsonDocument::Compact));
        }
        if (resultText.isEmpty()) {
            const QJsonValue resVal = msg.value(QStringLiteral("result"));
            if (resVal.isString())
                resultText = resVal.toString();
            else if (resVal.isObject())
                resultText = QString::fromUtf8(
                    QJsonDocument(resVal.toObject()).toJson(QJsonDocument::Compact));
        }

        qDebug().noquote() << "[Gateway] chat → toolResult:" << tName
                           << "error:" << isErr
                           << "len:" << resultText.length();

        if (m_session.isStreaming()) {
            m_session.setStreaming(false);
            emit streamingFinished();
        }
        emit toolResultReceived(tName, resultText, tcId, isErr);

        // 防抖补拉历史，原地合并完整 toolResult 文本
        m_toolResultRefreshTimer.start();
        return true;
    }

    // ── 检查 content 数组是否包含 toolCall ──
    const QJsonValue contentVal = msg.value(QStringLiteral("content"));
    if (!contentVal.isArray()) return false;

    const QJsonArray cArr = contentVal.toArray();
    bool hasToolCall = false;

    for (const QJsonValue &cv : cArr) {
        const QJsonObject co = cv.toObject();
        const QString ctype = co.value(QStringLiteral("type")).toString().trimmed().toLower();
        if (ctype == QLatin1String("toolcall")
            || ctype == QLatin1String("tool_call")
            || ctype == QLatin1String("tool-use")
            || ctype == QLatin1String("tool_use"))
            hasToolCall = true;
    }

    // 如果没有 toolCall，让常规流程处理（可能是纯文本 chat 事件）
    if (!hasToolCall) return false;

    // ── 有 toolCall：结束 streaming 并逐项发射信号 ──
    if (m_session.isStreaming()) {
        m_session.setStreaming(false);
        emit streamingFinished();
    }

    for (const QJsonValue &cv : cArr) {
        const QJsonObject co = cv.toObject();
        const QString ctype = co.value(QStringLiteral("type")).toString().trimmed().toLower();

        if (ctype == QLatin1String("toolcall")
            || ctype == QLatin1String("tool_call")
            || ctype == QLatin1String("tool-use")
            || ctype == QLatin1String("tool_use")) {
            const QString tcId  = co.value(QStringLiteral("id")).toString();
            const QString tName = co.value(QStringLiteral("name")).toString();
            QJsonObject args = co.value(QStringLiteral("arguments")).toObject();
            QString argsStr;
            if (!args.isEmpty()) {
                argsStr = QString::fromUtf8(
                    QJsonDocument(args).toJson(QJsonDocument::Compact));
            } else if (co.value(QStringLiteral("arguments")).isString()) {
                argsStr = co.value(QStringLiteral("arguments")).toString();
            }
            if (argsStr.length() > 1000)
                argsStr = argsStr.left(1000) + QStringLiteral("...");

            qDebug().noquote() << "[Gateway] chat → toolCall:" << tName
                               << "id:" << tcId;
            emit toolCallReceived(tName, argsStr, tcId);
        }
        // text 条目不在这里重复发射，因为流式 delta 已经推送过了
    }

    return true;
}

// ═══════════════════════════════════════════════════════════════════════
//  6. 出站请求发送
// ═══════════════════════════════════════════════════════════════════════

QString GatewayClient::nextRequestId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

/**
 * @brief 统一的 RPC 请求发送接口
 *
 * 帧格式：
 *   {
 *     "type": "req",
 *     "id": "<uuid>",
 *     "method": "<rpc-method>",
 *     "params": { ... }
 *   }
 */
QString GatewayClient::sendRequest(const QString &method,
                                    const QJsonObject &params)
{
    const QString reqId = nextRequestId();

    // 记录到 pending 映射，响应到达时通过 id 回查方法名
    m_pendingRequests.insert(reqId, method);

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = reqId;
    request[QStringLiteral("method")] = method;
    request[QStringLiteral("params")] = params;

    // 为了调试方便，使用缩进格式打印
    const QByteArray debugJson =
        QJsonDocument(request).toJson(QJsonDocument::Indented);
    qDebug().noquote() << "=== 发送请求 (" << method << ") ===";
    qDebug().noquote() << QString::fromUtf8(debugJson);

    // 发送时使用压缩格式以节省带宽
    const QByteArray json =
        QJsonDocument(request).toJson(QJsonDocument::Compact);
    m_socket->sendTextMessage(QString::fromUtf8(json));

    return reqId;
}

// ═══════════════════════════════════════════════════════════════════════
//  7. 业务方法（QML 调用入口）
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 加载当前会话的历史消息
 *
 * 前置条件：已连接（Connected）。
 * 请求参数由 WsSession::buildLoadHistoryParams() 构建。
 */
void GatewayClient::loadHistory()
{
    if (m_state != Connected) return;
    if (m_session.currentSessionKey().trimmed().isEmpty())
        return;
    sendRequest(QStringLiteral("messages.list"),
                m_session.buildLoadHistoryParams());
}

/**
 * @brief 刷新会话列表
 *
 * 前置条件：已连接。
 */
void GatewayClient::refreshSessions()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("sessions.list"),
                m_session.buildListSessionsParams());
}

/**
 * @brief 创建新会话（/new 命令）
 *
 * 向当前 sessionKey 发送 message="/new" 的 chat.send 请求。
 * 响应到达后自动刷新会话列表并发射 sessionCreated 信号。
 */
void GatewayClient::createNewSession()
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    if (m_session.currentSessionKey().trimmed().isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u8bf7\u5148\u5728\u4efb\u52a1\u8bb0\u5f55\u4e2d\u9009\u62e9 Agent"));
        return;
    }
    const QString reqId = sendRequest(
        QStringLiteral("chat.send"), m_session.buildNewSessionParams());
    m_session.setNewSessionReqId(reqId);
}

/**
 * @brief 删除指定会话
 * @param sessionKey 要删除的会话 key
 */
void GatewayClient::deleteSession(const QString &sessionKey)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    sendRequest(QStringLiteral("session.delete"),
                m_session.buildDeleteSessionParams(sessionKey));
}

// ═══════════════════════════════════════════════════════════════════════
//  7. 技能管理
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 获取所有 Agent 列表
 *
 * 发送 agents.list RPC，响应在 handleResponse() 中解析。
 * 连接成功后自动调用一次。
 */
void GatewayClient::refreshAgents()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("agents.list"), QJsonObject());
}

/**
 * @brief 创建新 Agent（agents.create RPC）
 *
 * params: { name, workspace, emoji?, avatar? }
 * 服务端 normalizeAgentId(name) 生成 agentId
 */
void GatewayClient::createAgent(const QString &name,
                                 const QString &workspace,
                                 bool applyPendingToolSelection)
{
    if (!applyPendingToolSelection) {
        m_pendingNewAgentToolPolicySet = false;
        m_pendingNewAgentEnabledToolIds.clear();
    }
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5"));
        return;
    }
    if (name.trimmed().isEmpty()) {
        emit agentCreated(name, false,
            QStringLiteral("name \u4e0d\u80fd\u4e3a\u7a7a"), false);
        return;
    }

    m_pendingCreateName = name;

    QString ws = workspace.trimmed();
    if (ws.isEmpty()) {
        ws = QStringLiteral("~/.openclaw/workspace-%1").arg(name.trimmed().toLower());
    }
    m_pendingCreateWorkspace = ws;

    QJsonObject params;
    params[QStringLiteral("name")]      = name.trimmed();
    params[QStringLiteral("workspace")] = ws;

    qDebug().noquote() << "[Gateway] agents.create:" << name
                       << "workspace:" << ws;
    sendRequest(QStringLiteral("agents.create"), params);
}

void GatewayClient::setPendingNewAgentToolSelection(const QVariantList &enabledToolIds)
{
    m_pendingNewAgentEnabledToolIds.clear();
    m_pendingNewAgentToolPolicySet = true;
    for (const QVariant &v : enabledToolIds) {
        const QString tid = v.toString().trimmed();
        if (!tid.isEmpty())
            m_pendingNewAgentEnabledToolIds.append(tid);
    }
}

/**
 * @brief 删除 Agent（agents.delete RPC）
 *
 * params: { agentId, deleteFiles? }
 * "main" 不可删除（服务端会拒绝）
 */
void GatewayClient::deleteAgent(const QString &agentId, bool deleteFiles)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5"));
        return;
    }
    if (agentId.trimmed().isEmpty()) {
        emit agentDeleted(agentId, false,
            QStringLiteral("agentId \u4e0d\u80fd\u4e3a\u7a7a"));
        return;
    }

    m_pendingDeleteId = agentId;

    QJsonObject params;
    params[QStringLiteral("agentId")]    = agentId.trimmed();
    params[QStringLiteral("deleteFiles")] = deleteFiles;

    qDebug().noquote() << "[Gateway] agents.delete:" << agentId
                       << "deleteFiles:" << deleteFiles;
    sendRequest(QStringLiteral("agents.delete"), params);
}

/**
 * @brief 获取所有技能状态
 *
 * 发送 skills.status RPC，响应在 handleResponse() 中由 WsSkill 解析。
 */
void GatewayClient::refreshSkills()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("skills.status"),
                m_skill.buildSkillsStatusParams());
}

/**
 * @brief 启用或禁用指定技能
 * @param skillKey 技能标识
 * @param enabled  true=启用, false=禁用
 */
void GatewayClient::setSkillEnabled(const QString &skillKey, bool enabled)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    sendRequest(QStringLiteral("skills.update"),
                m_skill.buildSkillUpdateParams(skillKey, enabled));
}

QString GatewayClient::expandTildePath(const QString &path)
{
    QString p = path.trimmed();
    if (p.startsWith(QLatin1String("~/")))
        return QDir::homePath() + QLatin1Char('/') + p.mid(2);
    if (p == QLatin1String("~"))
        return QDir::homePath();
    return p;
}

bool GatewayClient::copyDirectoryRecursive(const QString &srcDir, const QString &dstDir)
{
    QDir src(srcDir);
    if (!src.exists())
        return false;
    if (!QDir().mkpath(dstDir))
        return false;
    const QFileInfoList list =
        src.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : list) {
        const QString dstPath = dstDir + QLatin1Char('/') + fi.fileName();
        if (fi.isDir()) {
            if (!copyDirectoryRecursive(fi.absoluteFilePath(), dstPath))
                return false;
        } else {
            if (QFile::exists(dstPath) && !QFile::remove(dstPath))
                return false;
            if (!QFile::copy(fi.absoluteFilePath(), dstPath))
                return false;
        }
    }
    return true;
}

void GatewayClient::addSkillFromZip(const QString &zipPathRaw)
{
    const QString zipNative = QDir::fromNativeSeparators(zipPathRaw.trimmed());
    QFileInfo zipInfo(zipNative);
    if (!zipInfo.exists() || !zipInfo.isFile()) {
        emit errorOccurred(QStringLiteral(
            "ZIP \u6587\u4ef6\u65e0\u6548\u6216\u4e0d\u5b58\u5728"));
        return;
    }
    if (zipInfo.suffix().compare(QStringLiteral("zip"), Qt::CaseInsensitive) != 0) {
        emit errorOccurred(QStringLiteral(
            "\u8bf7\u9009\u62e9 .zip \u6587\u4ef6"));
        return;
    }

    const QString dstRoot = expandTildePath(m_config.skillsStoragePath()).trimmed();
    if (dstRoot.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u672a\u914d\u7f6e\u6280\u80fd\u5b58\u653e\u8def\u5f84"));
        return;
    }
    if (!QDir().mkpath(dstRoot)) {
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u521b\u5efa\u6280\u80fd\u5b58\u653e\u76ee\u5f55"));
        return;
    }

    const QString zipName = zipInfo.fileName();
    const QString destZip = QDir(dstRoot).filePath(zipName);
    if (QFile::exists(destZip)) {
        if (!QFile::remove(destZip)) {
            emit errorOccurred(QStringLiteral(
                "\u65e0\u6cd5\u8986\u76d6\u5df2\u5b58\u5728\u7684 ZIP"));
            return;
        }
    }
    if (!QFile::copy(zipInfo.absoluteFilePath(), destZip)) {
        emit errorOccurred(QStringLiteral(
            "\u590d\u5236 ZIP \u5230\u6280\u80fd\u76ee\u5f55\u5931\u8d25"));
        return;
    }

    const QString extractDir = QDir(dstRoot).filePath(zipInfo.completeBaseName());
    if (QDir(extractDir).exists()) {
        if (!QDir(extractDir).removeRecursively()) {
            QFile::remove(destZip);
            emit errorOccurred(QStringLiteral(
                "\u65e0\u6cd5\u6e05\u7a7a\u76ee\u6807\u89e3\u538b\u76ee\u5f55"));
            return;
        }
    }
    if (!QDir().mkpath(extractDir)) {
        QFile::remove(destZip);
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u521b\u5efa\u89e3\u538b\u76ee\u5f55"));
        return;
    }

    auto *proc = new QProcess(this);
    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                       this, [this, proc, destZip, extractDir](int exitCode,
                                                                QProcess::ExitStatus exitStatus) {
                           const QByteArray errBytes = proc->readAllStandardError();
                           const QByteArray outBytes = proc->readAllStandardOutput();
                           proc->deleteLater();
                           const QString msg =
                               QString::fromUtf8(errBytes + outBytes).trimmed();
                           if (exitCode != 0 || exitStatus != QProcess::NormalExit) {
                               QFile::remove(destZip);
                               QDir(extractDir).removeRecursively();
                               emit errorOccurred(msg.isEmpty()
                                                      ? QStringLiteral(
                                                            "\u89e3\u538b\u5931\u8d25")
                                                      : msg);
                               return;
                           }
                           refreshSkillMarketFolders();
                           if (m_state == Connected)
                               refreshSkills();
                       });

#ifdef Q_OS_WIN
    const QString ps =
        QStringLiteral("Expand-Archive -LiteralPath '%1' -DestinationPath '%2' -Force")
            .arg(escapePowerShellSingleQuoted(QDir::toNativeSeparators(destZip)),
                 escapePowerShellSingleQuoted(QDir::toNativeSeparators(extractDir)));
    proc->start(QStringLiteral("powershell"),
                  QStringList() << QStringLiteral("-NoProfile") << QStringLiteral("-NonInteractive")
                                << QStringLiteral("-Command") << ps);
#else
    proc->start(QStringLiteral("tar"),
                QStringList() << QStringLiteral("-xf") << destZip << QStringLiteral("-C")
                              << extractDir);
#endif
    if (!proc->waitForStarted(5000)) {
        proc->deleteLater();
        QFile::remove(destZip);
        QDir(extractDir).removeRecursively();
        emit errorOccurred(QStringLiteral("\u65e0\u6cd5\u542f\u52a8"));
    }
}

void GatewayClient::addSkillFromFolder(const QString &folderPathRaw)
{
    const QString src = QDir::fromNativeSeparators(folderPathRaw.trimmed());
    if (src.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u6587\u4ef6\u5939\u8def\u5f84\u65e0\u6548"));
        return;
    }
    const QFileInfo srcFi(src);
    if (!srcFi.exists() || !srcFi.isDir()) {
        emit errorOccurred(QStringLiteral(
            "\u6587\u4ef6\u5939\u4e0d\u5b58\u5728"));
        return;
    }
    const QString name = srcFi.fileName();
    if (name.isEmpty() || name == QLatin1String(".") || name == QLatin1String("..")) {
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6548\u7684\u6587\u4ef6\u5939\u540d"));
        return;
    }

    const QString dstRoot = expandTildePath(m_config.skillsStoragePath()).trimmed();
    if (dstRoot.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u672a\u914d\u7f6e\u6280\u80fd\u5b58\u653e\u8def\u5f84"));
        return;
    }
    if (!QDir().mkpath(dstRoot)) {
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u521b\u5efa\u6280\u80fd\u5b58\u653e\u76ee\u5f55"));
        return;
    }

    const QString dst = QDir(dstRoot).filePath(name);
    if (QDir(dst).exists()) {
        if (!QDir(dst).removeRecursively()) {
            emit errorOccurred(QStringLiteral(
                "\u65e0\u6cd5\u6e05\u7a7a\u76ee\u6807\u76ee\u5f55"));
            return;
        }
    }

    if (!copyDirectoryRecursive(srcFi.absoluteFilePath(), dst)) {
        emit errorOccurred(QStringLiteral(
            "\u590d\u5236\u6587\u4ef6\u5939\u5931\u8d25"));
        return;
    }
    refreshSkillMarketFolders();
    if (m_state == Connected)
        refreshSkills();
}

void GatewayClient::addSkillFromGit(const QString &urlRaw)
{
    const QString url = normalizeGitCloneUrl(urlRaw);
    if (url.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u8bf7\u8f93\u5165\u6709\u6548\u7684\u4ed3\u5e93\u5730\u5740"));
        return;
    }

    const QString dstRoot = expandTildePath(m_config.skillsStoragePath()).trimmed();
    if (dstRoot.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u672a\u914d\u7f6e\u6280\u80fd\u5b58\u653e\u8def\u5f84"));
        return;
    }
    if (!QDir().mkpath(dstRoot)) {
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u521b\u5efa\u6280\u80fd\u5b58\u653e\u76ee\u5f55"));
        return;
    }

    auto *proc = new QProcess(this);
    QObject::connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                       this, [this, proc](int exitCode, QProcess::ExitStatus exitStatus) {
                           const QByteArray errBytes = proc->readAllStandardError();
                           const QByteArray outBytes = proc->readAllStandardOutput();
                           proc->deleteLater();
                           if (exitCode != 0 || exitStatus != QProcess::NormalExit) {
                               const QString msg =
                                   QString::fromUtf8(errBytes + outBytes).trimmed();
                               emit errorOccurred(msg.isEmpty()
                                                      ? QStringLiteral("git clone \u5931\u8d25")
                                                      : msg);
                               return;
                           }
                           refreshSkillMarketFolders();
                           if (m_state == Connected)
                               refreshSkills();
                       });

    proc->setProgram(QStringLiteral("git"));
    proc->setArguments(QStringList() << QStringLiteral("clone") << url);
    proc->setWorkingDirectory(dstRoot);
    proc->start();
    if (!proc->waitForStarted(5000)) {
        proc->deleteLater();
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u542f\u52a8 git\uff0c\u8bf7\u786e\u8ba4\u5df2\u5b89\u88c5 Git \u5e76\u5728 PATH \u4e2d"));
    }
}

void GatewayClient::refreshSkillMarketFolders()
{
    m_skillMarketFolders.clear();
    const QString base = expandTildePath(m_config.skillMarketPath()).trimmed();
    const QString storage = expandTildePath(m_config.skillsStoragePath()).trimmed();
    if (base.isEmpty()) {
        emit skillMarketFoldersChanged();
        return;
    }
    QDir dir(base);
    if (!dir.exists()) {
        emit skillMarketFoldersChanged();
        return;
    }
    const QFileInfoList list = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : list) {
        if (!fi.isDir())
            continue;
        const QString name = fi.fileName();
        QVariantMap m;
        m[QStringLiteral("folderName")] = name;
        m[QStringLiteral("installed")] = QDir(storage + QLatin1Char('/') + name).exists();
        m_skillMarketFolders.append(m);
    }
    emit skillMarketFoldersChanged();
}

void GatewayClient::installSkillFromMarket(const QString &folderName)
{
    const QString name = folderName.trimmed();
    if (name.isEmpty())
        return;
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    if (m_skillInstallBusy)
        return;
    const QString srcRoot = expandTildePath(m_config.skillMarketPath());
    const QString dstRoot = expandTildePath(m_config.skillsStoragePath());
    const QString src = srcRoot + QLatin1Char('/') + name;
    const QString dst = dstRoot + QLatin1Char('/') + name;
    if (!QDir(src).exists()) {
        emit errorOccurred(QStringLiteral(
            "\u6280\u80fd\u6587\u4ef6\u5939\u4e0d\u5b58\u5728"));
        return;
    }
    QDir().mkpath(dstRoot);
    if (QDir(dst).exists()) {
        if (!QDir(dst).removeRecursively()) {
            emit errorOccurred(QStringLiteral(
                "\u65e0\u6cd5\u6e05\u9664\u76ee\u6807\u76ee\u5f55"));
            return;
        }
    }
    m_skillInstallBusy = true;
    emit skillInstallBusyChanged();
    if (!copyDirectoryRecursive(src, dst)) {
        m_skillInstallBusy = false;
        emit skillInstallBusyChanged();
        emit errorOccurred(QStringLiteral(
            "\u590d\u5236\u6280\u80fd\u6587\u4ef6\u5931\u8d25"));
        return;
    }
    m_skillInstallBusy = false;
    emit skillInstallBusyChanged();
    refreshSkillMarketFolders();
    refreshSkills();
}

// ═══════════════════════════════════════════════════════════════════════
//  8. 模型管理
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 获取可用模型列表
 *
 * 发送 models.list RPC，响应在 handleResponse() 中解析。
 * 连接成功后自动调用一次。
 */
void GatewayClient::refreshModels()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("models.list"), QJsonObject());
}

/**
 * @brief 查询或设置当前会话的模型
 *
 * sessions.patch RPC：
 *   - modelId 为空 → params.model = null → 查询当前模型
 *   - modelId 非空 → params.model = "model-id" → 切换到指定模型
 * 两种情况的响应都包含 modelProvider / model 字段。
 */
void GatewayClient::patchSessionModel(const QString &modelId)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5"));
        return;
    }
    if (m_session.currentSessionKey().trimmed().isEmpty()) {
        if (!modelId.isEmpty()) {
            if (m_pendingSessionModelId != modelId) {
                m_pendingSessionModelId = modelId;
                emit pendingSessionModelIdChanged();
            }
            qDebug().noquote() << "[Gateway] patchSessionModel deferred (no session), pending:"
                               << modelId;
        }
        return;
    }

    QJsonObject params;
    params[QStringLiteral("key")] = m_session.currentSessionKey();

    if (modelId.isEmpty()) {
        params[QStringLiteral("model")] = QJsonValue();
    } else {
        params[QStringLiteral("model")] = modelId;
    }

    qDebug().noquote() << "[Gateway] sessions.patch model:"
                       << (modelId.isEmpty() ? "null (query)" : modelId)
                       << "session:" << m_session.currentSessionKey();
    sendRequest(QStringLiteral("sessions.patch"), params);

    if (!modelId.isEmpty() && !m_pendingSessionModelId.isEmpty()) {
        m_pendingSessionModelId.clear();
        emit pendingSessionModelIdChanged();
    }
}

// ═══════════════════════════════════════════════════════════════════════
//  9. Agent 切换
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 切换 Agent
 *
 * 依次发送三个 RPC：
 *   1. agent.identity.get  → 获取 agent 身份信息
 *   2. chat.history        → 获取聊天历史
 *   3. sessions.list       → 刷新会话列表
 */
void GatewayClient::switchAgent(const QString &agentId)
{
    applyAgentSwitch(agentId, true);
}

void GatewayClient::applyAgentSwitch(const QString &agentId, bool shouldLoadHistory)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    if (agentId.trimmed().isEmpty()) {
        clearActiveAgentContext();
        return;
    }

    if (agentId.trimmed() != m_expectingToolPolicyApplyForAgentId) {
        m_pendingNewAgentToolPolicySet = false;
        m_pendingNewAgentEnabledToolIds.clear();
    }

    // 切换会话时取消未完成的工具结果补拉
    m_toolResultRefreshTimer.stop();
    m_toolResultRefreshReqIds.clear();

    const QString sessionKey = resolveChatSessionKeyForAgentId(agentId.trimmed());

    qDebug().noquote() << "[Gateway] switchAgent:" << agentId
                       << "sessionKey:" << sessionKey
                       << "loadHistory:" << shouldLoadHistory;

    m_session.setCurrentSessionKey(sessionKey);
    emit currentSessionChanged();

    getAgentIdentity(sessionKey);
    if (shouldLoadHistory)
        loadChatHistory(sessionKey);
    refreshSessions();
    if (!m_pendingSessionModelId.isEmpty())
        patchSessionModel(m_pendingSessionModelId);
    else
        patchSessionModel(QString());
    refreshToolsCatalog(agentId.trimmed());
}

/**
 * @brief 获取 agent 身份信息
 */
void GatewayClient::getAgentIdentity(const QString &sessionKey)
{
    if (m_state != Connected) return;
    const QString key = sessionKey.isEmpty()
        ? m_session.currentSessionKey() : sessionKey;
    if (key.trimmed().isEmpty())
        return;
    sendRequest(QStringLiteral("agent.identity.get"),
                m_session.buildAgentIdentityParams(key));
}

/**
 * @brief 加载指定会话的聊天历史
 */
void GatewayClient::loadChatHistory(const QString &sessionKey, int limit)
{
    if (m_state != Connected) return;
    const QString key = sessionKey.isEmpty()
        ? m_session.currentSessionKey() : sessionKey;
    if (key.trimmed().isEmpty())
        return;
    sendRequest(QStringLiteral("chat.history"),
                m_session.buildChatHistoryParams(key, limit));
}

/**
 * @brief 发送聊天消息
 * @param message    用户输入的消息文本
 * @param sessionKey 目标会话 key（空则使用当前会话）
 * @param workspaceForNewAgent 首条消息创建 agent 时传入的 workspace
 *
 * 消息发送后，服务器会通过 event 帧推送 agent 的流式回复，
 * 由 handleEvent() → WsSession::parseEvent() 链路处理。
 */
void GatewayClient::sendChatMessage(const QString &message,
                                     const QString &sessionKey,
                                     const QString &workspaceForNewAgent)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString trimmed = message.trimmed();
    if (trimmed.isEmpty())
        return;

    if (m_pendingAgentCreateForChat) {
        emit errorOccurred(QStringLiteral(
            "\u6b63\u5728\u521b\u5efa\u65b0\u667a\u80fd\u4f53\uff0c\u8bf7\u7a0d\u5019"));
        return;
    }

    const QString explicitKey = sessionKey.trimmed();
    const QString activeKey = explicitKey.isEmpty()
        ? m_session.currentSessionKey().trimmed() : explicitKey;

    if (activeKey.isEmpty()) {
        m_pendingFirstChatMessage = trimmed;
        m_pendingAgentCreateForChat = true;
        const QString autoName = QStringLiteral("task-%1")
            .arg(QDateTime::currentMSecsSinceEpoch());
        createAgent(autoName, workspaceForNewAgent, true);
        return;
    }

    sendRequest(QStringLiteral("chat.send"),
                m_session.buildChatSendParams(message, sessionKey));
}

// ═══════════════════════════════════════════════════════════════════════
//  8. 定时任务管理（QML 调用入口）
// ═══════════════════════════════════════════════════════════════════════

/**
 * @brief 刷新定时任务列表
 * @param includeDisabled 是否包含已禁用的任务
 *
 * 发送 cron.list RPC，响应在 handleResponse() 中由 WsScheduledTask 解析。
 */
void GatewayClient::refreshCronJobs(bool includeDisabled)
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("cron.list"),
                m_scheduledTask.buildListParams(includeDisabled));
}

/**
 * @brief 获取 cron 服务状态
 *
 * 发送 cron.status RPC，响应在 handleResponse() 中解析。
 */
void GatewayClient::refreshCronStatus()
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("cron.status"),
                m_scheduledTask.buildStatusParams());
}

/**
 * @brief 添加 cron 表达式定时任务
 * @param name      任务名称（如 "每日晨报"）
 * @param cronExpr  cron 表达式（如 "0 9 * * *" 表示每天 9 点）
 * @param message   触发时发送给 agent 的消息
 * @param tz        时区（默认 Asia/Shanghai）
 *
 * 常用 cron 表达式示例：
 *   "0 9 * * *"     每天 9:00
 *   "0 9 * * 1-5"   周一至周五 9:00
 *   "30 8,12 * * *"  每天 8:30 和 12:30
 *   "0 * /6 * * *"   每 6 小时
 */
void GatewayClient::addCronJob(const QString &name,
                                const QString &cronExpr,
                                const QString &message,
                                const QString &tz)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString agentName = cronDedicatedAgentDisplayName(name);
    createAgent(agentName, QString(), false);
    prepareCronJobWithDedicatedAgent(
        1, name, message, cronExpr,
        tz.isEmpty() ? QStringLiteral("Asia/Shanghai") : tz, 0, QString());
}

/**
 * @brief 添加固定间隔定时任务
 * @param name        任务名称
 * @param intervalSec 执行间隔（秒），内部转换为毫秒
 * @param message     触发时发送给 agent 的消息
 */
void GatewayClient::addIntervalJob(const QString &name,
                                    int intervalSec,
                                    const QString &message)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    if (intervalSec <= 0) {
        emit errorOccurred(
            QStringLiteral("\u95f4\u9694\u5fc5\u987b\u5927\u4e8e 0 \u79d2"));
        return;
    }
    const QString agentName = cronDedicatedAgentDisplayName(name);
    createAgent(agentName, QString(), false);
    prepareCronJobWithDedicatedAgent(2, name, message, QString(), QString(),
                                     intervalSec, QString());
}

/**
 * @brief 添加一次性定时任务
 * @param name     任务名称
 * @param dateTime 执行时间（ISO 8601 格式，如 "2026-03-20T09:00:00"）
 * @param message  触发时发送给 agent 的消息
 *
 * 任务执行后自动删除。
 */
void GatewayClient::addOneTimeJob(const QString &name,
                                   const QString &dateTime,
                                   const QString &message)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QDateTime at = QDateTime::fromString(dateTime, Qt::ISODate);
    if (!at.isValid()) {
        emit errorOccurred(
            QStringLiteral("\u65e0\u6548\u7684\u65f6\u95f4\u683c\u5f0f: %1").arg(dateTime));
        return;
    }
    const QString agentName = cronDedicatedAgentDisplayName(name);
    createAgent(agentName, QString(), false);
    prepareCronJobWithDedicatedAgent(3, name, message, QString(), QString(), 0,
                                     dateTime);
}

/**
 * @brief 启用或禁用定时任务
 * @param jobId   任务 ID
 * @param enabled true=启用, false=禁用
 */
void GatewayClient::setCronJobEnabled(const QString &jobId, bool enabled)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    sendRequest(QStringLiteral("cron.update"),
                m_scheduledTask.buildToggleEnabledParams(jobId, enabled));
}

/**
 * @brief 删除定时任务
 * @param jobId 要删除的任务 ID
 */
void GatewayClient::removeCronJob(const QString &jobId)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    m_scheduledTask.setLastOperatedJobId(jobId);
    sendRequest(QStringLiteral("cron.remove"),
                m_scheduledTask.buildRemoveParams(jobId));
}

/**
 * @brief 手动触发定时任务立即执行一次
 * @param jobId 任务 ID
 *
 * 使用 force 模式，忽略调度时间限制。
 */
void GatewayClient::runCronJobNow(const QString &jobId)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    m_scheduledTask.setLastOperatedJobId(jobId);
    sendRequest(QStringLiteral("cron.run"),
                m_scheduledTask.buildRunParams(jobId, QStringLiteral("force")));
}

void GatewayClient::updateCronJobContent(const QString &jobId,
                                         const QString &name,
                                         const QString &content,
                                         const QString &payloadKind,
                                         int scheduleKind,
                                         const QString &scheduleExpr,
                                         const QString &scheduleTz)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString jid = jobId.trimmed();
    if (jid.isEmpty()) {
        emit errorOccurred(QStringLiteral("jobId \u4e0d\u80fd\u4e3a\u7a7a"));
        return;
    }

    QJsonObject patch;
    if (!name.trimmed().isEmpty())
        patch[QStringLiteral("name")] = name.trimmed();

    QJsonObject payloadPatch;
    const QString pk = payloadKind.trimmed().toLower();
    if (pk == QLatin1String("systemevent")
        || pk == QLatin1String("system_event")) {
        payloadPatch[QStringLiteral("kind")] = QStringLiteral("systemEvent");
        payloadPatch[QStringLiteral("text")] = content;
    } else {
        payloadPatch[QStringLiteral("kind")] = QStringLiteral("agentTurn");
        payloadPatch[QStringLiteral("message")] = content;
    }
    patch[QStringLiteral("payload")] = payloadPatch;

    if (scheduleKind > 0 && !scheduleExpr.trimmed().isEmpty()) {
        QJsonObject sched;
        switch (scheduleKind) {
        case 1: {
            sched[QStringLiteral("kind")] = QStringLiteral("cron");
            sched[QStringLiteral("expr")] = scheduleExpr.trimmed();
            const QString tz = scheduleTz.trimmed().isEmpty()
                ? QStringLiteral("Asia/Shanghai") : scheduleTz.trimmed();
            sched[QStringLiteral("tz")] = tz;
            break;
        }
        case 2: {
            bool ok = false;
            const int ms = scheduleExpr.trimmed().toInt(&ok);
            if (ok && ms > 0) {
                sched[QStringLiteral("kind")] = QStringLiteral("every");
                sched[QStringLiteral("everyMs")] = ms;
            }
            break;
        }
        case 3: {
            sched[QStringLiteral("kind")] = QStringLiteral("at");
            sched[QStringLiteral("at")] = scheduleExpr.trimmed();
            break;
        }
        default:
            break;
        }
        if (!sched.isEmpty())
            patch[QStringLiteral("schedule")] = sched;
    }

    sendRequest(QStringLiteral("cron.update"),
                m_scheduledTask.buildUpdateParams(jid, patch));
}

/**
 * @brief 查询定时任务的执行记录
 * @param jobId 任务 ID（空则查询所有任务的记录）
 */
void GatewayClient::loadCronRuns(const QString &jobId)
{
    if (m_state != Connected) return;
    sendRequest(QStringLiteral("cron.runs"),
                m_scheduledTask.buildRunsParams(jobId));
}

void GatewayClient::rebuildMcpListFromConfigObject(const QJsonObject &config)
{
    m_mcpList.clear();
    const QJsonObject mcp = config.value(QStringLiteral("mcp")).toObject();
    const QJsonObject servers = mcp.value(QStringLiteral("servers")).toObject();
    QStringList keys;
    for (auto it = servers.begin(); it != servers.end(); ++it)
        keys.append(it.key());
    std::sort(keys.begin(), keys.end());
    for (const QString &key : keys) {
        if (key.isEmpty())
            continue;
        const QJsonObject s = servers.value(key).toObject();
        QVariantMap e;
        e[QStringLiteral("name")] = key;
        e[QStringLiteral("title")] = key;
        const QString url = s.value(QStringLiteral("url")).toString().trimmed();
        const QString cmd = s.value(QStringLiteral("command")).toString();
        const bool isHttp = !url.isEmpty();
        e[QStringLiteral("transportHttp")] = isHttp;
        e[QStringLiteral("url")] = url;
        e[QStringLiteral("command")] = cmd;
        QString desc = s.value(QStringLiteral("description")).toString();
        QStringList argLines;
        const QJsonArray args = s.value(QStringLiteral("args")).toArray();
        for (const QJsonValue &v : args)
            argLines.append(v.toString());
        e[QStringLiteral("argsText")] = argLines.join(QLatin1Char('\n'));

        // env → QVariantMap，供 QML 编辑预填
        const QJsonObject envObj = s.value(QStringLiteral("env")).toObject();
        QVariantMap envMap;
        for (auto eit = envObj.begin(); eit != envObj.end(); ++eit)
            envMap.insert(eit.key(), eit.value().toVariant());
        e[QStringLiteral("env")] = envMap;

        e[QStringLiteral("description")] = desc;
        if (desc.isEmpty()) {
            if (isHttp)
                desc = url;
            else {
                QStringList parts;
                if (!cmd.isEmpty())
                    parts.append(cmd);
                for (const QString &a : argLines) {
                    if (!a.isEmpty())
                        parts.append(a);
                }
                desc = parts.join(QLatin1Char(' '));
            }
        }
        e[QStringLiteral("desc")] = desc;
        e[QStringLiteral("icon")] = QStringLiteral("qrc:/images/skillIcon.png");
        m_mcpList.append(e);
    }
}

void GatewayClient::applyMcpListFromConfigGetPayload(const QJsonObject &payload)
{
    const QString h = payload.value(QStringLiteral("hash")).toString().trimmed();
    if (!h.isEmpty())
        m_configSnapshotHash = h;

    QJsonObject cfgRoot = payload.value(QStringLiteral("config")).toObject();
    if (cfgRoot.isEmpty())
        cfgRoot = payload.value(QStringLiteral("resolved")).toObject();
    if (cfgRoot.isEmpty()) {
        const QJsonValue parsed = payload.value(QStringLiteral("parsed"));
        if (parsed.isObject())
            cfgRoot = parsed.toObject();
    }
    m_lastConfigSnapshot = cfgRoot;

    rebuildMcpListFromConfigObject(m_lastConfigSnapshot);
    rebuildAgentWorkspaceMapFromConfigObject(m_lastConfigSnapshot);
    mergeWorkspaceIntoAgentIdentity();
    parseSettingsFromConfig();

    QString toolPolicyAgentId;
    if (!m_pendingProfileFullAgentId.isEmpty()) {
        const QString aid = m_pendingProfileFullAgentId;
        m_pendingProfileFullAgentId.clear();

        QStringList enabledIds;
        if (m_pendingNewAgentToolPolicySet) {
            enabledIds = m_pendingNewAgentEnabledToolIds;
            m_pendingNewAgentToolPolicySet = false;
            m_pendingNewAgentEnabledToolIds.clear();
        } else {
            for (const QVariant &tv : m_tools.toolList()) {
                const QString tid =
                    tv.toMap().value(QStringLiteral("toolId")).toString().trimmed();
                if (!tid.isEmpty())
                    enabledIds.append(tid);
            }
        }

        QJsonObject cfg = m_lastConfigSnapshot;
        cfg = m_tools.buildFullConfigWithBatchToolPolicy(cfg, aid, enabledIds);
        if (!cfg.isEmpty()) {
            m_lastConfigSnapshot = cfg;
            const QByteArray cfgJson = QJsonDocument(cfg).toJson(QJsonDocument::Compact);
            QJsonObject reqParams;
            reqParams[QStringLiteral("raw")] = QString::fromUtf8(cfgJson);
            if (!m_configSnapshotHash.isEmpty())
                reqParams[QStringLiteral("baseHash")] = m_configSnapshotHash;
            sendRequest(QStringLiteral("config.set"), reqParams);
            m_tools.batchSetLocalToolEnabled(enabledIds);
            toolPolicyAgentId = aid;
            qDebug() << "[Gateway] set tools.profile=full + deny for new agent" << aid
                     << "enabledCount=" << enabledIds.size();
        } else {
            qWarning() << "[Gateway] buildFullConfigWithBatchToolPolicy failed for new agent" << aid;
        }
        m_expectingToolPolicyApplyForAgentId.clear();
    }

    if (!m_tools.toolList().isEmpty()) {
        QString aid = toolPolicyAgentId.trimmed();
        if (aid.isEmpty()) {
            aid = m_tools.catalogAgentId().trimmed();
            if (aid.isEmpty())
                aid = m_defaultAgentId;
        }
        qDebug() << "[ConfigGet→ToolPolicy] applying policy for agent=" << aid
                 << "snapshotHash=" << m_configSnapshotHash;
        m_tools.applyToolPolicyFromConfig(m_lastConfigSnapshot, aid);
        emit toolListChanged();
    }

    // 如果刚才为新 agent 发送了 config.set（deny 列表），
    // 则 chat.send 必须延迟到 config.set 响应确认后再发，
    // 否则 gateway 可能并发处理导致 deny 未生效。
    // 仅在没有发出 config.set 的路径下直接发送。
    if (!toolPolicyAgentId.isEmpty()) {
        // config.set 已发出，m_pendingBootstrapChatMessage 保留不动，
        // 等 config.set 响应到达后再发送（见 config.set 响应处理分支）
    } else if (!m_pendingBootstrapChatMessage.isEmpty()) {
        const QString msg = m_pendingBootstrapChatMessage;
        m_pendingBootstrapChatMessage.clear();
        sendChatMessage(msg);
    }
}

void GatewayClient::rebuildAgentWorkspaceMapFromConfigObject(
    const QJsonObject &root)
{
    m_agentWorkspaceById.clear();
    m_agentsDefaultWorkspace.clear();
    if (root.isEmpty())
        return;

    const QJsonObject agents = root.value(QStringLiteral("agents")).toObject();
    m_agentsDefaultWorkspace =
        agents.value(QStringLiteral("defaults")).toObject()
            .value(QStringLiteral("workspace")).toString().trimmed();

    const QJsonArray list = agents.value(QStringLiteral("list")).toArray();
    for (const QJsonValue &v : list) {
        const QJsonObject a = v.toObject();
        const QString id = a.value(QStringLiteral("id")).toString().trimmed();
        const QString ws = a.value(QStringLiteral("workspace")).toString().trimmed();
        if (!id.isEmpty() && !ws.isEmpty())
            m_agentWorkspaceById.insert(id, ws);
    }
}

QString GatewayClient::resolveWorkspacePathForAgentId(const QString &agentId) const
{
    const QString id = agentId.trimmed();
    if (id.isEmpty())
        return QString();
    auto it = m_agentWorkspaceById.constFind(id);
    if (it != m_agentWorkspaceById.cend() && !it.value().isEmpty())
        return it.value();
    return m_agentsDefaultWorkspace;
}

void GatewayClient::mergeWorkspaceIntoAgentIdentity()
{
    const QString aid =
        m_agentIdentity.value(QStringLiteral("agentId")).toString().trimmed();
    if (aid.isEmpty())
        return;
    const QString ws = resolveWorkspacePathForAgentId(aid);
    if (ws.isEmpty())
        return;
    m_agentIdentity.insert(QStringLiteral("workspace"), ws);
    emit agentIdentityChanged();
}

void GatewayClient::refreshMcpList()
{
    if (m_state != Connected)
        return;
    sendRequest(QStringLiteral("config.get"), QJsonObject());
}

void GatewayClient::refreshToolsCatalog(const QString &agentId)
{
    if (m_state != Connected)
        return;
    const QString useAgent =
        agentId.trimmed().isEmpty() ? m_defaultAgentId : agentId.trimmed();
    const QJsonObject params =
        m_tools.buildToolsCatalogParams(useAgent, true);
    sendRequest(QStringLiteral("tools.catalog"), params);
}

void GatewayClient::setAgentToolEnabled(const QString &agentId, const QString &toolId,
                                        bool enabled)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString aid = agentId.trimmed();
    const QString tid = toolId.trimmed();
    if (aid.isEmpty() || tid.isEmpty()) {
        emit errorOccurred(QStringLiteral("agentId / toolId \u4e0d\u80fd\u4e3a\u7a7a"));
        return;
    }
    if (m_lastConfigSnapshot.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u914d\u7f6e\u5feb\u7167\u672a\u52a0\u8f7d\uff0c\u8bf7\u5148\u5237\u65b0\u8fde\u63a5\u6216 MCP \u5217\u8868"));
        return;
    }
    const QJsonObject patch =
        m_tools.buildToolToggleMergePatch(m_lastConfigSnapshot, aid, tid, enabled);
    if (patch.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u672a\u627e\u5230\u6307\u5b9a agent\uff0c\u65e0\u6cd5\u66f4\u65b0\u5de5\u5177\u72b6\u6001"));
        return;
    }

    QJsonObject reqParams;
    reqParams[QStringLiteral("raw")] =
        QString::fromUtf8(QJsonDocument(patch).toJson(QJsonDocument::Compact));
    if (!m_configSnapshotHash.isEmpty())
        reqParams[QStringLiteral("baseHash")] = m_configSnapshotHash;

    sendRequest(QStringLiteral("config.patch"), reqParams);

    m_tools.setLocalToolEnabled(tid, enabled);
    emit toolListChanged();
}

void GatewayClient::batchSetAgentToolsEnabled(const QString &agentId,
                                               const QVariantList &enabledToolIds)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString aid = agentId.trimmed();
    if (aid.isEmpty()) {
        emit errorOccurred(QStringLiteral("agentId \u4e0d\u80fd\u4e3a\u7a7a"));
        return;
    }
    if (m_configSnapshotHash.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u914d\u7f6e\u5feb\u7167\u672a\u52a0\u8f7d\uff0c\u8bf7\u5148\u5237\u65b0\u8fde\u63a5"));
        return;
    }

    if (m_lastConfigSnapshot.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u914d\u7f6e\u5feb\u7167\u672a\u52a0\u8f7d\uff0c\u8bf7\u5148\u5237\u65b0\u8fde\u63a5"));
        return;
    }

    QStringList ids;
    for (const QVariant &v : enabledToolIds)
        ids.append(v.toString().trimmed());

    const QJsonObject fullCfg =
        m_tools.buildFullConfigWithBatchToolPolicy(m_lastConfigSnapshot, aid, ids);
    if (fullCfg.isEmpty()) {
        emit errorOccurred(QStringLiteral(
            "\u65e0\u6cd5\u6784\u5efa\u914d\u7f6e\uff0c\u8bf7\u68c0\u67e5 agentId"));
        return;
    }

    const QByteArray cfgJson = QJsonDocument(fullCfg).toJson(QJsonDocument::Compact);
    qDebug() << "[ToolSave] agentId=" << aid
             << "enabledCount=" << ids.size()
             << "hash=" << m_configSnapshotHash
             << "configSize=" << cfgJson.size();

    QJsonObject reqParams;
    reqParams[QStringLiteral("raw")] = QString::fromUtf8(cfgJson);
    if (!m_configSnapshotHash.isEmpty())
        reqParams[QStringLiteral("baseHash")] = m_configSnapshotHash;

    sendRequest(QStringLiteral("config.set"), reqParams);

    m_tools.batchSetLocalToolEnabled(ids);
    emit toolListChanged();
}

void GatewayClient::applyMcpServer(bool isEdit,
                                   const QString &originalServerName,
                                   const QString &serverName,
                                   bool useHttp,
                                   const QString &stdioCommand,
                                   const QString &stdioArgsMultiline,
                                   const QString &httpUrl,
                                   const QString &description,
                                   const QString &envJson)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString name = serverName.trimmed();
    if (name.isEmpty()) {
        emit errorOccurred(
            QStringLiteral("MCP \u670d\u52a1\u540d\u79f0\u4e0d\u80fd\u4e3a\u7a7a"));
        return;
    }
    QJsonObject serverObj;
    if (useHttp) {
        const QString u = httpUrl.trimmed();
        if (u.isEmpty()) {
            emit errorOccurred(
                QStringLiteral("\u8bf7\u586b\u5199 MCP \u670d\u52a1 URL"));
            return;
        }
        serverObj[QStringLiteral("url")] = u;
    } else {
        const QString c = stdioCommand.trimmed();
        if (c.isEmpty()) {
            emit errorOccurred(
                QStringLiteral("\u8bf7\u9009\u62e9\u6216\u586b\u5199\u542f\u52a8\u547d\u4ee4"));
            return;
        }
        serverObj[QStringLiteral("command")] = c;
        QJsonArray args;
        const QStringList lines = stdioArgsMultiline.split(QLatin1Char('\n'));
        for (QString ln : lines) {
            ln = ln.trimmed();
            if (!ln.isEmpty())
                args.append(ln);
        }
        if (!args.isEmpty())
            serverObj[QStringLiteral("args")] = args;
    }
    const QString d = description.trimmed();
    if (!d.isEmpty())
        serverObj[QStringLiteral("description")] = d;

    if (!envJson.trimmed().isEmpty()) {
        const QJsonDocument envDoc = QJsonDocument::fromJson(envJson.toUtf8());
        if (envDoc.isObject() && !envDoc.object().isEmpty())
            serverObj[QStringLiteral("env")] = envDoc.object();
    }

    QJsonObject serversPatch;
    const QString orig = originalServerName.trimmed();
    if (isEdit && !orig.isEmpty() && orig != name)
        serversPatch[orig] = QJsonValue(QJsonValue::Null);
    serversPatch[name] = serverObj;

    QJsonObject mcpObj;
    mcpObj[QStringLiteral("servers")] = serversPatch;
    QJsonObject rawTop;
    rawTop[QStringLiteral("mcp")] = mcpObj;

    QJsonObject params;
    params[QStringLiteral("raw")] =
        QString::fromUtf8(QJsonDocument(rawTop).toJson(QJsonDocument::Compact));
    if (!m_configSnapshotHash.isEmpty())
        params[QStringLiteral("baseHash")] = m_configSnapshotHash;

    sendRequest(QStringLiteral("config.patch"), params);
}

void GatewayClient::removeMcpServer(const QString &serverName)
{
    if (m_state != Connected) {
        emit errorOccurred(
            QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }
    const QString n = serverName.trimmed();
    if (n.isEmpty())
        return;

    QJsonObject serversPatch;
    serversPatch[n] = QJsonValue(QJsonValue::Null);
    QJsonObject mcpObj;
    mcpObj[QStringLiteral("servers")] = serversPatch;
    QJsonObject rawTop;
    rawTop[QStringLiteral("mcp")] = mcpObj;

    QJsonObject params;
    params[QStringLiteral("raw")] =
        QString::fromUtf8(QJsonDocument(rawTop).toJson(QJsonDocument::Compact));
    if (!m_configSnapshotHash.isEmpty())
        params[QStringLiteral("baseHash")] = m_configSnapshotHash;

    sendRequest(QStringLiteral("config.patch"), params);
}

bool GatewayClient::saveTextToFile(const QString &localPath, const QString &content)
{
    const QString p = localPath.trimmed();
    if (p.isEmpty())
        return false;
    QFile f(p);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    const QByteArray utf8 = content.toUtf8();
    return f.write(utf8) == utf8.size();
}

// ═══════════════════════════════════════════════════════════════════════
//  文件附件：暂存 & 复制到工作空间
// ═══════════════════════════════════════════════════════════════════════

void GatewayClient::setPendingChatFiles(const QVariantList &files)
{
    m_pendingChatFiles = files;
}

static void copySingleFile(const QString &srcPath, const QString &destDir)
{
    const QFileInfo srcInfo(srcPath);
    if (!srcInfo.exists() || !srcInfo.isFile())
        return;

    QString destName = srcInfo.fileName();
    QString destPath = destDir + QLatin1Char('/') + destName;

    if (QFile::exists(destPath)) {
        const QString base = srcInfo.completeBaseName();
        const QString suffix = srcInfo.suffix();
        int seq = 1;
        do {
            destName = suffix.isEmpty()
                ? QStringLiteral("%1_%2").arg(base).arg(seq)
                : QStringLiteral("%1_%2.%3").arg(base).arg(seq).arg(suffix);
            destPath = destDir + QLatin1Char('/') + destName;
            ++seq;
        } while (QFile::exists(destPath));
    }

    if (QFile::copy(srcPath, destPath))
        qDebug() << "[Gateway] file copied:" << srcPath << "->" << destPath;
    else
        qWarning() << "[Gateway] file copy failed:" << srcPath << "->" << destPath;
}

static void copyDirRecursive(const QString &srcDir, const QString &destDir)
{
    const QDir src(srcDir);
    QDir().mkpath(destDir);

    for (const QFileInfo &entry : src.entryInfoList(QDir::Files))
        copySingleFile(entry.absoluteFilePath(), destDir);

    for (const QFileInfo &entry : src.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot))
        copyDirRecursive(entry.absoluteFilePath(),
                         destDir + QLatin1Char('/') + entry.fileName());
}

void GatewayClient::resolveAndCopyFiles(const QVariantList &files,
                                        const QString &workspace)
{
    if (files.isEmpty() || workspace.trimmed().isEmpty())
        return;

    QString ws = workspace;
    if (ws.startsWith(QStringLiteral("~/")))
        ws = QDir::homePath() + ws.mid(1);
    ws = QDir::cleanPath(ws);

    const QString uploadDir = ws;
    QDir().mkpath(uploadDir);

    for (const QVariant &v : files) {
        const QVariantMap fm = v.toMap();
        const QString rawUrl = fm.value(QStringLiteral("fileUrl")).toString();
        QString srcPath = rawUrl;
        if (srcPath.startsWith(QStringLiteral("file://")))
            srcPath = QUrl(srcPath).toLocalFile();

        const QFileInfo srcInfo(srcPath);
        if (!srcInfo.exists())
            continue;

        if (srcInfo.isDir()) {
            const QString destSubDir = uploadDir + QLatin1Char('/') + srcInfo.fileName();
            copyDirRecursive(srcPath, destSubDir);
            qDebug() << "[Gateway] folder copied:" << srcPath << "->" << destSubDir;
        } else {
            copySingleFile(srcPath, uploadDir);
        }
    }
}

QString GatewayClient::extractPayloadSessionKey(const QJsonObject &payload) const
{
    auto pick = [](const QJsonObject &o) -> QString {
        const QString s = o.value(QStringLiteral("sessionKey")).toString().trimmed();
        return s;
    };

    QString sk = pick(payload);
    if (!sk.isEmpty())
        return sk;

    const QJsonObject data = payload.value(QStringLiteral("data")).toObject();
    sk = pick(data);
    if (!sk.isEmpty())
        return sk;

    QString aid = payload.value(QStringLiteral("agentId")).toString().trimmed();
    if (aid.isEmpty())
        aid = data.value(QStringLiteral("agentId")).toString().trimmed();
    if (!aid.isEmpty())
        return QStringLiteral("agent:%1:main").arg(aid);

    return QString();
}

bool GatewayClient::eventAppliesToCurrentUiSession(
    const QJsonObject &payload, bool allowIfKeyMissing) const
{
    const QString cur = m_session.currentSessionKey().trimmed();
    if (cur.isEmpty())
        return allowIfKeyMissing;

    const QString evt = extractPayloadSessionKey(payload);
    if (evt.isEmpty())
        return allowIfKeyMissing;

    if (evt == cur)
        return true;

    // 宽松匹配：只比较 agent ID 部分（忽略尾部 session segment）
    // 例如 "agent:main:main" 与 "agent:main:abc123" 视为同一 agent
    const QStringList curParts = cur.split(QLatin1Char(':'));
    const QStringList evtParts = evt.split(QLatin1Char(':'));
    if (curParts.size() >= 2 && evtParts.size() >= 2
        && curParts[0] == evtParts[0] && curParts[1] == evtParts[1])
        return true;

    return false;
}

// ═══════════════════════════════════════════════════════════════════════
//  设置：记忆 / 沙箱 / 记忆条目管理
// ═══════════════════════════════════════════════════════════════════════

void GatewayClient::parseSettingsFromConfig()
{
    if (m_lastConfigSnapshot.isEmpty())
        return;

    const QJsonObject agents =
        m_lastConfigSnapshot.value(QStringLiteral("agents")).toObject();
    const QJsonObject defaults =
        agents.value(QStringLiteral("defaults")).toObject();

    // memorySearch.enabled（默认 true）
    const QJsonObject memSearch =
        defaults.value(QStringLiteral("memorySearch")).toObject();
    const bool newMem = memSearch.contains(QStringLiteral("enabled"))
        ? memSearch.value(QStringLiteral("enabled")).toBool(true)
        : true;
    if (m_memoryEnabled != newMem) {
        m_memoryEnabled = newMem;
        emit memoryEnabledChanged();
    }

    // sandbox.mode → 0=auto(non-main) 1=local(off) 2=all
    const QJsonObject sandbox =
        defaults.value(QStringLiteral("sandbox")).toObject();
    const QString modeStr =
        sandbox.value(QStringLiteral("mode")).toString().trimmed();
    int newSb = 0;
    if (modeStr == QLatin1String("off"))
        newSb = 1;
    else if (modeStr == QLatin1String("all"))
        newSb = 2;
    if (m_sandboxMode != newSb) {
        m_sandboxMode = newSb;
        emit sandboxModeChanged();
    }

    // LLM judgment（本地）
    const bool newLlm = m_config.llmJudgmentEnabled();
    if (m_llmJudgmentEnabled != newLlm) {
        m_llmJudgmentEnabled = newLlm;
        emit llmJudgmentEnabledChanged();
    }
}

void GatewayClient::saveGeneralSettings(bool memEnabled, bool llmEnabled, int sbMode)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("尚未连接到服务器"));
        return;
    }

    // 构建 config.patch payload
    QJsonObject memSearch;
    memSearch[QStringLiteral("enabled")] = memEnabled;
    QJsonObject sandboxObj;
    switch (sbMode) {
    case 1:  sandboxObj[QStringLiteral("mode")] = QStringLiteral("off");      break;
    case 2:  sandboxObj[QStringLiteral("mode")] = QStringLiteral("all");      break;
    default: sandboxObj[QStringLiteral("mode")] = QStringLiteral("non-main"); break;
    }
    QJsonObject defaults;
    defaults[QStringLiteral("memorySearch")] = memSearch;
    defaults[QStringLiteral("sandbox")]      = sandboxObj;
    QJsonObject agents;
    agents[QStringLiteral("defaults")] = defaults;
    QJsonObject rawTop;
    rawTop[QStringLiteral("agents")] = agents;

    QJsonObject params;
    params[QStringLiteral("raw")] =
        QString::fromUtf8(QJsonDocument(rawTop).toJson(QJsonDocument::Compact));
    if (!m_configSnapshotHash.isEmpty())
        params[QStringLiteral("baseHash")] = m_configSnapshotHash;
    sendRequest(QStringLiteral("config.patch"), params);

    // 更新本地状态
    if (m_memoryEnabled != memEnabled) {
        m_memoryEnabled = memEnabled;
        emit memoryEnabledChanged();
    }
    if (m_sandboxMode != sbMode) {
        m_sandboxMode = sbMode;
        emit sandboxModeChanged();
    }

    // LLM 判定：本地持久化
    if (m_llmJudgmentEnabled != llmEnabled) {
        m_llmJudgmentEnabled = llmEnabled;
        m_config.setLlmJudgmentEnabled(llmEnabled);
        emit llmJudgmentEnabledChanged();
    }

    emit settingsSaved();
    qDebug() << "[Settings] saved: memory=" << memEnabled
             << "llm=" << llmEnabled << "sandbox=" << sbMode;
}

// ── 记忆条目 CRUD（本地 JSON）──

static QString memoryEntriesFilePath()
{
    static const QString p =
        QStringLiteral("AppData/config/memory_entries.json");
    return p;
}

void GatewayClient::loadMemoryEntries()
{
    m_memoryEntries.clear();
    QFile f(memoryEntriesFilePath());
    if (f.open(QIODevice::ReadOnly)) {
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        f.close();
        if (doc.isArray()) {
            const QJsonArray arr = doc.array();
            for (const QJsonValue &v : arr) {
                if (v.isObject())
                    m_memoryEntries.append(v.toObject().toVariantMap());
            }
        }
    }
    emit memoryEntriesChanged();
}

void GatewayClient::saveMemoryEntriesToDisk()
{
    QDir().mkpath(QStringLiteral("AppData/config"));
    QJsonArray arr;
    for (const QVariant &v : m_memoryEntries)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QFile f(memoryEntriesFilePath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
}

void GatewayClient::addMemoryEntry(const QString &title, const QString &content)
{
    QVariantMap e;
    e[QStringLiteral("id")] = QUuid::createUuid().toString(QUuid::WithoutBraces);
    e[QStringLiteral("title")] = title.trimmed();
    e[QStringLiteral("content")] = content.trimmed();
    e[QStringLiteral("date")] =
        QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
    m_memoryEntries.append(e);
    saveMemoryEntriesToDisk();
    emit memoryEntriesChanged();
}

void GatewayClient::updateMemoryEntry(const QString &id, const QString &title,
                                       const QString &content)
{
    for (int i = 0; i < m_memoryEntries.size(); ++i) {
        QVariantMap e = m_memoryEntries[i].toMap();
        if (e.value(QStringLiteral("id")).toString() == id) {
            e[QStringLiteral("title")] = title.trimmed();
            e[QStringLiteral("content")] = content.trimmed();
            e[QStringLiteral("date")] =
                QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm"));
            m_memoryEntries[i] = e;
            saveMemoryEntriesToDisk();
            emit memoryEntriesChanged();
            return;
        }
    }
}

void GatewayClient::deleteMemoryEntry(const QString &id)
{
    for (int i = 0; i < m_memoryEntries.size(); ++i) {
        if (m_memoryEntries[i].toMap().value(QStringLiteral("id")).toString() == id) {
            m_memoryEntries.removeAt(i);
            saveMemoryEntriesToDisk();
            emit memoryEntriesChanged();
            return;
        }
    }
}
