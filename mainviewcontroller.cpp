#include "mainviewcontroller.h"
#include "chatmodel.h"
#include "gateway_client.h"
#include <QDebug>

MainViewController::MainViewController(QObject* parent)
    : QObject(parent)
{
}

void MainViewController::init(ChatModel *chatModel, GatewayClient *wsClient)
{
    m_chatModel = chatModel;
    m_wsClient  = wsClient;
}

void MainViewController::sendMessage(const QString &text)
{
    if (!m_chatModel || text.trimmed().isEmpty())
        return;

    m_chatModel->addMessage(QStringLiteral("user"), text);

    if (m_wsClient)
        m_wsClient->sendChatMessage(text);
}
