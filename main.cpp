#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>
#include "CommonFunc.h"
#include "mainviewcontroller.h"
#include "gateway_client.h"
#include "chatmodel.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
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

    // 新会话创建成功：清空聊天记录并显示系统提示
    QObject::connect(&wsClient, &GatewayClient::sessionCreated,
                     [&chatModel]() {
        chatModel.clear();
        chatModel.addMessage(QStringLiteral("system"),
                             QStringLiteral("\u65b0\u4f1a\u8bdd\u5df2\u521b\u5efa"));
    });

    // 历史消息加载完成：清空当前显示并填充历史记录
    QObject::connect(&wsClient, &GatewayClient::historyLoaded,
                     [&chatModel](const QVariantList &messages) {
        chatModel.clear();
        for (const QVariant &v : messages) {
            const QVariantMap m = v.toMap();
            chatModel.addMessage(m.value(QStringLiteral("role")).toString(),
                                 m.value(QStringLiteral("content")).toString());
        }
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("$MainViewController", GET_SINGLETON(MainViewController));
    engine.rootContext()->setContextProperty(QStringLiteral("wsClient"), &wsClient);
    engine.rootContext()->setContextProperty(QStringLiteral("chatModel"), &chatModel);

    int fontId1 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-55-Regular.ttf");
    int fontId2 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-65-Regular.ttf");
    int fontId3 = QFontDatabase::addApplicationFont(":/fonts/AlibabaPuHuiTi-3-85-Regular.ttf");
    int fontId4 = QFontDatabase::addApplicationFont(":/fonts/AlimamaShuHeiTi-Bold.ttf");

    // --test 参数启动测试界面，否则加载正式界面
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
