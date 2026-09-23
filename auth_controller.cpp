#include "auth_controller.h"

#include <QDir>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

namespace {
const char kProductionApiBaseUrl[] = "https://www.aethermind.cn/aether";
const char kTestApiBaseUrl[] = "http://111.6.178.34:23212/aether";
#ifdef MEDCLAW_EDITION_GOVERNMENT
const char kGovernmentEnterpriseCode[] = "gov-01";
#endif

QString normalizedBaseUrl(QString url)
{
    url = url.trimmed();
    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);
    return url;
}

QString apiBaseUrlFromEnvironment()
{
    const QString environment = qEnvironmentVariable("MEDCLAW_API_ENV").trimmed().toLower();
    if (environment == QStringLiteral("test"))
        return QString::fromLatin1(kTestApiBaseUrl);
    if (!environment.isEmpty() && environment != QStringLiteral("prod")) {
        qWarning().noquote()
            << "[API] Unsupported MEDCLAW_API_ENV value" << environment
            << "- falling back to prod";
    }
    return QString::fromLatin1(kProductionApiBaseUrl);
}

bool isSecretJsonKey(const QString &key)
{
    const QString normalized = key.toLower();
    return normalized.contains(QStringLiteral("token"))
           || normalized.contains(QStringLiteral("ticket"))
           || normalized.contains(QStringLiteral("password"))
           || normalized == QStringLiteral("apikey")
           || normalized == QStringLiteral("api_key")
           || normalized == QStringLiteral("authorization");
}

QJsonValue redactedJsonValue(const QJsonValue &value)
{
    if (value.isObject()) {
        QJsonObject object = value.toObject();
        for (auto it = object.begin(); it != object.end(); ++it)
            it.value() = isSecretJsonKey(it.key()) ? QJsonValue(QStringLiteral("<redacted>"))
                                                   : redactedJsonValue(it.value());
        return object;
    }
    if (value.isArray()) {
        QJsonArray array = value.toArray();
        for (qsizetype i = 0; i < array.size(); ++i)
            array[i] = redactedJsonValue(array.at(i));
        return array;
    }
    return value;
}

QString bodyForLog(const QByteArray &raw)
{
    if (raw.isEmpty())
        return QStringLiteral("<empty>");
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(raw, &parseError);
    if (parseError.error != QJsonParseError::NoError)
        return QString::fromUtf8(raw);
    if (document.isObject())
        return QString::fromUtf8(QJsonDocument(redactedJsonValue(document.object()).toObject())
                                     .toJson(QJsonDocument::Compact));
    if (document.isArray())
        return QString::fromUtf8(QJsonDocument(redactedJsonValue(document.array()).toArray())
                                     .toJson(QJsonDocument::Compact));
    return QString::fromUtf8(raw);
}

void logApiRequest(const char *method,
                   const QNetworkRequest &request,
                   const QByteArray &body = QByteArray())
{
    QString parameters = bodyForLog(body);
    if (body.isEmpty()) {
        const QString query = QUrlQuery(request.url()).query(QUrl::FullyEncoded);
        parameters = query.isEmpty() ? QStringLiteral("<none>") : query;
    }
    qInfo().noquote() << "[API request]" << method << request.url().toString(QUrl::FullyEncoded)
                      << "parameters:" << parameters;
}

void logApiResponse(QNetworkReply *reply, const QByteArray &body)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    qInfo().noquote() << "[API response]" << reply->url().toString(QUrl::FullyEncoded)
                      << "status:" << status << "networkError:" << reply->error()
                      << reply->errorString() << "body:" << bodyForLog(body);
}

void disableHttp2(QNetworkRequest &request)
{
    // Qt logs expected HTTP/2 401 responses as stream errors. Authentication
    // calls are infrequent, so HTTP/1.1 keeps failures quiet and deterministic.
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
}

QString responseMessage(const QJsonObject &body, const QString &fallback)
{
    QString message = body.value(QStringLiteral("message")).toString().trimmed();
    if (message.isEmpty())
        message = body.value(QStringLiteral("detail")).toString().trimmed();
    return message.isEmpty() ? fallback : message;
}

