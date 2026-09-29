/**
 * @file ws_config.cpp
 * @brief WebSocket 连接配置类 —— 实现
 */
#include "ws_config.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>
#include "ed25519_local.h"
#include <cstring>

namespace {

const QString kDefaultServer = QStringLiteral("ws://127.0.0.1:18789");
const QString kDefaultClientId = QStringLiteral("openclaw-control-ui");
const QString kDefaultSkillsStoragePath = QStringLiteral("~/AetherStudy/skills");

QString expandUserPath(const QString &path)
{
    const QString trimmed = path.trimmed();
    if (trimmed == QLatin1String("~"))
        return QDir::homePath();
    if (trimmed.startsWith(QLatin1String("~/")))
        return QDir(QDir::homePath()).filePath(trimmed.mid(2));
    return trimmed;
}

QString applicationConfigDirectory()
{
    QString root = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    if (root.trimmed().isEmpty())
        root = QDir(QDir::homePath()).filePath(QStringLiteral(".config"));
    return QDir(root).filePath(QStringLiteral("AetherStudy"));
}

bool readJsonObject(const QString &path, QJsonObject *object)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return false;
    *object = document.object();
    return true;
}

bool writePrivateJson(const QString &path, const QJsonObject &object)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(QJsonDocument(object).toJson(QJsonDocument::Indented));
    if (!file.commit())
        return false;
    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

bool isLocalGateway(const QString &serverUrl)
{
    const QString host = QUrl(serverUrl).host().trimmed().toLower();
    return host == QLatin1String("127.0.0.1") || host == QLatin1String("localhost")
           || host == QLatin1String("::1");
}

QString openClawGatewayToken(QString *source)
{
    QString token = qEnvironmentVariable("OPENCLAW_GATEWAY_TOKEN").trimmed();
    if (!token.isEmpty()) {
        if (source)
            *source = QStringLiteral("OPENCLAW_GATEWAY_TOKEN");
        return token;
    }

    QString stateDir = expandUserPath(qEnvironmentVariable("OPENCLAW_STATE_DIR"));
    if (stateDir.isEmpty())
        stateDir = QDir(QDir::homePath()).filePath(QStringLiteral(".openclaw"));

    const QString configPath = QDir(stateDir).filePath(QStringLiteral("openclaw.json"));
    QJsonObject root;
    if (!readJsonObject(configPath, &root))
        return {};

    token = root.value(QStringLiteral("gateway"))
                .toObject()
                .value(QStringLiteral("auth"))
                .toObject()
                .value(QStringLiteral("token"))
                .toString()
                .trimmed();
    if (!token.isEmpty() && source)
        *source = configPath;
    return token;
}

QString currentPlatformName()
{
#if defined(Q_OS_WIN)
    return QStringLiteral("Win32");
#elif defined(Q_OS_LINUX)
    return QStringLiteral("Linux %1").arg(QSysInfo::currentCpuArchitecture());
#elif defined(Q_OS_MACOS)
    return QStringLiteral("MacIntel");
#else
    return QSysInfo::prettyProductName();
#endif
}

} // namespace

// ═══════════════════════════════════════════════════════════════════════
//  构造 / 初始化
// ═══════════════════════════════════════════════════════════════════════

WsConfig::WsConfig()
    : m_serverUrl(kDefaultServer)
    , m_skillsStoragePath(QStringLiteral("~/AetherStudy/skills"))
    , m_clientId(kDefaultClientId)
    , m_clientVersion(QStringLiteral("dev"))
    , m_clientPlatform(currentPlatformName())
    // This is the desktop control client, not the browser WebChat client.
    // Session mutations such as model overrides are restricted for webchat
    // connections, so the handshake must declare the desktop UI mode.
    , m_clientMode(QStringLiteral("ui"))
    // ── 协议版本 & 角色 ──
    , m_minProtocol(3)
    , m_maxProtocol(3)
    , m_role(QStringLiteral("operator"))
    , m_scopes(QJsonArray({QStringLiteral("operator.admin"),
                           QStringLiteral("operator.approvals"),
                           QStringLiteral("operator.pairing")}))
    // ── Ed25519 密钥初始值 ──
    , m_hasKeys(false)
{
    loadOrCreatePersistentConfig();

    memset(m_ed25519Pk, 0, sizeof(m_ed25519Pk));
    memset(m_ed25519Sk, 0, sizeof(m_ed25519Sk));

    loadOrCreateDeviceKeys();
}

