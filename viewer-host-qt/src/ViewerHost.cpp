#include "ViewerHost.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHostAddress>
#include <QSaveFile>
#include <QTcpSocket>
#include <QUrlQuery>
#include <QUuid>

namespace {
constexpr quint16 kFirstViewerPort = 8200;
constexpr quint16 kLastViewerPort = 8210;
constexpr int kMaximumEventBodyBytes = 256 * 1024 * 1024;

QByteArray statusText(int status)
{
    switch (status) {
    case 200: return "OK";
    case 204: return "No Content";
    case 206: return "Partial Content";
    case 400: return "Bad Request";
    case 403: return "Forbidden";
    case 404: return "Not Found";
    case 405: return "Method Not Allowed";
    case 500: return "Internal Server Error";
    default: return "OK";
    }
}

QByteArray jsonBytesToByteArray(const QJsonValue &value)
{
    if (value.isString())
        return QByteArray::fromBase64(value.toString().toLatin1());
    if (!value.isArray())
        return {};
    const QJsonArray values = value.toArray();
    QByteArray result(values.size(), Qt::Uninitialized);
    for (int i = 0; i < values.size(); ++i)
        result[i] = static_cast<char>(values.at(i).toInt() & 0xff);
    return result;
}

QByteArray eventContentToByteArray(const QJsonValue &value, bool plainText)
{
    if (plainText && value.isString())
        return value.toString().toUtf8();
    return jsonBytesToByteArray(value);
}

bool isCssIdentChar(char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9') || c == '-' || c == '_';
}

// Qt 5.15 WebEngine is Chromium 83 and ignores the CSS inset shorthand
// (Chrome 87+). Expand it to top/right/bottom/left so overlays such as
// position:fixed;inset:0 actually cover the viewport.
QByteArray expandLegacyCssInset(const QByteArray &css)
{
    const QByteArray lowered = css.toLower();
    QByteArray out;
    out.reserve(css.size() + 32);
    int i = 0;
    const int n = css.size();
    while (i < n) {
        const int pos = lowered.indexOf("inset", i);
        if (pos < 0) {
            out.append(css.mid(i));
            break;
        }
        out.append(css.mid(i, pos - i));
        const bool startOk = pos == 0 || !isCssIdentChar(css.at(pos - 1));
        const int afterName = pos + 5;
        const bool nameOk = afterName >= n || !isCssIdentChar(css.at(afterName));
        if (!startOk || !nameOk) {
            out.append(css.mid(pos, 5));
            i = afterName;
            continue;
        }
        int look = afterName;
        while (look < n) {
            const char c = css.at(look);
            if (c != ' ' && c != '\t' && c != '\n' && c != '\r')
                break;
            ++look;
        }
        if (look >= n || css.at(look) != ':') {
            out.append(css.mid(pos, look - pos));
            i = look;
            continue;
        }
        ++look;
        const int valueStart = look;
        while (look < n && css.at(look) != ';' && css.at(look) != '}')
            ++look;
        QByteArray value = css.mid(valueStart, look - valueStart).trimmed();
        bool important = false;
        const int bang = value.toLower().indexOf("!important");
        if (bang >= 0) {
            important = true;
            value = value.left(bang).trimmed();
        }
        QByteArrayList tokens;
        for (const QByteArray &part : value.split(' ')) {
            const QByteArray token = part.trimmed();
            if (!token.isEmpty())
                tokens.append(token);
        }
        if (tokens.isEmpty()) {
            out.append(css.mid(pos, look - pos));
            i = look;
            continue;
        }
        QByteArray top = tokens.at(0);
        QByteArray right = top;
        QByteArray bottom = top;
        QByteArray left = top;
        if (tokens.size() == 2) {
            right = left = tokens.at(1);
        } else if (tokens.size() == 3) {
            right = left = tokens.at(1);
            bottom = tokens.at(2);
        } else if (tokens.size() >= 4) {
            right = tokens.at(1);
            bottom = tokens.at(2);
            left = tokens.at(3);
        }
        const QByteArray suffix = important ? " !important" : QByteArray();
        out += "top:" + top + suffix
            + ";right:" + right + suffix
            + ";bottom:" + bottom + suffix
            + ";left:" + left + suffix;
        i = look;
    }
    return out;
}

QByteArray withDocumentBase(QByteArray html, const QByteArray &baseUrl)
{
    QByteArray lower = html.toLower();
    if (lower.contains("<base ") || lower.contains("<base>"))
        return html;

    const QByteArray baseTag = "<base href=\"" + baseUrl + "\">";
    auto tagEnd = [&lower](const QByteArray &tagName) {
        int position = 0;
        while ((position = lower.indexOf(tagName, position)) >= 0) {
            const int nameEnd = position + tagName.size();
            if (nameEnd < lower.size()
                && (lower.at(nameEnd) == '>' || lower.at(nameEnd) == ' '
                    || lower.at(nameEnd) == '\t' || lower.at(nameEnd) == '\r'
                    || lower.at(nameEnd) == '\n')) {
                return lower.indexOf('>', nameEnd);
            }
            position = nameEnd;
        }
        return -1;
    };

    const int headEnd = tagEnd("<head");
    if (headEnd >= 0) {
        html.insert(headEnd + 1, baseTag);
        return html;
    }

    const int htmlEnd = tagEnd("<html");
    const QByteArray head = "<head>" + baseTag + "</head>";
    if (htmlEnd >= 0)
        html.insert(htmlEnd + 1, head);
    else
        html.prepend(head);
    return html;
}

QByteArray htmlCompatSnippet()
{
    QFile file(QStringLiteral(":/localviewer/html-compat.js"));
    QByteArray script;
    if (file.open(QIODevice::ReadOnly))
        script = file.readAll();
    if (script.isEmpty())
        return {};
    return "<style data-medclaw-html-compat>"
           ".focus-overlay.show,.modal-mask.show,[class*=\"overlay\"].show{"
           "position:fixed!important;top:0!important;right:0!important;bottom:0!important;left:0!important;"
           "width:auto!important;height:auto!important;max-width:none!important;max-height:none!important;"
           "z-index:2147483000!important;display:flex!important;flex-direction:column!important;"
           "box-sizing:border-box!important;}"
           ".flip-face{top:0!important;right:0!important;bottom:0!important;left:0!important;}"
           "</style><script data-medclaw-html-compat>"
           + script + "</script>";
}

QByteArray withHtmlCompat(QByteArray html)
{
    if (html.contains("data-medclaw-html-compat"))
        return html;
    const QByteArray snippet = htmlCompatSnippet();
    if (snippet.isEmpty())
        return html;
    const QByteArray lower = html.toLower();
    const int head = lower.indexOf("<head");
    if (head >= 0) {
        const int tagEnd = html.indexOf('>', head);
        if (tagEnd >= 0) {
            html.insert(tagEnd + 1, snippet);
            return html;
        }
    }
    html.prepend(snippet);
    return html;
}
}

