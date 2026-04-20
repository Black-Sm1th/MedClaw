/**
 * @file ws_tools.h
 * @brief Gateway tools.catalog 解析与 Agent 工具策略（deny / allow）展示、config.patch 片段生成
 */
#ifndef WS_TOOLS_H
#define WS_TOOLS_H

#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>

class WsTools
{
public:
    WsTools() = default;

    QJsonObject buildToolsCatalogParams(const QString &agentId,
                                        bool includePlugins = true) const;

    /// 解析 tools.catalog 成功响应，展平为 toolList
    void parseToolsCatalogResponse(const QJsonObject &payload);

    QVariantList toolList() const { return m_toolList; }
    QString catalogAgentId() const { return m_catalogAgentId; }

    /**
     * @brief 根据 config 中 agents.list[].tools 刷新各条目的 enabled
     */
    void applyToolPolicyFromConfig(const QJsonObject &config, const QString &agentId);

    /**
     * @brief 生成 config.patch merge 片段（agents.list 单条合并）
     */
    QJsonObject buildToolToggleMergePatch(const QJsonObject &fullConfig,
                                          const QString &agentId,
                                          const QString &toolId,
                                          bool enable) const;

    /**
     * @brief 在 fullConfig 上修改指定 agent 的 skills 白名单，返回完整 config
     *
     * 用于 config.set 全量写入（与工具批量保存一致）。语义与 OpenClaw Web UI 一致：
     * 无 skills 键表示未限制；显式空数组表示全部关闭。
     */
    QJsonObject buildFullConfigWithSkillToggle(const QJsonObject &fullConfig,
                                               const QString &agentId,
                                               const QStringList &allSkillNames,
                                               const QString &skillName,
                                               bool enabled) const;

    /**
     * @brief 将指定 agent 的 skills 设为显式白名单（完整 config，用于新建 agent 后 config.set）
     */
    QJsonObject buildFullConfigWithAgentSkillsAllowlist(const QJsonObject &fullConfig,
                                                        const QString &agentId,
                                                        const QStringList &enabledSkillNames) const;

    void setLocalToolEnabled(const QString &toolId, bool enabled);

    /**
     * @brief 在 fullConfig 上修改指定 agent 的 tools.deny，返回修改后的完整 config
     *
     * 用于 config.set 全量写入（与 Web UI 行为一致，不触发网关重启）。
     */
    QJsonObject buildFullConfigWithBatchToolPolicy(const QJsonObject &fullConfig,
                                                    const QString &agentId,
                                                    const QStringList &enabledToolIds) const;

    void batchSetLocalToolEnabled(const QStringList &enabledToolIds);

private:
    static QStringList jsonStringList(const QJsonArray &arr);
    static QJsonArray toJsonArray(const QStringList &list);
    static QJsonObject toolsObjectForAgent(const QJsonObject &config, const QString &agentId);

    QVariantList m_toolList;
    QString m_catalogAgentId;
};

#endif // WS_TOOLS_H
