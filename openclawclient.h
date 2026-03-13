#ifndef OPENCLAWCLIENT_H
#define OPENCLAWCLIENT_H

#include <QObject>
#include <QWebSocket>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>
#include <QUuid>
#include <QVariantList>
#include <QMap>
#include <cstdint>

class OpenClawClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int connectionState READ connectionState NOTIFY connectionStateChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY connectionStateChanged)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY sessionsChanged)
    Q_PROPERTY(QString currentSessionKey READ currentSessionKey
               WRITE setCurrentSessionKey NOTIFY currentSessionChanged)

public:
    enum ConnectionState {
        Disconnected = 0,
        Connecting,
        Handshaking,
        Connected
    };
    Q_ENUM(ConnectionState)

    explicit OpenClawClient(QObject *parent = nullptr);
    ~OpenClawClient();

    int connectionState() const;
    QString statusText() const;
    QVariantList sessions() const;
    QString currentSessionKey() const;

    Q_INVOKABLE void connectToServer(const QString &url = QStringLiteral("ws://127.0.0.1:18789"));
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE void sendChatMessage(const QString &message, const QString &sessionKey = QString());
    Q_INVOKABLE void refreshSessions();
    Q_INVOKABLE void createNewSession();
    Q_INVOKABLE void deleteSession(const QString &sessionKey);
    Q_INVOKABLE void setCurrentSessionKey(const QString &key);
    Q_INVOKABLE void loadHistory();

signals:
    void connectionStateChanged();
    void chatMessageReceived(const QString &role, const QString &content, bool isDelta);
    void streamingStarted();
    void streamingFinished();
    void errorOccurred(const QString &message);
    void sessionsChanged();
    void currentSessionChanged();
    void sessionCreated();
    void historyLoaded(const QVariantList &messages);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onSocketError(QAbstractSocket::SocketError error);

private:
    void setState(ConnectionState state);
    void handleEvent(const QJsonObject &msg);
    void handleResponse(const QJsonObject &msg);
    void sendConnectRequest();
    QString nextRequestId();
    QString sendRequest(const QString &method, const QJsonObject &params);

    void initDeviceKeys();
    QJsonObject buildSignedDevice();

    QWebSocket *m_socket;
    ConnectionState m_state;
    QString m_connectRequestId;
    QString m_token;
    QString m_deviceId;
    QString m_challengeNonce;
    bool m_isStreaming;

    uint8_t m_ed25519Pk[32];
    uint8_t m_ed25519Sk[64];
    bool m_hasKeys;

    QVariantList m_sessions;
    QString m_currentSessionKey;
    QMap<QString, QString> m_pendingRequests;
    QString m_newSessionReqId;
};

#endif // OPENCLAWCLIENT_H
