/**
 * @file ws_tools.cpp
 */
#include "ws_tools.h"

#include <algorithm>

#include <QDebug>
#include <QJsonValue>
#include <QSet>
#include <QVariantMap>

QJsonObject WsTools::buildToolsCatalogParams(const QString &agentId,
                                             const bool includePlugins) const
{
    QJsonObject p;
    const QString a = agentId.trimmed();
    if (!a.isEmpty())
        p[QStringLiteral("agentId")] = a;
    p[QStringLiteral("includePlugins")] = includePlugins;
    return p;
}

QStringList WsTools::jsonStringList(const QJsonArray &arr)
{
    QStringList out;
    for (const QJsonValue &v : arr) {
        const QString s = v.toString().trimmed();
        if (!s.isEmpty())
            out.append(s);
    }
    return out;
}

QJsonArray WsTools::toJsonArray(const QStringList &list)
{
    QJsonArray a;
    for (const QString &s : list)
        a.append(s);
    return a;
}

QJsonObject WsTools::toolsObjectForAgent(const QJsonObject &config, const QString &agentId)
{
    const QString want = agentId.trimmed();
    if (want.isEmpty())
        return QJsonObject();

    const QJsonArray list =
        config.value(QStringLiteral("agents")).toObject()
            .value(QStringLiteral("list")).toArray();
    for (const QJsonValue &v : list) {
        const QJsonObject ag = v.toObject();
        if (ag.value(QStringLiteral("id")).toString().trimmed() == want)
            return ag.value(QStringLiteral("tools")).toObject();
    }
    return QJsonObject();
}

void WsTools::parseToolsCatalogResponse(const QJsonObject &payload)
{
    m_toolList.clear();
    m_catalogAgentId = payload.value(QStringLiteral("agentId")).toString();

    const QJsonArray groups = payload.value(QStringLiteral("groups")).toArray();
    for (const QJsonValue &gv : groups) {
        const QJsonObject g = gv.toObject();
        const QString groupId = g.value(QStringLiteral("id")).toString();
        const QString groupLabel = g.value(QStringLiteral("label")).toString();
        const QJsonArray tools = g.value(QStringLiteral("tools")).toArray();
        for (const QJsonValue &tv : tools) {
            const QJsonObject t = tv.toObject();
            const QString id = t.value(QStringLiteral("id")).toString().trimmed();
            if (id.isEmpty())
                continue;

            QVariantMap entry;
            entry[QStringLiteral("toolId")] = id;
            entry[QStringLiteral("label")] =
                t.value(QStringLiteral("label")).toString().trimmed();
            if (entry[QStringLiteral("label")].toString().isEmpty())
                entry[QStringLiteral("label")] = id;
            entry[QStringLiteral("description")] =
                t.value(QStringLiteral("description")).toString();
            entry[QStringLiteral("source")] = t.value(QStringLiteral("source")).toString();
            entry[QStringLiteral("pluginId")] = t.value(QStringLiteral("pluginId")).toString();
            entry[QStringLiteral("groupId")] = groupId;
            entry[QStringLiteral("groupLabel")] = groupLabel;
            entry[QStringLiteral("optional")] = t.value(QStringLiteral("optional")).toBool(false);
            entry[QStringLiteral("enabled")] = true;
            m_toolList.append(entry);
        }
    }

    qDebug() << "[WsTools] catalog" << m_toolList.count() << "tools for agent"
             << m_catalogAgentId;
}

void WsTools::applyToolPolicyFromConfig(const QJsonObject &config, const QString &agentId)
{
    const QJsonObject tobj = toolsObjectForAgent(config, agentId);
    const QStringList deny = jsonStringList(tobj.value(QStringLiteral("deny")).toArray());
    const QStringList allow = jsonStringList(tobj.value(QStringLiteral("allow")).toArray());
    const QStringList alsoAllow =
        jsonStringList(tobj.value(QStringLiteral("alsoAllow")).toArray());
    qDebug() << "[ToolPolicy] agent=" << agentId
             << "deny=" << deny << "allow=" << allow
             << "alsoAllow=" << alsoAllow
             << "toolsObj.keys=" << tobj.keys();

    QSet<QString> denySet;
    for (const QString &s : deny)
        denySet.insert(s);
    QSet<QString> allowUnion;
    for (const QString &s : allow)
        allowUnion.insert(s);
    for (const QString &s : alsoAllow)
        allowUnion.insert(s);

    const bool explicitAllow = !allow.isEmpty();

    for (int i = 0; i < m_toolList.count(); ++i) {
        QVariantMap e = m_toolList[i].toMap();
        const QString tid = e.value(QStringLiteral("toolId")).toString().trimmed();
        if (tid.isEmpty())
            continue;

        bool enabled = true;
        if (denySet.contains(tid))
            enabled = false;
        else if (explicitAllow)
            enabled = allowUnion.contains(tid);

        e[QStringLiteral("enabled")] = enabled;
        m_toolList[i] = e;
    }
}

