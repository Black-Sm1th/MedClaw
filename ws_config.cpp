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
    add(QStringLiteral("Medical-Skills"), QStringLiteral("~/Medical-Skills"));
    add(QStringLiteral("Scientific-Skills"), QStringLiteral("~/Scientific-Skills"));
    return a;
}

static QJsonObject makeShortcutCard(const QString &name,
                                    const QString &description,
                                    const QString &icon,
                                    const QString &color,
                                    const QString &prompt)
{
    QJsonObject o;
    o[QStringLiteral("name")] = name;
    o[QStringLiteral("description")] = description;
    o[QStringLiteral("icon")] = icon;
    o[QStringLiteral("color")] = color;
    o[QStringLiteral("prompt")] = prompt;
    o[QStringLiteral("files")] = QJsonArray();
    return o;
}

static QJsonObject makeShortcutGroup(const QString &name,
                                     const QString &icon,
                                     const QString &color,
                                     const QJsonArray &tools,
                                     const QJsonArray &cards)
{
    QJsonObject o;
    o[QStringLiteral("name")] = name;
    o[QStringLiteral("icon")] = icon;
    o[QStringLiteral("tools")] = tools;
    o[QStringLiteral("color")] = color;
    o[QStringLiteral("cards")] = cards;
    return o;
}

