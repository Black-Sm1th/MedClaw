#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QString>

class OnlineOfficeClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString bridgeBaseUrl READ bridgeBaseUrl WRITE setBridgeBaseUrl NOTIFY bridgeBaseUrlChanged)
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool saving READ saving NOTIFY savingChanged)
    Q_PROPERTY(int uploadProgress READ uploadProgress NOTIFY uploadProgressChanged)
    Q_PROPERTY(QString editorUrl READ editorUrl NOTIFY editorUrlChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit OnlineOfficeClient(QObject *parent = nullptr);

    QString bridgeBaseUrl() const { return m_bridgeBaseUrl; }
    void setBridgeBaseUrl(const QString &value);
    QString apiKey() const { return QString::fromUtf8(m_apiKey); }
    void setApiKey(const QString &value);
    bool busy() const { return m_state != State::Idle; }
    bool saving() const;
    int uploadProgress() const { return m_uploadProgress; }
    QString editorUrl() const { return m_editorUrl; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE void openDocument(const QString &filePath,
                                  const QString &mode = QStringLiteral("view"));
    Q_INVOKABLE void finishDocument();
    Q_INVOKABLE void saveDocument();
    Q_INVOKABLE void cancel();

signals:
    void bridgeBaseUrlChanged();
    void apiKeyChanged();
    void busyChanged();
    void savingChanged();
    void uploadProgressChanged();
    void editorUrlChanged();
    void lastErrorChanged();
    void editorReady(const QString &url);
    void saveRequestFinished();
    void documentSaved(const QString &filePath);
    void saveFinished(const QString &filePath, bool saved);
    void sessionFinished(const QString &filePath, bool saved);
    void statusMessage(const QString &message);

private:
    enum class State { Idle, Uploading, Editing, WaitingForSave, Downloading };

    QNetworkRequest requestFor(const QString &path) const;
    void setState(State state);
    void setEditorUrl(const QString &value);
    void setLastError(const QString &value);
    void pollResult(int attemptsLeft);
    void downloadResult();
    void deleteSession(const QString &sessionId);
    void finishLocally(bool saved);

    QNetworkAccessManager m_network;
    QString m_bridgeBaseUrl;
    QByteArray m_apiKey;
    State m_state = State::Idle;
    int m_uploadProgress = 0;
    QString m_editorUrl;
    QString m_lastError;
    QString m_sessionId;
    QString m_filePath;
    QString m_mode;
    bool m_finishAfterSave = false;
    QPointer<QNetworkReply> m_activeReply;
};
