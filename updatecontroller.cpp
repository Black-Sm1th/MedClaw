#include "updatecontroller.h"

#include <QCryptographicHash>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantList>

#ifdef Q_OS_WIN
#include <qt_windows.h>
#include <shellapi.h>
#endif

namespace {
const QUrl latestReleaseUrl(QStringLiteral(
    "https://www.aethermind.cn/aether/api/app/releases/latest?"
    "app_key=aether-study&channel=STABLE&platform=WINDOWS&arch=x64"));
const QUrl downloadOrigin(QStringLiteral("https://www.aethermind.cn"));
const QString clientVersion(QStringLiteral("v1.0.0"));
}

UpdateController::UpdateController(QObject *parent)
    : QObject(parent), m_network(new QNetworkAccessManager(this)), m_timer(new QTimer(this)),
      m_downloadHash(QCryptographicHash::Sha256)
{
    m_timer->setInterval(10 * 60 * 1000);
    connect(m_timer, &QTimer::timeout, this, &UpdateController::checkForUpdates);
    m_timer->start();
    QTimer::singleShot(0, this, &UpdateController::checkForUpdates);
}

QString UpdateController::currentVersion() const { return clientVersion; }
QString UpdateController::latestVersion() const { return m_latestVersion; }
QString UpdateController::latestTitle() const { return m_latestTitle; }
QString UpdateController::latestSummary() const { return m_latestSummary; }
QString UpdateController::releaseNotes() const { return m_releaseNotes; }
QString UpdateController::downloadUrl() const { return m_downloadUrl; }
bool UpdateController::updateAvailable() const { return m_updateAvailable; }
bool UpdateController::forceUpdate() const { return m_forceUpdate; }
bool UpdateController::checking() const { return m_checking; }
bool UpdateController::downloading() const { return m_downloading; }
double UpdateController::downloadProgress() const { return m_downloadProgress; }
qint64 UpdateController::downloadReceivedBytes() const { return m_downloadReceivedBytes; }
qint64 UpdateController::downloadTotalBytes() const { return m_downloadTotalBytes; }
QString UpdateController::errorMessage() const { return m_errorMessage; }

void UpdateController::setError(const QString &message)
{
    if (m_errorMessage == message)
        return;
    m_errorMessage = message;
    emit errorMessageChanged();
}

void UpdateController::checkForUpdates()
{
    if (m_checking || m_downloading)
        return;
    m_checking = true;
    setError(QString());
    emit checkingChanged();
    QNetworkRequest request(latestReleaseUrl);
    request.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("AetherStudy-Qt/%1").arg(clientVersion));
    QNetworkReply *reply = m_network->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleReleaseReply(reply);
    });
}

void UpdateController::handleReleaseReply(QNetworkReply *reply)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const bool ok = reply->error() == QNetworkReply::NoError && status != 404;
    if (!ok) {
        if (status != 404)
            setError(reply->errorString());
        m_updateAvailable = false;
        emit updateAvailableChanged();
        emit updateCheckFinished(false);
        reply->deleteLater();
        m_checking = false;
        emit checkingChanged();
        return;
    }

    const QJsonDocument document = QJsonDocument::fromJson(body);
    const QVariantMap release = document.object().toVariantMap();
    const QString version = release.value(QStringLiteral("version")).toString().trimmed();
    if (version.isEmpty()) {
        setError(QStringLiteral("更新信息格式无效"));
        reply->deleteLater();
        m_checking = false;
        emit checkingChanged();
        return;
    }

    m_latestVersion = version;
    m_latestTitle = release.value(QStringLiteral("title")).toString();
    m_latestSummary = release.value(QStringLiteral("summary")).toString();
    m_releaseNotes = release.value(QStringLiteral("release_notes")).toString();
    m_downloadUrl = resolveDownloadUrl(release);
    m_fileName = release.value(QStringLiteral("file_name")).toString();
    m_sha256 = release.value(QStringLiteral("sha256")).toString().trimmed().toLower();
    m_fileSize = release.value(QStringLiteral("file_size")).toLongLong();
    m_forceUpdate = release.value(QStringLiteral("force_update")).toBool();
    const QString minimum = release.value(QStringLiteral("min_required_version")).toString();
    const bool belowMinimum = !minimum.isEmpty() && isNewerVersion(minimum, clientVersion);
    const bool available = isNewerVersion(version, clientVersion);
    m_updateAvailable = available;
    if (belowMinimum)
        m_forceUpdate = true;
    emit latestVersionChanged();
    emit updateAvailableChanged();
    emit updateCheckFinished(available);
    reply->deleteLater();
    m_checking = false;
    emit checkingChanged();
}

