#include <QCoreApplication>

#include "OnlineOfficeClient.h"

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    OnlineOfficeClient client;
    client.setBridgeBaseUrl(QStringLiteral("http://127.0.0.1:8090/bridge"));
    client.setApiKey(QStringLiteral("test-only"));
    return client.bridgeBaseUrl().isEmpty();
}