/// AppData/config.json 缺省 shortcut（与产品内置主界面快捷入口一致）
static QJsonArray defaultShortcutArray()
{
    const QString cMain = QStringLiteral("#0F006BFF");
    const QString cWarn = QStringLiteral("#0FFF3D40");

    QJsonArray g1cards;
    g1cards.append(makeShortcutCard(
        QStringLiteral("\u53ef\u89c6\u5316\u8bbe\u8ba1\u5e08"),
        QStringLiteral(
            "\u6839\u636e\u6570\u636e\u5b57\u6bb5\u667a\u80fd\u751f\u6210\u591a\u7c7b\u578b\u56fe\u8868\uff0c"
            "\u652f\u6301\u6837\u5f0f\u7f8e\u5316\u4e0e\u4ea4\u4e92\u5c55\u793a\u3002"),
        QStringLiteral("qrc:/images/shortcut/1.1.png"),
        cMain,
        QString()));
    g1cards.append(makeShortcutCard(
        QStringLiteral("\u6a21\u578b\u8bad\u7ec3\u5e08"),
        QStringLiteral(
            "\u5feb\u901f\u6784\u5efa\u4e8c\u5206\u7c7b\u6a21\u578b\uff0c\u5b8c\u6210\u8bad\u7ec3\u3001\u8bc4\u4f30"
            "\u548c\u7279\u5f81\u91cd\u8981\u6027\u5206\u6790\u3002"),
        QStringLiteral("qrc:/images/shortcut/1.2.png"),
        cMain,
        QString()));
    g1cards.append(makeShortcutCard(
        QStringLiteral("\u6570\u636e\u6e05\u6d17\u5e08"),
        QStringLiteral(
            "\u81ea\u52a8\u8bc6\u522b\u7f3a\u5931\u503c\u4e0e\u5f02\u5e38\u6570\u636e\uff0c\u5b8c\u6210\u5b57\u6bb5"
            "\u6e05\u6d17\u4e0e\u7ed3\u6784\u4f18\u5316\uff0c\u63d0\u5347\u6570\u636e\u8d28\u91cf\u3002"),
        QStringLiteral("qrc:/images/shortcut/1.3.png"),
        cMain,
        QString()));
    g1cards.append(makeShortcutCard(
        QStringLiteral("\u7edf\u8ba1\u5206\u6790\u5e08"),
        QStringLiteral(
            "\u63d0\u4f9b\u63cf\u8ff0\u6027\u7edf\u8ba1\u3001\u5047\u8bbe\u68c0\u9a8c\u548c\u56de\u5f52\u5efa\u6a21"
            "\u7b49\u6838\u5fc3\u5206\u6790\u529f\u80fd\uff0c\u9002\u7528\u4e8e\u901a\u7528\u6570\u636e\u7814\u7a76"
            "\u3002"),
        QStringLiteral("qrc:/images/shortcut/1.4.png"),
        cMain,
        QString()));

    QJsonArray g1tools;
    QJsonObject g1 = makeShortcutGroup(QStringLiteral("\u6df1\u5ea6\u95ee\u6570"),
                                       QStringLiteral("qrc:/images/shortcut/1.png"),
                                       cMain,
                                       g1tools,
                                       g1cards);

    QJsonArray g2cards;
    g2cards.append(makeShortcutCard(
        QStringLiteral("\u5355\u7ec6\u80de RNA-seq"),
        QStringLiteral(
            "\u5355\u7ec6\u80de RNA \u6d4b\u5e8f\u6a21\u5757\uff0c\u7cbe\u51c6\u6355\u83b7\u5355\u4e2a\u7ec6\u80de"
            "\u57fa\u56e0\u8868\u8fbe\u8c31,\u89e3\u6790\u7ec6\u80de\u5f02\u8d28\u6027\uff0c\u5b9e\u73b0\u7ec6\u80de"
            "\u5206\u7fa4\u3001\u62df\u65f6\u5e8f\u5206\u6790\u7b49\u6838\u5fc3\u751f\u4fe1\u5206\u6790\u529f\u80fd"
            "\u3002"),
        QStringLiteral("qrc:/images/shortcut/2.1.png"),
        cMain,
        QString()));
    g2cards.append(makeShortcutCard(
        QStringLiteral("\u7a7a\u95f4\u8f6c\u5f55\u7ec4"),
        QStringLiteral(
            "\u7a7a\u95f4\u8f6c\u5f55\u7ec4\u6a21\u5757\uff0c\u878d\u5408\u57fa\u56e0\u8868\u8fbe\u4e0e\u7a7a\u95f4"
            "\u4f4d\u7f6e\u4fe1\u606f\uff0c\u539f\u4f4d\u89e3\u6790\u7ec4\u7ec7\u8868\u8fbe\u6a21\u5f0f\uff0c\u652f"
            "\u6301\u7a7a\u95f4\u805a\u7c7b\u3001\u533a\u57df\u5dee\u5f02\u5206\u6790\u7b49\u5173\u952e\u5206"
            "\u3002"),
        QStringLiteral("qrc:/images/shortcut/2.2.png"),
        cMain,
        QString()));

    QJsonArray g2tools;
    QJsonObject g2 = makeShortcutGroup(QStringLiteral("\u751f\u4fe1\u5206\u6790"),
                                       QStringLiteral("qrc:/images/shortcut/2.png"),
                                       cMain,
                                       g2tools,
                                       g2cards);

    QJsonArray g3tools;
    g3tools.append(QStringLiteral("kb_ingest"));
    g3tools.append(QStringLiteral("kb_manage"));
    g3tools.append(QStringLiteral("kb_search"));

    QJsonArray g3cards;
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u6279\u91cf\u5bfc\u5165\u6587\u4ef6/\u76ee\u5f55\u5230\u77e5\u8bc6\u5e93"),
        QStringLiteral(
            "\u5c06\u672c\u5730\u6587\u4ef6\u6216\u6574\u4e2a\u6587\u4ef6\u5939\uff08PDF/DOCX/MD/TXT\uff09\u5bfc"
            "\u5165\u5230\u6307\u5b9a\u7684\u77e5\u8bc6\u5e93\u96c6\u5408\u4e2d\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.1.png"),
        cMain,
        QStringLiteral(
            "\u8bf7\u5e2e\u6211\u5c06\u6587\u4ef6 /home/user/docs/\u5e74\u5ea6\u62a5\u544a.pdf "
            "\u5bfc\u5165\u5230\u77e5\u8bc6\u5e93\u96c6\u5408\u201cA\u6587\u6863\u201d\u4e2d\u3002")));
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u5217\u51fa\u6240\u6709\u77e5\u8bc6\u5e93\u96c6\u5408"),
        QStringLiteral("\u67e5\u770b\u5f53\u524d\u7cfb\u7edf\u4e2d\u5df2\u7ecf\u521b\u5efa\u7684\u6240\u6709\u77e5"
                       "\u8bc6\u5e93\u96c6\u5408\u7684\u540d\u79f0\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.2.png"),
        cMain,
        QStringLiteral(
            "\u8bf7\u5217\u51fa\u5f53\u524d\u201c\u9879\u76ee\u77e5\u8bc6\u5e93\u201d\u4e2d\u6240\u6709\u7684\u96c6"
            "\u5408\uff0c\u4ee5\u7eaf\u6587\u672c\u5217\u8868\u5f62\u5f0f\u8fd4\u56de\u6240\u6709\u540d\u79f0\uff0c"
            "\u6bcf\u884c\u4e00\u4e2a\uff0c\u5e76\u540c\u65f6\u663e\u793a\u6bcf\u4e2a\u6587\u6863\u6570\u91cf\u3002")));
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u5217\u51fa\u6307\u5b9a\u96c6\u5408\u4e2d\u7684\u6240\u6709\u6587\u6863"),
        QStringLiteral(
            "\u67e5\u770b\u67d0\u4e2a\u77e5\u8bc6\u5e93\u96c6\u5408\u91cc\u5df2\u7ecf\u5165\u5e93\u4e86\u54ea\u4e9b"
            "\u6587\u6863\uff08\u6587\u6863\u540d\u79f0\u3001ID\u7b49\uff09\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.3.png"),
        cMain,
        QStringLiteral("\u8bf7\u5217\u51fa\u77e5\u8bc6\u5e93\u96c6\u5408\u201c\u4eea\u5668\u6587\u6863\u201d\u4e2d"
                       "\u7684\u6240\u6709\u6587\u6863\u3002")));
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u5220\u9664\u6307\u5b9a\u6587\u6863\uff08\u6309\u6587\u6863ID\u6216\u540d\u79f0\uff09"),
        QStringLiteral(
            "\u4ece\u67d0\u4e2a\u77e5\u8bc6\u5e93\u96c6\u5408\u4e2d\u5220\u9664\u4e00\u4e2a\u6216\u591a\u4e2a\u6307\u5b9a"
            "\u7684\u6587\u6863\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.4.png"),
        cWarn,
        QStringLiteral(
            "\u8bf7\u4ece\u77e5\u8bc6\u5e93\u96c6\u5408\u201c\u4eea\u5668\u6587\u6863\u201d\u4e2d\u5220\u9664\u6587\u6863"
            "\u540d\u79f0\u4e3a\u201c2023\u5e74\u5ea6\u62a5\u544a.pdf\u201d\u7684\u6587\u6863\u3002")));
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u5220\u9664\u6574\u4e2a\u77e5\u8bc6\u5e93\u96c6\u5408\uff08\u542b\u5185\u90e8\u6240\u6709"
                       "\u6587\u6863\uff09"),
        QStringLiteral(
            "\u5f7b\u5e95\u5220\u9664\u4e00\u4e2a\u77e5\u8bc6\u5e93\u96c6\u5408\u53ca\u5176\u5185\u90e8\u7684\u6240\u6709"
            "\u6587\u6863\uff0c\u64cd\u4f5c\u4e0d\u53ef\u9006\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.5.png"),
        cWarn,
        QStringLiteral("\u8bf7\u5220\u9664\u6574\u4e2a\u77e5\u8bc6\u5e93\u96c6\u5408\u201c\u4e34\u65f6\u6d4b\u8bd5"
                       "\u96c6\u201d")));
    g3cards.append(makeShortcutCard(
        QStringLiteral("\u8bed\u4e49\u68c0\u7d22\u77e5\u8bc6\u5e93"),
        QStringLiteral(
            "\u5728\u6307\u5b9a\u77e5\u8bc6\u5e93\u96c6\u5408\u4e2d\uff0c\u6839\u636e\u4f60\u7684\u95ee\u9898\u6216"
            "\u5173\u952e\u8bcd\uff0c\u8fd4\u56de\u6700\u76f8\u5173\u7684\u6587\u6863\u7247\u6bb5\uff08\u8bed\u4e49"
            "\u5339\u914d\uff09\u3002"),
        QStringLiteral("qrc:/images/shortcut/3.6.png"),
        cMain,
        QStringLiteral(
            "\u8bf7\u5728\u77e5\u8bc6\u5e93\u96c6\u5408\u201c\u4eea\u5668\u77e5\u8bc6\u5e93\u201d\u4e2d\u68c0\u7d22"
            "\uff1a\u201c\u4eea\u5668\u7684\u56fd\u5bb6\u8d28\u91cf\u6807\u51c6\u662f\u4ec0\u4e48\uff1f\u201d "
            "\u8fd4\u56de\u6700\u76f8\u5173\u76843\u4e2a\u6587\u6863\u7247\u6bb5\u3002")));

    QJsonObject g3 = makeShortcutGroup(QStringLiteral("\u77e5\u8bc6\u5e93"),
                                       QStringLiteral("qrc:/images/shortcut/3.png"),
                                       cMain,
                                       g3tools,
                                       g3cards);

    QJsonArray out;
    out.append(g1);
    out.append(g2);
    out.append(g3);
    return out;
}

