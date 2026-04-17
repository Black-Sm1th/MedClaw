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
#include <QJsonObject>
#include <QJsonValue>
#include <cstring>

namespace {

QJsonArray defaultSkillMarketCategoryArray()
{
    QJsonArray a;
    auto add = [&](const QString &name, const QString &path) {
        QJsonObject o;
        o[QStringLiteral("name")] = name;
        o[QStringLiteral("path")] = path;
        a.append(o);
    };
    add(QStringLiteral("Medical-Skills"), QStringLiteral("/home/poc-henan/Medical-Skills"));
    add(QStringLiteral("Scientific-Skills"), QStringLiteral("/home/poc-henan/Scientific-Skills"));
    return a;
}

void parseSkillMarketCategoriesFromJson(const QJsonArray &arr, QVariantList *out)
{
    out->clear();
    for (const QJsonValue &v : arr) {
        if (!v.isObject())
            continue;
        const QJsonObject o = v.toObject();
        const QString name = o.value(QStringLiteral("name")).toString().trimmed();
        if (name.isEmpty())
            continue;
        QVariantMap m;
        m[QStringLiteral("name")] = name;
        m[QStringLiteral("path")] = o.value(QStringLiteral("path")).toString();
        out->append(m);
    }
    if (out->isEmpty()) {
        QVariantMap m;
        m[QStringLiteral("name")] = QStringLiteral("\u5168\u90e8");
        m[QStringLiteral("path")] = QString();
        out->append(m);
    }
}

} // namespace

// ═══════════════════════════════════════════════════════════════════════
//  构造 / 初始化
// ═══════════════════════════════════════════════════════════════════════

WsConfig::WsConfig()
    // ── 占位；loadOrCreatePersistentConfig() 从 AppData/config.json 覆盖 ──
    : m_serverUrl(QStringLiteral("ws://127.0.0.1:18789"))
    , m_token(QStringLiteral(
          "a38eee0215d92267ee55c9ecf2dcdb6c2ee1e613a00c6d26"))
    , m_skillMarketPath(QStringLiteral("~/skills"))
    , m_skillsStoragePath(QStringLiteral("~/medclaw/MedClaw/skills"))
    , m_clientId(QStringLiteral("openclaw-control-ui"))
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
    loadOrCreatePersistentConfig();

    memset(m_ed25519Pk, 0, sizeof(m_ed25519Pk));
    memset(m_ed25519Sk, 0, sizeof(m_ed25519Sk));

    // 在构造阶段即生成设备密钥，确保后续握手时密钥可用
    initDeviceKeys();
}

void WsConfig::loadOrCreatePersistentConfig()
{
    static const QString kDefaultServer =
        QStringLiteral("ws://127.0.0.1:18789");
    static const QString kDefaultToken = QStringLiteral(
        "f22212ebdd26bcc13d041f66375c3f60617c387021ebdd63");
    static const QString kDefaultClientId =
        QStringLiteral("openclaw-control-ui");
    static const QString kDefaultSkillMarketPath =
        QStringLiteral("~/skills");
    static const QString kDefaultSkillsStoragePath =
        QStringLiteral("~/medclaw/MedClaw/skills");
    const QString base = QStringLiteral("AppData/config/");
    QDir().mkpath(base);
    const QString path = base + QStringLiteral("config.json");

    auto writeDefaults = [&](const QJsonObject &o) {
        QFile out(path);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qWarning() << "[WsConfig] cannot write" << path;
            return;
        }
        out.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
        out.close();
        qDebug().noquote() << "[WsConfig] wrote" << path;
    };

    QFile f(path);
    if (!f.exists()) {
        m_serverUrl = kDefaultServer;
        m_token     = kDefaultToken;
        m_clientId  = kDefaultClientId;
        QJsonObject o;
        o[QStringLiteral("serverUrl")]        = m_serverUrl;
        o[QStringLiteral("token")]            = m_token;
        o[QStringLiteral("clientId")]         = m_clientId;
        o[QStringLiteral("skillMarketPath")]  = m_skillMarketPath;
        o[QStringLiteral("skillsStoragePath")] = m_skillsStoragePath;
        o[QStringLiteral("skillMarketCategories")] = defaultSkillMarketCategoryArray();
        writeDefaults(o);
        parseSkillMarketCategoriesFromJson(defaultSkillMarketCategoryArray(),
                                           &m_skillMarketCategories);
        return;
    }

    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "[WsConfig] cannot read" << path;
        return;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) {
        qWarning() << "[WsConfig] invalid JSON in" << path;
        return;
    }

    QJsonObject merged = doc.object();
    bool mergedDirty = false;
    if (merged.value(QStringLiteral("skillMarketPath")).toString().trimmed().isEmpty()) {
        merged[QStringLiteral("skillMarketPath")] = kDefaultSkillMarketPath;
        mergedDirty = true;
    }
    if (merged.value(QStringLiteral("skillsStoragePath")).toString().trimmed().isEmpty()) {
        merged[QStringLiteral("skillsStoragePath")] = kDefaultSkillsStoragePath;
        mergedDirty = true;
    }
    const QJsonValue catVal = merged.value(QStringLiteral("skillMarketCategories"));
    QJsonArray catArr;
    if (!catVal.isArray() || catVal.toArray().isEmpty()) {
        catArr = defaultSkillMarketCategoryArray();
        merged[QStringLiteral("skillMarketCategories")] = catArr;
        mergedDirty = true;
    } else {
        catArr = catVal.toArray();
    }
    if (mergedDirty)
        writeDefaults(merged);

    if (merged.contains(QStringLiteral("serverUrl"))) {
        const QString u = merged.value(QStringLiteral("serverUrl")).toString().trimmed();
        if (!u.isEmpty())
            m_serverUrl = u;
    }
    if (merged.contains(QStringLiteral("token"))) {
        const QString t = merged.value(QStringLiteral("token")).toString().trimmed();
        if (!t.isEmpty())
            m_token = t;
    }
    if (merged.contains(QStringLiteral("clientId"))) {
        const QString c = merged.value(QStringLiteral("clientId")).toString().trimmed();
        if (!c.isEmpty())
            m_clientId = c;
    }

    m_skillMarketPath = merged.value(QStringLiteral("skillMarketPath")).toString().trimmed();
    m_skillsStoragePath = merged.value(QStringLiteral("skillsStoragePath")).toString().trimmed();
    m_llmJudgmentEnabled = merged.value(QStringLiteral("llmJudgmentEnabled")).toBool(false);

    if (m_serverUrl.isEmpty())
        m_serverUrl = kDefaultServer;
    if (m_token.isEmpty())
        m_token = kDefaultToken;
    if (m_clientId.isEmpty())
        m_clientId = kDefaultClientId;
    if (m_skillMarketPath.isEmpty())
        m_skillMarketPath = kDefaultSkillMarketPath;
    if (m_skillsStoragePath.isEmpty())
        m_skillsStoragePath = kDefaultSkillsStoragePath;

    parseSkillMarketCategoriesFromJson(catArr, &m_skillMarketCategories);

    qDebug().noquote() << "[WsConfig] loaded" << path << "serverUrl=" << m_serverUrl;
}