ViewerHost::ViewerHost(QObject *parent)
    : QObject(parent)
{
    connect(&m_server, &QTcpServer::newConnection, this, &ViewerHost::acceptConnection);
    for (quint16 candidate = kFirstViewerPort; candidate <= kLastViewerPort; ++candidate) {
        if (m_server.listen(QHostAddress::LocalHost, candidate))
            break;
    }
    if (!m_server.isListening())
        m_server.listen(QHostAddress::LocalHost, 0);
    if (!m_server.isListening())
        setLastError(QStringLiteral("无法启动 Viewer 本地服务：%1").arg(m_server.errorString()));
    emit serverChanged();
}

void ViewerHost::setViewerRootPath(const QString &path)
{
    m_viewerRootOverride = QDir(path).absolutePath();
}

namespace {
QString medicalViewerMode(const QFileInfo &info)
{
    if (info.isDir())
        return QStringLiteral("series");

    const QString name = info.fileName().toLower();
    if (name.endsWith(QStringLiteral(".nii"))
        || name.endsWith(QStringLiteral(".nii.gz")))
        return QStringLiteral("volume");

    const QString suffix = info.suffix().toLower();
    if (QStringList{QStringLiteral("dcm"), QStringLiteral("dicom"), QStringLiteral("ima")}
            .contains(suffix))
        return QStringLiteral("single");

    if (QStringList{QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"),
                    QStringLiteral("gif"), QStringLiteral("bmp"), QStringLiteral("webp"),
                    QStringLiteral("tif"), QStringLiteral("tiff")}.contains(suffix))
        return QStringLiteral("raster");

    // A DICOM object commonly has no extension. Let Cornerstone try it as a
    // single slice; an unsupported file will be reported by the viewer.
    return QStringLiteral("single");
}
}

