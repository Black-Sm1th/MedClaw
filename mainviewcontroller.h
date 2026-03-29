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

    Q_INVOKABLE QString copyFileToWorkspace(const QString &fileUrl,
                                            const QString &workspace) const;

private:
    static QString resolveWorkspacePath(const QString &ws);

    ChatModel      *m_chatModel  = nullptr;
    GatewayClient  *m_wsClient   = nullptr;
};

#endif // MAINVIEWCONTROLLER_H
