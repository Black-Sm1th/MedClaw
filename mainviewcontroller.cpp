#include "mainviewcontroller.h"
#include "chatmodel.h"
#include "gateway_client.h"
#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStringList>
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

QString MainViewController::resolveLocalFileLink(const QString &link,
                                                 const QString &workspace) const
{
    const QString candidate = normalizeLocalFileCandidate(link);
    if (candidate.isEmpty())
        return QString();

    auto asFileUrlIfExists = [](const QString &path) -> QString {
        const QFileInfo fi(path);
        if (!fi.exists())
            return QString();
        return QUrl::fromLocalFile(fi.absoluteFilePath()).toString();
    };

    QString direct = candidate;
    if (direct.startsWith(QStringLiteral("~/")))
        direct = QDir::homePath() + direct.mid(1);
    direct = QDir::cleanPath(direct);

    QString resolved = asFileUrlIfExists(direct);
    if (!resolved.isEmpty())
        return resolved;

    QStringList searchRoots;
    auto addSearchRoot = [&](const QString &root) {
        const QString path = resolveWorkspacePath(root);
        if (path.isEmpty() || !QFileInfo(path).isDir() || searchRoots.contains(path))
            return;
        searchRoots.append(path);
    };

    addSearchRoot(workspace);
    if (m_wsClient) {
        addSearchRoot(m_wsClient->currentTaskWorkspace());
        addSearchRoot(m_wsClient->agentIdentity().value(QStringLiteral("workspace")).toString());
    }
    addSearchRoot(QDir::homePath() + QStringLiteral("/.openclaw/workspace"));

    if (searchRoots.isEmpty())
        return QString();

    if (candidate.contains(QLatin1Char('/')) || candidate.contains(QLatin1Char('\\'))) {
        for (const QString &root : searchRoots) {
            resolved = asFileUrlIfExists(QDir(root).filePath(candidate));
            if (!resolved.isEmpty())
                return resolved;
        }
    }

    const QString fileName = QFileInfo(candidate).fileName();
    if (fileName.isEmpty() || fileName == QStringLiteral(".") || fileName == QStringLiteral(".."))
        return QString();

    for (const QString &root : searchRoots) {
        QDirIterator it(root,
                        QStringList() << fileName,
                        QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                        QDirIterator::Subdirectories);
        if (it.hasNext()) {
            it.next();
            return QUrl::fromLocalFile(it.fileInfo().absoluteFilePath()).toString();
        }
    }

    return QString();
}

QString MainViewController::resolveWorkspacePath(const QString &ws)
{
    QString p = ws;
    if (p.startsWith(QStringLiteral("~/")))
        p = QDir::homePath() + p.mid(1);
    return QDir::cleanPath(p);
}

QString MainViewController::normalizeLocalFileCandidate(const QString &link)
{
    QString value = link.trimmed();
    if (value.isEmpty())
        return QString();

    if (value.startsWith(QStringLiteral("medclaw-local:"), Qt::CaseInsensitive)) {
        value = value.mid(QStringLiteral("medclaw-local:").size());
        value = QUrl::fromPercentEncoding(value.toUtf8());
    }
    if (value.startsWith(QStringLiteral("file://"), Qt::CaseInsensitive))
        value = QUrl(value).toLocalFile();

    while (value.startsWith(QLatin1Char('`')) || value.startsWith(QLatin1Char('"')) ||
           value.startsWith(QLatin1Char('\'')) || value.startsWith(QLatin1Char('(')) ||
           value.startsWith(QLatin1Char('['))) {
        value = value.mid(1).trimmed();
    }
    while (value.endsWith(QLatin1Char('`')) || value.endsWith(QLatin1Char('"')) ||
           value.endsWith(QLatin1Char('\'')) || value.endsWith(QLatin1Char(')')) ||
           value.endsWith(QLatin1Char(']')) || value.endsWith(QLatin1Char(',')) ||
           value.endsWith(QLatin1Char('.')) || value.endsWith(QLatin1Char(';')) ||
           value.endsWith(QLatin1Char(':'))) {
        value.chop(1);
        value = value.trimmed();
    }

    const QFileInfo fullInfo(value);
    if (!fullInfo.exists()) {
        const QRegularExpression lineSuffix(QStringLiteral("^(.*):(\\d+)(?::\\d+)?$"));
        const QRegularExpressionMatch match = lineSuffix.match(value);
        if (match.hasMatch())
            value = match.captured(1).trimmed();
    }

    return value;
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
