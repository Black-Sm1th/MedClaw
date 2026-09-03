#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QTcpServer>
#include <QUrl>
#include <QVariant>
#include <QStringList>

class QTcpSocket;

// Reusable local host for viewer-web. The public API intentionally contains
// no application-specific document model: callers provide a local path and
// receive an HTTP URL suitable for QWebEngineView, WebView2, or a browser.
class ViewerHost : public QObject
{
    Q_OBJECT
    Q_PROPERTY(quint16 port READ port NOTIFY serverChanged)
    Q_PROPERTY(bool running READ running NOTIFY serverChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit ViewerHost(QObject *parent = nullptr);

    quint16 port() const { return m_server.isListening() ? m_server.serverPort() : 0; }
    bool running() const { return m_server.isListening(); }
    QString lastError() const { return m_lastError; }
    QString viewerRootPath() const { return m_viewerRootOverride; }

    void setViewerRootPath(const QString &path);

    Q_INVOKABLE QString openDocument(const QString &localPath,
                                     bool readOnly = false,
                                     const QString &language = QStringLiteral("zh-CN"));
    // Starts the local Cornerstone3D viewer. The viewer receives files through
    // the session-scoped manifest/file endpoints instead of file:// URLs,
    // which are intentionally blocked by Qt WebEngine.
    Q_INVOKABLE QString openMedicalImage(const QString &localPath);
    Q_INVOKABLE void closeDocument();
    Q_INVOKABLE bool saveAsCurrent();

signals:
    void serverChanged();
    void lastErrorChanged();
    void documentChanged();
    void documentSaved(const QString &path);
    void viewerEvent(const QString &type, const QVariant &content);

private:
    void acceptConnection();
    void readRequest(QTcpSocket *socket);
    void handleRequest(QTcpSocket *socket, const QByteArray &request);
    void handleEvent(QTcpSocket *socket, const QByteArray &body);
    void respond(QTcpSocket *socket, int statusCode, const QByteArray &contentType,
                 const QByteArray &body,
                 const QList<QPair<QByteArray, QByteArray>> &headers = {});
    void respondJson(QTcpSocket *socket, int statusCode, const QJsonObject &object);
    void setLastError(const QString &message);
    QString routeForPath(const QString &path) const;
    QString contentTypeForPath(const QString &path) const;
    QString viewerRoot() const;
    QJsonObject openPayload() const;
    QJsonObject medicalManifest() const;
    bool writeBytes(const QString &path, const QByteArray &bytes);

    QTcpServer m_server;
    QString m_currentPath;
    QString m_sessionId;
    QString m_language = QStringLiteral("zh-CN");
    QString m_lastError;
    QString m_viewerRootOverride;
    QStringList m_medicalFiles;
    bool m_readOnly = false;
    bool m_medicalMode = false;
    quint64 m_nonce = 0;
};