void WsConfig::loadOrCreatePersistentConfig()
{
    const QString configDir = applicationConfigDirectory();
    m_configPath = QDir(configDir).filePath(QStringLiteral("config.json"));
    m_deviceKeysPath = QDir(configDir).filePath(QStringLiteral("gateway-device.json"));

    QJsonObject merged;
    bool loaded = readJsonObject(m_configPath, &merged);
    if (!loaded) {
        // Older releases wrote below the process working directory. main.cpp
        // makes that directory stable, so migrate without deleting the source.
        const QString legacyPath = QDir::current().filePath(
            QStringLiteral("AppData/config/config.json"));
        if (readJsonObject(legacyPath, &merged)) {
            loaded = true;
            qDebug().noquote() << "[WsConfig] migrating legacy config" << legacyPath
                               << "to" << m_configPath;
        }
    }

    bool mergedDirty = false;
    if (merged.value(QStringLiteral("serverUrl")).toString().trimmed().isEmpty()) {
        merged[QStringLiteral("serverUrl")] = kDefaultServer;
        mergedDirty = true;
    }
    if (!merged.contains(QStringLiteral("token"))) {
        // Local OpenClaw credentials are discovered at runtime below.
        merged[QStringLiteral("token")] = QString();
        mergedDirty = true;
    }
    if (merged.value(QStringLiteral("clientId")).toString().trimmed().isEmpty()) {
        merged[QStringLiteral("clientId")] = kDefaultClientId;
        mergedDirty = true;
    }
    if (merged.value(QStringLiteral("skillsStoragePath")).toString().trimmed().isEmpty()) {
        merged[QStringLiteral("skillsStoragePath")] = kDefaultSkillsStoragePath;
        mergedDirty = true;
    }
    if (merged.contains(QStringLiteral("skillMarketCategories"))) {
        merged.remove(QStringLiteral("skillMarketCategories"));
        mergedDirty = true;
    }
    if (merged.contains(QStringLiteral("shortcut"))) {
        merged.remove(QStringLiteral("shortcut"));
        mergedDirty = true;
    }
    if (!loaded || mergedDirty || !QFileInfo::exists(m_configPath)) {
        if (!writePrivateJson(m_configPath, merged))
            qWarning().noquote() << "[WsConfig] cannot write" << m_configPath;
    }

    if (merged.contains(QStringLiteral("serverUrl"))) {
        const QString u = merged.value(QStringLiteral("serverUrl")).toString().trimmed();
        if (!u.isEmpty())
            m_serverUrl = u;
    }
    m_token = merged.value(QStringLiteral("token")).toString().trimmed();
    if (merged.contains(QStringLiteral("clientId"))) {
        const QString c = merged.value(QStringLiteral("clientId")).toString().trimmed();
        if (!c.isEmpty())
            m_clientId = c;
    }

    m_skillsStoragePath = merged.value(QStringLiteral("skillsStoragePath")).toString().trimmed();
    m_llmJudgmentEnabled = merged.value(QStringLiteral("llmJudgmentEnabled")).toBool(false);

    if (m_serverUrl.isEmpty())
        m_serverUrl = kDefaultServer;
    if (m_clientId.isEmpty())
        m_clientId = kDefaultClientId;
    if (m_skillsStoragePath.isEmpty())
        m_skillsStoragePath = kDefaultSkillsStoragePath;

    QString tokenSource;
    const QString explicitToken = qEnvironmentVariable("MEDCLAW_GATEWAY_TOKEN").trimmed();
    if (!explicitToken.isEmpty()) {
        m_token = explicitToken;
        tokenSource = QStringLiteral("MEDCLAW_GATEWAY_TOKEN");
    } else if (isLocalGateway(m_serverUrl)) {
        const QString localToken = openClawGatewayToken(&tokenSource);
        if (!localToken.isEmpty())
            m_token = localToken;
    }

    if (tokenSource.isEmpty() && !m_token.isEmpty())
        tokenSource = m_configPath;
    if (m_token.isEmpty())
        qWarning().noquote() << "[WsConfig] gateway token is empty for" << m_serverUrl;

    qDebug().noquote() << "[WsConfig] loaded" << m_configPath
                       << "serverUrl=" << m_serverUrl
                       << "platform=" << m_clientPlatform
                       << "tokenSource=" << (tokenSource.isEmpty()
                                                ? QStringLiteral("none") : tokenSource);
}

