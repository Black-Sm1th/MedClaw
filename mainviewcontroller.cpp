#include "mainviewcontroller.h"
#include "chatmodel.h"
#include "gateway_client.h"
#include <QDebug>
#include <QDir>
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
        const QString fileSuffix = m_wsClient->resolveAndCopyFiles(files, ws);
        QString finalMsg = text;
        if (!fileSuffix.isEmpty())
            finalMsg += fileSuffix;

        m_chatModel->addMessage(QStringLiteral("user"), text);
        m_wsClient->sendChatMessage(finalMsg);
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

    const qint64 bytes = fi.size();
    if (bytes < 1024)
        return QStringLiteral("%1B").arg(bytes);
    if (bytes < 1024 * 1024)
        return QStringLiteral("%1KB").arg(QString::number(bytes / 1024.0, 'f', 1));
    if (bytes < 1024LL * 1024 * 1024)
        return QStringLiteral("%1MB").arg(QString::number(bytes / (1024.0 * 1024.0), 'f', 1));
    return QStringLiteral("%1GB").arg(
        QString::number(bytes / (1024.0 * 1024.0 * 1024.0), 'f', 2));
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
    const QString uploadDir = ws + QStringLiteral("/uploads");
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
    QString p = ws;
    if (p.startsWith(QStringLiteral("~/")))
        p = QDir::homePath() + p.mid(1);
    return QDir::cleanPath(p);
}
