#include "ViewerHost.h"

#include <QCoreApplication>
#include <QEventLoop>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTemporaryDir>
#include <QUrlQuery>
#include <cstdio>

namespace {
struct Reply {
    int status = 0;
    QByteArray body;
};

Reply waitFor(QNetworkReply *reply)
{
    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();
    const Reply result{
        reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt(),
        reply->readAll()
    };
    reply->deleteLater();
    return result;
}

bool require(bool condition, const char *message)
{
    if (!condition)
        std::fprintf(stderr, "%s\n", message);
    return condition;
}
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    if (argc == 3 && QByteArray(argv[1]) == QByteArrayLiteral("--serve")) {
        ViewerHost host;
        host.setViewerRootPath(QString::fromUtf8(VIEWER_WEB_DIST));
        const QString url = host.openDocument(QString::fromLocal8Bit(argv[2]), true, QStringLiteral("zh-CN"));
        if (url.isEmpty()) {
            qCritical().noquote() << host.lastError();
            return 1;
        }
        qInfo().noquote() << url;
        return app.exec();
    }
    QTemporaryDir temp;
    if (!require(temp.isValid(), "temporary directory creation failed"))
        return 1;

    const QByteArray expected("viewer-host-smoke-document");
    const QString documentPath = temp.filePath(QStringLiteral("sample.xlsx"));
    QFile document(documentPath);
    if (!require(document.open(QIODevice::WriteOnly), "test document creation failed")
        || !require(document.write(expected) == expected.size(), "test document write failed"))
        return 1;
    document.close();

    ViewerHost host;
    host.setViewerRootPath(QString::fromUtf8(VIEWER_WEB_DIST));
    const QUrl viewerUrl(host.openDocument(documentPath, true, QStringLiteral("zh-CN")));
    if (!require(viewerUrl.isValid(), "openDocument did not return a URL"))
        return 1;

    QNetworkAccessManager network;
    const Reply index = waitFor(network.get(QNetworkRequest(viewerUrl)));
    if (!require(index.status == 200, "viewer index request failed")
        || !require(index.body.contains("id=\"root\""), "viewer index has no root element"))
        return 1;

    QUrl unauthorized = viewerUrl.resolved(QUrl(QStringLiteral("/api/events")));
    QNetworkRequest unauthorizedRequest(unauthorized);
    unauthorizedRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    if (!require(waitFor(network.post(unauthorizedRequest, QByteArrayLiteral("{\"type\":\"init\"}"))).status == 403,
                 "event endpoint accepted a missing session"))
        return 1;

    const QString session = QUrlQuery(viewerUrl).queryItemValue(QStringLiteral("session"));
    QUrl events = unauthorized;
    QUrlQuery eventQuery;
    eventQuery.addQueryItem(QStringLiteral("session"), session);
    events.setQuery(eventQuery);
    QNetworkRequest eventRequest(events);
    eventRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const Reply init = waitFor(network.post(eventRequest, QByteArrayLiteral("{\"type\":\"init\"}")));
    const QJsonObject initObject = QJsonDocument::fromJson(init.body).object();
    const QJsonObject openPayload = initObject.value(QStringLiteral("events")).toArray()
                                        .at(0).toObject()
                                        .value(QStringLiteral("content")).toObject();
    if (!require(init.status == 200, "authorized init request failed")
        || !require(!initObject.value(QStringLiteral("events")).toArray().isEmpty(),
                    "init response has no open event")
        || !require(openPayload.value(QStringLiteral("ext")).toString() == QStringLiteral(".xlsx"),
                    "open payload has no normalized file extension"))
        return 1;

    QUrl documentUrl = viewerUrl.resolved(QUrl(QStringLiteral("/api/document")));
    QUrlQuery documentQuery;
    documentQuery.addQueryItem(QStringLiteral("session"), session);
    documentUrl.setQuery(documentQuery);
    const Reply bytes = waitFor(network.get(QNetworkRequest(documentUrl)));
    if (!require(bytes.status == 200, "document request failed")
        || !require(bytes.body == expected, "document bytes changed in transit"))
        return 1;

    QNetworkRequest rangeRequest(documentUrl);
    rangeRequest.setRawHeader("Range", "bytes=7-10");
    const Reply rangeBytes = waitFor(network.get(rangeRequest));
    if (!require(rangeBytes.status == 206, "document range request did not return partial content")
        || !require(rangeBytes.body == expected.mid(7, 4), "document range bytes are incorrect"))
        return 1;

    const QUrl editableUrl(host.openDocument(documentPath, false, QStringLiteral("zh-CN")));
    const QString editableSession = QUrlQuery(editableUrl).queryItemValue(QStringLiteral("session"));
    QUrl editableEvents = editableUrl.resolved(QUrl(QStringLiteral("/api/events")));
    QUrlQuery editableQuery;
    editableQuery.addQueryItem(QStringLiteral("session"), editableSession);
    editableEvents.setQuery(editableQuery);
    QNetworkRequest editableRequest(editableEvents);
    editableRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const QByteArray replacement("saved-through-host");
    QJsonArray replacementBytes;
    for (const char byte : replacement)
        replacementBytes.append(static_cast<unsigned char>(byte));
    const QByteArray saveBody = QJsonDocument(QJsonObject{
        {QStringLiteral("type"), QStringLiteral("save")},
        {QStringLiteral("content"), replacementBytes}
    }).toJson(QJsonDocument::Compact);
    const Reply saved = waitFor(network.post(editableRequest, saveBody));
    const QJsonArray saveEvents = QJsonDocument::fromJson(saved.body).object()
                                      .value(QStringLiteral("events")).toArray();
    QFile savedDocument(documentPath);
    if (!require(saved.status == 200, "editable save request failed")
        || !require(!saveEvents.isEmpty()
                    && saveEvents.at(0).toObject().value(QStringLiteral("type")).toString()
                       == QStringLiteral("saveDone"),
                    "save response has no saveDone event")
        || !require(savedDocument.open(QIODevice::ReadOnly), "saved document could not be reopened")
        || !require(savedDocument.readAll() == replacement, "saved document bytes do not match"))
        return 1;

