#ifndef UPDATECONTROLLER_H
#define UPDATECONTROLLER_H

#include <QCryptographicHash>
#include <QFile>
#include <QObject>
#include <QVariantMap>

class QNetworkAccessManager;
class QNetworkReply;
class QProcess;
class QTimer;

class UpdateController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentVersion READ currentVersion CONSTANT)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY latestVersionChanged)
    Q_PROPERTY(QString latestTitle READ latestTitle NOTIFY latestVersionChanged)
    Q_PROPERTY(QString latestSummary READ latestSummary NOTIFY latestVersionChanged)
    Q_PROPERTY(QString releaseNotes READ releaseNotes NOTIFY latestVersionChanged)
    Q_PROPERTY(QString downloadUrl READ downloadUrl NOTIFY latestVersionChanged)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY updateAvailableChanged)
    Q_PROPERTY(bool forceUpdate READ forceUpdate NOTIFY latestVersionChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadingChanged)
    Q_PROPERTY(double downloadProgress READ downloadProgress NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64 downloadReceivedBytes READ downloadReceivedBytes NOTIFY downloadProgressChanged)
    Q_PROPERTY(qint64 downloadTotalBytes READ downloadTotalBytes NOTIFY downloadProgressChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)

public:
    explicit UpdateController(QObject *parent = nullptr);

    QString currentVersion() const;
    QString latestVersion() const;
    QString latestTitle() const;
    QString latestSummary() const;
    QString releaseNotes() const;
    QString downloadUrl() const;
    bool updateAvailable() const;
    bool forceUpdate() const;
    bool checking() const;
    bool downloading() const;
    double downloadProgress() const;
    qint64 downloadReceivedBytes() const;
    qint64 downloadTotalBytes() const;
    QString errorMessage() const;

    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void installUpdate();

signals:
    void latestVersionChanged();
    void updateAvailableChanged();
    void checkingChanged();
    void downloadingChanged();
    void downloadProgressChanged();
    void errorMessageChanged();
    void updateCheckFinished(bool available);

private:
    void setError(const QString &message);
    void handleReleaseReply(QNetworkReply *reply);
    void handleDownloadReply(QNetworkReply *reply);
    void consumeDownloadData(QNetworkReply *reply);
    void startNetworkDownload(const QString &target);
    void startCurlDownload(const QString &curlPath, const QString &target);
    bool verifyDownloadedFile(const QString &path);
    bool launchDownloadedFile(const QString &path);
    static bool isNewerVersion(const QString &candidate, const QString &current);
    static QString resolveDownloadUrl(const QVariantMap &release);

    QNetworkAccessManager *m_network = nullptr;
    QTimer *m_timer = nullptr;
    QProcess *m_downloadProcess = nullptr;
    QFile m_downloadFile;
    QCryptographicHash m_downloadHash;
    QString m_latestVersion;
    QString m_latestTitle;
    QString m_latestSummary;
    QString m_releaseNotes;
    QString m_downloadUrl;
    QString m_fileName;
    QString m_sha256;
    qint64 m_fileSize = 0;
    QString m_errorMessage;
    bool m_updateAvailable = false;
    bool m_forceUpdate = false;
    bool m_checking = false;
    bool m_downloading = false;
    double m_downloadProgress = 0.0;
    qint64 m_downloadReceivedBytes = 0;
    qint64 m_downloadTotalBytes = 0;
    bool m_downloadWriteFailed = false;
};

#endif // UPDATECONTROLLER_H
