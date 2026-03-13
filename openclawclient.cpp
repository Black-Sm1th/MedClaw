#include "openclawclient.h"
#include "ed25519_local.h"
#include <QDebug>
#include <QCryptographicHash>
#include <QDateTime>

static const QLatin1String T_EVENT("event");
static const QLatin1String T_REQ("req");
static const QLatin1String T_RES("res");

// ══════════════════════════════════════════════════════════════════════

OpenClawClient::OpenClawClient(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_state(Disconnected)
    , m_token(QStringLiteral("81Rfv9HOnc6uqLVT7GrZ42j5tbBpgQahCKWiAYyEmUFekJSld03IowsxMDPNXz"))
    , m_isStreaming(false)
    , m_hasKeys(false)
    , m_currentSessionKey(QStringLiteral("agent:main:main"))
{
    connect(m_socket, &QWebSocket::connected,
            this, &OpenClawClient::onConnected);
    connect(m_socket, &QWebSocket::disconnected,
            this, &OpenClawClient::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived,
            this, &OpenClawClient::onTextMessageReceived);
    connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error),
            this, &OpenClawClient::onSocketError);

    initDeviceKeys();
}

OpenClawClient::~OpenClawClient()
{
    m_socket->close();
}

int OpenClawClient::connectionState() const { return m_state; }
QVariantList OpenClawClient::sessions() const { return m_sessions; }
QString OpenClawClient::currentSessionKey() const { return m_currentSessionKey; }

QString OpenClawClient::statusText() const
{
    switch (m_state) {
    case Disconnected: return QStringLiteral("\u5df2\u65ad\u5f00");
    case Connecting:   return QStringLiteral("\u8fde\u63a5\u4e2d...");
    case Handshaking:  return QStringLiteral("\u63e1\u624b\u4e2d...");
    case Connected:    return QStringLiteral("\u5df2\u8fde\u63a5");
    }
    return QStringLiteral("\u672a\u77e5");
}

void OpenClawClient::setState(ConnectionState state)
{
    if (m_state != state) {
        m_state = state;
        emit connectionStateChanged();
    }
}

void OpenClawClient::setCurrentSessionKey(const QString &key)
{
    if (m_currentSessionKey != key) {
        m_currentSessionKey = key;
        emit currentSessionChanged();
    }
}

// ── Ed25519 key generation (pure C++, no OpenSSL) ─────────────────────

void OpenClawClient::initDeviceKeys()
{
    memset(m_ed25519Pk, 0, sizeof(m_ed25519Pk));
    memset(m_ed25519Sk, 0, sizeof(m_ed25519Sk));

    ed25519_create_keypair(m_ed25519Pk, m_ed25519Sk);
    m_hasKeys = true;

    QByteArray rawPk(reinterpret_cast<char *>(m_ed25519Pk), 32);
    m_deviceId = QString::fromLatin1(
        QCryptographicHash::hash(rawPk, QCryptographicHash::Sha256).toHex());

    qDebug() << "[OpenClaw] Ed25519 keypair ready (built-in). deviceId:" << m_deviceId.left(16) << "...";
}

