#include "auth_controller.h"

#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDir>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QSaveFile>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QUrl>

namespace {
const char kDefaultApiBaseUrl[] = "http://111.6.178.34:22910";
const char kPreviousDefaultApiBaseUrl[] = "http://111.6.178.34:24638";

QString normalizedBaseUrl(QString url)
{
    url = url.trimmed();
    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);
    return url;
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
        userId = data.value(QStringLiteral("userInfo")).toObject()
                     .value(QStringLiteral("id")).toVariant().toString().trimmed();
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
                *errorMessage = QStringLiteral("OpenClaw 配置格式无效：%1").arg(parseError.errorString());
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
        imageModel[QStringLiteral("primary")] =
            QStringLiteral("medclaw-primary/%1").arg(firstImageModelId);
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
}

AuthController::AuthController(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    m_creditsRefreshTimer.setInterval(15000);
    connect(&m_creditsRefreshTimer, &QTimer::timeout,
            this, &AuthController::refreshCredits);
    QSettings settings;
    // Import credentials from an earlier product name once. Without the marker,
    // a later logout could be undone by importing the stale token on next launch.
    const QString migrationKey = QStringLiteral("auth/legacyMigrationCompleted");
    if (!settings.value(migrationKey, false).toBool()
        && settings.value(QStringLiteral("auth/accessToken")).toString().isEmpty()) {
        const QStringList legacyApplicationNames = {
            QStringLiteral("Aether_ClawDESK"),
            QStringLiteral("ClawDESK")
        };
        for (const QString &applicationName : legacyApplicationNames) {
            QSettings legacySettings(QStringLiteral("AetherMED"), applicationName);
            const QString legacyToken =
                legacySettings.value(QStringLiteral("auth/accessToken")).toString();
            const QString legacyPhone =
                legacySettings.value(QStringLiteral("auth/phone")).toString().trimmed();
            QString legacyUserId =
                legacySettings.value(QStringLiteral("auth/userId")).toString().trimmed();
            if (legacyUserId.isEmpty() && !legacyPhone.isEmpty())
                legacyUserId = QStringLiteral("phone:%1").arg(legacyPhone);
            if (!legacyToken.isEmpty() && !legacyUserId.isEmpty()) {
                settings.setValue(QStringLiteral("auth/accessToken"), legacyToken);
                settings.setValue(QStringLiteral("auth/refreshToken"),
                                  legacySettings.value(QStringLiteral("auth/refreshToken")));
                settings.setValue(QStringLiteral("auth/userId"), legacyUserId);
                settings.setValue(QStringLiteral("auth/phone"), legacyPhone);
                settings.setValue(QStringLiteral("auth/apiBaseUrl"),
                                  legacySettings.value(QStringLiteral("auth/apiBaseUrl"),
                                                       QString::fromLatin1(kDefaultApiBaseUrl)));
                break;
            }
        }
    }
    if (!settings.value(migrationKey, false).toBool()) {
        settings.setValue(migrationKey, true);
        settings.sync();
    }
    m_apiBaseUrl = normalizedBaseUrl(settings.value(QStringLiteral("auth/apiBaseUrl"),
                                                    QString::fromLatin1(kDefaultApiBaseUrl)).toString());
    if (m_apiBaseUrl == QString::fromLatin1(kPreviousDefaultApiBaseUrl)
        || m_apiBaseUrl == QStringLiteral("http://192.168.0.36:8080")) {
        m_apiBaseUrl = QString::fromLatin1(kDefaultApiBaseUrl);
        settings.setValue(QStringLiteral("auth/apiBaseUrl"), m_apiBaseUrl);
    }
    m_accessToken = settings.value(QStringLiteral("auth/accessToken")).toString();
    m_refreshToken = settings.value(QStringLiteral("auth/refreshToken")).toString();
    m_userId = settings.value(QStringLiteral("auth/userId")).toString().trimmed();
    m_phone = settings.value(QStringLiteral("auth/phone")).toString();
    m_creditsBalance = settings.value(QStringLiteral("auth/creditsBalance")).toString();
    m_loggedIn = !m_accessToken.isEmpty() && !m_userId.isEmpty();
    if (m_loggedIn) {
        QTimer::singleShot(0, this, [this]() {
            fetchAndApplyModelConfig(m_accessToken,
                                     [this](bool ok, const QString &message) {
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

bool AuthController::loggedIn() const { return m_loggedIn; }
bool AuthController::busy() const { return m_busy; }
QString AuthController::userId() const { return m_userId; }
QString AuthController::phone() const { return m_phone; }
QString AuthController::errorMessage() const { return m_errorMessage; }
QString AuthController::apiBaseUrl() const { return m_apiBaseUrl; }
QString AuthController::creditsBalance() const { return m_creditsBalance; }
bool AuthController::modelConfigReady() const { return m_modelConfigReady; }

void AuthController::setApiBaseUrl(const QString &url)
{
    const QString normalized = normalizedBaseUrl(url);
    if (normalized.isEmpty() || normalized == m_apiBaseUrl)
        return;
    m_apiBaseUrl = normalized;
    QSettings().setValue(QStringLiteral("auth/apiBaseUrl"), m_apiBaseUrl);
    emit apiBaseUrlChanged();
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

void AuthController::fetchAndApplyModelConfig(
    const QString &token, const std::function<void(bool, const QString &)> &done)
{
    const quint64 generation = ++m_modelConfigGeneration;
    if (m_modelConfigReady) {
        m_modelConfigReady = false;
        emit modelConfigReadyChanged();
    }
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/v1/model-configs")));
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, token, generation, done]() {
        const QByteArray raw = reply->readAll();
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
            message = responseMessage(body, reply->errorString().isEmpty()
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
        if (current)
            done(ok, message);
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
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/auth/sms/send")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("phone"), normalizedPhone);
    QNetworkReply *reply = m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        setBusy(false);
        const QJsonObject body = QJsonDocument::fromJson(reply->readAll()).object();
        const bool ok = reply->error() == QNetworkReply::NoError && responseSucceeded(body);
        if (ok)
            emit smsCodeSent();
        else
            setErrorMessage(responseMessage(body, reply->errorString().isEmpty()
                                             ? QStringLiteral("验证码发送失败") : reply->errorString()));
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
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/auth/sms/agent-login")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("phone"), normalizedPhone);
    payload.insert(QStringLiteral("code"), normalizedCode);
    QNetworkReply *reply = m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, normalizedPhone]() {
        const QJsonObject body = QJsonDocument::fromJson(reply->readAll()).object();
        QJsonObject data = body.value(QStringLiteral("data")).toObject();
        if (data.isEmpty())
            data = body;
        QString accessToken = data.value(QStringLiteral("stable_token")).toString().trimmed();
        if (accessToken.isEmpty())
            accessToken = data.value(QStringLiteral("accessToken")).toString().trimmed();
        const bool ok = reply->error() == QNetworkReply::NoError && accessToken.size() > 0;
        if (!ok) {
            setBusy(false);
            setErrorMessage(responseMessage(body, reply->errorString().isEmpty()
                                             ? QStringLiteral("登录失败，请检查验证码") : reply->errorString()));
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
        fetchAndApplyModelConfig(m_accessToken,
                                 [this](bool configOk, const QString &message) {
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

void AuthController::refreshCredits()
{
    if (m_accessToken.isEmpty() || m_creditsRefreshInFlight)
        return;

    m_creditsRefreshInFlight = true;
    const QString token = m_accessToken;
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/credits/me")));
    request.setRawHeader("Authorization", QByteArray("Bearer ") + token.toUtf8());
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, token]() {
        m_creditsRefreshInFlight = false;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray raw = reply->readAll();
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
        const QJsonObject wallet = body.value(QStringLiteral("wallet")).toObject();
        QString balance = wallet.value(QStringLiteral("available_balance")).toVariant().toString().trimmed();
        if (balance.isEmpty())
            balance = wallet.value(QStringLiteral("balance")).toVariant().toString().trimmed();
        if (balance.isEmpty())
            balance = body.value(QStringLiteral("credits_balance")).toVariant().toString().trimmed();
        if (!balance.isEmpty() && balance != m_creditsBalance) {
            m_creditsBalance = balance;
            QSettings().setValue(QStringLiteral("auth/creditsBalance"), m_creditsBalance);
            emit creditsBalanceChanged();
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

    const QStringList legacyApplicationNames = {
        QStringLiteral("Aether_ClawDESK"),
        QStringLiteral("ClawDESK")
    };
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