bool responseSucceeded(const QJsonObject &body)
{
    if (body.value(QStringLiteral("ok")).toBool(false))
        return true;
    const QJsonValue code = body.value(QStringLiteral("code"));
    return (code.isDouble() && code.toInt() == 200)
           || (code.isString() && code.toString() == QStringLiteral("200"));
}

QString userIdFromLoginData(const QJsonObject &data, const QString &phone)
{
    QString userId = data.value(QStringLiteral("userId")).toVariant().toString().trimmed();
    if (userId.isEmpty())
        userId = data.value(QStringLiteral("user_id")).toVariant().toString().trimmed();
    if (userId.isEmpty())
        userId = data.value(QStringLiteral("id")).toVariant().toString().trimmed();
    const QJsonObject user = data.value(QStringLiteral("user")).toObject();
    if (userId.isEmpty() && !user.isEmpty())
        userId = user.value(QStringLiteral("id")).toVariant().toString().trimmed();
    if (userId.isEmpty())
        userId = data.value(QStringLiteral("userInfo"))
                     .toObject()
                     .value(QStringLiteral("id"))
                     .toVariant()
                     .toString()
                     .trimmed();
    return userId.isEmpty() ? QStringLiteral("phone:%1").arg(phone) : userId;
}

bool writeOpenClawModelConfig(const QJsonArray &sourceModels,
                              const QString &stableToken,
                              const QString &apiBaseUrl,
                              QString *errorMessage)
{
    QJsonArray models;
    QString firstModelId;
    QString firstImageModelId;
    QSet<QString> seenIds;
    for (const QJsonValue &value : sourceModels) {
        if (!value.isObject())
            continue;
        QJsonObject model = value.toObject();
        const QString id = model.value(QStringLiteral("id")).toString().trimmed();
        if (id.isEmpty() || seenIds.contains(id))
            continue;
        seenIds.insert(id);
        if (model.value(QStringLiteral("name")).toString().trimmed().isEmpty())
            model[QStringLiteral("name")] = id;
        models.append(model);
        if (firstModelId.isEmpty())
            firstModelId = id;
        const QJsonArray inputs = model.value(QStringLiteral("input")).toArray();
        for (const QJsonValue &input : inputs) {
            if (input.toString() == QLatin1String("image")) {
                firstImageModelId = id;
                break;
            }
        }
    }
    if (models.isEmpty()) {
        if (errorMessage)
            *errorMessage = QStringLiteral("模型列表为空");
        return false;
    }

    QString stateDir = qEnvironmentVariable("OPENCLAW_STATE_DIR").trimmed();
    if (stateDir.isEmpty())
        stateDir = QDir(QDir::homePath()).filePath(QStringLiteral(".openclaw"));
    const QString configPath = QDir(stateDir).filePath(QStringLiteral("openclaw.json"));
    QFile input(configPath);
    QJsonObject config;
    if (input.exists()) {
        if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
            if (errorMessage)
                *errorMessage = QStringLiteral("无法读取 OpenClaw 配置：%1").arg(input.errorString());
            return false;
        }
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(input.readAll(), &parseError);
        input.close();
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            if (errorMessage)
                *errorMessage = QStringLiteral("OpenClaw 配置格式无效：%1")
                                    .arg(parseError.errorString());
            return false;
        }
        config = document.object();
    }

    QJsonObject modelsConfig = config.value(QStringLiteral("models")).toObject();
    QJsonObject providers = modelsConfig.value(QStringLiteral("providers")).toObject();
    QJsonObject provider;
    QString providerBaseUrl = normalizedBaseUrl(apiBaseUrl);
    if (!providerBaseUrl.endsWith(QStringLiteral("/v1")))
        providerBaseUrl += QStringLiteral("/v1");
    provider[QStringLiteral("baseUrl")] = providerBaseUrl;
    provider[QStringLiteral("apiKey")] = stableToken;
    provider[QStringLiteral("api")] = QStringLiteral("openai-completions");
    provider[QStringLiteral("models")] = models;
    providers[QStringLiteral("medclaw-primary")] = provider;
    // The old image provider is managed by this client; remove it so stale
    // models cannot remain selectable after the server catalog changes.
    providers.remove(QStringLiteral("qwen-vl"));
    modelsConfig[QStringLiteral("mode")] = QStringLiteral("merge");
    modelsConfig[QStringLiteral("providers")] = providers;
    config[QStringLiteral("models")] = modelsConfig;

    QJsonObject agents = config.value(QStringLiteral("agents")).toObject();
    QJsonObject defaults = agents.value(QStringLiteral("defaults")).toObject();
    const QString primaryRef = QStringLiteral("medclaw-primary/%1").arg(firstModelId);
    QJsonObject defaultModel = defaults.value(QStringLiteral("model")).toObject();
    defaultModel[QStringLiteral("primary")] = primaryRef;
    defaults[QStringLiteral("model")] = defaultModel;
    QJsonObject defaultModels = defaults.value(QStringLiteral("models")).toObject();
    QStringList staleManagedRefs;
    for (auto it = defaultModels.constBegin(); it != defaultModels.constEnd(); ++it) {
        if (it.key().startsWith(QStringLiteral("medclaw-primary/"))
            || it.key().startsWith(QStringLiteral("qwen-vl/")))
            staleManagedRefs.append(it.key());
    }
    for (const QString &key : staleManagedRefs)
        defaultModels.remove(key);
    for (const QJsonValue &value : models) {
        const QString id = value.toObject().value(QStringLiteral("id")).toString();
        defaultModels[QStringLiteral("medclaw-primary/%1").arg(id)] = QJsonObject();
    }
    defaults[QStringLiteral("models")] = defaultModels;
    if (!firstImageModelId.isEmpty()) {
        QJsonObject imageModel = defaults.value(QStringLiteral("imageModel")).toObject();
        imageModel[QStringLiteral("primary")] = QStringLiteral("medclaw-primary/%1")
                                                    .arg(firstImageModelId);
        defaults[QStringLiteral("imageModel")] = imageModel;
    } else {
        defaults.remove(QStringLiteral("imageModel"));
    }
    agents[QStringLiteral("defaults")] = defaults;
    config[QStringLiteral("agents")] = agents;

    QDir().mkpath(QFileInfo(configPath).absolutePath());
    QSaveFile output(configPath);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text)
        || output.write(QJsonDocument(config).toJson(QJsonDocument::Indented)) < 0
        || !output.commit()) {
        if (errorMessage)
            *errorMessage = QStringLiteral("无法写入 OpenClaw 配置：%1").arg(output.errorString());
        return false;
    }
    return true;
}
} // namespace

