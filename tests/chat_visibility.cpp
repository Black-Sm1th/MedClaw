#include "chat_message_visibility.h"
#include "chatmodel.h"
#include "ws_session.h"
#include "session_reader.h"
#include "tool_result_status.h"
#include <QCoreApplication>
#include <QJsonDocument>
#include <QTemporaryFile>
#include <cstdlib>

static int checkIndex = 0;
static void check(bool ok)
{
    ++checkIndex;
    if (!ok) {
        qCritical() << "check failed:" << checkIndex;
        std::abort();
    }
}

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
    const QJsonObject imageCall{{"role", "assistant"}, {"content", QJsonArray{
        QJsonObject{{"type", "toolCall"}, {"id", "image-1"}, {"name", "image"},
                    {"arguments", QJsonObject{{"prompt", "test"}}}}}}};
    const QString imageError = QStringLiteral(
        "{\"status\":\"error\",\"tool\":\"image\",\"error\":\"Request was aborted\"}");
    const QJsonObject imageResult{{"role", "toolResult"}, {"toolCallId", "image-1"},
        {"toolName", "image"}, {"isError", false},
        {"content", QJsonArray{QJsonObject{{"type", "text"}, {"text", imageError}}}}};
    const QJsonObject abortedCall{{"role", "assistant"}, {"content", QJsonArray{
        QJsonObject{{"type", "toolCall"}, {"id", "image-2"}, {"name", "image"},
                    {"arguments", QJsonObject{{"prompt", "another test"}}}}}}};
    const QString abortedError = QStringLiteral(
        "{\"status\":\"error\",\"tool\":\"image\",\"error\":\"Image model failed: Request was aborted\"}");
    const QJsonObject abortedResult{{"role", "toolResult"}, {"toolCallId", "image-2"},
        {"toolName", "image"}, {"isError", false},
        {"content", QJsonArray{QJsonObject{{"type", "text"}, {"text", abortedError}}}}};
    const QJsonObject pathologyCall{{"role", "assistant"}, {"content", QJsonArray{
        QJsonObject{{"type", "toolCall"}, {"id", "pathology-1"},
                    {"name", "imaging_case"},
                    {"arguments", QJsonObject{{"task", "pathology report"}}}}}}};
    const QString pathologyError = QStringLiteral(
        "执行失败：脚本执行失败 (exit 2): usage: imaging_case.py [--input INPUT_PATH]");
    const QJsonObject pathologyResult{{"role", "toolResult"},
        {"toolCallId", "pathology-1"}, {"toolName", "imaging_case"},
        {"isError", false},
        {"content", QJsonArray{QJsonObject{{"type", "text"}, {"text", pathologyError}}}}};
    const QJsonObject answer{{"role", "assistant"}, {"content", "Final expert answer"}};
    QJsonObject arrayNotice = notice;
    arrayNotice["content"] = QJsonArray{QJsonObject{{"type", "text"}, {"text", internal}}};
    check(ChatMessageVisibility::isInternalMessage(arrayNotice));
    check(!ChatMessageVisibility::isInternalMessage(user));
    QJsonObject quoted = user;
    quoted["content"] = "Explain this log: " + internal;
    check(!ChatMessageVisibility::isInternalMessage(quoted));
    const QJsonArray messages{user, call, result, imageCall, imageResult,
                              abortedCall, abortedResult, pathologyCall, pathologyResult,
                              notice, forwarded, answer};
    WsSession session;
    const auto history = session.parseHistoryResponse(QJsonObject{{"messages", messages}});
    check(history.size() == 10);
    check(history[1].toMap()["toolName"] == "sessions_spawn");
    check(history[2].toMap()["toolCallId"] == "spawn-1");
    check(history[4].toMap()["isError"].toBool());
    check(history[6].toMap()["isError"].toBool());
    check(!toolResultIsError(QStringLiteral("{\"status\":\"success\"}")));
    check(toolResultIsError(QStringLiteral("completed"), true));
    check(toolResultIsError(pathologyError));
    check(!toolResultIsError(QStringLiteral("病理报告已生成：report.html")));
    ChatModel chatModel;
    chatModel.loadHistory(history);
    const QVariantList restored = chatModel.messages();
    check(restored.size() == 6);
    check(restored[2].toMap()["isError"].toBool());
    check(restored[3].toMap()["isError"].toBool());
    check(restored[4].toMap()["isError"].toBool());

    ChatModel liveModel;
    liveModel.addToolCall("imaging_case", "{}", "pathology-live");
    liveModel.addToolResult("imaging_case", pathologyError, "pathology-live", false);
    check(liveModel.messages()[0].toMap()["isError"].toBool());
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
    check(local.size() == 10);
    check(local[1].toMap()["toolName"] == "sessions_spawn");
    check(local[2].toMap()["toolCallId"] == "spawn-1");
    check(local[4].toMap()["isError"].toBool());
    check(local[6].toMap()["isError"].toBool());
    check(local[8].toMap()["isError"].toBool());
    for (const auto &row : local)
        check(!row.toMap()["content"].toString().contains("internal handoff"));
    QTemporaryFile response;
    check(response.open());
    response.write(QJsonDocument(QJsonObject{{"messages", messages}}).toJson());
    response.flush();
    const auto responseHistory = reader.parseResponseFile(response.fileName());
    check(responseHistory.size() == 10);
    check(responseHistory[4].toMap()["isError"].toBool());
    check(responseHistory[6].toMap()["isError"].toBool());
    check(responseHistory[8].toMap()["isError"].toBool());
    return 0;
}
