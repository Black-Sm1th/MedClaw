/**
 * @file ws_config.cpp
 * @brief WebSocket 连接配置类 —— 实现
 */
#include "ws_config.h"
#include "ed25519_local.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QProcessEnvironment>
#include <cstring>

static QString readNestedToken(const QJsonObject &root, const QStringList &path)
{
    QJsonValue cur(root);
    for (const QString &p : path) {
        if (!cur.isObject())
            return QString();
        cur = cur.toObject().value(p);
    }
    return cur.isString() ? cur.toString() : QString();
}

static QString resolveGatewayTokenFromConfig()
{
    const QString cfgPath = QDir::homePath() + QStringLiteral("/.openclaw/openclaw.json");
    QFile f(cfgPath);
    if (!f.open(QIODevice::ReadOnly))
        return QString();

    const QByteArray raw = f.readAll();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return QString();

    const QJsonObject root = doc.object();
    const QStringList candidates = {
        readNestedToken(root, {QStringLiteral("gateway"), QStringLiteral("token")}),
        readNestedToken(root, {QStringLiteral("gateway"), QStringLiteral("auth"), QStringLiteral("token")}),
        readNestedToken(root, {QStringLiteral("auth"), QStringLiteral("token")}),
        readNestedToken(root, {QStringLiteral("token")})
    };
    for (const QString &t : candidates) {
        if (!t.trimmed().isEmpty())
            return t.trimmed();
    }
    return QString();
}

static QString resolveGatewayToken(const QString &fallback)
{
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    const QString fromEnv = env.value(QStringLiteral("OPENCLAW_GATEWAY_TOKEN")).trimmed();
    if (!fromEnv.isEmpty())
        return fromEnv;

    const QString fromConfig = resolveGatewayTokenFromConfig();
    if (!fromConfig.isEmpty())
        return fromConfig;

    return fallback;
}

// ═══════════════════════════════════════════════════════════════════════
//  构造 / 初始化
// ═══════════════════════════════════════════════════════════════════════

WsConfig::WsConfig()
    // ── 服务器默认配置 ──
    : m_serverUrl(QStringLiteral("ws://127.0.0.1:18789"))
    // ── Token：Linux ARM 部署使用独立 Token ──
#if defined(Q_OS_LINUX) && defined(Q_PROCESSOR_ARM)
    , m_token(QStringLiteral("25e30855b27e123e31731de3769e4149380b8a5f89f3f5b5"))
#else
    , m_token(QStringLiteral("25e30855b27e123e31731de3769e4149380b8a5f89f3f5b5"))
#endif
    // ── 客户端身份（需与 Gateway 白名单中的 client.id 匹配） ──
    // Windows 部署的 OpenClaw-CN 使用 clawdbot-control-ui
    // Linux 部署的标准 OpenClaw 使用 openclaw-control-ui
#if defined(Q_OS_LINUX)
    , m_clientId(QStringLiteral("openclaw-control-ui"))
#else
    , m_clientId(QStringLiteral("openclaw-control-ui"))
#endif
    , m_clientVersion(QStringLiteral("dev"))
    // ── 平台标识：编译期自动检测 ──
#if defined(Q_OS_WIN)
    , m_clientPlatform(QStringLiteral("Win32"))
#elif defined(Q_OS_LINUX) && defined(Q_PROCESSOR_ARM)
    , m_clientPlatform(QStringLiteral("Linux x86_64"))
#elif defined(Q_OS_LINUX)
    , m_clientPlatform(QStringLiteral("Linux"))
#elif defined(Q_OS_MACOS)
    , m_clientPlatform(QStringLiteral("MacIntel"))
#else
    , m_clientPlatform(QStringLiteral("Unknown"))
#endif
    , m_clientMode(QStringLiteral("webchat"))
    // ── 协议版本 & 角色 ──
    , m_minProtocol(3)
    , m_maxProtocol(3)
    , m_role(QStringLiteral("operator"))
    , m_scopes(QJsonArray({
          QStringLiteral("operator.admin"),
          QStringLiteral("operator.approvals"),
          QStringLiteral("operator.pairing")
      }))
    // ── Ed25519 密钥初始值 ──
    , m_hasKeys(false)
{
    memset(m_ed25519Pk, 0, sizeof(m_ed25519Pk));
    memset(m_ed25519Sk, 0, sizeof(m_ed25519Sk));

    m_token = resolveGatewayToken(m_token);
    qDebug() << "[WsConfig] gateway token loaded, length:" << m_token.length();

    // 在构造阶段即生成设备密钥，确保后续握手时密钥可用
    initDeviceKeys();
}

// ═══════════════════════════════════════════════════════════════════════
//  Getter / Setter
// ═══════════════════════════════════════════════════════════════════════

QString WsConfig::serverUrl()     const { return m_serverUrl; }
void    WsConfig::setServerUrl(const QString &url) { m_serverUrl = url; }

QString WsConfig::token()         const { return m_token; }
void    WsConfig::setToken(const QString &token) { m_token = token; }

QString WsConfig::deviceId()      const { return m_deviceId; }
bool    WsConfig::hasDeviceKeys() const { return m_hasKeys; }

// ═══════════════════════════════════════════════════════════════════════
//  Ed25519 设备密钥生成
// ═══════════════════════════════════════════════════════════════════════

void WsConfig::initDeviceKeys()
{
    // 步骤 1：生成 Ed25519 密钥对（内嵌纯 C++ 实现，无需外部 OpenSSL）
    ed25519_create_keypair(m_ed25519Pk, m_ed25519Sk);
    m_hasKeys = true;

    // 步骤 2：公钥 → SHA-256 哈希 → 设备 ID（十六进制字符串，64 字符）
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
    dev[QStringLiteral("id")]    = m_deviceId;
    dev[QStringLiteral("nonce")] = challengeNonce;

    // 如果密钥不可用，返回不含签名的 device（Gateway 可能拒绝）
    if (!m_hasKeys)
        return dev;

    const qint64 signedAt = QDateTime::currentMSecsSinceEpoch();

    // ── 组装 v2 签名 payload ──
    // 格式：v2|{deviceId}|{clientId}|{mode}|{role}|{scopes}|{signedAt}|{token}|{nonce}
    QStringList scopeList;
    for (const QJsonValue &v : m_scopes)
        scopeList.append(v.toString());
    const QString scopeStr = scopeList.join(QLatin1Char(','));
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
    client[QStringLiteral("id")]       = m_clientId;
    client[QStringLiteral("version")]  = m_clientVersion;
    client[QStringLiteral("platform")] = m_clientPlatform;
    client[QStringLiteral("mode")]     = m_clientMode;
    client[QStringLiteral("instanceId")] = m_deviceId;

    // ── 组装顶层 params ──
    QJsonObject params;
    params[QStringLiteral("minProtocol")] = m_minProtocol;
    params[QStringLiteral("maxProtocol")] = m_maxProtocol;
    params[QStringLiteral("client")]      = client;
    params[QStringLiteral("role")]        = m_role;
    params[QStringLiteral("scopes")]      = m_scopes;
    params[QStringLiteral("caps")]        = QJsonArray({QStringLiteral("tool-events")});
    params[QStringLiteral("auth")]        = auth;
    params[QStringLiteral("locale")]      = QStringLiteral("zh-CN");
    params[QStringLiteral("userAgent")]   = QStringLiteral("MedClaw-Qt/1.0");
    params[QStringLiteral("device")]      = buildSignedDevice(challengeNonce);

    return params;
}