void parseSkillMarketCategoriesFromJson(const QJsonArray &arr, QVariantList *out)
{
    out->clear();
    for (const QJsonValue &v : arr) {
        if (!v.isObject())
            continue;
        const QJsonObject o = v.toObject();
        const QString name = o.value(QStringLiteral("name")).toString().trimmed();
        const QString path = o.value(QStringLiteral("path")).toString().trimmed();
        if (name.isEmpty() || path.isEmpty() || path == QLatin1Char('.')
            || path == QStringLiteral("."))
            continue;
        QVariantMap m;
        m[QStringLiteral("name")] = name;
        m[QStringLiteral("path")] = path;
        out->append(m);
    }
    if (out->isEmpty()) {
        QVariantMap m;
        m[QStringLiteral("name")] = QStringLiteral("\u5168\u90e8");
        m[QStringLiteral("path")] = QStringLiteral("~/skills");
        out->append(m);
    }
}

static QVariantList jsonArrayToVariantList(const QJsonArray &arr)
{
    QVariantList out;
    for (const QJsonValue &v : arr) {
        if (v.isString())
            out.append(v.toString());
        else if (v.isDouble())
            out.append(v.toDouble());
        else if (v.isBool())
            out.append(v.toBool());
        else if (v.isObject())
            out.append(v.toObject().toVariantMap());
        else if (v.isArray())
            out.append(QVariant(jsonArrayToVariantList(v.toArray())));
    }
    return out;
}