QJsonObject WsTools::buildToolToggleMergePatch(const QJsonObject &fullConfig,
                                               const QString &agentId,
                                               const QString &toolId,
                                               const bool enable) const
{
    const QString aid = agentId.trimmed();
    const QString tid = toolId.trimmed();
    if (aid.isEmpty() || tid.isEmpty())
        return QJsonObject();

    bool agentFound = false;
    const QJsonArray agentList =
        fullConfig.value(QStringLiteral("agents")).toObject()
            .value(QStringLiteral("list")).toArray();
    for (const QJsonValue &v : agentList) {
        if (v.toObject().value(QStringLiteral("id")).toString().trimmed() == aid) {
            agentFound = true;
            break;
        }
    }
    if (!agentFound)
        return QJsonObject();

    const QJsonObject existingTools = toolsObjectForAgent(fullConfig, aid);

    QStringList deny = jsonStringList(existingTools.value(QStringLiteral("deny")).toArray());
    QStringList allow = jsonStringList(existingTools.value(QStringLiteral("allow")).toArray());
    QStringList alsoAllow =
        jsonStringList(existingTools.value(QStringLiteral("alsoAllow")).toArray());

    const bool explicitAllow = !allow.isEmpty();

    if (enable) {
        deny.removeAll(tid);
        if (explicitAllow) {
            bool inUnion = false;
            for (const QString &s : allow) {
                if (s == tid) {
                    inUnion = true;
                    break;
                }
            }
            if (!inUnion) {
                for (const QString &s : alsoAllow) {
                    if (s == tid) {
                        inUnion = true;
                        break;
                    }
                }
            }
            if (!inUnion)
                allow.append(tid);
        }
    } else {
        if (!deny.contains(tid))
            deny.append(tid);
    }

    QJsonObject toolsFrag;
    toolsFrag[QStringLiteral("deny")] = toJsonArray(deny);
    if (explicitAllow || !allow.isEmpty())
        toolsFrag[QStringLiteral("allow")] = toJsonArray(allow);
    if (!alsoAllow.isEmpty())
        toolsFrag[QStringLiteral("alsoAllow")] = toJsonArray(alsoAllow);

    QJsonObject agentFrag;
    agentFrag[QStringLiteral("id")] = aid;
    agentFrag[QStringLiteral("tools")] = toolsFrag;

    QJsonArray one;
    one.append(agentFrag);

    QJsonObject agents;
    agents[QStringLiteral("list")] = one;

    QJsonObject root;
    root[QStringLiteral("agents")] = agents;
    return root;
}

QJsonObject WsTools::buildFullConfigWithSkillToggle(const QJsonObject &fullConfig,
                                                    const QString &agentId,
                                                    const QStringList &allSkillNames,
                                                    const QString &skillName,
                                                    const bool enabled) const
{
    const QString aid = agentId.trimmed();
    const QString skill = skillName.trimmed();
    if (aid.isEmpty() || skill.isEmpty())
        return QJsonObject();

    QJsonObject result = fullConfig;
    QJsonObject agentsObj = result.value(QStringLiteral("agents")).toObject();
    QJsonArray list = agentsObj.value(QStringLiteral("list")).toArray();

    int idx = -1;
    for (int i = 0; i < list.count(); ++i) {
        if (list[i].toObject().value(QStringLiteral("id")).toString().trimmed() == aid) {
            idx = i;
            break;
        }
    }
    if (idx < 0)
        return QJsonObject();

    QJsonObject agentEntry = list[idx].toObject();

    QStringList base;
    const QJsonValue skVal = agentEntry.value(QStringLiteral("skills"));
    if (!agentEntry.contains(QStringLiteral("skills")) || skVal.isNull()
        || skVal.isUndefined()) {
        base = allSkillNames;
    } else if (skVal.isArray()) {
        base = jsonStringList(skVal.toArray());
    } else {
        base = allSkillNames;
    }

    QSet<QString> next;
    for (const QString &s : base) {
        const QString t = s.trimmed();
        if (!t.isEmpty())
            next.insert(t);
    }
    if (enabled)
        next.insert(skill);
    else
        next.remove(skill);

    QStringList sorted;
    sorted.reserve(next.size());
    for (const QString &s : next)
        sorted.append(s);
    std::sort(sorted.begin(), sorted.end());

    QJsonArray skillsArr;
    for (const QString &s : sorted)
        skillsArr.append(s);

    agentEntry[QStringLiteral("skills")] = skillsArr;
    list[idx] = agentEntry;
    agentsObj[QStringLiteral("list")] = list;
    result[QStringLiteral("agents")] = agentsObj;

    qDebug() << "[SkillSave] agentId=" << aid << "skill=" << skill << "enabled=" << enabled
             << "skillsCount=" << skillsArr.size();
    return result;
}