QString UpdateController::resolveDownloadUrl(const QVariantMap &release)
{
    const QString external = release.value(QStringLiteral("file_url")).toString().trimmed();
    if (!external.isEmpty())
        return external;
    const QString relative = release.value(QStringLiteral("download_url")).toString().trimmed();
    if (relative.isEmpty())
        return QString();
    // Older release records return /downloads/... while the production gateway
    // serves the same file under /aether/api/downloads/....
    if (relative.startsWith(QStringLiteral("/downloads/")))
        return downloadOrigin.resolved(QUrl(QStringLiteral("/aether/api") + relative)).toString();
    return downloadOrigin.resolved(QUrl(relative)).toString();
}

bool UpdateController::isNewerVersion(const QString &candidate, const QString &current)
{
    const auto parse = [](const QString &value, QString *suffix) {
        QString base = value.trimmed().toLower();
        if (base.startsWith(QLatin1Char('v')))
            base.remove(0, 1);
        const int dash = base.indexOf(QLatin1Char('-'));
        if (dash >= 0) {
            *suffix = base.mid(dash + 1);
            base = base.left(dash);
        } else {
            suffix->clear();
        }
        QStringList parts = base.split(QLatin1Char('.'), Qt::KeepEmptyParts);
        QVector<int> numbers;
        for (const QString &part : parts)
            numbers.append(part.toInt());
        while (numbers.size() < 4)
            numbers.append(0);
        return numbers;
    };
    QString candidateSuffix, currentSuffix;
    const QVector<int> candidateParts = parse(candidate, &candidateSuffix);
    const QVector<int> currentParts = parse(current, &currentSuffix);
    for (int i = 0; i < qMax(candidateParts.size(), currentParts.size()); ++i) {
        const int a = i < candidateParts.size() ? candidateParts.at(i) : 0;
        const int b = i < currentParts.size() ? currentParts.at(i) : 0;
        if (a != b)
            return a > b;
    }
    if (candidateSuffix.isEmpty() != currentSuffix.isEmpty())
        return candidateSuffix.isEmpty();
    const QStringList candidateTokens = candidateSuffix.split(QLatin1Char('.'));
    const QStringList currentTokens = currentSuffix.split(QLatin1Char('.'));
    const int count = qMax(candidateTokens.size(), currentTokens.size());
    for (int i = 0; i < count; ++i) {
        if (i >= candidateTokens.size())
            return true;
        if (i >= currentTokens.size())
            return false;
        const QString a = candidateTokens.at(i);
        const QString b = currentTokens.at(i);
        const bool aNumeric = !a.isEmpty() && a.toInt() >= 0 && a == QString::number(a.toInt());
        const bool bNumeric = !b.isEmpty() && b.toInt() >= 0 && b == QString::number(b.toInt());
        if (aNumeric && bNumeric && a.toInt() != b.toInt())
            return a.toInt() > b.toInt();
        if (aNumeric != bNumeric)
            return !aNumeric;
        if (a != b)
            return a > b;
    }
    return false;
}

