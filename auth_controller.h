#ifndef AUTH_CONTROLLER_H
#define AUTH_CONTROLLER_H

#include <QObject>
#include <QString>
#include <QTimer>
#include <functional>

class QNetworkAccessManager;

class AuthController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY loggedInChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString userId READ userId NOTIFY userChanged)
    Q_PROPERTY(QString phone READ phone NOTIFY userChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(QString apiBaseUrl READ apiBaseUrl WRITE setApiBaseUrl NOTIFY apiBaseUrlChanged)
    Q_PROPERTY(QString creditsBalance READ creditsBalance NOTIFY creditsBalanceChanged)
    Q_PROPERTY(bool modelConfigReady READ modelConfigReady NOTIFY modelConfigReadyChanged)

public:
    explicit AuthController(QObject *parent = nullptr);

    bool loggedIn() const;
    bool busy() const;
    QString userId() const;
    QString phone() const;
    QString errorMessage() const;
    QString apiBaseUrl() const;
    QString creditsBalance() const;
    bool modelConfigReady() const;

    void setApiBaseUrl(const QString &url);

    Q_INVOKABLE void sendSmsCode(const QString &phone);
    Q_INVOKABLE void loginWithPhone(const QString &phone, const QString &smsCode);
    Q_INVOKABLE void refreshCredits();
    Q_INVOKABLE void logout();
    Q_INVOKABLE void clearError();

signals:
    void loggedInChanged();
    void busyChanged();
    void userChanged();
    void errorMessageChanged();
    void apiBaseUrlChanged();
    void creditsBalanceChanged();
    void modelConfigReadyChanged();
    void smsCodeSent();

private:
    void setBusy(bool busy);
    void setErrorMessage(const QString &message);
    void clearSession();
    void fetchAndApplyModelConfig(const QString &token,
                                  const std::function<void(bool, const QString &)> &done);

    QNetworkAccessManager *m_network;
    bool m_loggedIn = false;
    bool m_busy = false;
    QString m_userId;
    QString m_phone;
    QString m_accessToken;
    QString m_refreshToken;
    QString m_errorMessage;
    QString m_apiBaseUrl;
    QString m_creditsBalance;
    bool m_modelConfigReady = false;
    bool m_creditsRefreshInFlight = false;
    quint64 m_modelConfigGeneration = 0;
    QTimer m_creditsRefreshTimer;
};

#endif // AUTH_CONTROLLER_H