QJsonObject OpenClawClient::buildSignedDevice()
{
    QJsonObject dev;
    dev[QStringLiteral("id")]    = m_deviceId;
    dev[QStringLiteral("nonce")] = m_challengeNonce;

    if (!m_hasKeys)
        return dev;

    const qint64 signedAt = QDateTime::currentMSecsSinceEpoch();

    const QString scopes = QStringLiteral("operator.admin,operator.approvals,operator.pairing");
    const QString payload = QStringLiteral("v2|%1|%2|%3|%4|%5|%6|%7|%8")
        .arg(m_deviceId,
             QStringLiteral("clawdbot-control-ui"),
             QStringLiteral("webchat"),
             QStringLiteral("operator"),
             scopes)
        .arg(signedAt)
        .arg(m_token, m_challengeNonce);

    const QByteArray msg = payload.toUtf8();

    uint8_t sig[64];
    ed25519_sign(sig,
                 reinterpret_cast<const uint8_t *>(msg.constData()),
                 static_cast<size_t>(msg.size()),
                 m_ed25519Sk);

    QByteArray rawPk(reinterpret_cast<char *>(m_ed25519Pk), 32);
    QByteArray rawSig(reinterpret_cast<char *>(sig), 64);

    dev[QStringLiteral("publicKey")] = QString::fromLatin1(
        rawPk.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    dev[QStringLiteral("signature")] = QString::fromLatin1(
        rawSig.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    dev[QStringLiteral("signedAt")] = signedAt;

    return dev;
}

// ── Connection lifecycle ──────────────────────────────────────────────

void OpenClawClient::connectToServer(const QString &url)
{
    if (m_state != Disconnected)
        m_socket->close();

    m_challengeNonce.clear();
    m_pendingRequests.clear();
    setState(Connecting);
    m_socket->open(QUrl(url));
}

void OpenClawClient::disconnectFromServer()
{
    m_socket->close();
}

void OpenClawClient::onConnected()
{
    qDebug() << "[OpenClaw] WebSocket transport open, waiting for challenge...";
    setState(Handshaking);
}

void OpenClawClient::onDisconnected()
{
    qDebug() << "[OpenClaw] WebSocket disconnected";
    m_isStreaming = false;
    m_pendingRequests.clear();
    setState(Disconnected);
}

void OpenClawClient::onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    qWarning() << "[OpenClaw] Socket error:" << m_socket->errorString();
    emit errorOccurred(m_socket->errorString());
    setState(Disconnected);
}

// ── Protocol: connect handshake ───────────────────────────────────────

void OpenClawClient::sendConnectRequest()
{
    m_connectRequestId = nextRequestId();

    QJsonObject auth;
    auth[QStringLiteral("token")] = m_token;

    QJsonObject client;
    client[QStringLiteral("id")]       = QStringLiteral("clawdbot-control-ui");
    client[QStringLiteral("version")]  = QStringLiteral("dev");
    client[QStringLiteral("platform")] = QStringLiteral("Win32");
    client[QStringLiteral("mode")]     = QStringLiteral("webchat");

    QJsonObject params;
    params[QStringLiteral("minProtocol")] = 3;
    params[QStringLiteral("maxProtocol")] = 3;
    params[QStringLiteral("client")]      = client;
    params[QStringLiteral("role")]        = QStringLiteral("operator");
    params[QStringLiteral("scopes")]      = QJsonArray({
        QStringLiteral("operator.admin"),
        QStringLiteral("operator.approvals"),
        QStringLiteral("operator.pairing")
    });
    params[QStringLiteral("caps")]      = QJsonArray();
    params[QStringLiteral("auth")]      = auth;
    params[QStringLiteral("locale")]    = QStringLiteral("zh-CN");
    params[QStringLiteral("userAgent")] = QStringLiteral("MedClaw-Qt/1.0");
    params[QStringLiteral("device")]    = buildSignedDevice();

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = m_connectRequestId;
    request[QStringLiteral("method")] = QStringLiteral("connect");
    request[QStringLiteral("params")] = params;

    QByteArray json = QJsonDocument(request).toJson(QJsonDocument::Compact);
    qDebug().noquote() << "[OpenClaw] >> connect" << QString::fromUtf8(json);
    m_socket->sendTextMessage(QString::fromUtf8(json));
}

// ── Inbound message dispatch ──────────────────────────────────────────

void OpenClawClient::onTextMessageReceived(const QString &message)
{
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[OpenClaw] bad JSON:" << err.errorString();
        return;
    }

    QJsonObject msg = doc.object();
    const QString type = msg.value(QStringLiteral("type")).toString();

    if (type == T_EVENT) {
        handleEvent(msg);
        return;
    }
    if (type == T_RES || (type == T_REQ && msg.contains(QStringLiteral("ok")))) {
        handleResponse(msg);
        return;
    }
    if (msg.contains(QStringLiteral("event"))) {
        handleEvent(msg);
        return;
    }

    qDebug() << "[OpenClaw] unrecognised frame:" << message.left(400);
}

