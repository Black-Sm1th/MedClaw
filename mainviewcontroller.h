#ifndef MAINVIEWCONTROLLER_H
#define MAINVIEWCONTROLLER_H

#include "CommonFunc.h"
#include <QObject>

class GatewayClient;
class ChatModel;

class MainViewController : public QObject
{
    Q_OBJECT
    SINGLETON_CLASS(MainViewController)

    Q_PROPERTY(bool hasConversation READ hasConversation NOTIFY hasConversationChanged)

public:
    void setWsClient(GatewayClient *client);
    void setChatModel(ChatModel *model);

    Q_INVOKABLE void sendMessage(const QString &text);
    Q_INVOKABLE void startNewConversation();

    bool hasConversation() const;

signals:
    void hasConversationChanged();
    void conversationStarted(const QString &title);
    void messageSent();

private:
    GatewayClient *m_wsClient  = nullptr;
    ChatModel     *m_chatModel = nullptr;
    bool           m_hasConversation = false;
};

#endif // MAINVIEWCONTROLLER_H