QString ViewerHost::openDocument(const QString &localPath, bool readOnly, const QString &language)
{
    const QFileInfo info(localPath);
    if (!m_server.isListening()) {
        setLastError(QStringLiteral("Viewer 本地服务未运行"));
        return {};
    }
    if (!info.exists() || !info.isFile()) {
        setLastError(QStringLiteral("文件不存在：%1").arg(localPath));
        return {};
    }
    if (!QFileInfo(viewerRoot() + QStringLiteral("/index.html")).exists()) {
        setLastError(QStringLiteral("找不到 viewer-web/dist，请先构建前端"));
        return {};
    }

    m_currentPath = info.absoluteFilePath();
    m_medicalFiles.clear();
    m_medicalMode = false;
    m_readOnly = readOnly || !info.isWritable();
    m_language = language.isEmpty() ? QStringLiteral("zh-CN") : language;
    m_sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    ++m_nonce;
    setLastError({});

    const QString suffix = info.suffix().toLower();
    QUrl url;
    if (suffix == QStringLiteral("pdf")) {
        url = QUrl(QStringLiteral("http://127.0.0.1:%1/pdf/viewer.html").arg(port()));
    } else if (QStringList{QStringLiteral("md"), QStringLiteral("markdown"), QStringLiteral("txt")}.contains(suffix)) {
        url = QUrl(QStringLiteral("http://127.0.0.1:%1/markdown/index.html").arg(port()));
    } else if ((suffix == QStringLiteral("html") || suffix == QStringLiteral("htm")) && m_readOnly) {
        url = QUrl(QStringLiteral("http://127.0.0.1:%1/api/html/%2/%3")
                       .arg(port())
                       .arg(m_sessionId, QString::fromLatin1(QUrl::toPercentEncoding(info.fileName()))));
    } else {
        url = QUrl(QStringLiteral("http://127.0.0.1:%1/index.html").arg(port()));
    }
    QUrlQuery query;
    if (suffix == QStringLiteral("pdf")) {
        query.addQueryItem(QStringLiteral("file"),
                           QStringLiteral("/api/document?session=") + m_sessionId);
    }
    if (suffix != QStringLiteral("pdf")
        && suffix != QStringLiteral("md") && suffix != QStringLiteral("markdown") && suffix != QStringLiteral("txt")
        && !((suffix == QStringLiteral("html") || suffix == QStringLiteral("htm")) && m_readOnly)) {
        query.addQueryItem(QStringLiteral("route"),
                           (suffix == QStringLiteral("html") || suffix == QStringLiteral("htm"))
                               ? QStringLiteral("htmlEditor")
                               : routeForPath(m_currentPath));
    }
    query.addQueryItem(QStringLiteral("language"), m_language);
    query.addQueryItem(QStringLiteral("session"), m_sessionId);
    url.setQuery(query);
    return url.toString();
}

QString ViewerHost::openMedicalImage(const QString &localPath)
{
    const QFileInfo info(localPath);
    if (!m_server.isListening()) {
        setLastError(QStringLiteral("Viewer 本地服务未运行"));
        return {};
    }
    if (!info.exists() || (!info.isFile() && !info.isDir())) {
        setLastError(QStringLiteral("影像文件或文件夹不存在：%1").arg(localPath));
        return {};
    }
    const QDir viewerDirectory(viewerRoot());
    if (!QFileInfo::exists(viewerDirectory.filePath(QStringLiteral("cornerstone3d/index.html")))
        || !QFileInfo::exists(viewerDirectory.filePath(QStringLiteral("cornerstone3d/raster.html")))) {
        setLastError(QStringLiteral("找不到 Cornerstone3D 资源，请先构建或部署 viewer-web/cornerstone3d"));
        return {};
    }

    QStringList files;
    if (info.isDir()) {
        QDirIterator iterator(info.absoluteFilePath(), QDir::Files,
                              QDirIterator::Subdirectories);
        while (iterator.hasNext())
            files.append(QFileInfo(iterator.next()).absoluteFilePath());
        files.sort(Qt::CaseInsensitive);
    } else {
        files.append(info.absoluteFilePath());
    }
    if (files.isEmpty()) {
        setLastError(QStringLiteral("影像文件夹为空：%1").arg(info.absoluteFilePath()));
        return {};
    }

    m_currentPath = info.absoluteFilePath();
    m_medicalFiles = files;
    m_medicalMode = true;
    m_readOnly = true;
    m_language = QStringLiteral("zh-CN");
    m_sessionId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    ++m_nonce;
    setLastError({});

    const QString mode = medicalViewerMode(info);
    const QString page = mode == QStringLiteral("raster")
        ? QStringLiteral("raster.html") : QStringLiteral("index.html");
    QUrl url(QStringLiteral("http://127.0.0.1:%1/cornerstone3d/%2")
                 .arg(port()).arg(page));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("session"), m_sessionId);
    query.addQueryItem(QStringLiteral("mode"), mode);
    query.addQueryItem(QStringLiteral("nonce"), QString::number(m_nonce));
    url.setQuery(query);
    return url.toString();
}

void ViewerHost::closeDocument()
{
    m_currentPath.clear();
    m_sessionId.clear();
    m_medicalFiles.clear();
    m_medicalMode = false;
    m_readOnly = false;
}

bool ViewerHost::saveAsCurrent()
{
    if (m_currentPath.isEmpty())
        return false;
    const QFileInfo info(m_currentPath);
    const QString destination = QFileDialog::getSaveFileName(
        nullptr, QStringLiteral("另存为"), info.absoluteFilePath(),
        QStringLiteral("%1 (*.%2);;所有文件 (*.*)").arg(info.suffix().toUpper(), info.suffix()));
    if (destination.isEmpty())
        return false;
    QFile source(m_currentPath);
    if (!source.open(QIODevice::ReadOnly)) {
        setLastError(source.errorString());
        return false;
    }
    return writeBytes(destination, source.readAll());
}

void ViewerHost::acceptConnection()
{
    while (QTcpSocket *socket = m_server.nextPendingConnection()) {
        socket->setProperty("viewerRequest", QByteArray());
        connect(socket, &QTcpSocket::readyRead, this, [this, socket]() { readRequest(socket); });
        connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
    }
}