AuthController::AuthController(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    m_creditsRefreshTimer.setInterval(15000);
    connect(&m_creditsRefreshTimer, &QTimer::timeout, this, &AuthController::refreshCredits);
    QSettings settings;
    // Import credentials from an earlier product name once. Without the marker,
    // a later logout could be undone by importing the stale token on next launch.
    const QString migrationKey = QStringLiteral("auth/legacyMigrationCompleted");
#ifdef MEDCLAW_EDITION_GOVERNMENT
    // Government and main editions have separate accounts. Never import the
    // legacy main-edition token into the government settings namespace.
    const bool allowLegacyCredentialMigration = false;
#else
    const bool allowLegacyCredentialMigration = true;
#endif
    if (allowLegacyCredentialMigration && !settings.value(migrationKey, false).toBool()
        && settings.value(QStringLiteral("auth/accessToken")).toString().isEmpty()) {
        const QStringList legacyApplicationNames = {QStringLiteral("Aether_ClawDESK"),
                                                    QStringLiteral("ClawDESK")};
        for (const QString &applicationName : legacyApplicationNames) {
            QSettings legacySettings(QStringLiteral("AetherMED"), applicationName);
            const QString legacyToken = legacySettings.value(QStringLiteral("auth/accessToken"))
                                            .toString();
            const QString legacyPhone
                = legacySettings.value(QStringLiteral("auth/phone")).toString().trimmed();
            QString legacyUserId
                = legacySettings.value(QStringLiteral("auth/userId")).toString().trimmed();
            if (legacyUserId.isEmpty() && !legacyPhone.isEmpty())
                legacyUserId = QStringLiteral("phone:%1").arg(legacyPhone);
            if (!legacyToken.isEmpty() && !legacyUserId.isEmpty()) {
                settings.setValue(QStringLiteral("auth/accessToken"), legacyToken);
                settings.setValue(QStringLiteral("auth/refreshToken"),
                                  legacySettings.value(QStringLiteral("auth/refreshToken")));
                settings.setValue(QStringLiteral("auth/userId"), legacyUserId);
                settings.setValue(QStringLiteral("auth/phone"), legacyPhone);
                break;
            }
        }
    }
    if (!settings.value(migrationKey, false).toBool()) {
        settings.setValue(migrationKey, true);
        settings.sync();
    }
    // Runtime selection is intentionally limited to prod/test. The default is
    // always prod, so build and packaging environments cannot bake in test URLs.
    m_apiBaseUrl = normalizedBaseUrl(apiBaseUrlFromEnvironment());
    settings.remove(QStringLiteral("auth/apiBaseUrl"));
    qInfo().noquote() << "[API] environment:"
                      << (m_apiBaseUrl == QString::fromLatin1(kTestApiBaseUrl) ? "test" : "prod")
                      << "baseUrl:" << m_apiBaseUrl;
    m_accessToken = settings.value(QStringLiteral("auth/accessToken")).toString();
    m_refreshToken = settings.value(QStringLiteral("auth/refreshToken")).toString();
    m_userId = settings.value(QStringLiteral("auth/userId")).toString().trimmed();
    m_phone = settings.value(QStringLiteral("auth/phone")).toString();
    m_creditsBalance = settings.value(QStringLiteral("auth/creditsBalance")).toString();

    const QString previewPath = qEnvironmentVariable("MEDCLAW_ACCOUNT_PREVIEW_FILE").trimmed();
    if (!previewPath.isEmpty()) {
        QFile previewFile(previewPath);
        if (previewFile.open(QIODevice::ReadOnly)) {
            const QJsonDocument previewDocument = QJsonDocument::fromJson(previewFile.readAll());
            const QJsonObject previewRoot = previewDocument.object();
            const QJsonObject previewData = previewRoot.value(QStringLiteral("data")).toObject();
            const QJsonObject credits = previewData.isEmpty() ? previewRoot : previewData;
            if (!credits.isEmpty()) {
                const QJsonObject wallet = credits.value(QStringLiteral("wallet")).toObject();
                m_creditsBalance = wallet.value(QStringLiteral("available_balance"))
                                       .toVariant()
                                       .toString()
                                       .trimmed();
                if (m_creditsBalance.isEmpty())
                    m_creditsBalance
                        = wallet.value(QStringLiteral("balance")).toVariant().toString().trimmed();
                m_creditLots = credits.value(QStringLiteral("credit_lots")).toArray().toVariantList();
                m_creditPackages
                    = credits.value(QStringLiteral("packages")).toArray().toVariantList();
                m_userId = QStringLiteral("account-preview");
                m_phone = credits.value(QStringLiteral("preview_phone"))
                              .toString(QStringLiteral("13812348888"));
                m_accessToken.clear();
                m_refreshToken.clear();
                m_loggedIn = true;
                m_modelConfigReady = true;
                m_creditPreviewMode = true;
                return;
            }
        }
        qWarning() << "Unable to load account preview data:" << previewPath;
    }

    m_loggedIn = !m_accessToken.isEmpty() && !m_userId.isEmpty();
    if (m_loggedIn) {
        QTimer::singleShot(0, this, [this]() {
            fetchAndApplyModelConfig(m_accessToken, [this](bool ok, const QString &message) {
                if (!ok) {
                    setErrorMessage(message);
                    const bool wasLoggedIn = m_loggedIn;
                    m_loggedIn = false;
                    if (wasLoggedIn)
                        emit loggedInChanged();
                } else {
                    refreshCredits();
                    m_creditsRefreshTimer.start();
                }
            });
        });
    }
}