QJsonObject WsTools::buildFullConfigWithAgentSkillsAllowlist(const QJsonObject &fullConfig,
                                                             const QString &agentId,
                                                             const QStringList &enabledSkillNames) const
{
    const QString aid = agentId.trimmed();
    if (aid.isEmpty())
        return QJsonObject();

    QJsonObject result = fullConfig;
    QJsonObject agentsObj = result.value(QStringLiteral("agents")).toObject();
    QJsonArray list = agentsObj.value(QStringLiteral("list")).toArray();

    int idx = -1;
    for (int i = 0; i < list.count(); ++i) {
        if (list[i].toObject().value(QStringLiteral("id")).toString().trimmed() == aid) {
            idx = i;
            break;
        }
    }
    if (idx < 0)
        return QJsonObject();

    QJsonObject agentEntry = list[idx].toObject();

    QSet<QString> seen;
    QStringList sorted;
    for (const QString &s : enabledSkillNames) {
        const QString t = s.trimmed();
        if (t.isEmpty() || seen.contains(t))
            continue;
        seen.insert(t);
        sorted.append(t);
    }
    std::sort(sorted.begin(), sorted.end());

    QJsonArray skillsArr;
    for (const QString &s : sorted)
        skillsArr.append(s);

    agentEntry[QStringLiteral("skills")] = skillsArr;
    list[idx] = agentEntry;
    agentsObj[QStringLiteral("list")] = list;
    result[QStringLiteral("agents")] = agentsObj;

    qDebug() << "[SkillSave] allowlist agentId=" << aid << "count=" << skillsArr.size();
    return result;
}

void WsTools::setLocalToolEnabled(const QString &toolId, const bool enabled)
{
    const QString tid = toolId.trimmed();
    if (tid.isEmpty())
        return;
    for (int i = 0; i < m_toolList.count(); ++i) {
        QVariantMap e = m_toolList[i].toMap();
        if (e.value(QStringLiteral("toolId")).toString().trimmed() != tid)
            continue;
        e[QStringLiteral("enabled")] = enabled;
        m_toolList[i] = e;
        break;
    }
}

QJsonObject WsTools::buildFullConfigWithBatchToolPolicy(const QJsonObject &fullConfig,
                                                        const QString &agentId,
                                                        const QStringList &enabledToolIds) const
{
    const QString aid = agentId.trimmed();
    if (aid.isEmpty())
        return QJsonObject();

    QSet<QString> enabledSet;
    for (const QString &s : enabledToolIds)
        enabledSet.insert(s.trimmed());

    QStringList deny;
    for (const QVariant &tv : m_toolList) {
        const QString tid = tv.toMap().value(QStringLiteral("toolId")).toString().trimmed();
        if (!tid.isEmpty() && !enabledSet.contains(tid))
            deny.append(tid);
    }

    qDebug() << "[ToolSave] deny list =" << deny;

    QJsonObject result = fullConfig;

    QJsonObject agentsObj = result.value(QStringLiteral("agents")).toObject();
    QJsonArray list = agentsObj.value(QStringLiteral("list")).toArray();

    int idx = -1;
    for (int i = 0; i < list.count(); ++i) {
        if (list[i].toObject().value(QStringLiteral("id")).toString().trimmed() == aid) {
            idx = i;
            break;
        }
    }

    QJsonObject agentEntry;
    if (idx >= 0) {
        agentEntry = list[idx].toObject();
    } else {
        agentEntry[QStringLiteral("id")] = aid;
        qDebug() << "[ToolSave] agent not in config list, creating new entry";
    }

    QJsonObject existingTools = agentEntry.value(QStringLiteral("tools")).toObject();
    existingTools[QStringLiteral("profile")] = QStringLiteral("full");
    existingTools[QStringLiteral("deny")] = toJsonArray(deny);
    agentEntry[QStringLiteral("tools")] = existingTools;

    if (idx >= 0)
        list[idx] = agentEntry;
    else
        list.append(agentEntry);

    agentsObj[QStringLiteral("list")] = list;
    result[QStringLiteral("agents")] = agentsObj;

    QJsonObject globalTools = result.value(QStringLiteral("tools")).toObject();
    globalTools[QStringLiteral("profile")] = QStringLiteral("full");
    result[QStringLiteral("tools")] = globalTools;

    return result;
}

void WsTools::batchSetLocalToolEnabled(const QStringList &enabledToolIds)
{
    QSet<QString> enabledSet;
    for (const QString &s : enabledToolIds)
        enabledSet.insert(s.trimmed());

    for (int i = 0; i < m_toolList.count(); ++i) {
        QVariantMap e = m_toolList[i].toMap();
        const QString tid = e.value(QStringLiteral("toolId")).toString().trimmed();
        if (tid.isEmpty())
            continue;
        e[QStringLiteral("enabled")] = enabledSet.contains(tid);
        m_toolList[i] = e;
    }
}
