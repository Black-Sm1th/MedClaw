#include "OnlineOfficeClient.h"

#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QSaveFile>
#include <QTimer>
#include <QUrl>

OnlineOfficeClient::OnlineOfficeClient(QObject *parent)
    : QObject(parent)
{
}

bool OnlineOfficeClient::saving() const
{
    return m_state == State::WaitingForSave || m_state == State::Downloading;
}

void OnlineOfficeClient::setBridgeBaseUrl(const QString &value)
{
    QString normalized = value.trimmed();
    while (normalized.endsWith(QLatin1Char('/')))
        normalized.chop(1);
    if (m_bridgeBaseUrl == normalized)
        return;
    m_bridgeBaseUrl = normalized;
    emit bridgeBaseUrlChanged();
}

void OnlineOfficeClient::setApiKey(const QString &value)
{
    const QByteArray normalized = value.trimmed().toUtf8();
    if (m_apiKey == normalized)
        return;
    m_apiKey = normalized;
    emit apiKeyChanged();
}

QNetworkRequest OnlineOfficeClient::requestFor(const QString &path) const
{
    QNetworkRequest request(QUrl(m_bridgeBaseUrl + path));
    request.setRawHeader("X-API-Key", m_apiKey);
    return request;
}

void OnlineOfficeClient::setState(State state)
{
    const bool wasBusy = m_state != State::Idle;
    const bool wasSaving = saving();
    m_state = state;
    if (wasBusy != (m_state != State::Idle))
        emit busyChanged();
    if (wasSaving != saving())
        emit savingChanged();
}

void OnlineOfficeClient::setEditorUrl(const QString &value)
{
    if (m_editorUrl == value)
        return;
    m_editorUrl = value;
    emit editorUrlChanged();
}

void OnlineOfficeClient::setLastError(const QString &value)
{
    if (m_lastError == value)
        return;
    m_lastError = value;
    emit lastErrorChanged();
}

void OnlineOfficeClient::openDocument(const QString &filePath, const QString &mode)
{
    if (m_state != State::Idle) {
        setLastError(QStringLiteral("已有文档会话正在处理"));
        return;
    }
    if (m_bridgeBaseUrl.isEmpty() || m_apiKey.isEmpty()) {
        setLastError(QStringLiteral("未配置在线 Office 服务地址或访问令牌"));
        return;
    }

    const QFileInfo info(filePath);
    if (!info.isFile() || !info.isReadable()) {
        setLastError(QStringLiteral("文档不存在或不可读取"));
        return;
    }

    QFile *file = new QFile(info.absoluteFilePath());
    if (!file->open(QIODevice::ReadOnly)) {
        setLastError(QStringLiteral("无法打开待上传文档"));
        delete file;
        return;
    }

    QHttpMultiPart *multipart = new QHttpMultiPart(QHttpMultiPart::FormDataType);
    m_mode = mode.compare(QStringLiteral("edit"), Qt::CaseInsensitive) == 0
                 ? QStringLiteral("edit")
                 : QStringLiteral("view");
    QHttpPart modePart;
    modePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"mode\""));
    modePart.setBody(m_mode.toUtf8());
    multipart->append(modePart);

    QHttpPart filePart;
    QString fileName = info.fileName();
    fileName.replace(QLatin1Char('"'), QLatin1Char('_'));
    filePart.setHeader(QNetworkRequest::ContentDispositionHeader,
                       QStringLiteral("form-data; name=\"file\"; filename=\"%1\"")
                           .arg(fileName));
    filePart.setHeader(QNetworkRequest::ContentTypeHeader,
                       QStringLiteral("application/octet-stream"));
    filePart.setBodyDevice(file);
    file->setParent(multipart);
    multipart->append(filePart);

    m_filePath = info.absoluteFilePath();
    m_uploadProgress = 0;
    emit uploadProgressChanged();
    setLastError(QString());
    setEditorUrl(QString());
    setState(State::Uploading);
    emit statusMessage(QStringLiteral("正在上传文档..."));

    QNetworkReply *reply = m_network.post(
        requestFor(QStringLiteral("/api/office/sessions")), multipart);
    m_activeReply = reply;
    multipart->setParent(reply);
    connect(reply, &QNetworkReply::uploadProgress, this,
            [this](qint64 sent, qint64 total) {
                const int progress = total > 0 ? static_cast<int>((sent * 100) / total) : 0;
                if (m_uploadProgress != progress) {
                    m_uploadProgress = progress;
                    emit uploadProgressChanged();
                }
            });
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_activeReply == reply)
            m_activeReply.clear();
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString errorText = reply->errorString();
        const bool ok = reply->error() == QNetworkReply::NoError;
        reply->deleteLater();
        if (!ok) {
            setLastError(QStringLiteral("上传文档失败：%1（HTTP %2）")
                             .arg(errorText).arg(status));
            finishLocally(false);
            return;
        }

        const QJsonObject response = QJsonDocument::fromJson(body).object();
        m_sessionId = response.value(QStringLiteral("sessionId")).toString();
        const QString url = response.value(QStringLiteral("editorUrl")).toString();
        if (m_sessionId.isEmpty() || url.isEmpty()) {
            setLastError(QStringLiteral("在线 Office 服务返回的数据不完整"));
            finishLocally(false);
            return;
        }
        setEditorUrl(url);
        setState(State::Editing);
        emit editorReady(url);
        emit statusMessage(QStringLiteral("文档已打开"));
    });
}

