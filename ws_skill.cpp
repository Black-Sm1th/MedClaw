/**
 * @file ws_skill.cpp
 * @brief WebSocket 技能管理类 —— 实现
 */
#include "ws_skill.h"
#include <QJsonDocument>
#include <QDebug>

WsSkill::WsSkill() {}

QVariantList WsSkill::skillList() const { return m_skills; }
int WsSkill::skillCount() const { return m_skills.count(); }

// ═══════════════════════════════════════════════════════════════════════
//  解析 skills.status 响应
// ═══════════════════════════════════════════════════════════════════════

int WsSkill::parseSkillsStatusResponse(const QJsonObject &payload)
{
    m_skills.clear();
    m_workspaceDir    = payload.value(QStringLiteral("workspaceDir")).toString();
    m_managedSkillsDir = payload.value(QStringLiteral("managedSkillsDir")).toString();

    const QJsonArray arr = payload.value(QStringLiteral("skills")).toArray();

    for (const QJsonValue &v : arr) {
        const QJsonObject s = v.toObject();

        const QString skillKey = s.value(QStringLiteral("skillKey")).toString(
            s.value(QStringLiteral("name")).toString());
        if (skillKey.isEmpty()) continue;

        const bool disabled = s.value(QStringLiteral("disabled")).toBool(false);
        const bool always   = s.value(QStringLiteral("always")).toBool(false);

        QVariantMap entry;
        entry[QStringLiteral("name")]        = s.value(QStringLiteral("name")).toString();
        entry[QStringLiteral("description")] = s.value(QStringLiteral("description")).toString();
        entry[QStringLiteral("skillKey")]    = skillKey;
        entry[QStringLiteral("source")]      = s.value(QStringLiteral("source")).toString();
        entry[QStringLiteral("bundled")]     = s.value(QStringLiteral("bundled")).toBool(false);
        entry[QStringLiteral("homepage")]    = s.value(QStringLiteral("homepage")).toString();
        entry[QStringLiteral("always")]      = always;
        entry[QStringLiteral("disabled")]    = disabled;
        entry[QStringLiteral("enabled")]     = !disabled;
        entry[QStringLiteral("eligible")]    = s.value(QStringLiteral("eligible")).toBool(true);
        entry[QStringLiteral("filePath")]    = s.value(QStringLiteral("filePath")).toString();

        m_skills.append(entry);
    }

    qDebug() << "[WsSkill] loaded" << m_skills.count() << "skills"
             << "workspace:" << m_workspaceDir;
    return m_skills.count();
}

// ═══════════════════════════════════════════════════════════════════════
//  解析 skills.update 响应并更新本地缓存
// ═══════════════════════════════════════════════════════════════════════

QString WsSkill::parseSkillUpdateResponse(const QJsonObject &payload)
{
    if (!payload.value(QStringLiteral("ok")).toBool(false))
        return QString();

    const QString skillKey =
        payload.value(QStringLiteral("skillKey")).toString();
    if (skillKey.isEmpty()) return QString();

    const QJsonObject config =
        payload.value(QStringLiteral("config")).toObject();
    // config.enabled 可能是 true/false；如果 config 里没有 enabled 字段，
    // 也可能有 disabled 字段（取反即可）
    bool nowEnabled = true;
    if (config.contains(QStringLiteral("enabled")))
        nowEnabled = config.value(QStringLiteral("enabled")).toBool(true);
    else if (config.contains(QStringLiteral("disabled")))
        nowEnabled = !config.value(QStringLiteral("disabled")).toBool(false);

    // 更新本地缓存
    for (int i = 0; i < m_skills.count(); ++i) {
        QVariantMap entry = m_skills[i].toMap();
        if (entry.value(QStringLiteral("skillKey")).toString() == skillKey) {
            entry[QStringLiteral("enabled")]  = nowEnabled;
            entry[QStringLiteral("disabled")] = !nowEnabled;
            m_skills[i] = entry;
            break;
        }
    }

    qDebug() << "[WsSkill] updated" << skillKey << "enabled:" << nowEnabled;
    return skillKey;
}

// ═══════════════════════════════════════════════════════════════════════
//  构建 RPC 请求参数
// ═══════════════════════════════════════════════════════════════════════

QJsonObject WsSkill::buildSkillsStatusParams() const
{
    return QJsonObject(); // skills.status 无需参数
}

QJsonObject WsSkill::buildSkillUpdateParams(const QString &skillKey,
                                             bool enabled) const
{
    QJsonObject params;
    params[QStringLiteral("skillKey")] = skillKey;
    params[QStringLiteral("enabled")]  = enabled;
    return params;
}