void UpdateController::installUpdate()
{
    if (!m_updateAvailable || m_downloadUrl.isEmpty() || m_downloading)
        return;
    m_downloading = true;
    m_downloadProgress = 0.0;
    m_downloadReceivedBytes = 0;
    m_downloadTotalBytes = m_fileSize;
    setError(QString());
    emit downloadingChanged();
    emit downloadProgressChanged();
    const QString tempDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    const QString fileName = m_fileName.isEmpty()
        ? QStringLiteral("AetherStudy-update.exe") : QFileInfo(m_fileName).fileName();
    const QString target = QDir(tempDir).filePath(fileName);
    const QString curlPath = QStandardPaths::findExecutable(QStringLiteral("curl.exe"));
    if (!curlPath.isEmpty()) {
        startCurlDownload(curlPath, target);
        return;
    }
    startNetworkDownload(target);
}

void UpdateController::startNetworkDownload(const QString &target)
{
    m_downloadFile.setFileName(target);
    if (!m_downloadFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError(QStringLiteral("无法创建临时安装包文件"));
        m_downloading = false;
        emit downloadingChanged();
        return;
    }
    m_downloadHash.reset();
    m_downloadWriteFailed = false;

    QNetworkRequest request{QUrl(m_downloadUrl)};
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);
    request.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("Mozilla/5.0 AetherStudy-Qt/%1").arg(clientVersion));
    QNetworkReply *reply = m_network->get(request);
    reply->setProperty("targetPath", target);
    connect(reply, &QNetworkReply::readyRead, this, [this, reply]() {
        consumeDownloadData(reply);
    });
    connect(reply, &QNetworkReply::downloadProgress, this,
            [this](qint64 received, qint64 total) {
        m_downloadReceivedBytes = received;
        m_downloadTotalBytes = total;
        m_downloadProgress = total > 0
            ? qBound(0.0, static_cast<double>(received) / static_cast<double>(total), 1.0)
            : 0.0;
        emit downloadProgressChanged();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleDownloadReply(reply);
    });
}

void UpdateController::startCurlDownload(const QString &curlPath, const QString &target)
{
    const QString partialPath = target + QStringLiteral(".download");
    QFile::remove(partialPath);
    auto *process = new QProcess(this);
    m_downloadProcess = process;
    process->setProperty("targetPath", target);
    process->setProperty("partialPath", partialPath);
    process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(process, &QProcess::readyReadStandardError, this, [this, process]() {
        const QString output = QString::fromLocal8Bit(process->readAllStandardError());
        static const QRegularExpression percentPattern(QStringLiteral("(\\d+(?:\\.\\d+)?)%"));
        auto match = percentPattern.globalMatch(output);
        double latestPercent = -1.0;
        while (match.hasNext())
            latestPercent = match.next().captured(1).toDouble();
        if (latestPercent < 0.0)
            return;
        m_downloadProgress = qBound(0.0, latestPercent / 100.0, 1.0);
        if (m_downloadTotalBytes > 0)
            m_downloadReceivedBytes = qRound64(m_downloadProgress * m_downloadTotalBytes);
        emit downloadProgressChanged();
    });

    connect(process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this, process](int exitCode, QProcess::ExitStatus exitStatus) {
        const QString target = process->property("targetPath").toString();
        const QString partialPath = process->property("partialPath").toString();
        const QString errorOutput = QString::fromLocal8Bit(process->readAllStandardError()).trimmed();
        const bool downloaded = exitStatus == QProcess::NormalExit && exitCode == 0
                                && QFileInfo(partialPath).size() > 0;
        if (!downloaded) {
            QFile::remove(partialPath);
            setError(errorOutput.isEmpty() ? QStringLiteral("下载安装包失败")
                                           : QStringLiteral("下载安装包失败：%1").arg(errorOutput));
        } else if (!verifyDownloadedFile(partialPath)) {
            QFile::remove(partialPath);
            setError(QStringLiteral("安装包校验失败"));
        } else {
            QFile::remove(target);
            if (!QFile::rename(partialPath, target)) {
                QFile::remove(partialPath);
                setError(QStringLiteral("保存安装包失败"));
            } else {
                m_downloadProgress = 1.0;
                emit downloadProgressChanged();
                if (!launchDownloadedFile(target))
                    setError(QStringLiteral("安装程序启动失败，请手动运行：%1").arg(target));
            }
        }
        m_downloadProcess = nullptr;
        process->deleteLater();
        m_downloading = false;
        emit downloadingChanged();
    });

    process->start(curlPath, {
        QStringLiteral("--location"), QStringLiteral("--fail"),
        QStringLiteral("--progress-bar"), QStringLiteral("--connect-timeout"),
        QStringLiteral("20"), QStringLiteral("--retry"), QStringLiteral("3"),
        QStringLiteral("--output"), partialPath, m_downloadUrl
    });
}