void OnlineOfficeClient::finishDocument()
{
    if (m_state != State::Editing)
        return;
    setEditorUrl(QString());

    if (m_mode == QStringLiteral("view")) {
        const QString sessionId = m_sessionId;
        if (!sessionId.isEmpty())
            deleteSession(sessionId);
        finishLocally(false);
        return;
    }

    m_finishAfterSave = true;
    setState(State::WaitingForSave);
    emit statusMessage(QStringLiteral("正在等待 OnlyOffice 保存文档..."));
    QNetworkReply *reply = m_network.post(
        requestFor(QStringLiteral("/api/office/sessions/%1/force-save").arg(m_sessionId)),
        QByteArray());
    m_activeReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_activeReply == reply)
            m_activeReply.clear();
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString errorText = reply->errorString();
        const bool ok = reply->error() == QNetworkReply::NoError;
        const QJsonObject response = QJsonDocument::fromJson(body).object();
        reply->deleteLater();
        if (m_state == State::WaitingForSave) {
            emit saveRequestFinished();
            if (ok) {
                if (response.value(QStringLiteral("unchanged")).toBool()) {
                    const QString path = m_filePath;
                    deleteSession(m_sessionId);
                    finishLocally(true);
                    emit saveFinished(path, true);
                } else {
                    pollResult(120);
                }
            } else {
                const QString detail = response.value(QStringLiteral("detail")).toString();
                setLastError(detail.isEmpty()
                                 ? QStringLiteral("OnlyOffice save request failed: %1 (HTTP %2)")
                                       .arg(errorText).arg(status)
                                 : QStringLiteral("%1 (HTTP %2)").arg(detail).arg(status));
                finishLocally(false);
            }
        }
    });
}

void OnlineOfficeClient::saveDocument()
{
    if (m_state != State::Editing || m_mode != QStringLiteral("edit")
            || m_sessionId.isEmpty())
        return;

    m_finishAfterSave = false;
    setLastError(QString());
    setState(State::WaitingForSave);
    emit statusMessage(QStringLiteral("OnlyOffice is saving the document..."));
    QNetworkReply *reply = m_network.post(
        requestFor(QStringLiteral("/api/office/sessions/%1/force-save").arg(m_sessionId)),
        QByteArray());
    m_activeReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_activeReply == reply)
            m_activeReply.clear();
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QString errorText = reply->errorString();
        const bool ok = reply->error() == QNetworkReply::NoError;
        const QJsonObject response = QJsonDocument::fromJson(body).object();
        reply->deleteLater();
        if (m_state != State::WaitingForSave)
            return;
        emit saveRequestFinished();
        if (ok) {
            if (response.value(QStringLiteral("unchanged")).toBool()) {
                const QString path = m_filePath;
                setState(State::Editing);
                emit statusMessage(QStringLiteral("Document is already saved"));
                emit saveFinished(path, true);
                return;
            }
            pollResult(120);
            return;
        }
        const QString detail = response.value(QStringLiteral("detail")).toString();
        setLastError(detail.isEmpty()
                         ? QStringLiteral("OnlyOffice save request failed: %1 (HTTP %2)")
                               .arg(errorText).arg(status)
                         : QStringLiteral("%1 (HTTP %2)").arg(detail).arg(status));
        const QString path = m_filePath;
        setState(State::Editing);
        emit saveFinished(path, false);
    });
}