bool AuthController::loggedIn() const
{
    return m_loggedIn;
}
bool AuthController::busy() const
{
    return m_busy;
}
QString AuthController::userId() const
{
    return m_userId;
}
QString AuthController::phone() const
{
    return m_phone;
}
QString AuthController::errorMessage() const
{
    return m_errorMessage;
}
QString AuthController::apiBaseUrl() const
{
    return m_apiBaseUrl;
}
bool AuthController::enterpriseCredentialLoginEnabled() const
{
#ifdef MEDCLAW_EDITION_GOVERNMENT
    return m_apiBaseUrl == QString::fromLatin1(kTestApiBaseUrl);
#else
    return false;
#endif
}
QString AuthController::creditsBalance() const
{
    return m_creditsBalance;
}
QVariantList AuthController::creditLots() const
{
    return m_creditLots;
}
QVariantList AuthController::creditPackages() const
{
    return m_creditPackages;
}
bool AuthController::modelConfigReady() const
{
    return m_modelConfigReady;
}

void AuthController::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void AuthController::setErrorMessage(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emit errorMessageChanged();
}

void AuthController::clearError()
{
    setErrorMessage(QString());
}

void AuthController::fetchAndApplyModelConfig(const QString &token,
                                              const std::function<void(bool, const QString &)> &done)
{
    const quint64 generation = ++m_modelConfigGeneration;
    if (m_modelConfigReady) {
        m_modelConfigReady = false;
        emit modelConfigReadyChanged();
    }
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/v1/model-configs")));
    disableHttp2(request);
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    logApiRequest("GET", request);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, token, generation, done]() {
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(raw, &parseError);
        const bool current = generation == m_modelConfigGeneration && token == m_accessToken;
        QJsonArray modelArray;
        if (document.isArray())
            modelArray = document.array();
        else if (document.isObject())
            modelArray = document.object().value(QStringLiteral("models")).toArray();
        bool ok = reply->error() == QNetworkReply::NoError && !modelArray.isEmpty();
        QString message;
        if (!ok) {
            QJsonObject body = document.isObject() ? document.object() : QJsonObject();
            message = status == 401 ? QStringLiteral("登录已失效，请重新登录")
                                    : responseMessage(body,
                                                      reply->errorString().isEmpty()
                                                          ? QStringLiteral("模型列表获取失败")
                                                          : reply->errorString());
        } else {
            if (current)
                ok = writeOpenClawModelConfig(modelArray, token, m_apiBaseUrl, &message);
            if (ok && current && !m_modelConfigReady) {
                m_modelConfigReady = true;
                emit modelConfigReadyChanged();
            }
        }
        if (current) {
            done(ok, message);
            if (status == 401)
                clearSession();
        }
        reply->deleteLater();
    });
}

