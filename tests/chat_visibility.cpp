#include "chat_message_visibility.h"
#include "ws_session.h"
#include "session_reader.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QTemporaryFile>
#include <cstdlib>

static void check(bool ok) { if (!ok) std::abort(); }

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QString internal = QStringLiteral("OpenClaw runtime context (internal):\n"
        "[Internal task completion event]\n<<<BEGIN_UNTRUSTED_CHILD_RESULT>>>\n"
        "child output\n<<<END_UNTRUSTED_CHILD_RESULT>>>\nAction: internal handoff");
    const QJsonObject user{{"role", "user"}, {"content", "Please explain sessions_spawn"}};
    const QJsonObject notice{{"role", "user"}, {"content", internal}};
    const QJsonObject forwarded{{"role", "user"}, {"content", "delegated instruction"},
        {"provenance", QJsonObject{{"kind", "inter_session"}, {"sourceTool", "sessions_send"}}}};
    const QJsonObject call{{"role", "assistant"}, {"content", QJsonArray{
        QJsonObject{{"type", "toolCall"}, {"id", "spawn-1"}, {"name", "sessions_spawn"},
                    {"arguments", QJsonObject{{"task", "review image"}}}}}}};
    const QJsonObject result{{"role", "toolResult"}, {"toolCallId", "spawn-1"},
        {"toolName", "sessions_spawn"}, {"content", "accepted"}};
    const QJsonObject answer{{"role", "assistant"}, {"content", "Final expert answer"}};
    QJsonObject arrayNotice = notice;
    arrayNotice["content"] = QJsonArray{QJsonObject{{"type", "text"}, {"text", internal}}};
    check(ChatMessageVisibility::isInternalMessage(arrayNotice));
    check(!ChatMessageVisibility::isInternalMessage(user));
    QJsonObject quoted = user;
    quoted["content"] = "Explain this log: " + internal;
    check(!ChatMessageVisibility::isInternalMessage(quoted));
    const QJsonArray messages{user, call, result, notice, forwarded, answer};
    WsSession session;
    const auto history = session.parseHistoryResponse(QJsonObject{{"messages", messages}});
    check(history.size() == 4);
    check(history[1].toMap()["toolName"] == "sessions_spawn");
    check(history[2].toMap()["toolCallId"] == "spawn-1");
    check(session.parseEvent("chat", QJsonObject{{"message", notice}}).ignore);
    check(session.parseEvent("agent", QJsonObject{{"data", forwarded}}).ignore);
    QJsonObject inputForwarded = user;
    inputForwarded["inputProvenance"] = QJsonObject{{"kind", "inter_session"}};
    check(ChatMessageVisibility::isInternalMessage(inputForwarded));
    QJsonObject normalAssistant = answer;
    normalAssistant["content"] = internal;
    check(!ChatMessageVisibility::isInternalMessage(normalAssistant));

    QTemporaryFile jsonl;
    check(jsonl.open());
    for (const auto &message : messages) {
        QJsonObject entry = message.toObject();
        if (entry["content"].isString())
            entry["content"] = QJsonArray{QJsonObject{{"type", "text"}, {"text", entry["content"]}}};
        jsonl.write(QJsonDocument(QJsonObject{{"type", "message"}, {"message", entry}}).toJson(QJsonDocument::Compact));
        jsonl.write("\n");
    }
    jsonl.flush();
    SessionReader reader;
    // JSONL text entries use the content-block representation.
    const auto local = reader.readSessionMessages(jsonl.fileName());
    check(local.size() == 4);
    check(local[1].toMap()["toolName"] == "sessions_spawn");
    check(local[2].toMap()["toolCallId"] == "spawn-1");
    for (const auto &row : local)
        check(!row.toMap()["content"].toString().contains("internal handoff"));
    QTemporaryFile response;
    check(response.open());
    response.write(QJsonDocument(QJsonObject{{"messages", messages}}).toJson());
    response.flush();
    check(reader.parseResponseFile(response.fileName()).size() == 4);
    return 0;
}
