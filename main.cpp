#include <QGuiApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>
#include <QLibraryInfo>
#include <QDir>
#include <QtWebEngine/QtWebEngine>
#include "CommonFunc.h"
#include "mainviewcontroller.h"
#include "gateway_client.h"
#include "chatmodel.h"
#include "session_reader.h"

static void configureQtWebEngineRuntime()
{
    const QString libexecPath =
        QLibraryInfo::location(QLibraryInfo::LibraryExecutablesPath);
    const QString dataPath =
        QLibraryInfo::location(QLibraryInfo::DataPath);
    const QString translationsPath =
        QLibraryInfo::location(QLibraryInfo::TranslationsPath);

    const QString processPath = QDir(libexecPath).filePath(QStringLiteral("QtWebEngineProcess"));
    const QString resourcesPath = QDir(dataPath).filePath(QStringLiteral("resources"));
    const QString localesPath = QDir(translationsPath).filePath(QStringLiteral("qtwebengine_locales"));

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

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    if (qEnvironmentVariableIsEmpty("QT_OPENGL"))
        qputenv("QT_OPENGL", "desktop");
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL);
    configureQtWebEngineRuntime();
    QtWebEngine::initialize();

    QGuiApplication app(argc, argv);

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
                     [&chatModel](const QVariantList &messages) {
        chatModel.loadHistory(messages);
    });

    // ── 本地会话历史读取器 ──
    SessionReader sessionReader;

    GET_SINGLETON(MainViewController)->init(&chatModel, &wsClient);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("$MainViewController", GET_SINGLETON(MainViewController));
    engine.rootContext()->setContextProperty(QStringLiteral("wsClient"), &wsClient);
    engine.rootContext()->setContextProperty(QStringLiteral("chatModel"), &chatModel);
    engine.rootContext()->setContextProperty(QStringLiteral("sessionReader"), &sessionReader);

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
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