void OnlineOfficeClient::pollResult(int attemptsLeft)
{
    if (m_state != State::WaitingForSave || m_sessionId.isEmpty())
        return;
    QNetworkReply *reply = m_network.get(
        requestFor(QStringLiteral("/api/office/sessions/%1").arg(m_sessionId)));
    m_activeReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, attemptsLeft] {
        if (m_activeReply == reply)
            m_activeReply.clear();
        const QByteArray body = reply->readAll();
        const bool ok = reply->error() == QNetworkReply::NoError;
        const QString errorText = reply->errorString();
        reply->deleteLater();
        const QJsonObject response = QJsonDocument::fromJson(body).object();
        if (ok && response.value(QStringLiteral("resultReady")).toBool()) {
            downloadResult();
            return;
        }
        if (ok && response.value(QStringLiteral("status")).toString()
                      == QStringLiteral("closed")) {
            deleteSession(m_sessionId);
            finishLocally(false);
            return;
        }
        if (attemptsLeft > 1) {
            QTimer::singleShot(500, this,
                               [this, attemptsLeft] { pollResult(attemptsLeft - 1); });
            return;
        }
        setLastError(ok ? QStringLiteral("等待编辑结果超时")
                        : QStringLiteral("查询保存状态失败：%1").arg(errorText));
        const QString path = m_filePath;
        if (m_finishAfterSave)
            finishLocally(false);
        else
            setState(State::Editing);
        emit saveFinished(path, false);
    });
}

void OnlineOfficeClient::downloadResult()
{
    setState(State::Downloading);
    QNetworkReply *reply = m_network.get(
        requestFor(QStringLiteral("/api/office/sessions/%1/result").arg(m_sessionId)));
    m_activeReply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_activeReply == reply)
            m_activeReply.clear();
        const QByteArray data = reply->readAll();
        bool saved = reply->error() == QNetworkReply::NoError && !data.isEmpty();
        if (saved) {
            QSaveFile output(m_filePath);
            saved = output.open(QIODevice::WriteOnly)
                    && output.write(data) == data.size()
                    && output.commit();
        }
        if (saved) {
            setLastError(QString());
            emit documentSaved(m_filePath);
            emit statusMessage(QStringLiteral("编辑结果已保存到本地"));
        } else {
            setLastError(QStringLiteral("下载或写入编辑结果失败：%1")
                             .arg(reply->errorString()));
        }
        reply->deleteLater();
        const QString path = m_filePath;
        if (m_finishAfterSave) {
            if (saved)
                deleteSession(m_sessionId);
            finishLocally(saved);
        } else {
            setState(State::Editing);
        }
        emit saveFinished(path, saved);
    });
}

void OnlineOfficeClient::deleteSession(const QString &sessionId)
{
    if (sessionId.isEmpty())
        return;
    QNetworkReply *reply = m_network.deleteResource(
        requestFor(QStringLiteral("/api/office/sessions/%1").arg(sessionId)));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

void OnlineOfficeClient::finishLocally(bool saved)
{
    const QString completedPath = m_filePath;
    m_sessionId.clear();
    m_filePath.clear();
    m_mode.clear();
    m_finishAfterSave = false;
    setEditorUrl(QString());
    setState(State::Idle);
    emit sessionFinished(completedPath, saved);
}

void OnlineOfficeClient::cancel()
{
    if (m_state == State::Idle)
        return;
    const QString sessionId = m_sessionId;
    if (m_activeReply) {
        disconnect(m_activeReply, nullptr, this, nullptr);
        m_activeReply->abort();
        m_activeReply->deleteLater();
        m_activeReply.clear();
    }
    if (!sessionId.isEmpty())
        deleteSession(sessionId);
    finishLocally(false);
}
