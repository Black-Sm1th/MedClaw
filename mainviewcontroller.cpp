#include "mainviewcontroller.h"
#include "gateway_client.h"
#include "chatmodel.h"

MainViewController::MainViewController(QObject *parent)
    : QObject(parent)
{
}

void MainViewController::setWsClient(GatewayClient *client)
{
    m_wsClient = client;
}

void MainViewController::setChatModel(ChatModel *model)
{
    m_chatModel = model;
}

bool MainViewController::hasConversation() const
{
    return m_hasConversation;
}

void MainViewController::sendMessage(const QString &text)
{
    if (!m_wsClient || !m_chatModel || text.trimmed().isEmpty())
        return;

    const bool isFirst = !m_hasConversation;

    m_chatModel->addMessage(QStringLiteral("user"), text);
    m_wsClient->sendChatMessage(text);

    if (isFirst) {
        m_hasConversation = true;
        emit hasConversationChanged();

        QString title = text.trimmed();
        if (title.length() > 20)
            title = title.left(20) + QStringLiteral("...");
        emit conversationStarted(title);
    }

    emit messageSent();
}

void MainViewController::startNewConversation()
{
    if (m_chatModel)
        m_chatModel->clear();

    if (m_wsClient)
        m_wsClient->createNewSession();

    m_hasConversation = false;
    emit hasConversationChanged();
}