void AuthController::sendSmsCode(const QString &phone)
{
    const QString normalizedPhone = phone.trimmed();
    if (!QRegularExpression(QStringLiteral("^1[3-9]\\d{9}$")).match(normalizedPhone).hasMatch()) {
        setErrorMessage(QStringLiteral("请输入正确的 11 位手机号"));
        return;
    }

    setBusy(true);
    clearError();
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/auth/sms/send")));
    disableHttp2(request);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("phone"), normalizedPhone);
    const QByteArray requestBody = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    logApiRequest("POST", request, requestBody);
    QNetworkReply *reply = m_network->post(request, requestBody);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        setBusy(false);
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);
        const QJsonObject body = QJsonDocument::fromJson(raw).object();
        const bool ok = reply->error() == QNetworkReply::NoError && responseSucceeded(body);
        if (ok)
            emit smsCodeSent();
        else
            setErrorMessage(responseMessage(body,
                                            reply->errorString().isEmpty()
                                                ? QStringLiteral("验证码发送失败")
                                                : reply->errorString()));
        reply->deleteLater();
    });
}

void AuthController::loginWithPhone(const QString &phone, const QString &smsCode)
{
    const QString normalizedPhone = phone.trimmed();
    const QString normalizedCode = smsCode.trimmed();
    if (!QRegularExpression(QStringLiteral("^1[3-9]\\d{9}$")).match(normalizedPhone).hasMatch()) {
        setErrorMessage(QStringLiteral("请输入正确的 11 位手机号"));
        return;
    }
    if (normalizedCode.isEmpty()) {
        setErrorMessage(QStringLiteral("请输入短信验证码"));
        return;
    }

    setBusy(true);
    clearError();
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/auth/sms/agent-login")));
    disableHttp2(request);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("phone"), normalizedPhone);
    payload.insert(QStringLiteral("code"), normalizedCode);