void ViewerHost::readRequest(QTcpSocket *socket)
{
    QByteArray buffer = socket->property("viewerRequest").toByteArray();
    buffer += socket->readAll();
    const int headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd < 0) {
        socket->setProperty("viewerRequest", buffer);
        return;
    }
    int contentLength = 0;
    const QList<QByteArray> headers = buffer.left(headerEnd).split('\n');
    for (QByteArray header : headers) {
        header = header.trimmed();
        if (header.toLower().startsWith("content-length:"))
            contentLength = header.mid(header.indexOf(':') + 1).trimmed().toInt();
    }
    if (contentLength < 0 || contentLength > kMaximumEventBodyBytes) {
        respond(socket, 400, "text/plain", "Request body is too large");
        return;
    }
    if (buffer.size() < headerEnd + 4 + contentLength) {
        socket->setProperty("viewerRequest", buffer);
        return;
    }
    socket->setProperty("viewerRequest", QByteArray());
    handleRequest(socket, buffer.left(headerEnd + 4 + contentLength));
}

void ViewerHost::handleRequest(QTcpSocket *socket, const QByteArray &request)
{
    const int lineEnd = request.indexOf("\r\n");
    const int headerEnd = request.indexOf("\r\n\r\n");
    if (lineEnd < 0 || headerEnd < 0) {
        respond(socket, 400, "text/plain", "Bad request");
        return;
    }
    const QList<QByteArray> parts = request.left(lineEnd).split(' ');
    if (parts.size() < 2) {
        respond(socket, 400, "text/plain", "Bad request");
        return;
    }
    const QByteArray method = parts.at(0);
    const QUrl url = QUrl::fromEncoded(parts.at(1));
    const QByteArray body = request.mid(headerEnd + 4);

      if (method == "OPTIONS") {
          respond(socket, 204, "text/plain", {});
          return;
      }
      const QString htmlPrefix = QStringLiteral("/api/html/") + m_sessionId + QLatin1Char('/');
      if (method == "GET" && !m_sessionId.isEmpty() && url.path().startsWith(htmlPrefix)) {
          const QString relative = QDir::cleanPath(url.path().mid(htmlPrefix.size()));
          const QDir root(QFileInfo(m_currentPath).absolutePath());
          const QString path = QDir::fromNativeSeparators(
              QFileInfo(root.filePath(relative)).absoluteFilePath());
          const QString rootPath = QDir::fromNativeSeparators(
              QFileInfo(root.absolutePath()).absoluteFilePath()) + QLatin1Char('/');
          if (relative.startsWith(QStringLiteral(".."))
              || !path.startsWith(rootPath, Qt::CaseInsensitive)) {
              respond(socket, 403, "text/plain", "Forbidden");
              return;
          }
          QFile file(path);
          if (!file.open(QIODevice::ReadOnly)) {
              respond(socket, 404, "text/plain", "Not found");
              return;
          }
          QByteArray content = file.readAll();
          // Serve HTML as a real document URL. Unlike setHtml(), this gives
          // relative resources and parser-inserted scripts normal browser timing.
          if (path.endsWith(QStringLiteral(".html"), Qt::CaseInsensitive)
              || path.endsWith(QStringLiteral(".htm"), Qt::CaseInsensitive)) {
              const QString baseUrl = QStringLiteral("http://127.0.0.1:%1/api/html/%2/")
                  .arg(port()).arg(m_sessionId);
              content = withDocumentBase(content, baseUrl.toUtf8());
              content = expandLegacyCssInset(content);
              content = withHtmlCompat(content);
          } else if (path.endsWith(QStringLiteral(".css"), Qt::CaseInsensitive)) {
              content = expandLegacyCssInset(content);
          }
          // Do not synthesize a CSP here: author pages often legitimately load
          // scripts, styles, fonts, and images from external origins.
          respond(socket, 200, contentTypeForPath(path).toLatin1(), content,
                  {{"Cache-Control", "no-store"}});
          return;
      }
      if (method == "GET" && url.path() == QStringLiteral("/api/medical/manifest")) {
          const QUrlQuery query(url);
          if (!m_medicalMode || m_sessionId.isEmpty()
              || query.queryItemValue(QStringLiteral("session")) != m_sessionId) {
              respond(socket, 403, "text/plain", "Forbidden");
              return;
          }
          respondJson(socket, 200, medicalManifest());
          return;
      }
      if (method == "GET" && url.path() == QStringLiteral("/api/medical/file")) {
          const QUrlQuery query(url);
          bool validIndex = false;
          const int index = query.queryItemValue(QStringLiteral("index")).toInt(&validIndex);
          if (!m_medicalMode || m_sessionId.isEmpty()
              || query.queryItemValue(QStringLiteral("session")) != m_sessionId
              || !validIndex || index < 0 || index >= m_medicalFiles.size()) {
              respond(socket, 403, "text/plain", "Forbidden");
              return;
          }

          const QString localPath = m_medicalFiles.at(index);
          QFile file(localPath);
          if (!file.open(QIODevice::ReadOnly)) {
              respond(socket, 404, "text/plain", "File not found");
              return;
          }
          const QFileInfo info(localPath);
          const QByteArray disposition = "inline; filename*=UTF-8''"
              + QUrl::toPercentEncoding(info.fileName());
          respond(socket, 200, contentTypeForPath(info.absoluteFilePath()).toLatin1(),
                  file.readAll(), {{"Cache-Control", "no-store"},
                                   {"Content-Disposition", disposition}});
          return;
      }
      if (method == "GET" && url.path() == QStringLiteral("/api/document")) {
        const QUrlQuery query(url);
        if (m_currentPath.isEmpty() || query.queryItemValue(QStringLiteral("session")) != m_sessionId) {
            respond(socket, 403, "text/plain", "Forbidden");
            return;
        }
        QFile file(m_currentPath);
        if (!file.open(QIODevice::ReadOnly)) {
            respond(socket, 404, "text/plain", "File not found");
            return;
        }
        const qint64 fileSize = file.size();
        const QByteArray requestHeaders = request.left(headerEnd);
        QByteArray rangeValue;
        for (QByteArray header : requestHeaders.split('\n')) {
            header = header.trimmed();
            if (header.toLower().startsWith("range:")) {
                rangeValue = header.mid(header.indexOf(':') + 1).trimmed();
                break;
            }
        }
        const QByteArray disposition = "inline; filename*=UTF-8''"
            + QUrl::toPercentEncoding(QFileInfo(m_currentPath).fileName());
        if (rangeValue.startsWith("bytes=")) {
            const QByteArray range = rangeValue.mid(6).split(',').first().trimmed();
            const int dash = range.indexOf('-');
            bool valid = dash >= 0;
            qint64 start = 0;
            qint64 end = fileSize - 1;
            if (valid && dash > 0)
                start = range.left(dash).toLongLong(&valid);
            if (valid && dash + 1 < range.size())
                end = range.mid(dash + 1).toLongLong(&valid);
            if (valid && start >= 0 && start < fileSize && end >= start) {
                end = qMin(end, fileSize - 1);
                if (!file.seek(start)) {
                    respond(socket, 500, "text/plain", "Unable to seek document");
                    return;
                }
                const QByteArray body = file.read(end - start + 1);
                respond(socket, 206, contentTypeForPath(m_currentPath).toLatin1(), body, {
                    {"Accept-Ranges", "bytes"},
                    {"Content-Range", "bytes " + QByteArray::number(start) + "-"
                        + QByteArray::number(end) + "/" + QByteArray::number(fileSize)},
                    {"Cache-Control", "no-store"},
                    {"Content-Disposition", disposition}
                });
                return;
            }
        }
        respond(socket, 200, contentTypeForPath(m_currentPath).toLatin1(), file.readAll(), {
            {"Accept-Ranges", "bytes"},
            {"Cache-Control", "no-store"},
            {"Content-Disposition", disposition}
        });
        return;
    }
    if (method == "POST" && url.path() == QStringLiteral("/api/events")) {
        const QUrlQuery query(url);
        if (m_sessionId.isEmpty()
            || query.queryItemValue(QStringLiteral("session")) != m_sessionId) {
            respond(socket, 403, "text/plain", "Forbidden");
            return;
        }
        handleEvent(socket, body);
        return;
    }
    if (method != "GET") {
        respond(socket, 405, "text/plain", "Method not allowed");
        return;
    }

    QString relative = url.path();
    if (relative == QStringLiteral("/"))
        relative = QStringLiteral("/index.html");
    relative = QDir::cleanPath(relative.mid(1));
    if (relative.startsWith(QStringLiteral(".."))) {
        respond(socket, 403, "text/plain", "Forbidden");
        return;
    }
    const QDir root(viewerRoot());
    QString path = QDir::fromNativeSeparators(
        QFileInfo(root.filePath(relative)).absoluteFilePath());
    const QString rootPath = QDir::fromNativeSeparators(
        QFileInfo(root.absolutePath()).absoluteFilePath()) + QLatin1Char('/');
    if (!path.startsWith(rootPath, Qt::CaseInsensitive)) {
        respond(socket, 403, "text/plain", "Forbidden");
        return;
    }
    // The Cornerstone webpack build keeps its public path at "/". Resolve
    // those worker/chunk requests from the namespaced copy as a fallback while
    // keeping the normal viewer-web assets and routes unchanged.
    if (!QFileInfo::exists(path)) {
        const QString cornerstonePath = QDir::fromNativeSeparators(
            QFileInfo(root.filePath(QStringLiteral("cornerstone3d/") + relative))
                .absoluteFilePath());
        if (cornerstonePath.startsWith(rootPath, Qt::CaseInsensitive)
            && QFileInfo::exists(cornerstonePath)) {
            path = cornerstonePath;
        }
    }
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        respond(socket, 404, "text/plain", "Not found");
        return;
    }
      QByteArray responseBody = file.readAll();
      if (relative == QStringLiteral("pdf/viewer.html"))
          responseBody.replace("{{baseUrl}}", "/pdf");
      else if (relative == QStringLiteral("markdown/index.html"))
          responseBody.replace("{{baseUrl}}", "/markdown");
      const bool isMutableViewerResource = relative == QStringLiteral("index.html")
          || relative == QStringLiteral("cornerstone3d/index.html")
          || relative == QStringLiteral("webgl2-compat.js")
          || relative == QStringLiteral("cornerstone3d/webgl2-compat.js")
          || relative.startsWith(QStringLiteral("markdown/"))
          || relative.startsWith(QStringLiteral("pdf/"))
          || relative.startsWith(QStringLiteral("pptist/"))
          || relative == QStringLiteral("html/index.html");
      respond(socket, 200, contentTypeForPath(path).toLatin1(), responseBody, {
        {"Cache-Control", isMutableViewerResource ? "no-store" : "public, max-age=3600"}
    });
}

