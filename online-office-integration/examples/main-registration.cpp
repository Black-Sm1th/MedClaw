// Add these lines to MedClaw/main.cpp when integration is authorized.
#include "online-office-integration/client-qt/OnlineOfficeClient.h"

// Place after QGuiApplication is created and before engine.load(...).
OnlineOfficeClient onlineOffice;
onlineOffice.setBridgeBaseUrl(
    qEnvironmentVariable("MEDCLAW_OFFICE_BRIDGE_URL",
                         "http://111.6.178.34:24641/bridge"));
onlineOffice.setApiKey(qEnvironmentVariable("MEDCLAW_OFFICE_API_KEY"));
engine.rootContext()->setContextProperty(QStringLiteral("onlineOffice"), &onlineOffice);