#ifdef MEDCLAW_EDITION_GOVERNMENT
    payload.insert(QStringLiteral("enterprise_code"),
                   QString::fromLatin1(kGovernmentEnterpriseCode));
#endif
    const QByteArray requestBody = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    logApiRequest("POST", request, requestBody);
    QNetworkReply *reply = m_network->post(request, requestBody);
    connect(reply, &QNetworkReply::finished, this, [this, reply, normalizedPhone]() {
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);
        const QJsonObject body = QJsonDocument::fromJson(raw).object();
        QJsonObject data = body.value(QStringLiteral("data")).toObject();
        if (data.isEmpty())
            data = body;
        QString accessToken = data.value(QStringLiteral("stable_token")).toString().trimmed();
        if (accessToken.isEmpty())
            accessToken = data.value(QStringLiteral("accessToken")).toString().trimmed();
        const bool ok = reply->error() == QNetworkReply::NoError && accessToken.size() > 0;
        if (!ok) {
            setBusy(false);
            setErrorMessage(responseMessage(body,
                                            reply->errorString().isEmpty()
                                                ? QStringLiteral("登录失败，请检查验证码")
                                                : reply->errorString()));
            reply->deleteLater();
            return;
        }

        m_accessToken = accessToken;
        m_refreshToken = data.value(QStringLiteral("refreshToken")).toString();
        m_phone = data.value(QStringLiteral("phone")).toString();
        if (m_phone.isEmpty())
            m_phone = normalizedPhone;
        m_userId = userIdFromLoginData(data, m_phone);
        const QString credits = data.value(QStringLiteral("credits_balance")).toString();
        if (m_creditsBalance != credits) {
            m_creditsBalance = credits;
            emit creditsBalanceChanged();
        }
        QSettings settings;
        settings.setValue(QStringLiteral("auth/accessToken"), m_accessToken);
        settings.setValue(QStringLiteral("auth/refreshToken"), m_refreshToken);
        settings.setValue(QStringLiteral("auth/userId"), m_userId);
        settings.setValue(QStringLiteral("auth/phone"), m_phone);
        settings.setValue(QStringLiteral("auth/creditsBalance"), m_creditsBalance);
        m_modelConfigReady = false;
        emit modelConfigReadyChanged();
        fetchAndApplyModelConfig(m_accessToken, [this](bool configOk, const QString &message) {
            setBusy(false);
            if (!configOk) {
                setErrorMessage(message);
                const bool wasLoggedIn = m_loggedIn;
                m_loggedIn = false;
                if (wasLoggedIn)
                    emit loggedInChanged();
                return;
            }
            refreshCredits();
            m_creditsRefreshTimer.start();
            const bool wasLoggedIn = m_loggedIn;
            m_loggedIn = true;
            emit userChanged();
            if (!wasLoggedIn)
                emit loggedInChanged();
        });
        reply->deleteLater();
    });
}