void ViewerHost::handleEvent(QTcpSocket *socket, const QByteArray &body)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        respondJson(socket, 400, {{QStringLiteral("error"), parseError.errorString()}});
        return;
    }
    const QJsonObject message = document.object();
    const QString type = message.value(QStringLiteral("type")).toString();
    const QJsonValue content = message.value(QStringLiteral("content"));
    QJsonArray events;

    if (type == QStringLiteral("init")) {
        events.append(QJsonObject{{QStringLiteral("type"), QStringLiteral("open")},
                                  {QStringLiteral("content"), openPayload()}});
    } else if (type == QStringLiteral("images")) {
        const QFileInfo fileInfo(m_currentPath);
        const QString suffix = fileInfo.suffix().toLower();
        const QJsonObject image{
            {QStringLiteral("src"), QStringLiteral("/api/document?session=")
                + m_sessionId + QStringLiteral("&nonce=")
                + QString::number(m_nonce)},
            {QStringLiteral("title"), fileInfo.fileName()},
            {QStringLiteral("ext"), QStringLiteral(".") + suffix},
        };
        events.append(QJsonObject{{QStringLiteral("type"), QStringLiteral("images")},
                                  {QStringLiteral("content"), QJsonObject{
                                      {QStringLiteral("images"), QJsonArray{image}},
                                      {QStringLiteral("current"), 0},
                                  }}});
    } else if (type == QStringLiteral("change")) {
        emit documentChanged();
    } else if (type == QStringLiteral("save") || type == QStringLiteral("doSave")) {
        const QString suffix = QFileInfo(m_currentPath).suffix().toLower();
        const bool plainText = QStringList{QStringLiteral("md"), QStringLiteral("markdown"),
                                           QStringLiteral("txt"), QStringLiteral("svg")}.contains(suffix);
        const QByteArray bytes = eventContentToByteArray(content, plainText);
        if (m_currentPath.isEmpty() || m_readOnly || (!plainText && bytes.isEmpty())) {
            respondJson(socket, 403, {{QStringLiteral("error"), QStringLiteral("Document is read-only or empty")}});
            return;
        }
        if (!writeBytes(m_currentPath, bytes)) {
            respondJson(socket, 500, {{QStringLiteral("error"), m_lastError}});
            return;
        }
        events.append(QJsonObject{{QStringLiteral("type"), QStringLiteral("saveDone")}});
    } else if (type == QStringLiteral("saveAs")) {
        const QJsonObject saveAs = content.toObject();
        const QByteArray bytes = jsonBytesToByteArray(saveAs.value(QStringLiteral("content")));
        if (bytes.isEmpty()) {
            respondJson(socket, 400, {{QStringLiteral("error"), QStringLiteral("No document data to save")}});
            return;
        }
        QString extension = saveAs.value(QStringLiteral("ext")).toString();
        if (extension.startsWith(QLatin1Char('.')))
            extension.remove(0, 1);
        const QFileInfo current(m_currentPath);
        const QString suggested = current.absolutePath() + QDir::separator()
            + current.completeBaseName() + (extension.isEmpty() ? QString() : QStringLiteral(".") + extension);
        const QString destination = QFileDialog::getSaveFileName(nullptr, QStringLiteral("另存为"), suggested);
        if (destination.isEmpty()) {
            events.append(QJsonObject{{QStringLiteral("type"), QStringLiteral("saveCanceled")}});
        } else if (!writeBytes(destination, bytes)) {
            respondJson(socket, 500, {{QStringLiteral("error"), m_lastError}});
            return;
        } else {
            events.append(QJsonObject{{QStringLiteral("type"), QStringLiteral("saveDone")}});
        }
    } else if (type == QStringLiteral("openDefault")) {
        if (m_currentPath.isEmpty()
            || !QDesktopServices::openUrl(QUrl::fromLocalFile(m_currentPath))) {
            respondJson(socket, 500, {{QStringLiteral("error"), QStringLiteral("无法使用本地默认软件打开文件")}});
            return;
        }
    } else if (type == QStringLiteral("openExternal")) {
        QDesktopServices::openUrl(QUrl(content.toString()));
    }

    emit viewerEvent(type, content.toVariant());
    respondJson(socket, 200, {{QStringLiteral("events"), events}});
}