// ═══════════════════════════════════════════════════════════════════════
//  Getter / Setter
// ═══════════════════════════════════════════════════════════════════════

QString WsConfig::serverUrl()     const { return m_serverUrl; }
void    WsConfig::setServerUrl(const QString &url) { m_serverUrl = url; }

QString WsConfig::token()         const { return m_token; }
void    WsConfig::setToken(const QString &token) { m_token = token; }

QString WsConfig::skillMarketPath() const { return m_skillMarketPath; }
void    WsConfig::setSkillMarketPath(const QString &path) { m_skillMarketPath = path; }

QString WsConfig::skillsStoragePath() const { return m_skillsStoragePath; }
void    WsConfig::setSkillsStoragePath(const QString &path) { m_skillsStoragePath = path; }

QVariantList WsConfig::skillMarketCategories() const { return m_skillMarketCategories; }

bool    WsConfig::llmJudgmentEnabled() const { return m_llmJudgmentEnabled; }
void    WsConfig::setLlmJudgmentEnabled(bool enabled)
{
    m_llmJudgmentEnabled = enabled;
    const QString path = QStringLiteral("AppData/config/config.json");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return;
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject())
        return;
    QJsonObject o = doc.object();
    o[QStringLiteral("llmJudgmentEnabled")] = enabled;
    QFile out(path);
    if (out.open(QIODevice::WriteOnly | QIODevice::Truncate))
        out.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
}

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
    client[QStringLiteral("id")]       = m_clientId;
    client[QStringLiteral("version")]  = m_clientVersion;
    client[QStringLiteral("platform")] = m_clientPlatform;
    client[QStringLiteral("mode")]     = m_clientMode;

    // ── 组装顶层 params ──
    QJsonObject params;
    params[QStringLiteral("minProtocol")] = m_minProtocol;
    params[QStringLiteral("maxProtocol")] = m_maxProtocol;
    params[QStringLiteral("client")]      = client;
    params[QStringLiteral("role")]        = m_role;
    params[QStringLiteral("scopes")]      = m_scopes;
    // 与 OpenClaw GATEWAY_CLIENT_CAPS.TOOL_EVENTS 一致；无此项时 chat.send 不会
    // registerToolEventRecipient，agent 流中的 tool start/result 不会推送到本连接。
    QJsonArray caps;
    caps.append(QStringLiteral("tool-events"));
    params[QStringLiteral("caps")]        = caps;
    params[QStringLiteral("auth")]        = auth;
    params[QStringLiteral("locale")]      = QStringLiteral("zh-CN");
    params[QStringLiteral("userAgent")]   = QStringLiteral("MedClaw-Qt/1.0");
    params[QStringLiteral("device")]      = buildSignedDevice(challengeNonce);

    return params;
}