void parseShortcutsFromJson(const QJsonArray &arr, QVariantList *out)
{
    out->clear();
    for (const QJsonValue &v : arr) {
        if (!v.isObject())
            continue;
        const QJsonObject o = v.toObject();
        const QString name = o.value(QStringLiteral("name")).toString().trimmed();
        if (name.isEmpty())
            continue;
        QVariantMap top;
        top[QStringLiteral("name")] = name;
        top[QStringLiteral("icon")] = o.value(QStringLiteral("icon")).toString();
        top[QStringLiteral("color")] = o.value(QStringLiteral("color")).toString();
        const QJsonValue toolsVal = o.value(QStringLiteral("tools"));
        if (toolsVal.isArray())
            top[QStringLiteral("tools")] = jsonArrayToVariantList(toolsVal.toArray());
        else
            top[QStringLiteral("tools")] = QVariantList();

        QVariantList cardsOut;
        const QJsonArray cardsArr = o.value(QStringLiteral("cards")).toArray();
        for (const QJsonValue &cv : cardsArr) {
            if (!cv.isObject())
                continue;
            const QJsonObject co = cv.toObject();
            const QString cname = co.value(QStringLiteral("name")).toString().trimmed();
            if (cname.isEmpty())
                continue;
            QVariantMap cm;
            cm[QStringLiteral("name")] = cname;
            cm[QStringLiteral("description")] = co.value(QStringLiteral("description")).toString();
            cm[QStringLiteral("icon")] = co.value(QStringLiteral("icon")).toString();
            cm[QStringLiteral("prompt")] = co.value(QStringLiteral("prompt")).toString();
            cm[QStringLiteral("color")] = co.value(QStringLiteral("color")).toString();
            const QJsonValue filesVal = co.value(QStringLiteral("files"));
            if (filesVal.isArray())
                cm[QStringLiteral("files")] = jsonArrayToVariantList(filesVal.toArray());
            else
                cm[QStringLiteral("files")] = QVariantList();
            cardsOut.append(cm);
        }
        top[QStringLiteral("cards")] = cardsOut;
        out->append(top);
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
          "faaefb8293b41aaad4dfa2a2d25740505183f59286a348fe"))
    , m_skillsStoragePath(QStringLiteral("~/MedClaw/skills"))
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
        "faaefb8293b41aaad4dfa2a2d25740505183f59286a348fe");
    static const QString kDefaultClientId =
        QStringLiteral("openclaw-control-ui");
    static const QString kDefaultSkillsStoragePath =
        QStringLiteral("~/MedClaw/skills");
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
        o[QStringLiteral("skillsStoragePath")] = m_skillsStoragePath;
        o[QStringLiteral("skillMarketCategories")] = defaultSkillMarketCategoryArray();
        o[QStringLiteral("shortcut")] = defaultShortcutArray();
        writeDefaults(o);
        parseSkillMarketCategoriesFromJson(defaultSkillMarketCategoryArray(),
                                           &m_skillMarketCategories);
        parseShortcutsFromJson(defaultShortcutArray(), &m_shortcuts);
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
    if (!merged.contains(QStringLiteral("shortcut"))) {
        merged[QStringLiteral("shortcut")] = defaultShortcutArray();
        mergedDirty = true;
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

    m_skillsStoragePath = merged.value(QStringLiteral("skillsStoragePath")).toString().trimmed();
    m_llmJudgmentEnabled = merged.value(QStringLiteral("llmJudgmentEnabled")).toBool(false);

    if (m_serverUrl.isEmpty())
        m_serverUrl = kDefaultServer;
    if (m_token.isEmpty())
        m_token = kDefaultToken;
    if (m_clientId.isEmpty())
        m_clientId = kDefaultClientId;
    if (m_skillsStoragePath.isEmpty())
        m_skillsStoragePath = kDefaultSkillsStoragePath;

    parseSkillMarketCategoriesFromJson(catArr, &m_skillMarketCategories);
    const QJsonValue shortcutVal = merged.value(QStringLiteral("shortcut"));
    if (shortcutVal.isArray())
        parseShortcutsFromJson(shortcutVal.toArray(), &m_shortcuts);
    else
        parseShortcutsFromJson(QJsonArray(), &m_shortcuts);

    qDebug().noquote() << "[WsConfig] loaded" << path << "serverUrl=" << m_serverUrl;
}

// ═══════════════════════════════════════════════════════════════════════
//  Getter / Setter
// ═══════════════════════════════════════════════════════════════════════

QString WsConfig::serverUrl()     const { return m_serverUrl; }
void    WsConfig::setServerUrl(const QString &url) { m_serverUrl = url; }

QString WsConfig::token()         const { return m_token; }
void    WsConfig::setToken(const QString &token) { m_token = token; }

QString WsConfig::skillsStoragePath() const { return m_skillsStoragePath; }
void    WsConfig::setSkillsStoragePath(const QString &path) { m_skillsStoragePath = path; }

QVariantList WsConfig::skillMarketCategories() const { return m_skillMarketCategories; }

QVariantList WsConfig::shortcuts() const { return m_shortcuts; }

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