// ═══════════════════════════════════════════════════════════════════════
//  Getter / Setter
// ═══════════════════════════════════════════════════════════════════════

QString WsConfig::serverUrl() const
{
    return m_serverUrl;
}
void WsConfig::setServerUrl(const QString &url)
{
    m_serverUrl = url;
}

QString WsConfig::token() const
{
    return m_token;
}
void WsConfig::setToken(const QString &token)
{
    m_token = token;
}

QString WsConfig::skillsStoragePath() const
{
    return m_skillsStoragePath;
}
void WsConfig::setSkillsStoragePath(const QString &path)
{
    m_skillsStoragePath = path;
}

bool WsConfig::llmJudgmentEnabled() const
{
    return m_llmJudgmentEnabled;
}
void WsConfig::setLlmJudgmentEnabled(bool enabled)
{
    m_llmJudgmentEnabled = enabled;
    QJsonObject object;
    if (!readJsonObject(m_configPath, &object))
        return;
    object[QStringLiteral("llmJudgmentEnabled")] = enabled;
    if (!writePrivateJson(m_configPath, object))
        qWarning().noquote() << "[WsConfig] cannot update" << m_configPath;
}

QString WsConfig::deviceId() const
{
    return m_deviceId;
}
bool WsConfig::hasDeviceKeys() const
{
    return m_hasKeys;
}

// ═══════════════════════════════════════════════════════════════════════
//  Ed25519 设备密钥生成
// ═══════════════════════════════════════════════════════════════════════

void WsConfig::loadOrCreateDeviceKeys()
{
    QJsonObject stored;
    if (readJsonObject(m_deviceKeysPath, &stored)) {
        const QByteArray publicKey = QByteArray::fromBase64(
            stored.value(QStringLiteral("publicKey")).toString().toLatin1(),
            QByteArray::Base64UrlEncoding);
        const QByteArray privateKey = QByteArray::fromBase64(
            stored.value(QStringLiteral("privateKey")).toString().toLatin1(),
            QByteArray::Base64UrlEncoding);
        if (publicKey.size() == 32 && privateKey.size() == 64
            && privateKey.right(32) == publicKey) {
            memcpy(m_ed25519Pk, publicKey.constData(), 32);
            memcpy(m_ed25519Sk, privateKey.constData(), 64);
            m_hasKeys = true;
        }
    }

    if (!m_hasKeys) {
        ed25519_create_keypair(m_ed25519Pk, m_ed25519Sk);
        m_hasKeys = true;

        const QByteArray publicKey(reinterpret_cast<const char *>(m_ed25519Pk), 32);
        const QByteArray privateKey(reinterpret_cast<const char *>(m_ed25519Sk), 64);
        QJsonObject object;
        object[QStringLiteral("publicKey")] = QString::fromLatin1(
            publicKey.toBase64(QByteArray::Base64UrlEncoding
                               | QByteArray::OmitTrailingEquals));
        object[QStringLiteral("privateKey")] = QString::fromLatin1(
            privateKey.toBase64(QByteArray::Base64UrlEncoding
                                | QByteArray::OmitTrailingEquals));
        if (!writePrivateJson(m_deviceKeysPath, object))
            qWarning().noquote() << "[WsConfig] cannot persist device keys to"
                                 << m_deviceKeysPath;
    }

    // 公钥 → SHA-256 哈希 → 设备 ID（十六进制字符串，64 字符）
    const QByteArray rawPk(reinterpret_cast<char *>(m_ed25519Pk), 32);
    m_deviceId = QString::fromLatin1(
        QCryptographicHash::hash(rawPk, QCryptographicHash::Sha256).toHex());

    qDebug() << "[WsConfig] Ed25519 keypair ready. deviceId:" << m_deviceId.left(16) << "...";
}