    const QString htmlPath = temp.filePath(QStringLiteral("sample.html"));
    QFile html(htmlPath);
    if (!require(html.open(QIODevice::WriteOnly), "HTML test file creation failed")
        || !require(html.write("<h1>standalone-html</h1>") > 0, "HTML test file write failed"))
        return 1;
    html.close();
    const QUrl htmlUrl(host.openDocument(htmlPath, true, QStringLiteral("zh-CN")));
    const Reply htmlReply = waitFor(network.get(QNetworkRequest(htmlUrl)));
    if (!require(htmlReply.status == 200, "HTML document request failed")
        || !require(htmlReply.body.contains("standalone-html"), "HTML document content missing"))
        return 1;

    const QString pdfPath = temp.filePath(QStringLiteral("sample.pdf"));
    QFile pdf(pdfPath);
    if (!require(pdf.open(QIODevice::WriteOnly), "PDF test file creation failed")
        || !require(pdf.write("%PDF-1.4") > 0, "PDF test file write failed"))
        return 1;
    pdf.close();
    const QUrl pdfUrl(host.openDocument(pdfPath, true, QStringLiteral("zh-CN")));
    const Reply pdfViewer = waitFor(network.get(QNetworkRequest(pdfUrl)));
    if (!require(pdfViewer.status == 200, "PDF viewer request failed")
        || !require(pdfViewer.body.contains("<base href=\"/pdf/\">"),
                    "PDF viewer base URL was not configured for standalone use"))
        return 1;

    const QString markdownPath = temp.filePath(QStringLiteral("示例.md"));
    QFile markdown(markdownPath);
    const QByteArray markdownInitial = QStringLiteral("# 初始内容\n\n中文段落").toUtf8();
    if (!require(markdown.open(QIODevice::WriteOnly), "Markdown test file open failed")
        || !require(markdown.write(markdownInitial) == markdownInitial.size(), "Markdown test file write failed"))
        return 1;
    markdown.close();

    const QUrl markdownUrl(host.openDocument(markdownPath, true, QStringLiteral("zh-CN")));
    const Reply markdownViewer = waitFor(network.get(QNetworkRequest(markdownUrl)));
    if (!require(markdownUrl.path() == QStringLiteral("/markdown/index.html"), "Markdown viewer route is incorrect")
        || !require(markdownViewer.status == 200, "Markdown viewer request failed")
        || !require(markdownViewer.body.contains("<base href=\"/markdown/\">"), "Markdown base URL was not injected"))
        return 1;

    const QString markdownSession = QUrlQuery(markdownUrl).queryItemValue(QStringLiteral("session"));
    QUrl markdownEvents = markdownUrl.resolved(QUrl(QStringLiteral("/api/events")));
    QUrlQuery markdownQuery;
    markdownQuery.addQueryItem(QStringLiteral("session"), markdownSession);
    markdownEvents.setQuery(markdownQuery);
    QNetworkRequest markdownInitRequest(markdownEvents);
    markdownInitRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const Reply markdownInit = waitFor(network.post(markdownInitRequest, QByteArrayLiteral("{\"type\":\"init\"}")));
    const QJsonObject markdownOpenPayload = QJsonDocument::fromJson(markdownInit.body).object()
                                                .value(QStringLiteral("events")).toArray()
                                                .at(0).toObject()
                                                .value(QStringLiteral("content")).toObject();
    if (!require(markdownInit.status == 200, "Markdown init event failed")
        || !require(markdownOpenPayload.value(QStringLiteral("content")).toString()
                        == QString::fromUtf8(markdownInitial),
                    "Markdown open payload is missing UTF-8 content")
        || !require(markdownOpenPayload.value(QStringLiteral("readOnly")).toBool(),
                    "Markdown read-only state is missing"))
        return 1;

    const QUrl editableMarkdownUrl(host.openDocument(markdownPath, false, QStringLiteral("zh-CN")));
    QUrl editableMarkdownEvents = editableMarkdownUrl.resolved(QUrl(QStringLiteral("/api/events")));
    QUrlQuery editableMarkdownQuery;
    editableMarkdownQuery.addQueryItem(QStringLiteral("session"), QUrlQuery(editableMarkdownUrl).queryItemValue(QStringLiteral("session")));
    editableMarkdownEvents.setQuery(editableMarkdownQuery);
    QNetworkRequest markdownSaveRequest(editableMarkdownEvents);
    markdownSaveRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    const QByteArray markdownUpdated = QStringLiteral("# 已保存\n\nUTF-8 文本").toUtf8();
    const QByteArray markdownSaveBody = QJsonDocument(QJsonObject{
        {QStringLiteral("type"), QStringLiteral("doSave")},
        {QStringLiteral("content"), QString::fromUtf8(markdownUpdated)}
    }).toJson(QJsonDocument::Compact);
    const Reply markdownSave = waitFor(network.post(markdownSaveRequest, markdownSaveBody));
    QFile savedMarkdown(markdownPath);
    if (!require(markdownSave.status == 200, "Markdown save event failed")
        || !require(savedMarkdown.open(QIODevice::ReadOnly), "Saved Markdown could not be opened")
        || !require(savedMarkdown.readAll() == markdownUpdated, "Markdown UTF-8 content was not saved verbatim"))
        return 1;

    return 0;
}