void ViewerHost::respond(QTcpSocket *socket, int statusCode, const QByteArray &contentType,
                         const QByteArray &body,
                         const QList<QPair<QByteArray, QByteArray>> &headers)
{
    QByteArray response = "HTTP/1.1 " + QByteArray::number(statusCode) + ' ' + statusText(statusCode) + "\r\n";
    response += "Content-Type: " + contentType + "\r\n";
    response += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    response += "Access-Control-Allow-Origin: *\r\n";
    response += "Access-Control-Allow-Headers: Content-Type\r\n";
    response += "Connection: close\r\n";
    for (const auto &header : headers)
        response += header.first + ": " + header.second + "\r\n";
    response += "\r\n";
    response += body;
    socket->write(response);
    socket->disconnectFromHost();
}

void ViewerHost::respondJson(QTcpSocket *socket, int statusCode, const QJsonObject &object)
{
    respond(socket, statusCode, "application/json; charset=utf-8",
            QJsonDocument(object).toJson(QJsonDocument::Compact));
}

void ViewerHost::setLastError(const QString &message)
{
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}

QString ViewerHost::routeForPath(const QString &path) const
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    if (QStringList{QStringLiteral("docx"), QStringLiteral("dotx")}.contains(suffix)) return QStringLiteral("word");
    if (QStringList{QStringLiteral("xls"), QStringLiteral("xlsx"), QStringLiteral("xlsm"), QStringLiteral("ods"), QStringLiteral("csv"), QStringLiteral("tsv")}.contains(suffix)) return QStringLiteral("excel");
    if (QStringList{QStringLiteral("pptx"), QStringLiteral("pptm")}.contains(suffix)) return QStringLiteral("ppt");
    if (QStringList{QStringLiteral("jpg"), QStringLiteral("jpeg"), QStringLiteral("png"), QStringLiteral("gif"), QStringLiteral("bmp"), QStringLiteral("webp"), QStringLiteral("tif"), QStringLiteral("tiff"), QStringLiteral("heic"), QStringLiteral("heif")}.contains(suffix)) return QStringLiteral("image");
    if (suffix == QStringLiteral("svg")) return QStringLiteral("svg");
    if (QStringList{QStringLiteral("zip"), QStringLiteral("7z"), QStringLiteral("rar"), QStringLiteral("tar"), QStringLiteral("tgz")}.contains(suffix)) return QStringLiteral("zip");
    if (QStringList{QStringLiteral("ttf"), QStringLiteral("otf"), QStringLiteral("woff"), QStringLiteral("woff2")}.contains(suffix)) return QStringLiteral("font");
    if (suffix == QStringLiteral("epub")) return QStringLiteral("epub");
    if (suffix == QStringLiteral("icns")) return QStringLiteral("icns");
    if (suffix == QStringLiteral("psd")) return QStringLiteral("psd");
    if (suffix == QStringLiteral("xmind")) return QStringLiteral("xmind");
    if (suffix == QStringLiteral("parquet")) return QStringLiteral("parquet");
    if (QStringList{QStringLiteral("log"), QStringLiteral("json"), QStringLiteral("dat"),
                    QStringLiteral("xml"), QStringLiteral("hl7"), QStringLiteral("fasta"),
                    QStringLiteral("fastq"), QStringLiteral("vcf"), QStringLiteral("sam")}.contains(suffix))
        return QStringLiteral("textData");
    return QStringLiteral("webUnsupported");
}

