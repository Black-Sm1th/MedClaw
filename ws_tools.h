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