bool UpdateController::verifyDownloadedFile(const QString &path)
{
    if (m_sha256.isEmpty())
        return true;
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    QCryptographicHash hash(QCryptographicHash::Sha256);
    while (!file.atEnd())
        hash.addData(file.read(1024 * 1024));
    return QString::fromLatin1(hash.result().toHex()) == m_sha256;
}

bool UpdateController::launchDownloadedFile(const QString &path)
{
    if (!QFileInfo::exists(path))
        return false;

    bool started = false;
#ifdef Q_OS_WIN
    if (path.endsWith(QStringLiteral(".exe"), Qt::CaseInsensitive)) {
        const QString nativePath = QDir::toNativeSeparators(path);
        const QString workingDir = QFileInfo(path).absolutePath();
        const QString installLog = QDir(QStandardPaths::writableLocation(
            QStandardPaths::TempLocation)).filePath(QStringLiteral("AetherStudy-update-install.log"));
        const QString parameters = QStringLiteral(
            "/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS "
            "/AUTOSTART=1 /LOG=\"%1\"").arg(QDir::toNativeSeparators(installLog));
        const HINSTANCE result = ShellExecuteW(
            nullptr, L"open", reinterpret_cast<LPCWSTR>(nativePath.utf16()),
            reinterpret_cast<LPCWSTR>(parameters.utf16()),
            reinterpret_cast<LPCWSTR>(workingDir.utf16()), SW_SHOWNORMAL);
        started = reinterpret_cast<INT_PTR>(result) > 32;
    } else {
        started = QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
#else
    started = path.endsWith(QStringLiteral(".exe"), Qt::CaseInsensitive)
        ? QProcess::startDetached(path, {})
        : QDesktopServices::openUrl(QUrl::fromLocalFile(path));
#endif
    if (started)
        QTimer::singleShot(300, QCoreApplication::instance(), &QCoreApplication::quit);
    return started;
}

void UpdateController::consumeDownloadData(QNetworkReply *reply)
{
    const QByteArray chunk = reply->readAll();
    if (chunk.isEmpty())
        return;
    if (m_downloadWriteFailed || !m_downloadFile.isOpen()
        || m_downloadFile.write(chunk) != chunk.size()) {
        m_downloadWriteFailed = true;
        reply->abort();
        return;
    }
    m_downloadHash.addData(chunk);
}

void UpdateController::handleDownloadReply(QNetworkReply *reply)
{
    const QString target = reply->property("targetPath").toString();
    consumeDownloadData(reply);
    m_downloadFile.flush();
    m_downloadFile.close();
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const bool httpOk = status == 200 || status == 206;
    bool ok = reply->error() == QNetworkReply::NoError && httpOk
              && !m_downloadWriteFailed && QFileInfo(target).size() > 0;
    if (ok && !m_sha256.isEmpty())
        ok = QString::fromLatin1(m_downloadHash.result().toHex()) == m_sha256;
    if (ok) {
        m_downloadProgress = 1.0;
        emit downloadProgressChanged();
    }
    if (!ok) {
        QFile::remove(target);
        if (m_downloadWriteFailed)
            setError(QStringLiteral("保存安装包失败"));
        else if (!httpOk)
            setError(QStringLiteral("下载安装包失败（HTTP %1）").arg(status));
        else if (!m_sha256.isEmpty())
            setError(QStringLiteral("安装包校验失败"));
        else
            setError(reply->errorString());
    } else {
        if (!launchDownloadedFile(target))
            setError(QStringLiteral("安装程序启动失败，请手动运行：%1").arg(target));
    }
    reply->deleteLater();
    m_downloading = false;
    emit downloadingChanged();
}