QString ViewerHost::contentTypeForPath(const QString &path) const
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    if (suffix == QStringLiteral("html") || suffix == QStringLiteral("htm")) return QStringLiteral("text/html; charset=utf-8");
    if (suffix == QStringLiteral("js")) return QStringLiteral("text/javascript; charset=utf-8");
    if (suffix == QStringLiteral("css")) return QStringLiteral("text/css; charset=utf-8");
    if (suffix == QStringLiteral("json")) return QStringLiteral("application/json; charset=utf-8");
    if (suffix == QStringLiteral("svg")) return QStringLiteral("image/svg+xml");
    if (suffix == QStringLiteral("png")) return QStringLiteral("image/png");
    if (QStringList{QStringLiteral("jpg"), QStringLiteral("jpeg")}.contains(suffix)) return QStringLiteral("image/jpeg");
    if (suffix == QStringLiteral("gif")) return QStringLiteral("image/gif");
    if (suffix == QStringLiteral("wasm")) return QStringLiteral("application/wasm");
    if (suffix == QStringLiteral("woff2")) return QStringLiteral("font/woff2");
    if (suffix == QStringLiteral("pdf")) return QStringLiteral("application/pdf");
    if (QStringList{QStringLiteral("dcm"), QStringLiteral("dicom"), QStringLiteral("ima")}
            .contains(suffix)) return QStringLiteral("application/dicom");
    return QStringLiteral("application/octet-stream");
}

