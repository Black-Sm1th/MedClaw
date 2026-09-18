#include <QApplication>
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QLibraryInfo>
#include <QPainterPath>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QRegion>
#include <QScreen>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QSurfaceFormat>
#include <QTimer>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineScriptCollection>
#include <QWindow>
#include <QtWebEngineQuick>
#include "CommonFunc.h"
#include "auth_controller.h"
#include "chatmodel.h"
#include "gateway_client.h"
#include "mainviewcontroller.h"
#include "session_reader.h"
#include "updatecontroller.h"
#include "viewer-host-qt/include/ViewerHost.h"

static void appendChromiumFlag(QByteArray &flags, const char *flag)
{
    const QList<QByteArray> tokens = flags.split(' ');
    for (const QByteArray &token : tokens) {
        if (token == flag)
            return;
    }
    if (!flags.isEmpty() && !flags.endsWith(' '))
        flags += ' ';
    flags += flag;
}

// Qt 5.15.2 WebEngine is Chromium 83. WebGL2 exists, but the UI process was
// sharing a GLES2 context and Chromium was left on the GPU blocklist / D3D9
// ANGLE path, so getContext('webgl2') returned null. Cornerstone3D MPR and
// volume rendering need a real WebGL2 (ES 3.0) context.
static QString firstExistingPath(const QStringList &candidates)
{
    for (const QString &path : candidates) {
        if (!path.isEmpty() && QFileInfo::exists(path))
            return path;
    }
    return {};
}

