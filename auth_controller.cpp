#include "auth_controller.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>

namespace {
const char kDefaultApiBaseUrl[] = "http://111.6.178.34:24638";
const char kPreviousDefaultApiBaseUrl[] = "http://192.168.0.36:8080";

QString normalizedBaseUrl(QString url)
{
    url = url.trimmed();
    while (url.endsWith(QLatin1Char('/')))
        url.chop(1);
    return url;
}

QString responseMessage(const QJsonObject &body, const QString &fallback)
{
    const QString message = body.value(QStringLiteral("message")).toString().trimmed();
    return message.isEmpty() ? fallback : message;
}

bool responseSucceeded(const QJsonObject &body)
{
    const QJsonValue code = body.value(QStringLiteral("code"));
    return (code.isDouble() && code.toInt() == 200)
        || (code.isString() && code.toString() == QStringLiteral("200"));
}

QString userIdFromLoginData(const QJsonObject &data, const QString &phone)
{
    QString userId = data.value(QStringLiteral("userId")).toVariant().toString().trimmed();
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
}

AuthController::AuthController(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    QSettings settings;
    // Preserve the last authenticated account after the product name changed.
    if (settings.value(QStringLiteral("auth/accessToken")).toString().isEmpty()) {
        QSettings legacySettings(QStringLiteral("AetherMED"), QStringLiteral("ClawDESK"));
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
        }
    }
    m_apiBaseUrl = normalizedBaseUrl(settings.value(QStringLiteral("auth/apiBaseUrl"),
                                                    QString::fromLatin1(kDefaultApiBaseUrl)).toString());
    if (m_apiBaseUrl == QString::fromLatin1(kPreviousDefaultApiBaseUrl)) {
        m_apiBaseUrl = QString::fromLatin1(kDefaultApiBaseUrl);
        settings.setValue(QStringLiteral("auth/apiBaseUrl"), m_apiBaseUrl);
    }
    m_accessToken = settings.value(QStringLiteral("auth/accessToken")).toString();
    m_refreshToken = settings.value(QStringLiteral("auth/refreshToken")).toString();
    m_userId = settings.value(QStringLiteral("auth/userId")).toString().trimmed();
    m_phone = settings.value(QStringLiteral("auth/phone")).toString();
    m_loggedIn = !m_accessToken.isEmpty() && !m_userId.isEmpty();
}

bool AuthController::loggedIn() const { return m_loggedIn; }
bool AuthController::busy() const { return m_busy; }
QString AuthController::userId() const { return m_userId; }
QString AuthController::phone() const { return m_phone; }
QString AuthController::errorMessage() const { return m_errorMessage; }
QString AuthController::apiBaseUrl() const { return m_apiBaseUrl; }

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

void AuthController::sendSmsCode(const QString &phone)
{
    const QString normalizedPhone = phone.trimmed();
    if (!QRegularExpression(QStringLiteral("^1\\d{10}$")).match(normalizedPhone).hasMatch()) {
        setErrorMessage(QStringLiteral("请输入正确的 11 位手机号"));
        return;
    }

    setBusy(true);
    clearError();
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/v1/sms/send")));
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
    if (!QRegularExpression(QStringLiteral("^1\\d{10}$")).match(normalizedPhone).hasMatch()) {
        setErrorMessage(QStringLiteral("请输入正确的 11 位手机号"));
        return;
    }
    if (normalizedCode.isEmpty()) {
        setErrorMessage(QStringLiteral("请输入短信验证码"));
        return;
    }

    setBusy(true);
    clearError();
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/v1/auth/login/phone")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    QJsonObject payload;
    payload.insert(QStringLiteral("phone"), normalizedPhone);
    payload.insert(QStringLiteral("smsCode"), normalizedCode);
    QNetworkReply *reply = m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, normalizedPhone]() {
        setBusy(false);
        const QJsonObject body = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonObject data = body.value(QStringLiteral("data")).toObject();
        const QString accessToken = data.value(QStringLiteral("accessToken")).toString();
        const bool ok = reply->error() == QNetworkReply::NoError && responseSucceeded(body)
                     && !accessToken.isEmpty();
        if (!ok) {
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
        QSettings settings;
        settings.setValue(QStringLiteral("auth/accessToken"), m_accessToken);
        settings.setValue(QStringLiteral("auth/refreshToken"), m_refreshToken);
        settings.setValue(QStringLiteral("auth/userId"), m_userId);
        settings.setValue(QStringLiteral("auth/phone"), m_phone);
        const bool wasLoggedIn = m_loggedIn;
        m_loggedIn = true;
        emit userChanged();
        if (!wasLoggedIn)
            emit loggedInChanged();
        reply->deleteLater();
    });
}

void AuthController::clearSession()
{
    const bool wasLoggedIn = m_loggedIn;
    m_loggedIn = false;
    m_accessToken.clear();
    m_refreshToken.clear();
    m_userId.clear();
    m_phone.clear();
    QSettings settings;
    settings.remove(QStringLiteral("auth/accessToken"));
    settings.remove(QStringLiteral("auth/refreshToken"));
    settings.remove(QStringLiteral("auth/userId"));
    settings.remove(QStringLiteral("auth/phone"));
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

    setBusy(true);
    QNetworkRequest request(QUrl(m_apiBaseUrl + QStringLiteral("/api/v1/auth/logout")));
    request.setHeader(QNetworkRequest::ContentTypeHeader,
                      QStringLiteral("application/x-www-form-urlencoded"));
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_accessToken.toUtf8());
    QNetworkReply *reply = m_network->post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        setBusy(false);
        clearSession();
        reply->deleteLater();
    });
}
