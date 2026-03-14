/**
 * @file ws_skill.h
 * @brief WebSocket 技能管理类（技能类 / 子类之一）【预留】
 *
 * 预留类结构，用于后续扩展 WebSocket 关联的业务技能逻辑。
 *
 * 可能的应用场景：
 *   - 自定义工具调用（Tool Call）的注册与执行
 *   - Agent 技能/插件管理（安装、启用、禁用、配置）
 *   - 外部服务集成（如搜索引擎、数据库查询、文件操作等）
 *   - 技能执行结果的解析与回传
 *
 * 预期 RPC 方法（待确认）：
 *   - skills.list        获取可用技能列表
 *   - skill.invoke       调用指定技能
 *   - skill.configure    配置技能参数
 *   - tool.result        回传工具执行结果
 *
 * 设计说明：
 *   本类为纯逻辑类，不继承 QObject。
 *   由 WebSocket 主类（GatewayClient）持有。
 *   当前无具体实现，仅保留类结构和注释。
 */
#ifndef WS_SKILL_H
#define WS_SKILL_H

#include <QString>
#include <QJsonObject>
#include <QVariantList>

class WsSkill
{
public:
    WsSkill();

    // ═══════════════════════════════════════════════════════════════
    //  技能列表管理（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】获取当前可用的技能列表
    // QVariantList availableSkills() const;

    /// 【预留】解析 skills.list 响应
    // int parseSkillsResponse(const QJsonObject &payload);

    // ═══════════════════════════════════════════════════════════════
    //  技能调用（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】构建技能调用请求参数
    // QJsonObject buildInvokeParams(const QString &skillId,
    //                               const QJsonObject &args) const;

    /// 【预留】解析技能调用结果
    // QVariantMap parseInvokeResult(const QJsonObject &payload) const;

    // ═══════════════════════════════════════════════════════════════
    //  工具结果回传（预留）
    // ═══════════════════════════════════════════════════════════════

    /// 【预留】构建 tool.result 回传参数
    // QJsonObject buildToolResultParams(const QString &toolCallId,
    //                                   const QJsonObject &result) const;
};

#endif // WS_SKILL_H
