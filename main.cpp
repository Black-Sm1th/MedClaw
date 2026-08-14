#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainterPath>
#include <QRegion>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QWindow>
#include <QtWebEngine/QtWebEngine>
#include "CommonFunc.h"
#include "mainviewcontroller.h"
#include "gateway_client.h"
#include "chatmodel.h"
#include "session_reader.h"
#include "auth_controller.h"
#include "online-office-integration/client-qt/OnlineOfficeClient.h"

static void configureQtWebEngineRuntime(const char *executablePath)
{
    const QString appDir = QFileInfo(QString::fromLocal8Bit(executablePath)).absolutePath();
    const QString processPath = QDir(appDir).filePath(QStringLiteral("QtWebEngineProcess.exe"));
    const QString resourcesPath = QDir(appDir).filePath(QStringLiteral("resources"));
    const QString localesPath =
        QDir(appDir).filePath(QStringLiteral("translations/qtwebengine_locales"));

    if (qEnvironmentVariableIsEmpty("QTWEBENGINEPROCESS_PATH"))
        qputenv("QTWEBENGINEPROCESS_PATH", processPath.toLocal8Bit());
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_RESOURCES_PATH"))
        qputenv("QTWEBENGINE_RESOURCES_PATH", resourcesPath.toLocal8Bit());
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_LOCALES_PATH"))
        qputenv("QTWEBENGINE_LOCALES_PATH", localesPath.toLocal8Bit());

    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_DISABLE_SANDBOX"))
        qputenv("QTWEBENGINE_DISABLE_SANDBOX", "1");

    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_CHROMIUM_FLAGS")) {
        QByteArray flags("--no-sandbox");
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", flags);
    }
}

static void updateRoundedWindowMask(QWindow *window)
{
    if (!window || window->width() <= 0 || window->height() <= 0)
        return;

    const Qt::WindowStates states = window->windowStates();
    if (states.testFlag(Qt::WindowMaximized) || states.testFlag(Qt::WindowFullScreen)) {
        window->setMask(QRegion());
        return;
    }

    constexpr qreal cornerRadius = 12.0;
    QPainterPath path;
    path.addRoundedRect(QRectF(0, 0, window->width(), window->height()),
                        cornerRadius, cornerRadius);
    window->setMask(QRegion(path.toFillPolygon().toPolygon()));
}

static QJsonObject loadOfficeConfig(const QString &dataRoot)
{
    const QDir applicationDir(QCoreApplication::applicationDirPath());
    const QStringList candidates = {
        QDir(dataRoot).filePath(QStringLiteral("AppData/config/office.json")),
        applicationDir.filePath(QStringLiteral("config/office.json")),
        QDir(applicationDir.filePath(QStringLiteral("..")))
            .filePath(QStringLiteral("config/office.json"))
    };
    for (const QString &path : candidates) {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly))
            continue;
        QJsonParseError error;
        const QJsonDocument document = QJsonDocument::fromJson(file.readAll(), &error);
        if (error.error != QJsonParseError::NoError || !document.isObject()) {
            qWarning() << "[OnlineOffice] invalid config:" << path
                       << error.errorString();
            continue;
        }
        qDebug().noquote() << "[OnlineOffice] loaded config:" << path;
        return document.object();
    }
    return {};
}

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
#if QT_VERSION >= QT_VERSION_CHECK(5, 14, 0)
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
        Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