void AuthController::loginWithCredentials(const QString &username, const QString &password)
{
    const QString normalizedUsername = username.trimmed();
    if (normalizedUsername.isEmpty()) {
        setErrorMessage(QStringLiteral("请输入账号"));
        return;
    }
    if (password.isEmpty()) {
        setErrorMessage(QStringLiteral("请输入密码"));
        return;
    }

    setBusy(true);
    clearError();
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/enterprise/auth/agent-login")));
    disableHttp2(request);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("username"), normalizedUsername);
    payload.insert(QStringLiteral("password"), password);
    const QByteArray requestBody = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    logApiRequest("POST", request, requestBody);
    QNetworkReply *reply = m_network->post(request, requestBody);
    connect(reply, &QNetworkReply::finished, this, [this, reply, normalizedUsername]() {
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);
        const QJsonDocument document = QJsonDocument::fromJson(raw);
        const QJsonObject body = document.isObject() ? document.object() : QJsonObject();
        QString accessToken = body.value(QStringLiteral("stable_token")).toString().trimmed();
        if (accessToken.isEmpty())
            accessToken = body.value(QStringLiteral("access_token")).toString().trimmed();
        if (accessToken.isEmpty())
            accessToken = body.value(QStringLiteral("accessToken")).toString().trimmed();
        const bool ok = reply->error() == QNetworkReply::NoError && !accessToken.isEmpty();
        if (!ok) {
            setBusy(false);
            setErrorMessage(responseMessage(body,
                                            reply->errorString().isEmpty()
                                                ? QStringLiteral("登录失败，请检查账号和密码")
                                                : reply->errorString()));
            reply->deleteLater();
            return;
        }

        m_accessToken = accessToken;
        m_refreshToken = body.value(QStringLiteral("refresh_token")).toString();
        if (m_refreshToken.isEmpty())
            m_refreshToken = body.value(QStringLiteral("refreshToken")).toString();
        m_phone = body.value(QStringLiteral("username")).toString().trimmed();
        if (m_phone.isEmpty())
            m_phone = normalizedUsername;
        m_userId = userIdFromLoginData(body, m_phone);
        const QString credits = body.value(QStringLiteral("credits_balance")).toString();
        if (m_creditsBalance != credits) {
            m_creditsBalance = credits;
            emit creditsBalanceChanged();
        }
        QSettings settings;
        settings.setValue(QStringLiteral("auth/accessToken"), m_accessToken);
        settings.setValue(QStringLiteral("auth/refreshToken"), m_refreshToken);
        settings.setValue(QStringLiteral("auth/userId"), m_userId);
        settings.setValue(QStringLiteral("auth/phone"), m_phone);
        settings.setValue(QStringLiteral("auth/creditsBalance"), m_creditsBalance);
        m_modelConfigReady = false;
        emit modelConfigReadyChanged();
        fetchAndApplyModelConfig(m_accessToken, [this](bool configOk, const QString &message) {
            setBusy(false);
            if (!configOk) {
                setErrorMessage(message);
                const bool wasLoggedIn = m_loggedIn;
                m_loggedIn = false;
                if (wasLoggedIn)
                    emit loggedInChanged();
                return;
            }
            refreshCredits();
            m_creditsRefreshTimer.start();
            const bool wasLoggedIn = m_loggedIn;
            m_loggedIn = true;
            emit userChanged();
            if (!wasLoggedIn)
                emit loggedInChanged();
        });
        reply->deleteLater();
    });
}

void AuthController::requestWebLogin()
{
    if (m_webLoginRequestInFlight)
        return;
    if (!m_loggedIn || m_accessToken.isEmpty()) {
        emit webLoginFailed(QStringLiteral("当前登录状态无效，请重新登录"));
        return;
    }

    m_webLoginRequestInFlight = true;
    const QString token = m_accessToken;
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/auth/web-login-ticket")));
    disableHttp2(request);
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    request.setRawHeader("Accept", "application/json");
    logApiRequest("POST", request);
    QNetworkReply *reply = m_network->post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply, token]() {
        m_webLoginRequestInFlight = false;
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);

        if (token != m_accessToken) {
            reply->deleteLater();
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(raw, &parseError);
        const QJsonObject body = document.isObject() ? document.object() : QJsonObject();
        const QJsonObject wrappedData = body.value(QStringLiteral("data")).toObject();
        const QJsonObject data = wrappedData.isEmpty() ? body : wrappedData;
        const QString ticket = data.value(QStringLiteral("ticket")).toString().trimmed();
        if (reply->error() != QNetworkReply::NoError || ticket.isEmpty()) {
            const QString fallback = reply->errorString().isEmpty()
                                         ? QStringLiteral("官网登录凭证获取失败，请稍后重试")
                                         : reply->errorString();
            emit webLoginFailed(responseMessage(body, fallback));
            reply->deleteLater();
            return;
        }

        const QByteArray callback
            = m_apiBaseUrl.toUtf8() + QByteArrayLiteral("/#/auth/callback?login_ticket=")
              + QUrl::toPercentEncoding(ticket);
        emit webLoginUrlReady(QUrl::fromEncoded(callback).toString(QUrl::FullyEncoded));
        reply->deleteLater();
    });
}