static void configureQtWebEngineRuntime(const char *executablePath)
{
    const QString appDir = QFileInfo(QString::fromLocal8Bit(executablePath)).absolutePath();
    const QString qtBin = QLibraryInfo::path(QLibraryInfo::BinariesPath);
    const QString qtLibExec = QLibraryInfo::path(QLibraryInfo::LibraryExecutablesPath);
    const QString qtData = QLibraryInfo::path(QLibraryInfo::DataPath);
    const QString qtTranslations = QLibraryInfo::path(QLibraryInfo::TranslationsPath);

    const QString processPath = firstExistingPath({
        QDir(appDir).filePath(QStringLiteral("QtWebEngineProcess.exe")),
        QDir(qtLibExec).filePath(QStringLiteral("QtWebEngineProcess.exe")),
        QDir(qtBin).filePath(QStringLiteral("QtWebEngineProcess.exe")),
    });
    const QString resourcesPath = firstExistingPath({
        QDir(appDir).filePath(QStringLiteral("resources")),
        QDir(qtData).filePath(QStringLiteral("resources")),
        QDir(qtBin).filePath(QStringLiteral("../resources")),
    });
    const QString localesPath = firstExistingPath({
        QDir(appDir).filePath(QStringLiteral("translations/qtwebengine_locales")),
        QDir(qtTranslations).filePath(QStringLiteral("qtwebengine_locales")),
    });

    if (qEnvironmentVariableIsEmpty("QTWEBENGINEPROCESS_PATH") && !processPath.isEmpty())
        qputenv("QTWEBENGINEPROCESS_PATH", processPath.toLocal8Bit());
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_RESOURCES_PATH") && !resourcesPath.isEmpty())
        qputenv("QTWEBENGINE_RESOURCES_PATH", resourcesPath.toLocal8Bit());
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_LOCALES_PATH") && !localesPath.isEmpty())
        qputenv("QTWEBENGINE_LOCALES_PATH", localesPath.toLocal8Bit());

    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_DISABLE_SANDBOX"))
        qputenv("QTWEBENGINE_DISABLE_SANDBOX", "1");

    // Keep Qt Quick and WebEngine on the same desktop OpenGL implementation.
    // The Windows compatibility path uses Qt's bundled Mesa software renderer:
    // Qt 6.8 builds disable SwiftShader, so --use-angle=swiftshader cannot work.
#ifdef Q_OS_WIN
    const bool hardwareGpu = qEnvironmentVariableIntValue("MEDCLAW_SOFTWARE_OPENGL") != 1;
    qputenv("QT_OPENGL", hardwareGpu ? "desktop" : "software");
    qputenv("QSG_RHI_BACKEND", "opengl");
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
#endif

    QByteArray flags = qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
    // Remove obsolete GPU overrides, including inherited flags from older launches.
    const QStringList args = QProcess::splitCommand(QString::fromLocal8Bit(flags));
    flags.clear();
    for (const QString &arg : args) {
        if (arg.startsWith("--use-gl=") || arg.startsWith("--use-angle=")
            || arg == "--disable-gpu" || arg == "--disable-webgl"
            || arg == "--disable-gpu-process-crash-limit"
            || arg == "--ignore-gpu-blacklist" || arg == "--ignore-gpu-blocklist"
            || arg == "--enable-gpu-rasterization" || arg == "--enable-accelerated-2d-canvas"
            || arg == "--enable-unsafe-swiftshader" || arg == "--in-process-gpu")
            continue;
        QByteArray token = arg.toLocal8Bit();
        if (token.contains(' '))
            token = '"' + token + '"';
        appendChromiumFlag(flags, token.constData());
    }
    appendChromiumFlag(flags, "--enable-webgl");
#ifdef Q_OS_WIN
    appendChromiumFlag(flags, "--use-gl=desktop");
    if (!hardwareGpu)
        appendChromiumFlag(flags, "--enable-webgl-software-rendering");
#endif
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    appendChromiumFlag(flags, "--disable-web-security");
    appendChromiumFlag(flags, "--allow-running-insecure-content");
    appendChromiumFlag(flags,
                       "--disable-features=LocalNetworkAccess,BlockInsecurePrivateNetworkRequests,"
                       "RendererCodeIntegrity,CalculateNativeWinOcclusion");
#else
    appendChromiumFlag(flags, "--disable-features=RendererCodeIntegrity");
#endif
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", flags);

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QSurfaceFormat format;
    format.setRenderableType(QSurfaceFormat::OpenGLES);
    format.setVersion(3, 0);
    format.setProfile(QSurfaceFormat::NoProfile);
    format.setDepthBufferSize(24);
    format.setStencilBufferSize(8);
    format.setSamples(0);
    format.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    QSurfaceFormat::setDefaultFormat(format);
#endif

    qDebug().noquote() << "[WebEngine] QT_OPENGL=" << qgetenv("QT_OPENGL")
                       << "QT_ANGLE_PLATFORM=" << qgetenv("QT_ANGLE_PLATFORM")
                       << "QSG_RHI_BACKEND=" << qgetenv("QSG_RHI_BACKEND")
                       << "CHROMIUM_FLAGS=" << qgetenv("QTWEBENGINE_CHROMIUM_FLAGS");
}

static void insertWebGlScript(QWebEngineScriptCollection *scripts, const QWebEngineScript &script)
{
    if (!scripts)
        return;
    const QList<QWebEngineScript> existing = scripts->find(QStringLiteral("medclaw-webgl-compat"));
    for (const QWebEngineScript &old : existing)
        scripts->remove(old);
    scripts->insert(script);
}

static void insertWebGlScript(QWebEngineScriptCollection &scripts, const QWebEngineScript &script)
{
    insertWebGlScript(&scripts, script);
}

static void installWebGlUserScript()
{
    QFile file(QStringLiteral(":/web/webgl-compat.js"));
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[WebEngine] missing :/web/webgl-compat.js";
        return;
    }

    QWebEngineScript script;
    script.setName(QStringLiteral("medclaw-webgl-compat"));
    script.setInjectionPoint(QWebEngineScript::DocumentCreation);
    script.setWorldId(QWebEngineScript::MainWorld);
    script.setRunsOnSubFrames(true);
    script.setSourceCode(QString::fromUtf8(file.readAll()));

    QWebEngineProfile *profile = QWebEngineProfile::defaultProfile();
    if (!profile)
        return;
    // Qt 5 / some 6.8 kits: scripts() returns a pointer.
    // Later 6.x: it returns a reference. Overload both.
    insertWebGlScript(profile->scripts(), script);
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
    path.addRoundedRect(QRectF(0, 0, window->width(), window->height()), cornerRadius, cornerRadius);
    window->setMask(QRegion(path.toFillPolygon().toPolygon()));
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
    configureQtWebEngineRuntime(argv[0]);
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QtWebEngineQuick::initialize();
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("AetherMED"));
#ifdef MEDCLAW_EDITION_GOVERNMENT
    QCoreApplication::setApplicationName(QStringLiteral("Aether study Government"));
