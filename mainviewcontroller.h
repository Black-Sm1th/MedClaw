#ifndef MAINVIEWCONTROLLER_H
#define MAINVIEWCONTROLLER_H

#include "CommonFunc.h"
#include <QObject>

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

private:
    ChatModel      *m_chatModel  = nullptr;
    GatewayClient  *m_wsClient   = nullptr;
};

#endif // MAINVIEWCONTROLLER_H