void AuthController::refreshCredits()
{
    if (m_creditPreviewMode || m_accessToken.isEmpty() || m_creditsRefreshInFlight)
        return;

    m_creditsRefreshInFlight = true;
    const QString token = m_accessToken;
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/credits/me")));
    disableHttp2(request);
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    logApiRequest("GET", request);
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, token]() {
        m_creditsRefreshInFlight = false;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
        logApiResponse(reply, raw);
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(raw, &parseError);
        if (token != m_accessToken) {
            reply->deleteLater();
            return;
        }
        if (status == 401) {
            setErrorMessage(QStringLiteral("登录已失效，请重新登录"));
            clearSession();
            reply->deleteLater();
            return;
        }
        if (reply->error() != QNetworkReply::NoError || !document.isObject()) {
            reply->deleteLater();
            return;
        }

        const QJsonObject body = document.object();
        const QJsonObject wrappedData = body.value(QStringLiteral("data")).toObject();
        const QJsonObject credits = wrappedData.isEmpty() ? body : wrappedData;
        const QJsonObject wallet = credits.value(QStringLiteral("wallet")).toObject();
        QString balance
            = wallet.value(QStringLiteral("available_balance")).toVariant().toString().trimmed();
        if (balance.isEmpty())
            balance = wallet.value(QStringLiteral("balance")).toVariant().toString().trimmed();
        if (balance.isEmpty())
            balance
                = credits.value(QStringLiteral("credits_balance")).toVariant().toString().trimmed();
        if (!balance.isEmpty() && balance != m_creditsBalance) {
            m_creditsBalance = balance;
            QSettings().setValue(QStringLiteral("auth/creditsBalance"), m_creditsBalance);
            emit creditsBalanceChanged();
        }

        const QVariantList creditLots
            = credits.value(QStringLiteral("credit_lots")).toArray().toVariantList();
        const QVariantList creditPackages
            = credits.value(QStringLiteral("packages")).toArray().toVariantList();
        if (creditLots != m_creditLots || creditPackages != m_creditPackages) {
            m_creditLots = creditLots;
            m_creditPackages = creditPackages;
            emit creditDetailsChanged();
        }
        reply->deleteLater();
    });
}

void AuthController::clearSession()
{
    ++m_modelConfigGeneration;
    m_creditsRefreshTimer.stop();
    m_creditsRefreshInFlight = false;
    const bool wasLoggedIn = m_loggedIn;
    m_loggedIn = false;
    m_accessToken.clear();
    m_refreshToken.clear();
    m_userId.clear();
    m_phone.clear();
    if (!m_creditsBalance.isEmpty()) {
        m_creditsBalance.clear();
        emit creditsBalanceChanged();
    }
    if (!m_creditLots.isEmpty() || !m_creditPackages.isEmpty()) {
        m_creditLots.clear();
        m_creditPackages.clear();
        emit creditDetailsChanged();
    }
    if (m_modelConfigReady) {
        m_modelConfigReady = false;
        emit modelConfigReadyChanged();
    }
    QSettings settings;
    settings.remove(QStringLiteral("auth/accessToken"));
    settings.remove(QStringLiteral("auth/refreshToken"));
    settings.remove(QStringLiteral("auth/userId"));
    settings.remove(QStringLiteral("auth/phone"));
    settings.remove(QStringLiteral("auth/creditsBalance"));
    settings.setValue(QStringLiteral("auth/legacyMigrationCompleted"), true);

    const QStringList legacyApplicationNames = {QStringLiteral("Aether_ClawDESK"),
                                                QStringLiteral("ClawDESK")};
    for (const QString &applicationName : legacyApplicationNames) {
        QSettings legacySettings(QStringLiteral("AetherMED"), applicationName);
        legacySettings.remove(QStringLiteral("auth/accessToken"));
        legacySettings.remove(QStringLiteral("auth/refreshToken"));
        legacySettings.remove(QStringLiteral("auth/userId"));
        legacySettings.remove(QStringLiteral("auth/phone"));
        legacySettings.sync();
    }
    settings.sync();
    emit userChanged();
    if (wasLoggedIn)
        emit loggedInChanged();
}

void AuthController::logout()
{
    if (!m_loggedIn) {
        clearSession();
        return;
    }

    clearSession();
}
