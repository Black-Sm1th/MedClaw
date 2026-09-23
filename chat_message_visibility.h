#ifndef CHAT_MESSAGE_VISIBILITY_H
#define CHAT_MESSAGE_VISIBILITY_H

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

namespace ChatMessageVisibility {

inline bool isInternalMessage(const QJsonObject &message)
{
    if (message.value(QStringLiteral("role")).toString().trimmed().toLower()
        != QLatin1String("user"))
        return false;

    for (const QString &key : {QStringLiteral("provenance"), QStringLiteral("inputProvenance")}) {
        if (message.value(key).toObject().value(QStringLiteral("kind")).toString()
            == QLatin1String("inter_session"))
            return true;
    }

    QString text;
    const QJsonValue content = message.value(QStringLiteral("content"));
    if (content.isString()) {
        text = content.toString();
    } else {
        for (const QJsonValue &block : content.toArray()) {
            if (block.toObject().value(QStringLiteral("type")).toString() == QLatin1String("text"))
                text += block.toObject().value(QStringLiteral("text")).toString() + QLatin1Char('\n');
        }
    }
    if (text.isEmpty())
        text = message.value(QStringLiteral("text")).toString();
    text = text.trimmed();
    // Older histories omit provenance. Require the runtime envelope, not
    // words such as "subagent" that a real user may legitimately write.
    return (text.startsWith(QLatin1String("OpenClaw runtime context (internal):"))
            || text.startsWith(QLatin1String("[Internal task completion event]")))
        && text.contains(QLatin1String("<<<BEGIN_UNTRUSTED_CHILD_RESULT>>>"))
        && text.contains(QLatin1String("<<<END_UNTRUSTED_CHILD_RESULT>>>"));
}

} // namespace ChatMessageVisibility
#endif