// ═══════════════════════════════════════════════════════════════════════
//  构建带签名的 device 对象
// ═══════════════════════════════════════════════════════════════════════

QJsonObject WsConfig::buildSignedDevice(const QString &challengeNonce) const
{
    QJsonObject dev;
    dev[QStringLiteral("id")] = m_deviceId;
    dev[QStringLiteral("nonce")] = challengeNonce;

    // 如果密钥不可用，返回不含签名的 device（Gateway 可能拒绝）
    if (!m_hasKeys)
        return dev;

    const qint64 signedAt = QDateTime::currentMSecsSinceEpoch();

    // ── 组装 v2 签名 payload ──
    // 格式：v2|{deviceId}|{clientId}|{mode}|{role}|{scopes}|{signedAt}|{token}|{nonce}
    const QString scopeStr = QStringLiteral("operator.admin,operator.approvals,operator.pairing");
    const QString payload = QStringLiteral("v2|%1|%2|%3|%4|%5|%6|%7|%8")
                                .arg(m_deviceId, m_clientId, m_clientMode, m_role, scopeStr)
                                .arg(signedAt)
                                .arg(m_token, challengeNonce);

    const QByteArray msg = payload.toUtf8();

    // ── 使用 Ed25519 私钥对 payload 签名 ──
    uint8_t sig[64];
    ed25519_sign(sig,
                 reinterpret_cast<const uint8_t *>(msg.constData()),
                 static_cast<size_t>(msg.size()),
                 m_ed25519Sk);

    // ── 将公钥和签名编码为 Base64Url（无填充） ──
    const QByteArray rawPk(reinterpret_cast<const char *>(m_ed25519Pk), 32);
    const QByteArray rawSig(reinterpret_cast<const char *>(sig), 64);

    dev[QStringLiteral("publicKey")] = QString::fromLatin1(
        rawPk.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    dev[QStringLiteral("signature")] = QString::fromLatin1(
        rawSig.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    dev[QStringLiteral("signedAt")] = signedAt;

    return dev;
}

// ═══════════════════════════════════════════════════════════════════════
//  构建完整的 connect 握手参数
// ═══════════════════════════════════════════════════════════════════════

QJsonObject WsConfig::buildConnectParams(const QString &challengeNonce) const
{
    // ── auth 认证块 ──
    QJsonObject auth;
    auth[QStringLiteral("token")] = m_token;

    // ── client 客户端身份块 ──
    QJsonObject client;
    client[QStringLiteral("id")] = m_clientId;
    client[QStringLiteral("version")] = m_clientVersion;
    client[QStringLiteral("platform")] = m_clientPlatform;
    client[QStringLiteral("mode")] = m_clientMode;

    // ── 组装顶层 params ──
    QJsonObject params;
    params[QStringLiteral("minProtocol")] = m_minProtocol;
    params[QStringLiteral("maxProtocol")] = m_maxProtocol;
    params[QStringLiteral("client")] = client;
    params[QStringLiteral("role")] = m_role;
    params[QStringLiteral("scopes")] = m_scopes;
    // 与 OpenClaw GATEWAY_CLIENT_CAPS.TOOL_EVENTS 一致；无此项时 chat.send 不会
    // registerToolEventRecipient，agent 流中的 tool start/result 不会推送到本连接。
    QJsonArray caps;
    caps.append(QStringLiteral("tool-events"));
    params[QStringLiteral("caps")] = caps;
    params[QStringLiteral("auth")] = auth;
    params[QStringLiteral("locale")] = QStringLiteral("zh-CN");
    params[QStringLiteral("userAgent")] = QStringLiteral("AetherStudy-Qt/1.0");
    params[QStringLiteral("device")] = buildSignedDevice(challengeNonce);

    return params;
}
