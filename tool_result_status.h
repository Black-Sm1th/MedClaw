#ifndef TOOL_RESULT_STATUS_H
#define TOOL_RESULT_STATUS_H

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QString>

/// Older persisted histories may keep an error envelope only in the tool
/// output text and omit the separate isError flag. Preserve that status when
/// rendering the history. An explicit error flag always remains authoritative.
inline bool toolResultIsError(const QString &content, bool explicitIsError = false)
{
    if (explicitIsError)
        return true;

    const QString trimmed = content.trimmed();
    const QStringList failurePrefixes{
        QStringLiteral("执行失败"),
        QStringLiteral("执行错误"),
        QStringLiteral("工具执行失败"),
        QStringLiteral("脚本执行失败"),
        QStringLiteral("execution failed"),
        QStringLiteral("tool execution failed"),
        QStringLiteral("command failed")
    };
    for (const QString &prefix : failurePrefixes) {
        if (trimmed.startsWith(prefix, Qt::CaseInsensitive))
            return true;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(trimmed.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return false;

    const QJsonObject object = document.object();
    const QString status = object.value(QStringLiteral("status")).toString().trimmed();
    return status.compare(QStringLiteral("error"), Qt::CaseInsensitive) == 0
        || object.value(QStringLiteral("isError")).toBool(false)
        || (object.contains(QStringLiteral("success"))
            && !object.value(QStringLiteral("success")).toBool(true));
}

#endif // TOOL_RESULT_STATUS_H
