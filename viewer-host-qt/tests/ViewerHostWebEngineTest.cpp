#include "ViewerHost.h"

#include <QApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>
#include <QWebEnginePage>
#include <QWebEngineView>
#include <cstdio>

class DiagnosticPage final : public QWebEnginePage
{
public:
    using QWebEnginePage::QWebEnginePage;

protected:
    void javaScriptConsoleMessage(JavaScriptConsoleMessageLevel level,
                                  const QString &message, int lineNumber,
                                  const QString &sourceId) override
    {
        std::fprintf(stderr, "console[%d] %s:%d %s\n", static_cast<int>(level),
                     sourceId.toUtf8().constData(), lineNumber,
                     message.toUtf8().constData());
    }
};

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    if (argc != 2) {
        std::fprintf(stderr, "usage: ViewerHostQtWebEngineTest <pdf>\n");
        return 2;
    }

    ViewerHost host;
    host.setViewerRootPath(QString::fromUtf8(VIEWER_WEB_DIST));
    const QString url = host.openDocument(QString::fromLocal8Bit(argv[1]), true,
                                          QStringLiteral("zh-CN"));
    if (url.isEmpty()) {
        std::fprintf(stderr, "%s\n", host.lastError().toUtf8().constData());
        return 3;
    }

    QWebEngineView view;
    view.setPage(new DiagnosticPage(&view));
    view.resize(1200, 800);
    view.move(-30000, -30000);
    view.show();

    QObject::connect(&view, &QWebEngineView::loadFinished, &app, [&](bool ok) {
        std::fprintf(stderr, "loadFinished=%d url=%s\n", ok ? 1 : 0,
                     view.url().toString().toUtf8().constData());
        QTimer::singleShot(6000, &app, [&] {
            view.page()->runJavaScript(QStringLiteral(
                "(function(){return {"
                "title:document.title,"
                "pages:document.querySelectorAll('.page').length,"
                "canvases:document.querySelectorAll('canvas').length,"
                "canvasWidth:document.querySelector('canvas')?.width||0,"
                "canvasHeight:document.querySelector('canvas')?.height||0,"
                "error:document.querySelector('#errorMessage')?.textContent||''"
                "};})()"), [&](const QVariant &result) {
                const QJsonObject object = QJsonObject::fromVariantMap(result.toMap());
                std::puts(QJsonDocument(object).toJson(QJsonDocument::Compact).constData());
                const bool rendered = object.value(QStringLiteral("canvases")).toInt() > 0
                    && object.value(QStringLiteral("canvasWidth")).toInt() > 0;
                app.exit(rendered ? 0 : 1);
            });
        });
    });

    view.setUrl(QUrl(url));
    return app.exec();
}
