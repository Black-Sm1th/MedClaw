#ifndef MAINVIEWCONTROLLER_H
#define MAINVIEWCONTROLLER_H

#include "CommonFunc.h"
#include <QObject>
#include <QVariantList>

class ChatModel;
class GatewayClient;

class MainViewController : public QObject
{
    Q_OBJECT
    SINGLETON_CLASS(MainViewController)
public:
    void init(ChatModel *chatModel, GatewayClient *wsClient);

    Q_INVOKABLE void sendMessage(const QString &text,
                                 const QString &workspaceForNewAgent = QString());

    Q_INVOKABLE void sendMessageWithFiles(const QString &text,
                                          const QVariantList &files,
                                          const QString &workspaceForNewAgent = QString());

    Q_INVOKABLE QString fileSizeHuman(const QString &fileUrl) const;

    Q_INVOKABLE QVariantList listFolderFiles(const QString &folderUrl) const;

    Q_INVOKABLE QString copyFileToWorkspace(const QString &fileUrl,
                                            const QString &workspace) const;

    Q_INVOKABLE QString resolveLocalFileLink(const QString &link,
                                             const QString &workspace) const;

private:
    static QString resolveWorkspacePath(const QString &ws);
    static QString fileSizeHumanBytes(qint64 bytes);
    static QString normalizeLocalFileCandidate(const QString &link);

    ChatModel      *m_chatModel  = nullptr;
    GatewayClient  *m_wsClient   = nullptr;
};

#endif // MAINVIEWCONTROLLER_H