QString ViewerHost::viewerRoot() const
{
    if (!m_viewerRootOverride.isEmpty())
        return m_viewerRootOverride;

    const QDir appDir(QCoreApplication::applicationDirPath());
    // Accept both supported release layouts. Some installers copy dist itself,
    // while others copy its contents into viewer-web.
    const QStringList candidates{
        appDir.absoluteFilePath(QStringLiteral("viewer-web")),
        appDir.absoluteFilePath(QStringLiteral("viewer-web/dist")),
        appDir.absoluteFilePath(QStringLiteral("../release/viewer-web")),
        appDir.absoluteFilePath(QStringLiteral("../release/viewer-web/dist")),
        appDir.absoluteFilePath(QStringLiteral("../viewer-web/dist")),
        appDir.absoluteFilePath(QStringLiteral("../../viewer-web/dist")),
    };
    for (const QString &candidate : candidates) {
        if (QFileInfo(candidate + QStringLiteral("/index.html")).exists())
            return candidate;
    }
    // Preserve a useful path in the error message even when no candidate exists.
    return candidates.constFirst();
}

QJsonObject ViewerHost::medicalManifest() const
{
    const QFileInfo source(m_currentPath);
    const QDir root = source.isDir() ? QDir(source.absoluteFilePath()) : QDir();
    QJsonArray files;
    for (int index = 0; index < m_medicalFiles.size(); ++index) {
        const QFileInfo info(m_medicalFiles.at(index));
        if (!info.exists() || !info.isFile())
            continue;
        QString relativePath = info.fileName();
        if (source.isDir())
            relativePath = QDir::fromNativeSeparators(root.relativeFilePath(info.absoluteFilePath()));
        const QString fileUrl = QStringLiteral("/api/medical/file?session=%1&index=%2&nonce=%3")
            .arg(m_sessionId).arg(index).arg(m_nonce);
        files.append(QJsonObject{
            {QStringLiteral("name"), info.fileName()},
            {QStringLiteral("relativePath"), relativePath},
            {QStringLiteral("url"), fileUrl},
            {QStringLiteral("mime"), contentTypeForPath(info.absoluteFilePath())},
            {QStringLiteral("size"), info.size()},
            {QStringLiteral("modifiedAt"), info.lastModified().toMSecsSinceEpoch()}
        });
    }
    return QJsonObject{
        {QStringLiteral("files"), files},
        {QStringLiteral("source"), source.fileName()},
        {QStringLiteral("session"), m_sessionId}
    };
}

QJsonObject ViewerHost::openPayload() const
{
    const QFileInfo fileInfo(m_currentPath);
    const QString suffix = fileInfo.suffix().toLower();
    if (suffix == QStringLiteral("svg")) {
        QFile file(m_currentPath);
        QString content;
        QString error;
        if (file.open(QIODevice::ReadOnly))
            content = QString::fromUtf8(file.readAll());
        else
            error = file.errorString();
        return {
            {QStringLiteral("path"), m_currentPath},
            {QStringLiteral("content"), content},
            {QStringLiteral("scheme"), QStringLiteral("file")},
            {QStringLiteral("error"), error},
            {QStringLiteral("readOnly"), m_readOnly},
        };
    }
    if (QStringList{QStringLiteral("md"), QStringLiteral("markdown"), QStringLiteral("txt")}.contains(suffix)) {
        QFile file(m_currentPath);
        QString content;
        if (file.open(QIODevice::ReadOnly))
            content = QString::fromUtf8(file.readAll());
        return {
            {QStringLiteral("content"), content},
            {QStringLiteral("rootPath"), QStringLiteral("/markdown")},
            {QStringLiteral("workspaceBaseUrl"), QStringLiteral("/api/html/") + m_sessionId + QLatin1Char('/')},
            {QStringLiteral("documentCacheId"), m_sessionId},
            {QStringLiteral("pendingFragment"), QString()},
            {QStringLiteral("readOnly"), m_readOnly},
            {QStringLiteral("config"), QJsonObject{
                {QStringLiteral("language"), m_language},
                {QStringLiteral("isWeb"), true},
                {QStringLiteral("isDev"), false},
                {QStringLiteral("markdown"), QJsonObject{}},
                {QStringLiteral("editMode"), QStringLiteral("wysiwyg")},
                {QStringLiteral("editorTheme"), QStringLiteral("classic")},
                {QStringLiteral("codeMirrorTheme"), QStringLiteral("github")},
                {QStringLiteral("mermaidTheme"), QStringLiteral("default")}
            }}
        };
    }
    return {
        {QStringLiteral("path"), QStringLiteral("/api/document?session=") + m_sessionId},
        {QStringLiteral("fileName"), fileInfo.fileName()},
        {QStringLiteral("ext"), QStringLiteral(".") + fileInfo.suffix().toLower()},
        {QStringLiteral("readOnly"), m_readOnly},
        {QStringLiteral("documentCacheId"), m_sessionId},
        {QStringLiteral("workspaceBaseUrl"), QStringLiteral("/api/html/")
            + m_sessionId + QLatin1Char('/')},
        {QStringLiteral("nonce"), static_cast<qint64>(m_nonce)}
    };
}

bool ViewerHost::writeBytes(const QString &path, const QByteArray &bytes)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly) || file.write(bytes) != bytes.size() || !file.commit()) {
        setLastError(file.errorString());
        return false;
    }
    setLastError({});
    emit documentSaved(path);
    return true;
}