void OpenClawClient::handleEvent(const QJsonObject &msg)
{
    const QString event       = msg.value(QStringLiteral("event")).toString();
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();

    if (event == QLatin1String("connect.challenge")) {
        m_challengeNonce = payload.value(QStringLiteral("nonce")).toString();
        qDebug() << "[OpenClaw] challenge nonce:" << m_challengeNonce;
        sendConnectRequest();
        return;
    }

    if (event == QLatin1String("tick") || event == QLatin1String("heartbeat"))
        return;

    const QString subEvent = payload.value(QStringLiteral("event")).toString();
    const QJsonObject data = payload.value(QStringLiteral("data")).toObject();

    static int debugCount = 0;
    if (debugCount < 15 && (event == QLatin1String("agent") || event == QLatin1String("chat"))) {
        ++debugCount;
        qDebug().noquote() << "[OpenClaw] EVT" << event << "|" << subEvent
                           << "data:" << QString::fromUtf8(
                                  QJsonDocument(data).toJson(QJsonDocument::Compact)).left(300);
    }

    // Detect semantics from BOTH sub-event name AND data fields
    const QString phase  = data.value(QStringLiteral("phase")).toString();
    const bool hasDelta  = data.contains(QStringLiteral("delta"));
    const QString delta  = data.value(QStringLiteral("delta")).toString();

    const bool isDelta    = hasDelta
                         || subEvent.contains(QLatin1String("delta"))
                         || subEvent.contains(QLatin1String("chunk"));
    const bool isStart    = phase == QLatin1String("start")
                         || subEvent.contains(QLatin1String("start"));
    const bool isComplete = phase == QLatin1String("complete")
                         || phase == QLatin1String("done")
                         || subEvent.contains(QLatin1String("complete"))
                         || subEvent.contains(QLatin1String("done"))
                         || subEvent.contains(QLatin1String("finish"));

    // Prefer delta for streaming; fall back to content/text
    QString content = delta;
    if (content.isEmpty())
        content = data.value(QStringLiteral("content")).toString();
    if (content.isEmpty())
        content = data.value(QStringLiteral("text")).toString();
    if (content.isEmpty())
        content = payload.value(QStringLiteral("content")).toString();

    const QString role = data.value(QStringLiteral("role")).toString(
        payload.value(QStringLiteral("role")).toString(QStringLiteral("assistant")));

    // ── agent events ──
    if (event == QLatin1String("agent")) {
        if (isStart) {
            if (!m_isStreaming) { m_isStreaming = true; emit streamingStarted(); }
            return;
        }
        if (isDelta && !content.isEmpty()) {
            if (!m_isStreaming) { m_isStreaming = true; emit streamingStarted(); }
            emit chatMessageReceived(QStringLiteral("assistant"), content, true);
            return;
        }
        if (isComplete) {
            if (m_isStreaming) { m_isStreaming = false; emit streamingFinished(); }
            else if (!content.isEmpty())
                emit chatMessageReceived(role, content, false);
            return;
        }
        if (!content.isEmpty()) {
            if (!m_isStreaming) { m_isStreaming = true; emit streamingStarted(); }
            emit chatMessageReceived(QStringLiteral("assistant"), content, true);
        }
        return;
    }

    // ── chat events ──
    if (event == QLatin1String("chat")) {
        if (isDelta && !content.isEmpty()) {
            if (!m_isStreaming) { m_isStreaming = true; emit streamingStarted(); }
            emit chatMessageReceived(QStringLiteral("assistant"), content, true);
            return;
        }
        if (isComplete) {
            if (m_isStreaming) { m_isStreaming = false; emit streamingFinished(); }
            else if (!content.isEmpty())
                emit chatMessageReceived(role, content, false);
            return;
        }
        // chat events with empty data are normal (status updates), just ignore
        return;
    }

    if (!content.isEmpty())
        emit chatMessageReceived(role, content, false);
}

