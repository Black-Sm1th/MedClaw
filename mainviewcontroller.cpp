#include "mainviewcontroller.h"
#include "chatmodel.h"
#include "gateway_client.h"
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QUrl>

MainViewController::MainViewController(QObject* parent)
    : QObject(parent)
{
}

void MainViewController::init(ChatModel *chatModel, GatewayClient *wsClient)
{
    m_chatModel = chatModel;
    m_wsClient  = wsClient;
}

void MainViewController::sendMessage(const QString &text,
                                     const QString &workspaceForNewAgent)
{
    if (!m_chatModel || text.trimmed().isEmpty())
        return;

    m_chatModel->addMessage(QStringLiteral("user"), text);

    if (m_wsClient)
        m_wsClient->sendChatMessage(text, QString(), workspaceForNewAgent);
}

void MainViewController::sendMessageWithFiles(const QString &text,
                                              const QVariantList &files,
                                              const QString &workspaceForNewAgent)
{
    if (!m_chatModel || text.trimmed().isEmpty())
        return;

    if (!m_wsClient) {
        sendMessage(text, workspaceForNewAgent);
        return;
    }

    const bool isNewAgent = m_wsClient->currentSessionKey().isEmpty();

    if (!isNewAgent && !files.isEmpty()) {
        const QVariantMap identity = m_wsClient->agentIdentity();
        const QString ws = identity.value(QStringLiteral("workspace")).toString();
        m_wsClient->resolveAndCopyFiles(files, ws);

        m_chatModel->addMessage(QStringLiteral("user"), text);
        m_wsClient->sendChatMessage(text);
    } else if (!files.isEmpty()) {
        m_wsClient->setPendingChatFiles(files);
        m_chatModel->addMessage(QStringLiteral("user"), text);
        m_wsClient->sendChatMessage(text, QString(), workspaceForNewAgent);
    } else {
        sendMessage(text, workspaceForNewAgent);
    }
}

QString MainViewController::userHomePath() const
{
    return QDir::homePath();
}

QString MainViewController::fileSizeHuman(const QString &fileUrl) const
{
    QString path = fileUrl;
    if (path.startsWith(QStringLiteral("file://")))
        path = QUrl(path).toLocalFile();

    const QFileInfo fi(path);
    if (!fi.exists())
        return QString();

    if (fi.isDir()) {
        qint64 total = 0;
        int count = 0;
        QDirIterator it(fi.absoluteFilePath(), QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            total += it.fileInfo().size();
            ++count;
        }
        const QString sizeStr = fileSizeHumanBytes(total);
        return QStringLiteral("%1 (%2 个文件)").arg(sizeStr).arg(count);
    }

    return fileSizeHumanBytes(fi.size());
}

QVariantList MainViewController::listFolderFiles(const QString &folderUrl) const
{
    QString path = folderUrl;
    if (path.startsWith(QStringLiteral("file://")))
        path = QUrl(path).toLocalFile();

    QVariantList result;
    const QFileInfo fi(path);
    if (!fi.exists() || !fi.isDir())
        return result;

    const QString folderName = fi.fileName();
    QDirIterator it(path, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        const QFileInfo entryInfo = it.fileInfo();
        const QString relPath = QDir(path).relativeFilePath(entryInfo.absoluteFilePath());
        const QString displayName = folderName + QStringLiteral("/") + relPath;

        const QString ext = entryInfo.suffix().toUpper();
        const QStringList imgExts = {
            QStringLiteral("JPG"), QStringLiteral("JPEG"), QStringLiteral("PNG"),
            QStringLiteral("GIF"), QStringLiteral("BMP"), QStringLiteral("WEBP")
        };
        const bool isImg = imgExts.contains(ext);
        const QString url = QUrl::fromLocalFile(entryInfo.absoluteFilePath()).toString();

        QVariantMap entry;
        entry[QStringLiteral("fileName")] = displayName;
        entry[QStringLiteral("filePath")] = isImg ? url : QString();
        entry[QStringLiteral("fileUrl")]  = url;
        entry[QStringLiteral("fileSize")] = fileSizeHumanBytes(entryInfo.size());
        entry[QStringLiteral("ext")]      = ext;
        entry[QStringLiteral("isImage")]  = isImg;
        result.append(entry);
    }
    return result;
}

QString MainViewController::copyFileToWorkspace(const QString &fileUrl,
                                                const QString &workspace) const
{
    QString srcPath = fileUrl;
    if (srcPath.startsWith(QStringLiteral("file://")))
        srcPath = QUrl(srcPath).toLocalFile();

    const QFileInfo srcInfo(srcPath);
    if (!srcInfo.exists() || !srcInfo.isFile())
        return QString();

    const QString ws = resolveWorkspacePath(workspace);
    const QString uploadDir = ws;
    QDir().mkpath(uploadDir);

    QString destName = srcInfo.fileName();
    QString destPath = uploadDir + QStringLiteral("/") + destName;

    if (QFile::exists(destPath)) {
        const QString base = srcInfo.completeBaseName();
        const QString suffix = srcInfo.suffix();
        int seq = 1;
        do {
            destName = suffix.isEmpty()
                ? QStringLiteral("%1_%2").arg(base).arg(seq)
                : QStringLiteral("%1_%2.%3").arg(base).arg(seq).arg(suffix);
            destPath = uploadDir + QStringLiteral("/") + destName;
            ++seq;
        } while (QFile::exists(destPath));
    }

    if (!QFile::copy(srcPath, destPath)) {
        qWarning() << "[MainVC] copy failed:" << srcPath << "->" << destPath;
        return QString();
    }
    qDebug() << "[MainVC] copied" << srcPath << "->" << destPath;
    return destName;
}

QString MainViewController::resolveWorkspacePath(const QString &ws)
{
    QString p = ws.trimmed();
    if (p.isEmpty())
        return p;
    if (p.startsWith(QStringLiteral("~/")))
        p = QDir::homePath() + p.mid(1);
    if (QDir::isAbsolutePath(p))
        return QDir::cleanPath(p);
    return QDir::cleanPath(QDir::homePath() + QLatin1Char('/') + p);
}

QString MainViewController::fileSizeHumanBytes(qint64 bytes)
{
    if (bytes < 1024)
        return QStringLiteral("%1B").arg(bytes);
    if (bytes < 1024 * 1024)
        return QStringLiteral("%1KB").arg(QString::number(bytes / 1024.0, 'f', 1));
    if (bytes < 1024LL * 1024 * 1024)
        return QStringLiteral("%1MB").arg(QString::number(bytes / (1024.0 * 1024.0), 'f', 1));
    return QStringLiteral("%1GB").arg(
        QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 2));
}
