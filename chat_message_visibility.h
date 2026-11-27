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

/// Message kinds used by the gateway transcript contract for non-user-facing
/// system injections. Keep this list explicit: normal system-role messages,
/// user text that resembles a System: event, and unknown kinds stay visible.
inline bool isHiddenSystemMessage(const QJsonObject &message)
{
    const QString kind = message.value(QStringLiteral("kind")).toString()
                             .trimmed().toLower();
    return kind == QLatin1String("system-event")
        || kind == QLatin1String("system-turn");
}

inline bool shouldHideMessage(const QJsonObject &message)
{
    return isInternalMessage(message) || isHiddenSystemMessage(message);
}

} // namespace ChatMessageVisibility
#endif