void OpenClawClient::handleResponse(const QJsonObject &msg)
{
    const QString id          = msg.value(QStringLiteral("id")).toString();
    const bool ok             = msg.value(QStringLiteral("ok")).toBool(false);
    const QJsonObject payload = msg.value(QStringLiteral("payload")).toObject();
    const QJsonValue errVal   = msg.value(QStringLiteral("error"));

    const QString method = m_pendingRequests.take(id);

    if (!ok && id != m_connectRequestId) {
        QString errMsg;
        if (errVal.isObject())
            errMsg = errVal.toObject().value(QStringLiteral("message")).toString();
        if (errMsg.isEmpty() && errVal.isString())
            errMsg = errVal.toString();
        if (errMsg.isEmpty())
            errMsg = QStringLiteral("Request failed (ok=false)");
        qWarning() << "[OpenClaw] error" << method << "id=" << id << errMsg;
        emit errorOccurred(errMsg);
        return;
    }

    // ── Connect handshake ──
    if (id == m_connectRequestId) {
        if (!ok) {
            QString errMsg;
            if (errVal.isObject())
                errMsg = errVal.toObject().value(QStringLiteral("message")).toString();
            if (errMsg.isEmpty() && errVal.isString())
                errMsg = errVal.toString();
            qWarning() << "[OpenClaw] connect failed:" << errMsg;
            emit errorOccurred(errMsg);
            return;
        }
        qDebug() << "[OpenClaw] handshake complete!";
        setState(Connected);
        refreshSessions();
        loadHistory();
        return;
    }

    qDebug().noquote() << "[OpenClaw] <<" << method << "id=" << id
                       << QString::fromUtf8(
                              QJsonDocument(payload).toJson(QJsonDocument::Compact)).left(500);

    // ── sessions.list ──
    if (method == QLatin1String("sessions.list")) {
        m_sessions.clear();
        QJsonArray arr = payload.value(QStringLiteral("sessions")).toArray();
        if (arr.isEmpty())
            arr = payload.value(QStringLiteral("items")).toArray();

        for (const QJsonValue &v : arr) {
            const QJsonObject s = v.toObject();
            const QString key = s.value(QStringLiteral("key")).toString(
                s.value(QStringLiteral("sessionKey")).toString());
            if (key.isEmpty()) continue;

            QString name = s.value(QStringLiteral("title")).toString(
                s.value(QStringLiteral("name")).toString());
            if (name.isEmpty()) {
                const QStringList parts = key.split(QLatin1Char(':'));
                name = (parts.size() >= 2) ? parts[1] : key;
            }
            const QString model = s.value(QStringLiteral("model")).toString();
            if (!model.isEmpty())
                name += QStringLiteral(" (%1)").arg(model);

            QVariantMap entry;
            entry[QStringLiteral("sessionKey")]  = key;
            entry[QStringLiteral("displayName")] = name;
            m_sessions.append(entry);
        }

        if (m_sessions.isEmpty()) {
            QVariantMap def;
            def[QStringLiteral("sessionKey")]  = QStringLiteral("agent:main:main");
            def[QStringLiteral("displayName")] = QStringLiteral("Main Agent");
            m_sessions.append(def);
        }

        qDebug() << "[OpenClaw] sessions loaded:" << m_sessions.count();
        emit sessionsChanged();
        return;
    }

    // ── chat.send (check if it was /new) ──
    if (method == QLatin1String("chat.send") && id == m_newSessionReqId) {
        m_newSessionReqId.clear();
        qDebug() << "[OpenClaw] /new session response, refreshing list...";
        refreshSessions();
        emit sessionCreated();
        return;
    }

    // ── session.delete ──
    if (method == QLatin1String("session.delete")) {
        qDebug() << "[OpenClaw] session deleted, refreshing list...";
        refreshSessions();
        return;
    }

    // ── messages.list ──
    if (method == QLatin1String("messages.list")) {
        QVariantList history;

        QJsonArray arr = payload.value(QStringLiteral("messages")).toArray();
        if (arr.isEmpty())
            arr = payload.value(QStringLiteral("items")).toArray();
        if (arr.isEmpty())
            arr = payload.value(QStringLiteral("data")).toArray();

        for (const QJsonValue &v : arr) {
            const QJsonObject m = v.toObject();
            QString role = m.value(QStringLiteral("role")).toString();
            QString text = m.value(QStringLiteral("content")).toString();
            if (text.isEmpty())
                text = m.value(QStringLiteral("text")).toString();
            if (text.isEmpty())
                text = m.value(QStringLiteral("message")).toString();
            if (role.isEmpty() || text.isEmpty())
                continue;
            QVariantMap entry;
            entry[QStringLiteral("role")]    = role;
            entry[QStringLiteral("content")] = text;
            history.append(entry);
        }

        qDebug() << "[OpenClaw] history loaded:" << history.count() << "messages";
        emit historyLoaded(history);
        return;
    }
}

