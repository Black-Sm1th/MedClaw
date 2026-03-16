/**
 * @file ws_skill.h
 * @brief WebSocket 技能管理类
 *
 * 负责 OpenClaw 技能（Skills）的查询与配置：
 *   ① 发送 skills.status RPC 获取所有可用技能
 *   ② 解析响应，缓存技能列表供 QML 绑定
 *   ③ 发送 skills.update RPC 启用/禁用指定技能
 *
 * 技能数据字段（来自 skills.status 响应）：
 *   - name          : 技能显示名称（如 "GitHub"、"天气查询"）
 *   - description   : 技能描述
 *   - skillKey      : 技能唯一标识（用于 skills.update）
 *   - source        : 来源（openclaw-bundled / user / community）
 *   - bundled       : 是否为内置技能
 *   - homepage      : 官方主页链接
 *   - always        : 是否始终启用
 *   - disabled      : 是否被禁用
 *   - eligible      : 当前环境是否满足需求
 *   - filePath      : SKILL.md 文件路径
 */
#ifndef WS_SKILL_H
#define WS_SKILL_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>
#include <QVariantMap>

class WsSkill
{
public:
    WsSkill();

    /// 获取缓存的技能列表（每项为 QVariantMap）
    QVariantList skillList() const;

    /// 技能总数
    int skillCount() const;

    /**
     * @brief 解析 skills.status RPC 响应
     * @param payload 响应 payload 对象
     * @return 解析到的技能数量
     *
     * payload 结构：
     *   {
     *     workspaceDir: "...",
     *     managedSkillsDir: "...",
     *     skills: [ { name, description, skillKey, disabled, ... }, ... ]
     *   }
     */
    int parseSkillsStatusResponse(const QJsonObject &payload);

    /**
     * @brief 解析 skills.update RPC 响应
     * @param payload 响应 payload
     * @return 被操作的 skillKey（空表示解析失败）
     *
     * 成功后更新本地缓存中对应技能的 disabled 状态
     */
    QString parseSkillUpdateResponse(const QJsonObject &payload);

    /// 构建 skills.status 请求参数（空对象）
    QJsonObject buildSkillsStatusParams() const;

    /// 构建 skills.update 请求参数
    QJsonObject buildSkillUpdateParams(const QString &skillKey,
                                        bool enabled) const;

private:
    QVariantList m_skills;          ///< 缓存的技能列表
    QString      m_workspaceDir;    ///< 工作空间目录
    QString      m_managedSkillsDir;///< 托管技能目录
};

#endif // WS_SKILL_H