#else
    QCoreApplication::setApplicationName(QStringLiteral("Aether study"));
#endif
    installWebGlUserScript();

    // Keep relative runtime data paths stable and carry existing installs forward.
    const QString genericDataRoot = QStandardPaths::writableLocation(
        QStandardPaths::GenericDataLocation);
    const QString preferredDataRoot = QDir(genericDataRoot).filePath(QStringLiteral("AetherStudy"));
    const QString legacyDataRoot = QDir(genericDataRoot).filePath(QStringLiteral("Aether_ClawDESK"));
    QString dataRoot = preferredDataRoot;
    if (!QFileInfo::exists(preferredDataRoot) && QFileInfo::exists(legacyDataRoot)
        && !QDir(genericDataRoot)
                .rename(QStringLiteral("Aether_ClawDESK"), QStringLiteral("AetherStudy"))) {
        dataRoot = legacyDataRoot;
    }
    if (!QDir().mkpath(dataRoot) || !QDir::setCurrent(dataRoot))
        qWarning() << "Unable to use application data directory:" << dataRoot;

    // ── WebSocket 客户端 & 聊天数据模型 ──
    GatewayClient wsClient;
    ChatModel chatModel;

    // 收到聊天消息：完整消息直接添加，增量消息追加到流式缓冲
    QObject::connect(&wsClient,
                     &GatewayClient::chatMessageReceived,
                     [&chatModel](const QString &role, const QString &content, bool isDelta) {
                         if (isDelta) {
                             chatModel.appendStreamChunk(content);
                         } else if (!content.isEmpty()) {
                             chatModel.addMessage(role, content);
                         }
                     });

    // 流式输出开始：在 ChatModel 中创建空的 assistant 消息占位
    QObject::connect(&wsClient, &GatewayClient::streamingStarted, [&chatModel]() {
        chatModel.beginStreaming();
    });

    // 流式输出结束：标记流式状态完成
    QObject::connect(&wsClient, &GatewayClient::streamingFinished, [&chatModel]() {
        chatModel.endStreaming();
    });

    QObject::connect(&wsClient,
                     &GatewayClient::artifactsDetected,
                     [&chatModel, &wsClient](const QString &sessionKey,
                                             const QVariantList &artifacts) {
                         QString visibleSession = wsClient.currentViewSessionKey().trimmed();
                         if (visibleSession.isEmpty())
                             visibleSession = wsClient.currentTaskSessionKey().trimmed();
                         const QString trackingKey = sessionKey.trimmed();
                         if (wsClient.artifactResultsBelongToView(trackingKey, visibleSession)) {
                             if (chatModel.setArtifactsForLastAssistant(artifacts))
                                 wsClient.persistSessionArtifacts(visibleSession,
                                                                  chatModel.messages());
                             wsClient.persistDetectedArtifacts(visibleSession, artifacts);
                             if (!trackingKey.isEmpty() && trackingKey != visibleSession)
                                 wsClient.persistDetectedArtifacts(trackingKey, artifacts);
                         } else {
                             wsClient.persistDetectedArtifacts(trackingKey, artifacts);
                         }
                     });

    // 工具调用：在 ChatModel 中插入工具卡片
    QObject::connect(&wsClient,
                     &GatewayClient::toolCallReceived,
                     [&chatModel](const QString &name, const QString &args, const QString &id) {
                         chatModel.addToolCall(name, args, id);
                     });

    // 工具增量：在执行中的卡片内持续追加输出
    QObject::connect(&wsClient,
                     &GatewayClient::toolUpdateReceived,
                     [&chatModel](const QString &name, const QString &content, const QString &id) {
                         chatModel.appendToolResult(name, content, id);
                     });

    // 工具结果：在 ChatModel 中插入工具结果块
    QObject::connect(&wsClient,
                     &GatewayClient::toolResultReceived,
                     [&chatModel](const QString &name,
                                  const QString &content,
                                  const QString &id,
                                  bool isError) {
                         chatModel.addToolResult(name, content, id, isError);
                     });

    // 工具结果补拉完成：原地合并完整文本（不清空聊天模型，避免闪烁）
    // 同时补插实时事件中漏掉的 toolCall 条目
    QObject::connect(
        &wsClient, &GatewayClient::toolResultsRefreshed, [&chatModel](const QVariantList &messages) {
            for (const QVariant &v : messages) {
                const QVariantMap m = v.toMap();
                const QString mtype = m.value(QStringLiteral("msgType")).toString();
                const QString tcId = m.value(QStringLiteral("toolCallId")).toString();
                if (tcId.isEmpty())
                    continue;

                if (mtype == QLatin1String("toolCall")) {
                    if (!chatModel.hasToolCallId(tcId))
                        chatModel.addToolCall(m.value(QStringLiteral("toolName")).toString(),
                                              m.value(QStringLiteral("toolArgs")).toString(),
                                              tcId);
                } else if (mtype == QLatin1String("toolResult")) {
                    if (!chatModel.hasToolCallId(tcId))
                        chatModel.addToolCall(m.value(QStringLiteral("toolName")).toString(),
                                              QString(),
                                              tcId);
                    chatModel.addToolResult(m.value(QStringLiteral("toolName")).toString(),
                                            m.value(QStringLiteral("content")).toString(),
                                            tcId,
                                            m.value(QStringLiteral("isError")).toBool());
                }
            }
        });

    // 新会话创建成功：聊天区保留本地已追加的首条用户消息。
    QObject::connect(&wsClient, &GatewayClient::sessionCreated, []() {});

    // 历史消息加载完成：清空当前显示并填充历史记录
    QObject::connect(&wsClient,
                     &GatewayClient::historyLoaded,
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
    UpdateController updateController;
    wsClient.setTaskSessionUserId(authController.userId());
    QObject::connect(&authController, &AuthController::userChanged, [&wsClient, &authController]() {
        wsClient.setTaskSessionUserId(authController.userId());
    });

    GET_SINGLETON(MainViewController)->init(&chatModel, &wsClient);

    QQmlApplicationEngine engine;
    qmlRegisterType<ViewerHost>("MedClaw.Viewer", 1, 0, "ViewerHost");
    QSize savedWindowSize = QSettings().value(QStringLiteral("ui/windowSize")).toSize();
    // Older versions could persist the screen-sized geometry while maximizing.
    // Treat that value as stale so it cannot make a windowed launch look full-screen.
    if (QScreen *screen = QGuiApplication::primaryScreen()) {
        const QSize availableSize = screen->availableGeometry().size();
        if (savedWindowSize.width() >= availableSize.width()
            && savedWindowSize.height() >= availableSize.height()) {
            savedWindowSize = QSize();
        }
    }
    engine.rootContext()->setContextProperty(QStringLiteral("initialWindowWidth"),
                                             savedWindowSize.width());
    engine.rootContext()->setContextProperty(QStringLiteral("initialWindowHeight"),
                                             savedWindowSize.height());
#ifdef MEDCLAW_EDITION_GOVERNMENT
    engine.rootContext()->setContextProperty(QStringLiteral("buildGovernmentEdition"), true);
#else
    engine.rootContext()->setContextProperty(QStringLiteral("buildGovernmentEdition"), false);
#endif
    engine.rootContext()->setContextProperty("$MainViewController",
                                             GET_SINGLETON(MainViewController));
    engine.rootContext()->setContextProperty(QStringLiteral("wsClient"), &wsClient);
    engine.rootContext()->setContextProperty(QStringLiteral("chatModel"), &chatModel);
    engine.rootContext()->setContextProperty(QStringLiteral("sessionReader"), &sessionReader);
    engine.rootContext()->setContextProperty(QStringLiteral("authController"), &authController);
    engine.rootContext()->setContextProperty(QStringLiteral("updateController"), &updateController);

    QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-55-Regular.ttf");
    QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-65-Regular.ttf");
    QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-85-Regular.ttf");
    QFontDatabase::addApplicationFont(":/fonts/AlimamaShuHeiTi-Bold.ttf");

    // --test 启动 WebSocket 测试页。
    const bool testMode = app.arguments().contains(QStringLiteral("--test"));
    const bool accountPreviewMode = app.arguments().contains(QStringLiteral("--account-preview"));
    QString accountPreviewOutput;
    const QString accountPreviewOutputPrefix = QStringLiteral("--account-preview-output=");
    for (const QString &argument : app.arguments()) {
        if (argument.startsWith(accountPreviewOutputPrefix)) {
            accountPreviewOutput = argument.mid(accountPreviewOutputPrefix.size());
            break;
        }
    }
    const QUrl url(testMode ? QStringLiteral("qrc:/TestChatClient.qml")
                            : QStringLiteral("qrc:/main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url, testMode, accountPreviewMode, accountPreviewOutput](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);

            QWindow *window = qobject_cast<QWindow *>(obj);
            if (!window || url != objUrl)
                return;

            if (!testMode && !accountPreviewMode) {
                auto *saveWindowSizeTimer = new QTimer(window);
                saveWindowSizeTimer->setSingleShot(true);
                saveWindowSizeTimer->setInterval(250);

                const auto scheduleWindowSizeSave = [window, saveWindowSizeTimer]() {
                    // Window size changes can arrive before windowStateChanged while
                    // maximizing/restoring. Defer both the cache update and the
                    // persisted write until the final state is known.
                    saveWindowSizeTimer->start();
                };
                QObject::connect(window, &QWindow::widthChanged, window, scheduleWindowSizeSave);
                QObject::connect(window, &QWindow::heightChanged, window, scheduleWindowSizeSave);
                QObject::connect(window,
                                 &QWindow::windowStateChanged,
                                 window,
                                 scheduleWindowSizeSave);
                QObject::connect(saveWindowSizeTimer, &QTimer::timeout, window, [window]() {
                    const Qt::WindowStates states = window->windowStates();
                    if (states.testFlag(Qt::WindowMinimized) || states.testFlag(Qt::WindowMaximized)
                        || states.testFlag(Qt::WindowFullScreen)) {
                        return;
                    }

                    window->setProperty("normalWindowSize", window->size());
                    const QSize size = window->property("normalWindowSize").toSize();
                    if (size.isValid())
                        QSettings().setValue(QStringLiteral("ui/windowSize"), size);
                });
                window->setProperty("normalWindowSize", window->size());

                QObject::connect(qApp, &QCoreApplication::aboutToQuit, window, [window]() {
                    const QSize size = window->property("normalWindowSize").toSize();
                    if (!size.isValid())
                        return;
                    QSettings settings;
                    settings.setValue(QStringLiteral("ui/windowSize"), size);
                    settings.sync();
                });
            }

            QObject::connect(window, &QWindow::widthChanged, window, [window]() {
                updateRoundedWindowMask(window);
            });
            QObject::connect(window, &QWindow::heightChanged, window, [window]() {
                updateRoundedWindowMask(window);
            });
            QObject::connect(window, &QWindow::windowStateChanged, window, [window]() {
                updateRoundedWindowMask(window);
            });
            QTimer::singleShot(0, window, [window]() { updateRoundedWindowMask(window); });
            if (accountPreviewMode && !accountPreviewOutput.isEmpty()) {
                QQuickWindow *quickWindow = qobject_cast<QQuickWindow *>(window);
                QTimer::singleShot(1200, window, [quickWindow, accountPreviewOutput]() {
                    const bool saved = quickWindow
                                       && quickWindow->grabWindow().save(accountPreviewOutput);
                    QCoreApplication::exit(saved ? 0 : 2);
                });
            }
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