// ── Outbound helpers ──────────────────────────────────────────────────

QString OpenClawClient::nextRequestId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QString OpenClawClient::sendRequest(const QString &method, const QJsonObject &params)
{
    QString reqId = nextRequestId();
    m_pendingRequests.insert(reqId, method);

    QJsonObject request;
    request[QStringLiteral("type")]   = QStringLiteral("req");
    request[QStringLiteral("id")]     = reqId;
    request[QStringLiteral("method")] = method;
    request[QStringLiteral("params")] = params;

    QByteArray json = QJsonDocument(request).toJson(QJsonDocument::Compact);
    qDebug().noquote() << "[OpenClaw] >>" << method << QString::fromUtf8(json);
    m_socket->sendTextMessage(QString::fromUtf8(json));
    return reqId;
}

// ── History ───────────────────────────────────────────────────────────

void OpenClawClient::loadHistory()
{
    if (m_state != Connected) return;

    QJsonObject params;
    params[QStringLiteral("sessionKey")] = m_currentSessionKey;
    params[QStringLiteral("limit")]      = 100;

    sendRequest(QStringLiteral("messages.list"), params);
}

// ── Session management ────────────────────────────────────────────────

void OpenClawClient::refreshSessions()
{
    if (m_state != Connected) return;

    QJsonObject params;
    params[QStringLiteral("includeGlobal")]  = true;
    params[QStringLiteral("includeUnknown")] = false;
    params[QStringLiteral("limit")]          = 120;

    sendRequest(QStringLiteral("sessions.list"), params);
}

void OpenClawClient::createNewSession()
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }

    QJsonObject params;
    params[QStringLiteral("sessionKey")]     = m_currentSessionKey;
    params[QStringLiteral("message")]        = QStringLiteral("/new");
    params[QStringLiteral("deliver")]        = false;
    params[QStringLiteral("idempotencyKey")] =
        QUuid::createUuid().toString(QUuid::WithoutBraces);

    m_newSessionReqId = sendRequest(QStringLiteral("chat.send"), params);
}

void OpenClawClient::deleteSession(const QString &sessionKey)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }

    QJsonObject params;
    params[QStringLiteral("sessionKey")] = sessionKey;

    sendRequest(QStringLiteral("session.delete"), params);
}

// ── Chat ──────────────────────────────────────────────────────────────

void OpenClawClient::sendChatMessage(const QString &message, const QString &sessionKey)
{
    if (m_state != Connected) {
        emit errorOccurred(QStringLiteral("\u5c1a\u672a\u8fde\u63a5\u5230\u670d\u52a1\u5668"));
        return;
    }

    const QString key = sessionKey.isEmpty() ? m_currentSessionKey : sessionKey;

    QJsonObject params;
    params[QStringLiteral("sessionKey")]     = key;
    params[QStringLiteral("message")]        = message;
    params[QStringLiteral("deliver")]        = false;
    params[QStringLiteral("idempotencyKey")] =
        QUuid::createUuid().toString(QUuid::WithoutBraces);

    sendRequest(QStringLiteral("chat.send"), params);
}