#endif
#endif
    if (qEnvironmentVariableIsEmpty("QT_OPENGL"))
        qputenv("QT_OPENGL", "angle");
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QCoreApplication::setAttribute(Qt::AA_UseOpenGLES);
    configureQtWebEngineRuntime(argv[0]);
    QtWebEngine::initialize();

    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("AetherMED"));
    QCoreApplication::setApplicationName(QStringLiteral("Aether study"));

    // Keep relative runtime data paths stable and carry existing installs forward.
    const QString genericDataRoot =
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    const QString preferredDataRoot =
        QDir(genericDataRoot).filePath(QStringLiteral("AetherStudy"));
    const QString legacyDataRoot =
        QDir(genericDataRoot).filePath(QStringLiteral("Aether_ClawDESK"));
    QString dataRoot = preferredDataRoot;
    if (!QFileInfo::exists(preferredDataRoot) && QFileInfo::exists(legacyDataRoot)
        && !QDir(genericDataRoot).rename(QStringLiteral("Aether_ClawDESK"),
                                         QStringLiteral("AetherStudy"))) {
        dataRoot = legacyDataRoot;
    }
    if (!QDir().mkpath(dataRoot) || !QDir::setCurrent(dataRoot))
        qWarning() << "Unable to use application data directory:" << dataRoot;

    // ── WebSocket 客户端 & 聊天数据模型 ──
    GatewayClient wsClient;
    ChatModel chatModel;

    // 收到聊天消息：完整消息直接添加，增量消息追加到流式缓冲
    QObject::connect(&wsClient, &GatewayClient::chatMessageReceived,
                     [&chatModel](const QString &role, const QString &content, bool isDelta) {
        if (isDelta) {
            chatModel.appendStreamChunk(content);
        } else if (!content.isEmpty()) {
            chatModel.addMessage(role, content);
        }
    });

    // 流式输出开始：在 ChatModel 中创建空的 assistant 消息占位
    QObject::connect(&wsClient, &GatewayClient::streamingStarted,
                     [&chatModel]() { chatModel.beginStreaming(); });

    // 流式输出结束：标记流式状态完成
    QObject::connect(&wsClient, &GatewayClient::streamingFinished,
                     [&chatModel]() { chatModel.endStreaming(); });

    QObject::connect(&wsClient, &GatewayClient::artifactsDetected,
                     [&chatModel, &wsClient](const QString &sessionKey,
                                             const QVariantList &artifacts) {
        chatModel.setArtifactsForLastAssistant(artifacts);
        wsClient.persistSessionArtifacts(sessionKey, chatModel.messages());
    });

    // 工具调用：在 ChatModel 中插入工具卡片
    QObject::connect(&wsClient, &GatewayClient::toolCallReceived,
                     [&chatModel](const QString &name, const QString &args,
                                  const QString &id) {
        chatModel.addToolCall(name, args, id);
    });

    // 工具结果：在 ChatModel 中插入工具结果块
    QObject::connect(&wsClient, &GatewayClient::toolResultReceived,
                     [&chatModel](const QString &name, const QString &content,
                                  const QString &id, bool isError) {
        chatModel.addToolResult(name, content, id, isError);
    });

    // 工具结果补拉完成：原地合并完整文本（不清空聊天模型，避免闪烁）
    // 同时补插实时事件中漏掉的 toolCall 条目
    QObject::connect(&wsClient, &GatewayClient::toolResultsRefreshed,
                     [&chatModel](const QVariantList &messages) {
        for (const QVariant &v : messages) {
            const QVariantMap m = v.toMap();
            const QString mtype = m.value(QStringLiteral("msgType")).toString();
            const QString tcId  = m.value(QStringLiteral("toolCallId")).toString();
            if (tcId.isEmpty())
                continue;

            if (mtype == QLatin1String("toolCall")) {
                if (!chatModel.hasToolCallId(tcId))
                    chatModel.addToolCall(
                        m.value(QStringLiteral("toolName")).toString(),
                        m.value(QStringLiteral("toolArgs")).toString(),
                        tcId);
            } else if (mtype == QLatin1String("toolResult")) {
                if (!chatModel.hasToolCallId(tcId))
                    chatModel.addToolCall(
                        m.value(QStringLiteral("toolName")).toString(),
                        QString(), tcId);
                chatModel.addToolResult(
                    m.value(QStringLiteral("toolName")).toString(),
                    m.value(QStringLiteral("content")).toString(),
                    tcId,
                    m.value(QStringLiteral("isError")).toBool());
            }
        }
    });

    // 新会话创建成功：聊天区保留本地已追加的首条用户消息。
    QObject::connect(&wsClient, &GatewayClient::sessionCreated,
                     []() {});

    // 历史消息加载完成：清空当前显示并填充历史记录
    QObject::connect(&wsClient, &GatewayClient::historyLoaded,
                     [&chatModel, &wsClient](const QVariantList &messages) {
        QString sessionKey = wsClient.currentViewSessionKey().trimmed();
        if (sessionKey.isEmpty())
            sessionKey = wsClient.currentTaskSessionKey().trimmed();
        wsClient.rememberInputFilesFromHistory(messages);
        chatModel.loadHistory(
            wsClient.restoreSessionArtifacts(sessionKey, messages));
    });

    // ── 本地会话历史读取器 ──
    SessionReader sessionReader;
    AuthController authController;
    wsClient.setTaskSessionUserId(authController.userId());
    QObject::connect(&authController, &AuthController::userChanged,
                     [&wsClient, &authController]() {
        wsClient.setTaskSessionUserId(authController.userId());
    });

    GET_SINGLETON(MainViewController)->init(&chatModel, &wsClient);

    QQmlApplicationEngine engine;
    qmlRegisterType<OnlineOfficeClient>("MedClaw.Office", 1, 0,
                                        "OnlineOfficeClient");
    const QJsonObject officeConfig = loadOfficeConfig(dataRoot);
    QString officeBridgeUrl = qEnvironmentVariable("MEDCLAW_OFFICE_BRIDGE_URL").trimmed();
    QString officeApiKey = qEnvironmentVariable("MEDCLAW_OFFICE_API_KEY").trimmed();
    if (officeBridgeUrl.isEmpty())
        officeBridgeUrl = officeConfig.value(QStringLiteral("bridgeUrl")).toString().trimmed();
    if (officeApiKey.isEmpty())
        officeApiKey = officeConfig.value(QStringLiteral("apiKey")).toString().trimmed();
    if (officeBridgeUrl.isEmpty())
        officeBridgeUrl = QStringLiteral("http://111.6.178.34:24641/bridge");

    OnlineOfficeClient onlineOffice;
    onlineOffice.setBridgeBaseUrl(officeBridgeUrl);
    onlineOffice.setApiKey(officeApiKey);
    const QSize savedWindowSize = QSettings().value(
        QStringLiteral("ui/windowSize")).toSize();
    engine.rootContext()->setContextProperty(
        QStringLiteral("initialWindowWidth"), savedWindowSize.width());
    engine.rootContext()->setContextProperty(
        QStringLiteral("initialWindowHeight"), savedWindowSize.height());
    engine.rootContext()->setContextProperty("$MainViewController", GET_SINGLETON(MainViewController));
    engine.rootContext()->setContextProperty(QStringLiteral("wsClient"), &wsClient);
    engine.rootContext()->setContextProperty(QStringLiteral("chatModel"), &chatModel);
    engine.rootContext()->setContextProperty(QStringLiteral("sessionReader"), &sessionReader);
    engine.rootContext()->setContextProperty(QStringLiteral("authController"), &authController);
    engine.rootContext()->setContextProperty(QStringLiteral("onlineOffice"), &onlineOffice);

    int fontId1 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-55-Regular.ttf");
    int fontId2 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-65-Regular.ttf");
    int fontId3 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-85-Regular.ttf");
    int fontId4 = QFontDatabase::addApplicationFont(":/fonts/AlimamaShuHeiTi-Bold.ttf");

    // --test 启动 WebSocket 测试页。
    const bool testMode = app.arguments().contains(QStringLiteral("--test"));
    const QUrl url(testMode ? QStringLiteral("qrc:/TestChatClient.qml")
                            : QStringLiteral("qrc:/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url, testMode](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);

            QWindow *window = qobject_cast<QWindow *>(obj);
            if (!window || url != objUrl)
                return;

            if (!testMode) {
                auto *saveWindowSizeTimer = new QTimer(window);
                saveWindowSizeTimer->setSingleShot(true);
                saveWindowSizeTimer->setInterval(250);

                const auto scheduleWindowSizeSave = [window, saveWindowSizeTimer]() {
                    const Qt::WindowStates states = window->windowStates();
                    if (states.testFlag(Qt::WindowMinimized)
                        || states.testFlag(Qt::WindowMaximized)
                        || states.testFlag(Qt::WindowFullScreen)) {
                        return;
                    }

                    window->setProperty("normalWindowSize", window->size());
                    saveWindowSizeTimer->start();
                };
                QObject::connect(window, &QWindow::widthChanged, window,
                                 scheduleWindowSizeSave);
                QObject::connect(window, &QWindow::heightChanged, window,
                                 scheduleWindowSizeSave);
                QObject::connect(saveWindowSizeTimer, &QTimer::timeout, window,
                                 [window]() {
                    const QSize size = window->property("normalWindowSize").toSize();
                    if (size.isValid())
                        QSettings().setValue(QStringLiteral("ui/windowSize"), size);
                });
                window->setProperty("normalWindowSize", window->size());

                QObject::connect(qApp, &QCoreApplication::aboutToQuit, window,
                                 [window]() {
                    const QSize size = window->property("normalWindowSize").toSize();
                    if (!size.isValid())
                        return;
                    QSettings settings;
                    settings.setValue(QStringLiteral("ui/windowSize"), size);
                    settings.sync();
                });
            }

            QObject::connect(window, &QWindow::widthChanged, window,
                             [window]() { updateRoundedWindowMask(window); });
            QObject::connect(window, &QWindow::heightChanged, window,
                             [window]() { updateRoundedWindowMask(window); });
            QObject::connect(window, &QWindow::windowStateChanged, window,
                             [window]() { updateRoundedWindowMask(window); });
            QTimer::singleShot(0, window,
                               [window]() { updateRoundedWindowMask(window); });
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
