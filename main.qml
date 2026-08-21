import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.3
import QtGraphicalEffects 1.0
import "./components"
import "data/TemplatePrompts.js" as TemplatePrompts
ApplicationWindow {
    id: window
    // Use logical (DIP) screen dimensions so the initial window fits on
    // high-DPI displays instead of opening larger than the work area.
    readonly property real availableScreenWidth: Screen.desktopAvailableWidth > 0
                                                  ? Screen.desktopAvailableWidth : 1440
    readonly property real availableScreenHeight: Screen.desktopAvailableHeight > 0
                                                   ? Screen.desktopAvailableHeight : 800
    readonly property bool compactLayout: width < 1100
    readonly property bool sidebarExpanded: !sidebarCollapsed && !compactLayout
    readonly property int windowCornerRadius: 12
    minimumWidth: Math.min(1024, Math.max(560, availableScreenWidth - 96), availableScreenWidth)
    minimumHeight: Math.min(640, Math.max(420, availableScreenHeight - 120), availableScreenHeight)
    width: Math.min(availableScreenWidth,
                    Math.max(minimumWidth,
                             initialWindowWidth > 0 ? initialWindowWidth
                                                    : Math.min(1440, Math.max(640, availableScreenWidth - 48))))
    height: Math.min(availableScreenHeight,
                     Math.max(minimumHeight,
                              initialWindowHeight > 0 ? initialWindowHeight
                                                     : Math.min(800, Math.max(480, availableScreenHeight - 80))))
    visible: true
    title: qsTr("Aether study")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    color: "transparent"
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    property int leftSelectedIndex: 0
    property bool sidebarCollapsed: false
    property string knowledgeBaseReadyUserId: ""
    property bool userSessionInitializing: authController.loggedIn
    readonly property bool userSessionReady: authController.loggedIn
                                             && String(authController.userId || "").length > 0
                                             && knowledgeBaseReadyUserId === String(authController.userId || "")
                                             && !userSessionInitializing
    readonly property bool configurationUpdateActive: userSessionReady
                                                       && (wsClient.connectionState !== 3
                                                           || !wsClient.knowledgeBaseDataDirReady)
    /// 非空表示「编辑」已有定时任务；空为新建
    property string editingCronJobId: ""
    property string editingCronPayloadKind: "agentTurn"
    property string editingCronScheduleKind: ""
    property string editingCronScheduleExpr: ""
    property string editingCronScheduleTz: ""
    property string pendingDeleteCronJobId: ""
    property string pendingDeleteCronJobName: ""
    property int selectedCronTemplateCategory: 0
    property string pendingCronTemplateExpr: ""
    property string pendingCronTemplateTz: "Asia/Shanghai"
    property string pendingCronTemplateTrigger: ""
    property var cronTemplateCategories: [
        { name: "医疗科研", tasks: [
            { title: "每日文献追踪", expr: "0 8 * * *", prompt: "检索 PubMed上[研究方向]近3天新文献，按IF排序TOP10，标注与课题组方向关联度，摘要中译，附带DOI" },
            { title: "临床试验入组日报", expr: "0 9 * * *", prompt: "汇总昨日各中心筛选、入组、随机、完成、脱落数据，对比入组计划曲线，落后 >20%标记[加速]，SAE单独列出" },
            { title: "科研基金申报预警", expr: "0 9 * * 1", prompt: "搜索未来 90天截止的科研基金(国自然/省自然/科技部重点研发)，标注匹配度、金额、截止日，≤30天标记[赶]，≤7天标记[急]" },
            { title: "伦理审查到期提醒", expr: "0 10 1 * *", prompt: "查询所有在研项目伦理批件状态：初始审查有效期、年度跟踪审查截止、方案修正案审批、SAE伦理报告，到期≤30天标记[续审]" },
            { title: "学术会议与投稿日历", expr: "0 9 * * 1", prompt: "扫描未来 90天相关领域学术会议截稿日和特刊征稿：会议名称/地点/截稿日期/影响因子/注册截止、期刊特刊征稿主题/截止日、课题组适配度评分，≤14天标记[紧迫]" },
            { title: "传染病监测日报", expr: "0 7 * * *", prompt: "检索中国 CDC、WHO、ECDC过去24h传染病报告更新：法定传染病发病数/发病率、聚集性疫情、新发传染病预警，标注超过基线2倍SD的异常信号" },
            { title: "疫苗接种率周报", expr: "0 9 * * 1", prompt: "统计上周各疫苗接种率(国家免疫规划+重点非免疫规划)：分年龄组/分区域接种覆盖率、未种儿童清单、库存预警(<最低库存量)，覆盖率<90%标记[风险]" },
            { title: "突发公卫事件扫描", expr: "0 */4 * * *", prompt: "扫描 WHO Disease Outbreak News、中国CDC突发公卫事件报告、ProMED-mail、社交媒体异常聚集信号，按PHEIC标准评估严重性，新发信号推送[关注等级]" },
            { title: "慢病管理指标月报", expr: "0 9 3 * *", prompt: "统计上月慢病管理核心指标：规范管理率、血压/血糖控制率、随访完成率、并发症筛查率，对比国家基本公卫考核目标，低于目标指标标记[整改]" },
            { title: "公卫应急物资核查", expr: "0 9 * * 1", prompt: "从物资管理系统核查应急物资库存：品目/数量/有效期/存储条件合规性(均基于数据库记录)，低于储备标准标记[需补充]，近效期≤3月标记[轮换提醒]" },
            { title: "处方前置审核异常日报", expr: "0 9 * * *", prompt: "汇总昨日处方前置审核分类统计(禁忌症/超剂量/相互作用/重复用药/溶媒不当)、拦截率趋势、高频拦截品种TOP10、医生驳回后未修改处方清单[需人工跟进]" },
            { title: "抗菌药物使用强度周报", expr: "0 9 * * 1", prompt: "统计上周全院及各科室抗菌药物使用强度(DDDs)、使用率(%)、微生物送检率(%)、特殊使用级审批情况、碳青霉烯专项监控，AUD超目标值20%标记[重点监控]" },
            { title: "药品库存与效期管理", expr: "0 7 * * *", prompt: "扫描 HIS药品库存记录：近效期≤6月清单(药品/批号/数量/库位)、昨日消耗量异常(超日均2倍)品种、高危/麻精药品库存核对(账物是否相符)，均为数据库查询无需IoT" },
            { title: "DDI高危处方筛查", expr: "0 10 * * *", prompt: "对昨日全量住院医嘱运行 DDI筛查：X级(禁止合用)和D级(考虑调整)的DDI清单、涉及药品/科室/潜在后果、替代方案建议，X级DDI标记[药师须立即介入]" },
            { title: "集采药品达标监控", expr: "0 9 1 * *", prompt: "统计上月各批次集采中选品种约定采购量完成进度：品种/中选企业/约定量/完成量/完成率(%)，完成率<时间进度80%标记[预警]，分析原因并给处方引导建议" }
        ] },
        { name: "政务助手", tasks: [
            { title: "每日舆情早报", expr: "0 7 * * *", prompt: "搜索过去 24h关于[地市/部门名称]新闻和社交媒体讨论：正/中/负面新闻各TOP5(标题/来源/转载量)、敏感舆情事件(热度+情感倾向)、负面事件附回应口径建议" },
            { title: "公文流转超期预警", expr: "0 9 * * *", prompt: "检查 OA系统中在办公文状态：超期1-3天(提醒)/3-7天(催办)/>7天(通报)，按紧急程度和部门分组列出文号/标题/当前环节/停留天数/办理人" },
            { title: "12345热线工单日报", expr: "0 8 * * *", prompt: "统计昨日 12345热线和市长信箱数据：受理总量/按时办结率/满意率/热点诉求TOP5/办结率最低部门TOP5/超期未办结工单清单" },
            { title: "重点工作督办跟踪", expr: "0 10 * * 1", prompt: "对年度重点工作任务清单逐一核查：任务/牵头单位/年度目标/完成率(%)/时间进度对比(正常/滞后/严重滞后)，按完成率排序标注红黄绿灯" },
            { title: "网站错敏词巡检", expr: "0 3 * * *", prompt: "对政府门户网站和各部门子站全站巡检：错别字、领导人姓名职务表述不规范、涉政敏感词、失效链接、隐私信息泄露，生成问题清单和修改建议" }
        ] },
        { name: "情报研究", tasks: [
            { title: "全球管线动态日报", expr: "0 7 * * *", prompt: "搜索过去 24h全球药物研发重大新闻：III期数据读出/FDA审批/突破性疗法认定/NDA提交/License-in-out，按影响等级排序" },
            { title: "竞品临床试验里程碑", expr: "0 8 * * 1", prompt: "更新竞品品种试验里程碑：品种/申办方/靶点/适应症/当前阶段/预期下一里程碑日期，≤30天标记[即将]，≤7天标记[临近]" },
            { title: "PDUFA审批日期监控", expr: "0 8 * * *", prompt: "查询未来 90天主要监管机构审批决定日期：FDA PDUFA/AdCom、EMA CHMP opinion、NMPA CDE审批，附关键临床数据摘要和分析师预期" },
            { title: "专利到期预警", expr: "0 10 1 * *", prompt: "更新重点品种全球专利到期日历：化合物专利/制剂/用途专利到期日(各国)、专利挑战、儿科/孤儿药exclusivity到期，≤24月标记[关注窗口]" },
            { title: "药物安全信号检测", expr: "0 9 * * 1", prompt: "对目标品种进行安全性数据库信号检测：PRR/ROR/EBGM算法、新安全信号(IC025>0)、信号强度趋势、同类药物class effect对比" }
        ] },
        { name: "设备管理", tasks: [
            { title: "每日设备巡检派单", expr: "0 7 * * *", prompt: "从设备管理系统中提取今日需巡检设备清单(按科室分组)，生成巡检工单：设备编码/名称/科室/巡检项目/上次巡检日期/指派工程师，急救类优先标注" },
            { title: "预防性维护到期预警", expr: "0 8 * * *", prompt: "扫描所有设备 PM计划，筛选未来7天到期的PM任务：≤3天标记[紧急]，≤7天标记[预警]，列出设备名称/科室/PM内容/计划日期/负责工程师" },
            { title: "设备维修工单闭环追踪", expr: "0 8,16 * * *", prompt: "查询设备管理系统的报修工单状态：待派单/维修中/待验收/已完成/超时未关闭，按工程师统计完成数和平均响应时间，超48h未关闭工单标记[升级]，生成周度故障类型分析" },
            { title: "计量校准到期提醒", expr: "0 8 * * 1", prompt: "提取所有计量设备校准证书有效期，筛选未来30天到期设备：设备名称/型号/序列号/上次校准日期/到期日/是否强检，到期≤14天标记[紧急停用风险]" },
            { title: "医疗器械不良事件", expr: "0 10 * * 1", prompt: "汇总上周所有科室上报的医疗器械不良事件：事件类型/设备型号/严重程度分级/根因分析完成情况/是否上报MDR系统，严重事件标记[立即关注]" }
        ] },
        { name: "投行助手", tasks: [
            { title: "盘前市场简报", expr: "0 8 * * 1-5", prompt: "生成今日盘前简报：隔夜美股涨跌/A50期货/中概股表现、人民币汇率/美债收益率/原油黄金走势、今日重点财经事件、盘前异动个股和大宗交易提示" },
            { title: "重点持仓异动监控", expr: "*/15 9-15 * * 1-5", prompt: "扫描持仓占比 >3%股票：涨跌幅超±3%/成交量超20日均量2倍/大单净流入流出/盘口异动/突发新闻，异动项推送即时警报" },
            { title: "宏观数据日历提醒", expr: "0 8 * * 1", prompt: "生成本周宏观事件日历：中国(CPI/PPI/PMI/社融)、美国(非农/CPI/FOMC)、欧洲(ECB/PMI)，标注市场预期值/前值/对A股利率汇率潜在影响方向" },
            { title: "公司公告智能解读", expr: "0 7,18 * * *", prompt: "扫描自选股公告(年报/季报/重大合同/资产重组/股权激励/增减持/分红/业绩预告)：提取关键数据变化、与一致预期偏差、业绩预告大幅偏离(>20%)标记[重点关注]" },
            { title: "舆情/ESG风险扫描", expr: "0 7,13,19 * * *", prompt: "搜索持仓标的负面舆情：产品安全/环境处罚/劳动纠纷/监管调查/财务造假嫌疑/高管负面，按事件严重程度1-5分评级，4分及以上立即推送预警" }
        ] }
    ]

    function openCronTemplate(template) {
        window.editingCronJobId = ""
        window.editingCronPayloadKind = "agentTurn"
        window.editingCronScheduleKind = "cron"
        window.editingCronScheduleExpr = template.expr || ""
        window.editingCronScheduleTz = "Asia/Shanghai"
        window.pendingCronTemplateExpr = template.expr || ""
        window.pendingCronTemplateTz = "Asia/Shanghai"
        window.pendingCronTemplateTrigger = window.cronTriggerDisplay(template.expr || "")
        newTaskTitleInput.text = template.title || ""
        newTaskPromptInput.text = template.prompt || ""
        newTaskIntervalInput.text = ""
        var parts = String(template.expr || "").split(" ")
        var minute = parseInt(parts[0]); var hour = parseInt(parts[1])
        var standardDaily = parts.length === 5 && /^\d+$/.test(parts[0]) && /^\d+$/.test(parts[1])
                            && parts[2] === "*" && parts[3] === "*" && parts[4] === "*"
        var standardWeekly = parts.length === 5 && /^\d+$/.test(parts[0]) && /^\d+$/.test(parts[1])
                             && parts[2] === "*" && parts[3] === "*" && /^[0-6]$/.test(parts[4])
        var standardMonthly = parts.length === 5 && /^\d+$/.test(parts[0]) && /^\d+$/.test(parts[1])
                              && /^\d+$/.test(parts[2]) && parts[3] === "*" && parts[4] === "*"
        if (standardDaily || standardWeekly || standardMonthly) {
            newTaskRepeatSelect.currentIndex = standardDaily ? 1 : (standardWeekly ? 2 : 4)
            if (!isNaN(hour)) newTaskTimePicker.selectedHour = hour
            if (!isNaN(minute)) newTaskTimePicker.selectedMinute = minute

            var now = new Date()
            var selectedDate = new Date(now.getFullYear(), now.getMonth(), now.getDate())
            if (standardMonthly) {
                var targetDay = parseInt(parts[2])
                selectedDate = new Date(now.getFullYear(), now.getMonth(), targetDay,
                                        hour, minute, 0, 0)
                if (selectedDate.getTime() <= now.getTime())
                    selectedDate = new Date(now.getFullYear(), now.getMonth() + 1, targetDay,
                                            hour, minute, 0, 0)
            } else if (standardWeekly) {
                var targetDow = parseInt(parts[4])
                selectedDate.setDate(selectedDate.getDate() + (targetDow - selectedDate.getDay() + 7) % 7)
                var weeklyTrigger = new Date(selectedDate.getFullYear(), selectedDate.getMonth(),
                                              selectedDate.getDate(), hour, minute, 0, 0)
                if (weeklyTrigger.getTime() <= now.getTime())
                    selectedDate.setDate(selectedDate.getDate() + 7)
            } else {
                var dailyTrigger = new Date(selectedDate.getFullYear(), selectedDate.getMonth(),
                                             selectedDate.getDate(), hour, minute, 0, 0)
                if (dailyTrigger.getTime() <= now.getTime())
                    selectedDate.setDate(selectedDate.getDate() + 1)
            }
            newTaskDatePicker.selectedYear = selectedDate.getFullYear()
            newTaskDatePicker.selectedMonth = selectedDate.getMonth() + 1
            newTaskDatePicker.selectedDay = selectedDate.getDate()
        } else if (template.expr === "0 * * * *") {
            newTaskRepeatSelect.currentIndex = 3
        } else {
            newTaskRepeatSelect.currentIndex = 4
        }
        newTaskDialog.open()
    }

    function cronTriggerDisplay(expr) {
        var value = String(expr || "")
        if (value === "0 */4 * * *") return "每 4 小时"
        if (value === "*/15 9-15 * * 1-5") return "交易时段 每 15 分钟"
        if (value === "0 8 * * 1-5") return "工作日 08:00"
        if (value === "0 8,16 * * *") return "每天 08:00、16:00"
        if (value === "0 7,18 * * *") return "每天 07:00、18:00"
        if (value === "0 7,13,19 * * *") return "每天 07:00、13:00、19:00"
        var fields = value.split(" ")
        if (fields.length !== 5) return value
        var minute = fields[0], hour = fields[1], dom = fields[2], dow = fields[4]
        if (/^\d+$/.test(minute) && /^\d+$/.test(hour)) {
            var time = (parseInt(hour) < 10 ? "0" : "") + parseInt(hour) + ":"
                     + (parseInt(minute) < 10 ? "0" : "") + parseInt(minute)
            if (dom === "1" && fields[3] === "*") return "每月 1 号 " + time
            if (dom === "3" && fields[3] === "*") return "每月 3 号 " + time
            if (dow === "1") return "每周一 " + time
            if (dow === "*") return "每天 " + time
        }
        return value
    }
    property string pendingDeleteMcpName: ""
    /// 右键删除任务会话流程暂存（上下文菜单 → 确认弹窗）
    property string pendingDeleteTaskSessionId: ""
    property string pendingDeleteTaskSessionName: ""
    property string pendingDeleteAgentId: ""
    property string pendingDeleteAgentName: ""
    property int agentManageTabIndex: 0
    property bool agentEditorIsEdit: false
    property string agentEditorAgentId: ""
    property var kbSources: []
    property var kbCollections: []
    property string kbSelectedCollection: ""
    property string chatKnowledgeCollection: ""
    property string kbSearchText: ""
    property bool kbLoading: false
    property string kbBusyText: ""
    property var kbUploadQueue: []
    property int kbUploadIndex: 0
    property string kbUploadCollection: ""
    property int kbUploadSuccessCount: 0
    property var kbUploadFailures: []
    property var kbMetadata: ({ "version": 2, "collections": [], "selectedCollection": "", "filesByCollection": {} })
    property string kbMetadataUser: ""
    property var kbSelectedKeys: []
    property var kbDeleteQueue: []
    property var kbDeleteKeys: []
    property int kbListRequestGeneration: 0
    property var uploadedDocxTemplates: []
    property string uploadedDocxTemplatesUserId: ""
    /// 编辑 MCP 弹窗预填（由列表 delegate 写入）
    property var mcpEditEntry: null

    function reloadUploadedDocxTemplates() {
        var userId = String(authController.userId || "")
        if (!authController.loggedIn || !userId) {
            uploadedDocxTemplates = []
            uploadedDocxTemplatesUserId = ""
            return
        }
        uploadedDocxTemplates = $MainViewController.loadUserTemplates(userId) || []
        uploadedDocxTemplatesUserId = userId
    }

    function stripKnowledgePolicyText(value) {
        var text = String(value || "")
        var tags = ["knowledge-base-policy", "workspace-policy", "template-parameters"]
        for (var i = 0; i < tags.length; i++) {
            var begin = "<" + tags[i] + ">"
            var end = "</" + tags[i] + ">"
            var beginPos = text.indexOf(begin)
            while (beginPos >= 0) {
                var endPos = text.indexOf(end, beginPos + begin.length)
                if (endPos < 0) {
                    text = text.substring(0, beginPos)
                    break
                }
                text = text.substring(0, beginPos)
                        + text.substring(endPos + end.length)
                beginPos = text.indexOf(begin)
            }
        }
        return text.trim()
    }
    property string pendingExpertPrompt: ""
    property double pendingExpertInstallStartedAt: 0

    /// 若整段里出现第二对「()」，只保留到第一对括号结束（含前面文字与第一对括号）
    function trimToFirstParenPairOnly(s) {
        if (!s || s.length < 2)
            return s || ""
        var first = s.indexOf("(")
        if (first < 0)
            return s
        var depth = 0
        var i
        for (i = first; i < s.length; i++) {
            var c = s.charAt(i)
            if (c === "(")
                depth++
            else if (c === ")") {
                depth--
                if (depth === 0)
                    break
            }
        }
        if (i >= s.length)
            return s
        if (s.indexOf("(", i + 1) < 0)
            return s
        return s.substring(0, i + 1).trim()
    }

    /// 任务记录列表中 agent 的展示标题（与左侧列表 Label 渲染逻辑保持一致）
    function agentDisplayTitle(agent) {
        if (!agent) return ""
        var nm = agent.name || ""
        if (nm.indexOf("定时-") === 0) {
            var body = nm.substring(3)
            var lastDash = body.lastIndexOf("-")
            if (lastDash > 0 && /^\d+$/.test(body.substring(lastDash + 1)))
                return body.substring(0, lastDash)
            return body
        }
        var t = window.stripKnowledgePolicyText(agent.activeSessionTitle || "")
        if (t.length === 0) {
            if (nm.match(/^task-\d+$/))
                return qsTr("新对话")
            return nm || agent.id || ""
        }
        return t
    }

    function agentIdentityName(agent) {
        if (!agent) return ""
        var ident = agent.identity || {}
        return ident.name || agent.name || agent.id || ""
    }

    function agentIdentitySummary(agent) {
        if (!agent)
            return ""
        var description = String(agent.description || "").trim()
        if (description.length > 0)
            return description

        var ident = agent.identity || {}
        var parts = []
        if (ident.name) parts.push("Name: " + ident.name)
        if (ident.emoji) parts.push("Emoji: " + ident.emoji)
        if (ident.creature) parts.push("Creature: " + ident.creature)
        if (ident.theme) parts.push("Theme: " + ident.theme)
        if (ident.vibe) parts.push("Vibe: " + ident.vibe)
        if (parts.length > 0)
            return parts.join(" · ")
        return agent.id || ""
    }

    function isMainAgentId(agentId) {
        return String(agentId || "").trim().toLowerCase() === "main"
    }

    function visibleAgentList() {
        var list = wsClient.agentList || []
        var out = []
        for (var i = 0; i < list.length; i++) {
            var id = list[i].id || ""
            if (!window.isMainAgentId(id))
                out.push(list[i])
        }
        return out
    }

    function findVisibleAgentId(preferredId) {
        var target = String(preferredId || "").trim().toLowerCase()
        if (!target || window.isMainAgentId(target))
            return ""
        var list = window.visibleAgentList()
        for (var i = 0; i < list.length; i++) {
            var id = String(list[i].id || "").trim()
            var name = String(list[i].name || "").trim()
            if (id.toLowerCase() === target || name.toLowerCase() === target)
                return id
        }
        return ""
    }

    function medicalAnalysisTeamAgentIds() {
        var wanted = ["Orchestrator", "writer", "researcher", "analyst"]
        var ids = []
        var missing = []
        for (var i = 0; i < wanted.length; i++) {
            var id = window.findVisibleAgentId(wanted[i])
            if (id.length > 0)
                ids.push(id)
            else
                missing.push(wanted[i])
        }
        if (missing.length > 0) {
            errorToast.text = "医疗分析团队缺少专家：" + missing.join(", ")
            errorToast.visible = true
            errorToastTimer.restart()
            return []
        }
        return ids
    }

    function orderedAgentIds(limit) {
        var list = wsClient.agentList || []
        var ids = []
        var preferred = wsClient.defaultAgentId || "main"
        for (var i = 0; i < list.length; i++) {
            var id0 = list[i].id || ""
            if (id0 === preferred) {
                ids.push(id0)
                break
            }
        }
        for (var j = 0; j < list.length; j++) {
            var id = list[j].id || ""
            if (!id) continue
            var exists = false
            for (var k = 0; k < ids.length; k++) {
                if (ids[k] === id) { exists = true; break }
            }
            if (!exists)
                ids.push(id)
        }
        if (limit > 0 && ids.length > limit)
            ids = ids.slice(0, limit)
        return ids
    }

    function startTaskWithAgents(agentIds) {
        var ids = agentIds || []
        if (ids.length === 0) {
            errorToast.text = "暂无可用专家"
            errorToast.visible = true
            errorToastTimer.restart()
            return
        }
        chatModel.clear()
        leftMidPanel.activeAgentId = ""
        leftMidPanel.activeSessionKey = ""
        wsClient.clearActiveAgentContext()
        newTaskRec.clearDocxTemplateSelection(true)
        newTaskRec.selectedCollaborationAgentIds = ids
        window.leftSelectedIndex = 0
    }

    function summonExpert(agentId, promptText) {
        var id = String(agentId || "").trim()
        if (!id)
            return
        newTaskRec.clearDocxTemplateSelection(true)
        chatKnowledgeCollection = ""
        knowledgePopup.close()
        pendingExpertPrompt = String(promptText || "")
        pendingExpertInstallStartedAt = Date.now()
        wsClient.summonAgent(id)
    }

    function taskSessionDisplayTitle(task) {
        if (!task) return ""
        var t = window.stripKnowledgePolicyText(task.title || "")
        if (t.length === 0)
            t = qsTr("新对话")
        return t
    }

    function agentIdFromSessionKey(sessionKey) {
        var key = String(sessionKey || "")
        var parts = key.split(":")
        if (parts.length >= 2 && parts[0] === "agent")
            return parts[1] || ""
        return ""
    }

    /// FileDialog.fileUrl → 本地路径（与定时任务工作目录选择逻辑一致）
    function localFilePathFromUrl(fileUrl) {
        var path = decodeURIComponent(fileUrl.toString().replace(/^file:\/{2,3}/, ""))
        if (Qt.platform.os === "windows") {
            if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                path = path.substring(1)
            path = path.replace(/\//g, "\\")
        } else if (Qt.platform.os === "linux" || Qt.platform.os === "osx") {
            path = "/" + path
        }
        return path
    }

    function kbShowError(message) {
        kbLoading = false
        kbBusyText = ""
        kbUploadQueue = []
        kbUploadIndex = 0
        kbUploadCollection = ""
        kbUploadSuccessCount = 0
        kbUploadFailures = []
        kbDeleteQueue = []
        kbDeleteKeys = []
        errorToast.text = message || "知识库操作失败"
        errorToast.visible = true
        errorToastTimer.restart()
    }

    function kbShowUnsupportedFileMessage() {
        kbUploadFormatMessage.visible = true
        kbUploadFormatMessageTimer.restart()
    }

    function kbDefaultCollectionId() {
        if (!authController.loggedIn || !authController.userId)
            return ""
        var raw = String(authController.userId).trim()
        var safe = raw.toLowerCase().replace(/[^a-z0-9_]/g, "_")
        safe = safe.replace(/^_+|_+$/g, "").substring(0, 32)
        if (!safe)
            safe = "account"
        var hash = 0
        for (var i = 0; i < raw.length; i++)
            hash = (hash * 131 + raw.charCodeAt(i)) % 4294967291
        return "user_kb_" + safe + "_" + Math.floor(hash).toString(16)
    }

    function kbUserCollection() {
        return kbSelectedCollection
    }

    function kbOwnsCollection(collection) {
        var base = kbDefaultCollectionId()
        var value = String(collection || "")
        return base.length > 0 && (value === base || value.indexOf(base + "_") === 0)
    }

    function kbCollectionName(collection) {
        for (var i = 0; i < kbCollections.length; i++) {
            if (String(kbCollections[i].id || "") === String(collection || ""))
                return String(kbCollections[i].name || qsTr("未命名知识库"))
        }
        return qsTr("请选择知识库")
    }

    function kbReconcileCollectionsFromServer(serverCollections) {
        var metadata = kbMetadata || kbDefaultMetadata()
        var localCollections = metadata.collections || []
        var actualIds = {}
        var serverItems = {}
        for (var i = 0; serverCollections && i < serverCollections.length; i++) {
            var item = serverCollections[i]
            var serverId = typeof item === "string"
                    ? String(item) : String(item.name || "")
            if (kbOwnsCollection(serverId)) {
                actualIds[serverId] = true
                serverItems[serverId] = item
            }
        }

        var collections = []
        var filesByCollection = {}
        var included = {}
        for (var j = 0; j < localCollections.length; j++) {
            var local = localCollections[j]
            var id = String(local.id || "")
            var existsOnServer = actualIds[id] === true
            if (!existsOnServer && local.pending !== true)
                continue
            collections.push({
                "id": id,
                "name": String(local.name || qsTr("未命名知识库")),
                "pending": !existsOnServer
            })
            filesByCollection[id] = kbCollectionFiles(metadata, id)
            included[id] = true
        }

        var ids = Object.keys(actualIds)
        for (var k = 0; k < ids.length; k++) {
            var actualId = ids[k]
            if (included[actualId])
                continue
            var actualItem = serverItems[actualId]
            var displayName = typeof actualItem === "object"
                    ? String(actualItem.description || actualId) : actualId
            collections.push({ "id": actualId, "name": displayName, "pending": false })
            filesByCollection[actualId] = kbCollectionFiles(metadata, actualId)
        }

        var selected = String(metadata.selectedCollection || "")
        var selectedExists = false
        var chatExists = false
        for (var n = 0; n < collections.length; n++) {
            var collectionId = String(collections[n].id || "")
            if (collectionId === selected)
                selectedExists = true
            if (collectionId === chatKnowledgeCollection)
                chatExists = true
        }
        if (!selectedExists)
            selected = collections.length > 0 ? String(collections[0].id || "") : ""
        if (!chatExists)
            chatKnowledgeCollection = ""
        metadata.chatSelectedCollection = chatKnowledgeCollection

        metadata.collections = collections
        metadata.filesByCollection = filesByCollection
        metadata.selectedCollection = selected
        kbSelectedCollection = selected
        kbSaveMetadata(metadata)
        return actualIds[selected] === true
    }

    function kbToggleChatCollection(collection) {
        var collectionId = String(collection || "")
        var nextCollection = chatKnowledgeCollection === collectionId
                ? "" : collectionId
        if (nextCollection)
            newTaskRec.clearDocxTemplateSelection(true)
        chatKnowledgeCollection = nextCollection
        var metadata = kbMetadata || kbDefaultMetadata()
        metadata.chatSelectedCollection = chatKnowledgeCollection
        kbSaveMetadata(metadata)
    }

    function chatHasSelectedExpert() {
        var ids = newTaskRec.selectedCollaborationAgentIds || []
        if (newTaskRec.isNewTaskWelcome)
            return ids.length > 0
        var activeAgentId = String(leftMidPanel.activeAgentId || "")
        var defaultAgentId = String(wsClient.defaultAgentId || "main")
        return activeAgentId.length > 0 && activeAgentId !== defaultAgentId
    }

    function kbToolDetails(result) {
        if (!result) return {}
        if (result.details) return result.details
        if (result.result && result.result.details) return result.result.details
        return {}
    }

    function kbInvoke(tool, args, action, collection, done, acceptInactiveCollection, failed) {
        var base = wsClient.gatewayHttpBaseUrl
        var token = wsClient.gatewayAuthToken
        var requestUser = String(authController.userId || "")
        if (!base || !token) {
            if (typeof failed === "function") failed("知识库服务配置不完整")
            else kbShowError("知识库服务配置不完整")
            return
        }
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            if (requestUser !== String(authController.userId || "")
                    || (!acceptInactiveCollection && collection !== kbUserCollection())) {
                return
            }
            var response = null
            try { response = JSON.parse(xhr.responseText || "{}") } catch (e) {}
            if (xhr.status < 200 || xhr.status >= 300 || !response || response.ok !== true) {
                var message = response && response.error
                        ? (response.error.message || response.error.type) : ""
                message = message || ("知识库请求失败（HTTP " + xhr.status + "）")
                if (typeof failed === "function") failed(message)
                else kbShowError(message)
                return
            }
            var result = response.result || {}
            var details = kbToolDetails(result)
            if (details.error) {
                var detailMessage = String(details.error)
                detailMessage = detailMessage.replace(/^Error:\s*/, "")
                if (typeof failed === "function") failed(detailMessage)
                else kbShowError(detailMessage)
                return
            }
            if (details.errors && details.errors.length > 0
                    && (!details.results || details.results.length === 0)) {
                var firstError = details.errors[0]
                var firstMessage = firstError.error || String(firstError)
                if (typeof failed === "function") failed(firstMessage)
                else kbShowError(firstMessage)
                return
            }
            done(result)
        }
        xhr.open("POST", base + "/tools/invoke")
        xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.setRequestHeader("Content-Type", "application/json")
        var body = { "tool": tool, "args": args || {} }
        if (action)
            body.action = action
        xhr.send(JSON.stringify(body))
    }

    function kbRefreshFiles() {
        var requestGeneration = ++kbListRequestGeneration
        kbSources = []
        kbSelectedKeys = []
        if (kbMetadataUser !== String(authController.userId || ""))
            kbLoadMetadata()
        if (!wsClient.knowledgeBaseDataDirReady) {
            kbLoading = true
            kbBusyText = wsClient.knowledgeBaseDataDirMessage
                    || qsTr("正在切换当前用户的知识库目录...")
            return
        }
        var collection = kbUserCollection()
        kbLoading = true
        kbBusyText = "正在加载知识库..."
        kbInvoke("kb_manage", {}, "list_collections", collection, function(collectionResult) {
            if (requestGeneration !== kbListRequestGeneration
                    || collection !== kbUserCollection()) {
                return
            }
            var collectionDetails = kbToolDetails(collectionResult)
            var selectedExistsOnServer = kbReconcileCollectionsFromServer(
                collectionDetails.collections || [])
            var selectedCollection = kbUserCollection()
            if (!selectedCollection || !selectedExistsOnServer) {
                kbSources = []
                if (selectedCollection)
                    kbReconcileMetadata()
                kbLoading = false
                kbBusyText = ""
                return
            }

            kbBusyText = "正在加载文件..."
            kbInvoke("kb_manage", { "collection": selectedCollection },
                     "list_sources", selectedCollection, function(result) {
                if (requestGeneration !== kbListRequestGeneration
                        || selectedCollection !== kbUserCollection()) {
                    return
                }
                var details = kbToolDetails(result)
                var sources = details.sources || []
                kbSources = sources.slice ? sources.slice(0) : []
                kbReconcileMetadata()
                kbLoading = false
                kbBusyText = ""
            })
        })
    }

    function kbDefaultMetadata() {
        return { "version": 2, "collections": [], "selectedCollection": "",
                 "chatSelectedCollection": "", "filesByCollection": {} }
    }

    function kbCollectionFiles(metadata, collection) {
        if (!metadata || !metadata.filesByCollection || !collection)
            return {}
        return metadata.filesByCollection[collection] || {}
    }

    function kbLoadMetadata() {
        if (!authController.loggedIn || !authController.userId) {
            kbMetadata = kbDefaultMetadata()
            kbMetadataUser = ""
            kbCollections = []
            kbSelectedCollection = ""
            chatKnowledgeCollection = ""
            return
        }
        var loaded = $MainViewController.loadKnowledgeBaseMetadata(String(authController.userId)) || {}
        var defaultId = kbDefaultCollectionId()
        var metadata = kbDefaultMetadata()
        var isCurrentSchema = Number(loaded.version || 0) >= 2
        var loadedCollections = loaded.collections || []
        var names = {}
        for (var i = 0; i < loadedCollections.length; i++) {
            var id = String(loadedCollections[i].id || "")
            var name = String(loadedCollections[i].name || "").trim()
            if (!kbOwnsCollection(id) || !name || names[name])
                continue
            names[name] = true
            metadata.collections.push({
                "id": id,
                "name": name,
                "pending": loadedCollections[i].pending === true
            })
        }
        if (!isCurrentSchema && metadata.collections.length === 0)
            metadata.collections.push({
                "id": defaultId,
                "name": qsTr("知识库1"),
                "pending": false
            })

        var loadedFiles = loaded.filesByCollection || {}
        for (var j = 0; j < metadata.collections.length; j++) {
            var collectionId = metadata.collections[j].id
            metadata.filesByCollection[collectionId] = loadedFiles[collectionId] || {}
        }
        if (!isCurrentSchema && loaded.files)
            metadata.filesByCollection[defaultId] = loaded.files

        // Start each authenticated session from the leftmost knowledge-base tab.
        // Manual tab changes continue to be saved and used until the next reload.
        var selected = metadata.collections.length > 0
                ? String(metadata.collections[0].id || "") : ""
        var chatSelected = String(loaded.chatSelectedCollection || "")
        var chatSelectedExists = false
        for (var m = 0; m < metadata.collections.length; m++) {
            if (String(metadata.collections[m].id || "") === chatSelected) {
                chatSelectedExists = true
                break
            }
        }
        if (!chatSelectedExists)
            chatSelected = ""
        metadata.selectedCollection = selected
        metadata.chatSelectedCollection = chatSelected
        kbMetadata = metadata
        kbCollections = metadata.collections.slice(0)
        kbSelectedCollection = selected
        chatKnowledgeCollection = chatSelected
        kbMetadataUser = String(authController.userId)
        kbSaveMetadata(metadata)
    }

    function kbSaveMetadata(metadata) {
        var saved = JSON.parse(JSON.stringify(metadata))
        kbMetadata = saved
        kbCollections = (saved.collections || []).slice(0)
        if (authController.loggedIn && authController.userId)
            $MainViewController.saveKnowledgeBaseMetadata(String(authController.userId), saved)
    }

    function kbReconcileMetadata() {
        var metadata = kbMetadata || kbDefaultMetadata()
        if (!metadata.filesByCollection) metadata.filesByCollection = {}
        var files = kbCollectionFiles(metadata, kbUserCollection())
        var actual = {}
        for (var i = 0; i < kbSources.length; i++) {
            var source = String(kbSources[i] || "")
            actual[source] = true
            if (!files[source])
                files[source] = { "addedAt": 0, "sizeBytes": -1, "fileSize": "--" }
        }
        var names = Object.keys(files)
        for (var j = 0; j < names.length; j++) {
            if (!actual[names[j]])
                delete files[names[j]]
        }
        metadata.filesByCollection[kbUserCollection()] = files
        kbSaveMetadata(metadata)
        kbSelectedKeys = []
    }

    function kbSelectCollection(collection) {
        collection = String(collection || "")
        if (kbLoading || !kbOwnsCollection(collection) || collection === kbSelectedCollection)
            return
        var exists = false
        for (var i = 0; i < kbCollections.length; i++) {
            if (String(kbCollections[i].id || "") === collection) {
                exists = true
                break
            }
        }
        if (!exists)
            return
        kbSelectedCollection = collection
        kbSearchText = ""
        kbSelectedKeys = []
        kbSources = []
        var metadata = kbMetadata
        metadata.selectedCollection = collection
        kbSaveMetadata(metadata)
        kbRefreshFiles()
    }

    function kbCreateCollection(name) {
        name = String(name || "").trim()
        if (!name) {
            kbShowError(qsTr("知识库名称不能为空"))
            return false
        }
        if (name.length > 40) {
            kbShowError(qsTr("知识库名称不能超过 40 个字符"))
            return false
        }
        for (var i = 0; i < kbCollections.length; i++) {
            if (String(kbCollections[i].name || "") === name) {
                kbShowError(qsTr("已存在同名知识库"))
                return false
            }
        }
        var id = kbDefaultCollectionId() + "_" + Date.now().toString(36)
        var metadata = kbMetadata
        var collections = (metadata.collections || []).slice(0)
        collections.push({ "id": id, "name": name, "pending": true })
        metadata.collections = collections
        if (!metadata.filesByCollection) metadata.filesByCollection = {}
        metadata.filesByCollection[id] = {}
        metadata.selectedCollection = id
        kbSelectedCollection = id
        kbSources = []
        kbSearchText = ""
        kbSelectedKeys = []
        kbSaveMetadata(metadata)
        if (wsClient.connectionState === 3)
            kbRefreshFiles()
        return true
    }

    function kbDeleteCollection(collection) {
        collection = String(collection || "")
        if (!wsClient.knowledgeBaseDataDirReady) {
            kbShowError(wsClient.knowledgeBaseDataDirMessage
                        || qsTr("当前用户的知识库目录尚未就绪"))
            return
        }
        if (!kbOwnsCollection(collection) || kbLoading)
            return
        kbLoading = true
        kbBusyText = qsTr("正在删除知识库...")
        kbInvoke("kb_manage", { "collection": collection }, "delete_collection", collection,
                 function(result) {
            var metadata = kbMetadata
            var kept = []
            var collections = metadata.collections || []
            for (var i = 0; i < collections.length; i++) {
                if (String(collections[i].id || "") !== collection)
                    kept.push(collections[i])
            }
            metadata.collections = kept
            if (metadata.filesByCollection)
                delete metadata.filesByCollection[collection]
            if (chatKnowledgeCollection === collection)
                chatKnowledgeCollection = ""
            if (kbSelectedCollection === collection) {
                kbSelectedCollection = kept.length > 0 ? String(kept[0].id || "") : ""
                metadata.selectedCollection = kbSelectedCollection
                kbSources = []
                kbSearchText = ""
                kbSelectedKeys = []
            }
            kbSaveMetadata(metadata)
            kbLoading = false
            kbBusyText = ""
            if (kbSelectedCollection && wsClient.connectionState === 3)
                kbRefreshFiles()
        }, true)
    }

    function kbDeleteSource(source) {
        kbDeleteEntries(["file:" + source])
    }

    function kbDeleteEntries(keys) {
        var collection = kbUserCollection()
        if (!collection) return
        var sources = []
        var seen = {}
        for (var i = 0; i < keys.length; i++) {
            var key = String(keys[i])
            if (key.indexOf("file:") === 0) {
                var source = key.substring(5)
                if (!seen[source]) { seen[source] = true; sources.push(source) }
            }
        }
        kbDeleteQueue = sources
        kbDeleteKeys = keys.slice(0)
        kbLoading = true
        kbBusyText = "正在删除..."
        kbDeleteNext()
    }

    function kbDeleteNext() {
        if (kbDeleteQueue.length === 0) {
            var metadata = kbMetadata
            var files = kbCollectionFiles(metadata, kbUserCollection())
            for (var i = 0; i < kbDeleteKeys.length; i++) {
                var key = String(kbDeleteKeys[i])
                if (key.indexOf("file:") === 0)
                    delete files[key.substring(5)]
            }
            metadata.filesByCollection[kbUserCollection()] = files
            kbSaveMetadata(metadata)
            kbDeleteKeys = []
            kbSelectedKeys = []
            kbRefreshFiles()
            return
        }
        var collection = kbUserCollection()
        var source = kbDeleteQueue[0]
        kbInvoke("kb_manage", { "collection": collection, "source": source },
                 "delete_source", collection, function(result) {
            var details = kbToolDetails(result)
            if (Number(details.deleted || 0) <= 0) {
                kbSelectedKeys = []
                kbShowError(qsTr("文件“%1”不在当前知识库中，列表将重新同步。").arg(source))
                kbRefreshFiles()
                return
            }
            kbDeleteQueue = kbDeleteQueue.slice(1)
            kbDeleteNext()
        })
    }

    function kbStartUpload(urls) {
        var entries = []
        for (var i = 0; urls && i < urls.length; i++) {
            var info = $MainViewController.localFileInfo(urls[i])
            if (info && info.fileName)
                entries.push(info)
        }
        kbStartUploadEntries(entries)
    }

    function kbIsSupportedUploadFile(entry) {
        var extension = String(entry && entry.ext || "").toLowerCase()
        return extension === "pdf"
                || extension === "doc"
                || extension === "docx"
                || extension === "txt"
                || extension === "md"
                || extension === "xlsx"
    }

    function kbStartUploadEntries(entries) {
        var collection = kbUserCollection()
        for (var entryIndex = 0; entries && entryIndex < entries.length; entryIndex++) {
            if (!kbIsSupportedUploadFile(entries[entryIndex])) {
                kbShowUnsupportedFileMessage()
                return
            }
        }
        if (!wsClient.knowledgeBaseDataDirReady) {
            kbShowError(wsClient.knowledgeBaseDataDirMessage
                        || qsTr("当前用户的知识库目录尚未就绪"))
            return
        }
        if (!collection) {
            kbShowError("请先登录后再上传文件")
            return
        }
        var existing = {}
        for (var i = 0; i < kbSources.length; i++) existing[String(kbSources[i])] = true
        kbUploadQueue = []
        kbUploadFailures = []
        kbUploadSuccessCount = 0
        for (var j = 0; entries && j < entries.length; j++) {
            var entry = entries[j]
            var source = String(entry.fileName || "")
            if (source && !existing[source]) {
                existing[source] = true
                kbUploadQueue.push(entry)
            } else if (source) {
                kbUploadFailures.push({ "name": source, "message": qsTr("文件名重复") })
            }
        }
        if (kbUploadQueue.length === 0) {
            kbShowError(entries.length ? "文件名与知识库现有文件重复" : "没有可上传的文件")
            return
        }
        kbUploadIndex = 0
        kbUploadCollection = collection
        kbUploadNext()
    }

    function kbUploadNext() {
        if (kbUploadCollection !== kbUserCollection()) {
            kbShowError("登录用户已切换，上传已停止")
            return
        }
        if (kbUploadIndex >= kbUploadQueue.length) {
            var successCount = kbUploadSuccessCount
            var failures = kbUploadFailures.slice(0)
            kbUploadQueue = []
            kbUploadIndex = 0
            kbUploadCollection = ""
            kbUploadSuccessCount = 0
            kbUploadFailures = []
            kbRefreshFiles()
            var message = qsTr("上传完成：成功 %1 个，失败 %2 个")
                    .arg(successCount).arg(failures.length)
            if (failures.length > 0) {
                var failedNames = []
                var shown = Math.min(3, failures.length)
                for (var i = 0; i < shown; i++)
                    failedNames.push(String(failures[i].name || qsTr("未命名文件")))
                message += qsTr("。失败文件：") + failedNames.join("、")
                if (failures.length > shown)
                    message += qsTr(" 等")
            }
            errorToast.text = message
            errorToast.visible = true
            errorToastTimer.restart()
            return
        }
        kbLoading = true
        kbBusyText = "正在上传 " + (kbUploadIndex + 1) + "/" + kbUploadQueue.length + "..."
        var entry = kbUploadQueue[kbUploadIndex]
        var path = entry.absolutePath || localFilePathFromUrl(entry.fileUrl)
        kbInvoke("kb_ingest", { "path": path, "collection": kbUploadCollection }, "",
                 kbUploadCollection, function(result) {
            var metadata = kbMetadata
            var files = kbCollectionFiles(metadata, kbUploadCollection)
            files[String(entry.fileName)] = {
                "addedAt": Date.now(),
                "sizeBytes": Number(entry.sizeBytes || 0),
                "fileSize": String(entry.fileSize || "--")
            }
            metadata.filesByCollection[kbUploadCollection] = files
            var collections = metadata.collections || []
            for (var i = 0; i < collections.length; i++) {
                if (String(collections[i].id || "") === kbUploadCollection) {
                    collections[i].pending = false
                    break
                }
            }
            kbSaveMetadata(metadata)
            kbUploadSuccessCount++
            kbUploadIndex++
            kbUploadNext()
        }, false, function(message) {
            var failures = kbUploadFailures.slice(0)
            failures.push({
                "name": String(entry.fileName || qsTr("未命名文件")),
                "message": String(message || qsTr("上传失败"))
            })
            kbUploadFailures = failures
            kbUploadIndex++
            kbUploadNext()
        })
    }

    function kbFileIcon(name) {
        var lower = String(name || "").toLowerCase()
        if (/\.(xlsx|xls)$/.test(lower)) return "qrc:/images/knowledge/excel.png"
        if (/\.pptx$/.test(lower)) return "qrc:/images/knowledge/ppt.png"
        if (/\.(docx|doc)$/.test(lower)) return "qrc:/images/knowledge/word.png"
        return "qrc:/images/knowledge/others.png"
    }

    function kbFormatTime(value) {
        var timestamp = Number(value || 0)
        return timestamp > 0 ? Qt.formatDateTime(new Date(timestamp), "yyyy/M/d HH:mm") : "--"
    }

    function kbVisibleEntries() {
        var query = kbSearchText.trim().toLowerCase()
        var rows = []
        var files = kbCollectionFiles(kbMetadata, kbUserCollection())
        for (var i = 0; i < kbSources.length; i++) {
            var source = String(kbSources[i] || "")
            var info = files[source] || {}
            if (!query || source.toLowerCase().indexOf(query) >= 0) {
                rows.push({ "kind": "file", "key": "file:" + source, "name": source,
                              "addedAt": Number(info.addedAt || 0),
                              "size": String(info.fileSize || "--") })
            }
        }
        return rows
    }

    function kbIsSelected(key) { return kbSelectedKeys.indexOf(key) >= 0 }

    function kbToggleSelected(key) {
        var selected = kbSelectedKeys.slice(0)
        var index = selected.indexOf(key)
        if (index >= 0) selected.splice(index, 1)
        else selected.push(key)
        kbSelectedKeys = selected
    }

    function kbToggleSelectAll() {
        var rows = kbVisibleEntries()
        if (rows.length > 0 && kbSelectedKeys.length === rows.length) {
            kbSelectedKeys = []
            return
        }
        var selected = []
        for (var i = 0; i < rows.length; i++) selected.push(rows[i].key)
        kbSelectedKeys = selected
    }

    /// Markdown / 富文本中的超链接点击（需 Text.textFormat 为 MarkdownText 等）
    function openMarkdownLink(link) {
        var raw = String(link || "")
        if (!raw)
            return

        var ws = ""
        if (typeof dropdownSelectionWorkSpace !== "undefined")
            ws = dropdownSelectionWorkSpace.effectiveWorkspacePath || ""
        if (!ws)
            ws = wsClient.currentTaskWorkspace || ""

        var isLocalLink = raw.indexOf("medclaw-local:") === 0
        if (isLocalLink || raw.indexOf("file://") === 0) {
            var resolved = $MainViewController.resolveLocalFileLink(raw, ws)
            if (resolved) {
                Qt.openUrlExternally(resolved)
                return
            }
            if (isLocalLink) {
                console.warn("local file link not found:", raw)
                return
            }
        }

        Qt.openUrlExternally(raw)
    }

    function modelDisplayLabel(nm, pv) {
        var raw = pv ? (nm + " (" + pv + ")") : nm
        return trimToFirstParenPairOnly(raw)
    }

    // Only connect to the Gateway after the user has an authenticated session.
    Component.onCompleted: {
        if (authController.loggedIn) {
            reloadUploadedDocxTemplates()
            kbLoadMetadata()
            wsClient.connectToServer(wsClient.serverUrl)
        }
    }
    Connections {
        target: authController
        function onUserChanged() {
            if (!authController.loggedIn)
                return
            window.userSessionInitializing = true
            window.reloadUploadedDocxTemplates()
            if (window.kbMetadataUser === String(authController.userId || ""))
                return
            window.knowledgeBaseReadyUserId = ""
            window.kbListRequestGeneration++
            kbSources = []
            kbSearchText = ""
            kbSelectedKeys = []
            kbLoadMetadata()
            if (wsClient.connectionState === 3)
                wsClient.configureKnowledgeBaseForUser(String(authController.userId || ""))
            if (wsClient.connectionState === 3 && window.leftSelectedIndex === 7)
                kbRefreshFiles()
        }
        function onLoggedInChanged() {
            if (authController.loggedIn) {
                window.userSessionInitializing = true
                window.knowledgeBaseReadyUserId = ""
                window.reloadUploadedDocxTemplates()
                kbLoadMetadata()
                wsClient.connectToServer(wsClient.serverUrl)
            } else {
                window.userSessionInitializing = false
                window.knowledgeBaseReadyUserId = ""
                window.kbListRequestGeneration++
                knowledgePopup.close()
                wsClient.configureKnowledgeBaseForUser("")
                wsClient.clearActiveAgentContext()
                wsClient.disconnectFromServer()
                chatModel.clear()
                window.leftSelectedIndex = 0
                window.isNewTask = true
                leftMidPanel.activeAgentId = ""
                leftMidPanel.activeSessionKey = ""
                textInputArea.text = ""
                newTaskRec.resetShortcutSelection()
                newTaskRec.selectedDocxTemplate = ({})
                newTaskRec.selectedCollaborationAgentIds = []
                dropdownSelectionWorkSpace.currentText = qsTr("workspace")
                dropdownSelectionWorkSpace.absolutePath = ""
                dropdownSelectionModel.currentIndex = 0
                window.pendingExpertPrompt = ""
                window.pendingExpertInstallStartedAt = 0
                kbSources = []
                kbSearchText = ""
                kbLoading = false
                kbBusyText = ""
                kbUploadQueue = []
                kbDeleteQueue = []
                kbDeleteKeys = []
                kbMetadata = kbDefaultMetadata()
                kbMetadataUser = ""
                kbCollections = []
                kbSelectedCollection = ""
                chatKnowledgeCollection = ""
                kbSelectedKeys = []
                uploadedDocxTemplates = []
                uploadedDocxTemplatesUserId = ""
            }
        }
    }
    Connections{
        target: wsClient
        function onConnectionStateChanged(){
            if(wsClient.connectionState === 3){
                wsClient.configureKnowledgeBaseForUser(String(authController.userId || ""))
                wsClient.refreshSkills()
                wsClient.refreshCronJobs(true)
                wsClient.refreshCronStatus()
                wsClient.refreshMcpList()
                wsClient.refreshAgents()
                if (window.leftSelectedIndex === 7)
                    window.kbRefreshFiles()
            }
        }
        function onKnowledgeBaseDataDirStateChanged() {
            if (wsClient.knowledgeBaseDataDirReady) {
                window.knowledgeBaseReadyUserId = String(authController.userId || "")
                window.userSessionInitializing = false
                window.kbLoading = false
                window.kbBusyText = ""
                if (window.leftSelectedIndex === 7)
                    window.kbRefreshFiles()
            } else if (authController.loggedIn) {
                if (window.userSessionInitializing) {
                    window.knowledgeBaseReadyUserId = ""
                    window.kbListRequestGeneration++
                    window.kbSources = []
                }
                var message = wsClient.knowledgeBaseDataDirMessage
                        || qsTr("正在切换当前用户的知识库目录...")
                if (message.indexOf(qsTr("知识库目录切换失败")) === 0) {
                    window.kbLoading = false
                    window.kbBusyText = ""
                    errorToast.text = message
                    errorToast.visible = true
                    errorToastTimer.restart()
                } else {
                    window.kbLoading = true
                    window.kbBusyText = message
                }
            }
        }
        function onCronJobAdded(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronJobRemoved(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronJobUpdated(jobId){
            wsClient.refreshCronJobs(true)
        }
        function onCronRunsLoaded(runs){
            cronRunsModel.clear()
            for(var i = 0; i < runs.length; i++){
                cronRunsModel.append(runs[i])
            }
        }
        function onAgentListChanged(){
            // 不在列表刷新时自动选中 main；仅用户点击任务记录后才 switchAgent 并加载历史
        }
        function onAgentCreated(agentId, success, message, forChat){
            if (success && forChat) {
                leftMidPanel.activeAgentId = String(agentId || "")
                window.leftSelectedIndex = 6
            }
        }
        function onAgentDeleted(agentId, success, message){
            if (success && leftMidPanel.activeAgentId === agentId) {
                leftMidPanel.activeAgentId = ""
                leftMidPanel.activeSessionKey = ""
                chatModel.clear()
                wsClient.clearActiveAgentContext()
                /// 被删任务正在选中：跳回「新建任务」首页，与点击侧栏「新建任务」一致
                window.leftSelectedIndex = 0
            }
        }
        function onAgentInstallFinished(agentId, success, message) {
            var elapsed = window.pendingExpertInstallStartedAt > 0
                    ? Date.now() - window.pendingExpertInstallStartedAt : 0
            var autoOpen = success && elapsed <= 5000
            if (autoOpen && String(agentId || "").length > 0) {
                var selected = newTaskRec.selectedCollaborationAgentIds || []
                if (window.leftSelectedIndex !== 0 || selected.length !== 1
                        || String(selected[0] || "") !== String(agentId || ""))
                    window.startTaskWithAgents([agentId])
                if (window.pendingExpertPrompt.length > 0) {
                    textInputArea.text = window.pendingExpertPrompt
                    textInputArea.forceActiveFocus()
                }
            } else if (success) {
                errorToast.text = qsTr("专家安装成功")
                errorToast.visible = true
                errorToastTimer.restart()
            }
            window.pendingExpertPrompt = ""
            window.pendingExpertInstallStartedAt = 0
        }
        function onCurrentSessionChanged() {
            var sk = wsClient.currentSessionKey || ""
            leftMidPanel.activeSessionKey = sk
            leftMidPanel.activeAgentId = String(window.agentIdFromSessionKey(sk) || "")
            if (sk.length > 0)
                window.leftSelectedIndex = 6
        }
        function onErrorOccurred(message){
            console.warn("[Gateway Error]", message)
            errorToast.text = message
            errorToast.visible = true
            errorToastTimer.restart()
        }
    }
    ListModel { id: cronRunsModel }

    Rectangle {
        id: kbUploadFormatMessage
        visible: false
        z: 10000
        width: Math.min(kbUploadFormatMessageContent.implicitWidth + 32, window.width - 80)
        height: 44
        radius: 6
        color: "#FFFFFF"
        border.width: 1
        border.color: "#12000000"
        anchors.top: parent.top
        anchors.topMargin: 32
        anchors.horizontalCenter: parent.horizontalCenter
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 10
            samples: 21
            color: "#26000000"
            verticalOffset: 4
        }

        Row {
            id: kbUploadFormatMessageContent
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 18
                height: 18
                radius: 9
                color: "#FF8A34"
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#FFFFFF"
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("不支持该文件格式，请上传PDF，Word，TXT，MD，XLSX格式")
                color: "#D9000000"
                font.pixelSize: 14
            }
        }

        Timer {
            id: kbUploadFormatMessageTimer
            interval: 5000
            onTriggered: kbUploadFormatMessage.visible = false
        }
    }

    // 错误提示 Toast
    Rectangle {
        id: errorToast
        property string text: ""
        visible: false
        z: 9999
        width: Math.min(errorToastLabel.implicitWidth + 40, window.width - 80)
        height: 44
        radius: 8
        color: "#CC000000"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60

        Label {
            id: errorToastLabel
            text: errorToast.text
            color: "#FFFFFF"
            font.pixelSize: 14
            anchors.centerIn: parent
            width: parent.width - 32
            elide: Text.ElideRight
        }

        Timer {
            id: errorToastTimer
            interval: 5000
            onTriggered: errorToast.visible = false
        }

        Behavior on visible {
            NumberAnimation { property: "opacity"; duration: 200 }
        }
    }
    Rectangle{
        id: leftContainer
        enabled: window.userSessionReady
        width: window.userSessionReady ? (window.sidebarExpanded ? 280 : 68) : 0
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        color: "#F7F9FA"
        clip: true

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Column{
            height: parent.height
            width: parent.width
            leftPadding: 16
            rightPadding: 16
            Rectangle{
                id: leftTopPanel
                width: parent.width - 32
                height: 56
                color: "transparent"
                Image{
                    id: logoImage
                    width: 28
                    height: 28
                    source: "qrc:/images/logoImage.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label{
                    text: "Aether study"
                    font.family: "Alimama ShuHeiTi"
                    font.pixelSize: 18
                    anchors.left: logoImage.right
                    anchors.leftMargin: 8
                    visible: window.sidebarExpanded
                    anchors.verticalCenter: parent.verticalCenter
                }
                ImageButton{
                    btnHeight: 20
                    btnWidth: 20
                    source: "qrc:/images/sidebarMinimalistic.png"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    visible: window.sidebarExpanded
                    onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56 - 72
                color: "transparent"

                // 当前选中的 agent ID（用于高亮）
                property string activeAgentId: ""
                // 当前选中的 session key（用于任务记录高亮）
                property string activeSessionKey: ""

                Column{
                    id: leftMenuColumn
                    spacing: 12
                    width: parent.width
                    ImageButton{
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/sidebarMinimalistic.png"
                        visible: !window.sidebarExpanded
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: window.sidebarExpanded
                        Repeater {
                            id: selectionRepeater
                            model: ["新建任务", "定时任务", "专家·技能·工具", "知识库", "模板库"/*, "MCP"*/]
                            delegate: Rectangle{
                                readonly property int targetIndex: index < 2 ? index : (index === 2 ? 2 : (index === 3 ? 7 : 8))
                                property bool isSelected: index === 2
                                                          ? window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                                                          : targetIndex === window.leftSelectedIndex
                                width: leftMidPanel.width
                                height: 36
                                radius: 8
                                color: isSelected ? "#E6E7EB"
                                     : selItemMouse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Row {
                                    height: parent.height
                                    width: parent.width
                                    spacing: 8
                                    leftPadding: 8
                                    rightPadding: 8
                                    Image{
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16
                                        height: 16
                                        source: {
                                            if(modelData === "新建任务"){
                                                return "qrc:/images/chatNew.png"
                                            }else if(modelData === "定时任务"){
                                                return "qrc:/images/alarm.png"
                                            }else if(modelData === "专家·技能·工具"){
                                                return "qrc:/images/category.png"
                                            }else if(modelData === "知识库"){
                                                return "qrc:/images/knowledge.png"
                                            }else if(modelData === "模板库"){
                                                return "qrc:/images/template.png"
                                            }else if(modelData === "MCP"){
                                                return "qrc:/images/puzzle.png"
                                            }
                                        }
                                    }
                                    Label{
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData
                                        color: "#D9000000"
                                    }
                                }
                                MouseArea {
                                    id: selItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.leftSelectedIndex = targetIndex
                                            leftMidPanel.activeAgentId = ""
                                            leftMidPanel.activeSessionKey = ""
                                            chatModel.clear()
                                            wsClient.clearActiveAgentContext()
                                            if (targetIndex === 7) {
                                                window.kbSearchText = ""
                                                window.kbRefreshFiles()
                                            }
                                    }
                                }
                                ToolTip {
                                    id: scheduledTaskMenuTip
                                    visible: modelData === "定时任务" && selItemMouse.containsMouse
                                    text: qsTr("可设置task开机联网后定时启动")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: scheduledTaskMenuTip.text
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: !window.sidebarExpanded
                        Repeater {
                            id: selectionRepeaterCollapsed
                            model: ["新建任务", "定时任务", "专家·技能·工具", "知识库", "模板库" /*, "MCP"*/ ]
                            delegate: Rectangle{
                                readonly property int targetIndex: index < 2 ? index : (index === 2 ? 2 : (index === 3 ? 7 : 8))
                                property bool isSelected: index === 2
                                                          ? window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                                                          : targetIndex === window.leftSelectedIndex
                                width: leftMidPanel.width
                                height: 36
                                radius: 8
                                color: isSelected ? "#E6E7EB"
                                     : selItemMouseCollapse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Image{
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: {
                                        if(modelData === "新建任务"){
                                            return "qrc:/images/chatNew.png"
                                        }else if(modelData === "定时任务"){
                                            return "qrc:/images/alarm.png"
                                        }else if(modelData === "专家·技能·工具"){
                                            return "qrc:/images/category.png"
                                        }else if(modelData === "知识库"){
                                            return "qrc:/images/knowledge.png"
                                        }else if(modelData === "模板库"){
                                            return "qrc:/images/template.png"
                                        }else if(modelData === "MCP"){
                                            return "qrc:/images/puzzle.png"
                                        }
                                    }
                                }
                                MouseArea {
                                    id: selItemMouseCollapse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.leftSelectedIndex = targetIndex
                                        leftMidPanel.activeAgentId = ""
                                        leftMidPanel.activeSessionKey = ""
                                        chatModel.clear()
                                        wsClient.clearActiveAgentContext()
                                        if (targetIndex === 7) {
                                            window.kbSearchText = ""
                                            window.kbRefreshFiles()
                                        }
                                    }
                                }
                                ToolTip {
                                    id: scheduledTaskMenuTipCollapsed
                                    visible: modelData === "定时任务" && selItemMouseCollapse.containsMouse
                                    text: qsTr("创建定时任务，让 AI 按计划自动执行")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: scheduledTaskMenuTipCollapsed.text
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                        Rectangle {
                            id: collapsedHistoryTrigger
                            width: leftMidPanel.width
                            height: 36
                            radius: 8
                            color: collapsedHistoryPopup.visible ? "#E6E7EB"
                                 : collapsedHistoryTriggerMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: "qrc:/images/history.png"
                            }
                            MouseArea {
                                id: collapsedHistoryTriggerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (collapsedHistoryPopup.visible) {
                                        collapsedHistoryPopup.close()
                                    } else {
                                        var gap = 6
                                        var pt = collapsedHistoryTrigger.mapToItem(window.contentItem,
                                                                                  collapsedHistoryTrigger.width + gap, 0)
                                        collapsedHistoryPopup.x = pt.x
                                        collapsedHistoryPopup._pendingAnchorY = pt.y
                                        collapsedHistoryPopup.open()
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════════════
                //  任务记录列表（本地 SQLite 会话列表）
                // ═══════════════════════════════════════════════
                Item {
                    visible: window.sidebarExpanded
                    anchors.top: leftMenuColumn.bottom
                    anchors.topMargin: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: parent.width

                    // 分隔标题
                    Label {
                        id: taskRecordLabel
                        text: "任务记录"
                        font.pixelSize: 12
                        color: "#80000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                    }

                    // 可滚动的任务会话列表
                    ScrollView {
                        id: agentListScrollView
                        anchors.top: taskRecordLabel.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Column {
                            spacing: 2
                            width: agentListScrollView.width

                            Repeater {
                                model: wsClient.taskSessionList

                                delegate: Rectangle {
                                    id: agentItemRect
                                    width: agentListScrollView.width
                                    height: 55
                                    radius: 8
                                    color: {
                                        var isActive = (modelData.session_id === wsClient.currentTaskSessionKey)
                                        if (isActive) return "#E6E7EB"
                                        if (agentItemMouse.containsMouse) return "#0A000000"
                                        return "transparent"
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Row {
                                            spacing: 4
                                            width: parent.width
                                            Label {
                                                id: agentListCronTag
                                                visible: {
                                                    var sk = modelData.session_id || ""
                                                    return sk.indexOf(":cron:") >= 0
                                                }
                                                text: qsTr("[定时]")
                                                font.pixelSize: 14
                                                color: "#73000000"
                                                height: 21
                                            }
                                            Label {
                                                text: window.taskSessionDisplayTitle(modelData)
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                height: 21
                                                elide: Text.ElideRight
                                                width: agentListCronTag.visible
                                                       ? Math.max(0, parent.width - agentListCronTag.width - parent.spacing)
                                                       : parent.width
                                            }
                                        }

                                        // 最近活跃会话的更新时间（与上行标题为同一条 session）
                                        Row {
                                            spacing: 5

                                            TaskSessionStatusIndicator {
                                                running: modelData.isRunning || false
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                text: {
                                                    var ms = Number(modelData.updated_at || modelData.created_at || 0)
                                                    if (!ms || ms <= 0) return ""
                                                    return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm")
                                                }
                                                font.pixelSize: 12
                                                color: "#73000000"
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: agentItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (mouse.button === Qt.RightButton) {
                                                window.pendingDeleteTaskSessionId = modelData.session_id || ""
                                                window.pendingDeleteTaskSessionName = window.taskSessionDisplayTitle(modelData)
                                                var p = agentItemMouse.mapToItem(window.contentItem, mouse.x, mouse.y)
                                                agentContextMenu.x = Math.min(p.x, window.width - agentContextMenu.width - 4)
                                                agentContextMenu.y = Math.min(p.y, window.height - agentContextMenu.height - 4)
                                                agentContextMenu.open()
                                                return
                                            }
                                            leftMidPanel.activeAgentId = modelData.agentId || ""
                                            window.leftSelectedIndex = 6
                                            wsClient.switchTaskSession(modelData.session_id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: accountEntry
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 48
            radius: 6
            color: accountMouse.containsMouse || accountPopup.visible ? "#E6E7EB" : "transparent"
            Image {
                width: 28
                height: 28
                source: "qrc:/images/logoImage.png"
                anchors.left: parent.left
                anchors.leftMargin: window.sidebarExpanded ? 8 : 4
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                visible: window.sidebarExpanded
                anchors.left: parent.left
                anchors.leftMargin: 46
                anchors.right: accountArrow.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Label { text: "用户管理"; color: "#D9000000"; font.pixelSize: 14 }
                Label { width: parent.width; text: authController.phone; color: "#73000000"; font.pixelSize: 14; elide: Text.ElideMiddle }
            }
            Label {
                id: accountArrow
                visible: window.sidebarExpanded
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: "#73000000"
                font.pixelSize: 18
            }
            MouseArea {
                id: accountMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var pt = accountEntry.mapToItem(window.contentItem,
                                                    window.sidebarExpanded ? 0 : accountEntry.width + 6,
                                                    -accountPopup.height - 6)
                    accountPopup.x = pt.x
                    accountPopup.y = Math.max(8, pt.y)
                    accountPopup.open()
                }
            }
        }
    }

    Popup {
        id: accountPopup
        parent: window.contentItem
        width: window.sidebarExpanded ? 248 : 190
        height: 92
        padding: 8
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: "#FFFFFF"; radius: 6; border.width: 1; border.color: "#1F000000" }
        contentItem: Column {
            spacing: 2
            Rectangle {
                width: parent.width
                height: 34
                color: "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Label { text: "账号"; color: "#73000000"; font.pixelSize: 14 }
                    Label { text: authController.phone; color: "#D9000000"; font.pixelSize: 14 }
                }
            }
            Rectangle {
                width: parent.width
                height: 40
                radius: 5
                color: logoutMouse.containsMouse ? "#F2F3F5" : "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Label { text: "↪"; color: "#D9000000"; font.pixelSize: 16 }
                    Label { text: authController.busy ? "正在退出..." : "退出登录"; color: "#D9000000"; font.pixelSize: 14 }
                }
                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    enabled: !authController.busy
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { accountPopup.close(); authController.logout() }
                }
            }
        }
    }

    Popup {
        id: collapsedHistoryPopup
        parent: window.contentItem
        modal: false
        focus: true
        padding: 12
        width: 300
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        /// 打开后根据实际高度贴底边校正 y（布局完成后再读 height）
        property real _pendingAnchorY: 0
        onOpened: {
            var ph = height
            var ny = _pendingAnchorY
            if (ny + ph > window.height - 12)
                ny = Math.max(12, window.height - 12 - ph)
            collapsedHistoryPopup.y = ny
        }

        readonly property int _maxPopupH: 440
        readonly property int _listViewportH: Math.min(_maxPopupH - 2 * padding,
                                                         Math.max(histPopListColumn.implicitHeight, 0))
        implicitHeight: 2 * padding + _listViewportH

        Connections {
            target: window
            function onSidebarCollapsedChanged() {
                if (!window.sidebarCollapsed)
                    collapsedHistoryPopup.close()
            }
        }

        background: Rectangle {
            radius: 10
            color: "#FFFFFF"
            border.width: 1
            border.color: "#14000000"
        }

        contentItem: ScrollView {
            id: collapsedHistoryPopupScroll
            width: collapsedHistoryPopup.availableWidth
            height: collapsedHistoryPopup._listViewportH
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                id: histPopListColumn
                spacing: 2
                width: collapsedHistoryPopupScroll.width

                Repeater {
                    model: wsClient.taskSessionList

                    delegate: Rectangle {
                        width: collapsedHistoryPopupScroll.width
                        height: 55
                        radius: 8
                        color: {
                            var isActive = (modelData.session_id === wsClient.currentTaskSessionKey)
                            if (isActive) return "#E6E7EB"
                            if (histPopAgentMouse.containsMouse) return "#0A000000"
                            return "transparent"
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Row {
                                spacing: 4
                                width: parent.width
                                Label {
                                    id: histPopCronTag
                                    visible: {
                                        var sk = modelData.session_id || ""
                                        return sk.indexOf(":cron:") >= 0
                                    }
                                    text: qsTr("[定时]")
                                    font.pixelSize: 14
                                    color: "#73000000"
                                    height: 21
                                }
                                Label {
                                    text: window.taskSessionDisplayTitle(modelData)
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                    height: 21
                                    elide: Text.ElideRight
                                    width: histPopCronTag.visible
                                           ? Math.max(0, parent.width - histPopCronTag.width - parent.spacing)
                                           : parent.width
                                }
                            }

                            Row {
                                spacing: 5

                                TaskSessionStatusIndicator {
                                    running: modelData.isRunning || false
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Label {
                                    text: {
                                        var ms = Number(modelData.updated_at || modelData.created_at || 0)
                                        if (!ms || ms <= 0) return ""
                                        return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm")
                                    }
                                    font.pixelSize: 12
                                    color: "#73000000"
                                }
                            }
                        }

                        MouseArea {
                            id: histPopAgentMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (mouse.button === Qt.RightButton) {
                                    window.pendingDeleteTaskSessionId = modelData.session_id || ""
                                    window.pendingDeleteTaskSessionName = window.taskSessionDisplayTitle(modelData)
                                    var p = histPopAgentMouse.mapToItem(window.contentItem, mouse.x, mouse.y)
                                    agentContextMenu.x = Math.min(p.x, window.width - agentContextMenu.width - 4)
                                    agentContextMenu.y = Math.min(p.y, window.height - agentContextMenu.height - 4)
                                    agentContextMenu.open()
                                    return
                                }
                                leftMidPanel.activeAgentId = modelData.agentId || ""
                                window.leftSelectedIndex = 6
                                wsClient.switchTaskSession(modelData.session_id)
                                collapsedHistoryPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle{
        id:rightContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftContainer.right
        anchors.right: parent.right
        color: "#FFFFFF"
        Rectangle{
            id: rightTopPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#14000000"
            }

            MouseArea {
                anchors.fill: parent
                property point dragPos

                onPressed: {
                    dragPos = Qt.point(mouseX, mouseY)
                }
                onPositionChanged: {
                    if (pressed) {
                        var delta = Qt.point(mouseX - dragPos.x, mouseY - dragPos.y)
                        window.x += delta.x
                        window.y += delta.y
                    }
                }
            }
            Rectangle{
                visible: window.userSessionReady
                color: "#F7F9FA"
                width: statusRow.width
                height: 31
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                radius: 8
                Row{
                    id: statusRow
                    height: parent.height
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 5
                    bottomPadding: 5
                    // 连接状态指示灯 + 文本
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: {
                            switch (wsClient.connectionState) {
                            case 0: return "#D32F2F"  // Disconnected
                            case 1: return "#FF9800"  // Connecting
                            case 2: return "#FF9800"  // Handshaking
                            case 3: return "#006BFF"  // Connected
                            default: return "#9E9E9E"
                            }
                        }
                    }
                    Rectangle{
                        width: 8
                        height: 1
                        color: "transparent"
                    }
                    Label {
                        text: wsClient.statusText
                        font.pixelSize: 14
                        color: "#A6000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row{
                rightPadding: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Item {
                    id: workspaceTopBarSlot
                    width: (window.userSessionReady
                            && (window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6)
                            && !newTaskRec.isNewTaskWelcome) ? 137 : 0
                    height: parent.height
                    clip: true
                }
                Rectangle {
                    width: workspaceTopBarSlot.width > 0 ? 8 : 0
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: settingBtn
                    btnHeight: 20
                    btnWidth: 20
                    visible: window.userSessionReady
                    source: "qrc:/images/setting.png"
                    onClicked: settingsDialog.open()
                }
                Rectangle{
                    visible: window.userSessionReady
                    width: 20
                    height: 1
                    color: "transparent"
                }
                Rectangle{
                    visible: window.userSessionReady
                    width: 1
                    height: 16
                    color: "#1F000000"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle{
                    visible: window.userSessionReady
                    width: 20
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: minusBtn
                    btnWidth: 20
                    btnHeight: 20
                    source: "qrc:/images/minus.png"
                    onClicked: window.showMinimized()
                }
                Rectangle{
                    width: 10
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: maxmizeBtn
                    source: "qrc:/images/add-square.png"
                    btnWidth: 20
                    btnHeight: 20
                    onClicked: {
                        if (window.visibility === Window.Maximized) {
                            window.showNormal()
                        } else {
                            window.showMaximized()
                        }
                    }
                }
                Rectangle{
                    width: 10
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: closeBtn
                    btnWidth: 20
                    btnHeight: 20
                    source: "qrc:/images/close.png"
                    onClicked: {
                        Qt.quit()
                    }
                }
            }
        }
        Rectangle{
            id: rightMainPanel
            enabled: window.userSessionReady
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rightTopPanel.bottom
            anchors.bottom: parent.bottom
            Rectangle{
                id: newTaskRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6
                property bool hasMessages: chatModel.count > 0
                readonly property bool hasActiveTask: String(wsClient.currentTaskSessionKey || "").length > 0
                property bool isNewTaskWelcome: window.leftSelectedIndex === 0
                                                && !hasActiveTask && !hasMessages
                property var selectedCollaborationAgentIds: []
                property var selectedDocxTemplate: ({})
                readonly property bool hasSelectedDocxTemplate:
                    String((selectedDocxTemplate && selectedDocxTemplate.id) || "").length > 0
                onSelectedCollaborationAgentIdsChanged: {
                    if ((selectedCollaborationAgentIds || []).length > 0) {
                        newTaskRec.clearDocxTemplateSelection(true)
                        if (newTaskRec.isNewTaskWelcome) {
                            window.chatKnowledgeCollection = ""
                            knowledgePopup.close()
                        }
                    }
                }
                readonly property bool viewingControllerSession: (wsClient.currentViewSessionKey || "") === ""
                                                             || (wsClient.currentViewSessionKey || "") === (wsClient.currentTaskSessionKey || "")
                property bool artifactSidebarVisible: false
                property var sessionInputFiles: []
                property var sessionArtifacts: []
                property string artifactSidebarMode: "list"
                property var selectedOfficeFile: ({})
                property alias officeTabs: officeTabsModel
                ListModel { id: officeTabsModel }
                property int activeOfficeTabIndex: -1
                property bool officePanelMaximized: false
                property bool officePanelSizeManuallySet: false
                property bool sidebarFilesAscending: true
                property bool inputFilesExpanded: true
                property bool artifactsExpanded: true
                property bool resourcePopoverVisible: false
                property bool resourcePopoverMayKeepOpen: false
                property bool officeMoreMenuVisible: false
                property string officeDownloadSourcePath: ""
                property bool sessionHistoryLoading: false
                property string sidebarStateSessionKey: ""
                property var sidebarVisibilityBySession: ({})
                property bool officeSaveRequested: false
                property bool officeEditPending: false
                property bool officePreviewPending: false
                readonly property bool officeDocumentVisible: artifactSidebarMode === "preview"
                                                             || artifactSidebarMode === "edit"
                readonly property int currentSessionOfficeTabCount: {
                    var key = currentSidebarSessionKey()
                    var count = 0
                    for (var i = 0; i < officeTabs.count; i++) {
                        if (String(officeTabs.get(i).sessionKey || "") === key)
                            count++
                    }
                    return count
                }
                onCurrentSessionOfficeTabCountChanged: {
                    // A maximized document panel must not leak into a session
                    // which has no file tabs to display.
                    if (currentSessionOfficeTabCount === 0 && officePanelMaximized) {
                        officePanelMaximized = false
                        officePanelSizeManuallySet = false
                    }
                }
                readonly property int officePreviewWidth: Math.min(680, Math.max(420, width - 360))
                readonly property int artifactSidebarWidth: artifactSidebarVisible
                    ? (officePanelMaximized ? width
                       : (officeDocumentVisible ? officePreviewWidth : 300))
                    : 0

                function sortedSidebarFiles(files) {
                    var sorted = (files || []).slice(0)
                    sorted.sort(function(left, right) {
                        var a = String((left && left.name) || (left && left.path) || "")
                        var b = String((right && right.name) || (right && right.path) || "")
                        return a.localeCompare(b)
                    })
                    if (!sidebarFilesAscending)
                        sorted.reverse()
                    return sorted
                }

                function showResourcePopover() {
                    resourcePopoverCloseTimer.stop()
                    resourcePopoverMayKeepOpen = true
                    resourcePopoverVisible = true
                }

                function scheduleResourcePopoverClose() {
                    resourcePopoverCloseTimer.restart()
                }

                function keepResourcePopoverOpen() {
                    if (resourcePopoverMayKeepOpen)
                        resourcePopoverCloseTimer.stop()
                }

                function leaveResourcePopover() {
                    resourcePopoverMayKeepOpen = false
                    if (resourcePopoverVisible)
                        scheduleResourcePopoverClose()
                }

                function hideResourcePopover() {
                    resourcePopoverCloseTimer.stop()
                    resourcePopoverMayKeepOpen = false
                    resourcePopoverVisible = false
                }

                function currentSidebarSessionKey() {
                    return String(wsClient.currentViewSessionKey
                                  || wsClient.currentTaskSessionKey || "")
                }

                function beginSidebarSessionSwitch() {
                    var nextKey = currentSidebarSessionKey()
                    if (nextKey === sidebarStateSessionKey)
                        return
                    var states = ({})
                    for (var key in sidebarVisibilityBySession)
                        states[key] = sidebarVisibilityBySession[key]
                    if (sidebarStateSessionKey) {
                        states[sidebarStateSessionKey] = {
                            visible: artifactSidebarVisible,
                            activePath: String(selectedOfficeFile.path || ""),
                            maximized: officePanelMaximized,
                            sizeManuallySet: officePanelSizeManuallySet
                        }
                    }
                    sidebarVisibilityBySession = states
                    sidebarStateSessionKey = nextKey
                    sessionHistoryLoading = nextKey.length > 0
                    sessionInputFiles = []
                    sessionArtifacts = []
                    hideResourcePopover()
                    officeMoreMenuVisible = false
                    officeSaveRequested = false
                    officeEditPending = false
                    officePreviewPending = false
                    selectedOfficeFile = ({})
                    activeOfficeTabIndex = -1
                    artifactSidebarMode = "list"
                    artifactSidebarVisible = false
                }

                function finishSidebarSessionLoad() {
                    var key = currentSidebarSessionKey()
                    sidebarStateSessionKey = key
                    sessionInputFiles = wsClient.currentSessionInputFiles()
                    rebuildSessionArtifacts()
                    var saved = sidebarVisibilityBySession[key]
                    officePanelMaximized = !!(saved && saved.maximized)
                    officePanelSizeManuallySet = !!(saved && saved.sizeManuallySet)
                    var activePath = String((saved && saved.activePath) || "")
                    var activeIndex = activePath ? findOfficeTab(activePath, key) : -1
                    if (activeIndex >= 0) {
                        activateOfficeTab(activeIndex)
                        artifactSidebarVisible = !!saved.visible
                    } else {
                        activeOfficeTabIndex = -1
                        selectedOfficeFile = ({})
                        artifactSidebarMode = "list"
                        officePanelMaximized = false
                        officePanelSizeManuallySet = false
                        artifactSidebarVisible = !!(saved && saved.visible)
                    }
                    sessionHistoryLoading = false
                }

                Timer {
                    id: resourcePopoverCloseTimer
                    interval: 800
                    repeat: false
                    onTriggered: {
                        if (!resourcePopoverHover.hovered)
                            newTaskRec.hideResourcePopover()
                    }
                }

                FileDialog {
                    id: officeDownloadFolderDialog
                    title: qsTr("选择下载位置")
                    selectFolder: true
                    onAccepted: {
                        var destination = window.localFilePathFromUrl(fileUrl)
                        var copiedName = $MainViewController.copyFileToWorkspace(
                                    newTaskRec.officeDownloadSourcePath, destination)
                        errorToast.text = copiedName
                                ? qsTr("已下载：") + copiedName
                                : qsTr("下载失败，请重试")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        newTaskRec.officeDownloadSourcePath = ""
                    }
                    onRejected: newTaskRec.officeDownloadSourcePath = ""
                }

                function fileExtension(path) {
                    var name = String(path || "").replace(/\\/g, "/").split("/").pop()
                    var dot = name.lastIndexOf(".")
                    return dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
                }

                function artifactIcon(file) {
                    if (file && (file.isDirectory === true || file.folder === true
                                 || file.type === "directory" || file.type === "folder"))
                        return "qrc:/images/doc/document-fold.svg"
                    var ext = String((file && file.extension) || fileExtension(file && file.path)).toLowerCase()
                    if (ext === "doc" || ext === "docx")
                        return "qrc:/images/doc/document-word.svg"
                    if (ext === "xls" || ext === "xlsx" || ext === "xlsm" || ext === "csv")
                        return "qrc:/images/doc/document-excel.svg"
                    if (ext === "ppt" || ext === "pptx")
                        return "qrc:/images/doc/document-ppt.svg"
                    return "qrc:/images/doc/document-text.svg"
                }

                function supportsLocalViewer(file) {
                    if (!file || file.folder === true || file.isDirectory === true
                            || file.type === "directory" || file.type === "folder")
                        return false
                    if (isNeverOpenFile(file))
                        return false
                    return true
                }

                function isNeverOpenFile(file) {
                    var path = String((file && file.path) || "")
                    var ext = String((file && file.extension) || fileExtension(path)).toLowerCase()
                    // These formats are intentionally outside MedClaw's supported
                    // document scope, even when viewer-web contains a generic viewer.
                    return /^(zip|7z|rar|tar|tar\.gz|tgz|ttf|otf|woff|woff2|parquet|psd|mp4|avi|dcm)$/.test(ext)
                }

                function supportsLocalViewerEdit(file) {
                    var ext = String((file && file.extension) || fileExtension((file && file.path) || "")).toLowerCase()
                    return /^(docx|dotx|xls|xlsx|xlsm|ods|csv|tsv|pptx|pptm|md|markdown|txt|html|htm)$/.test(ext)
                }

                function openOfficeFile(file) {
                    var path = String((file && file.path) || "")
                    if (!path)
                        return
                    if (!supportsLocalViewer(file)) {
                        errorToast.text = qsTr("该文件类型不支持打开")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    var localInfo = $MainViewController.localFileInfo(path)
                    if (!localInfo || !localInfo.absolutePath) {
                        errorToast.text = qsTr("文件不存在或已被删除")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    var tabIndex = findOfficeTab(path)
                    var reloadExistingPreview = tabIndex >= 0
                    if (tabIndex < 0) {
                        officeTabs.append({
                            "name": String(file.name || path.replace(/\\/g, "/").split("/").pop()),
                            "path": path,
                            "extension": String(file.extension || fileExtension(path)),
                            "sessionKey": currentSidebarSessionKey()
                        })
                        tabIndex = officeTabs.count - 1
                    }
                    activateOfficeTab(tabIndex)
                    if (reloadExistingPreview) {
                        Qt.callLater(function() {
                            var host = officeViewsRepeater.itemAt(tabIndex)
                            if (!host || !host.officeView
                                    || tabIndex !== activeOfficeTabIndex
                                    || host.officeView.mode !== "view")
                                return
                            officePreviewPending = true
                            if (!host.officeView.open(path, "view"))
                                officePreviewPending = false
                        })
                    }
                }

                function officeTabKey(path) {
                    return String(path || "").replace(/\\/g, "/").toLowerCase()
                }

                function findOfficeTab(path, sessionKey) {
                    var key = officeTabKey(path)
                    var owner = String(sessionKey === undefined
                                       ? currentSidebarSessionKey() : sessionKey)
                    for (var i = 0; i < officeTabs.count; i++) {
                        var tab = officeTabs.get(i)
                        if (String(tab.sessionKey || "") === owner
                                && officeTabKey(tab.path) === key)
                            return i
                    }
                    return -1
                }

                function nextOfficeTabIndex(sessionKey, preferredIndex) {
                    var owner = String(sessionKey || "")
                    for (var i = Math.max(0, preferredIndex); i < officeTabs.count; i++) {
                        if (String(officeTabs.get(i).sessionKey || "") === owner)
                            return i
                    }
                    for (var j = Math.min(preferredIndex - 1, officeTabs.count - 1); j >= 0; j--) {
                        if (String(officeTabs.get(j).sessionKey || "") === owner)
                            return j
                    }
                    return -1
                }

                function activateOfficeTab(index) {
                    if (index < 0 || index >= officeTabs.count)
                        return
                    var source = officeTabs.get(index)
                    if (String(source.sessionKey || "") !== currentSidebarSessionKey())
                        return
                    var file = { name: source.name, path: source.path, extension: source.extension }
                    var path = String(file.path || "")
                    if (!path)
                        return
                    activeOfficeTabIndex = index
                    selectedOfficeFile = file
                    officeMoreMenuVisible = false
                    officeEditPending = false
                    officePreviewPending = false
                    artifactSidebarVisible = true
                    artifactSidebarMode = "preview"
                    officeSaveRequested = false
                    Qt.callLater(function() {
                        var host = officeViewsRepeater.itemAt(index)
                        if (!host || index !== activeOfficeTabIndex)
                            return
                        officeSaveRequested = host.officeClient.saving
                        if (host.officeView && host.officeView.mode === "edit")
                            artifactSidebarMode = "edit"
                    })
                }

                function closeOfficeTab(index) {
                    if (index < 0 || index >= officeTabs.count)
                        return
                    var host = officeViewsRepeater.itemAt(index)
                    if (host && host.officeView && host.officeClient.busy) {
                        host.closeWhenFinished = true
                        host.officeView.closeEditor()
                        return
                    }
                    closeOfficeTabNow(index)
                }

                function closeOfficeTabNow(index) {
                    if (index < 0 || index >= officeTabs.count)
                        return
                    var owner = String(officeTabs.get(index).sessionKey || "")
                    var wasActive = index === activeOfficeTabIndex
                    officeTabs.remove(index)
                    if (!wasActive) {
                        if (index < activeOfficeTabIndex)
                            activeOfficeTabIndex--
                        return
                    }
                    var nextIndex = nextOfficeTabIndex(owner, index)
                    if (nextIndex >= 0 && owner === currentSidebarSessionKey()) {
                        activateOfficeTab(nextIndex)
                    } else {
                        activeOfficeTabIndex = -1
                        selectedOfficeFile = ({})
                        artifactSidebarMode = "list"
                        officeSaveRequested = false
                        officeEditPending = false
                        officePreviewPending = false
                    }
                }

                function showArtifactList() {
                    artifactSidebarVisible = true
                    artifactSidebarMode = "list"
                }

                function openArtifactPath(path) {
                    var raw = String(path || "")
                    if (!raw)
                        return
                    var ws = dropdownSelectionWorkSpace.effectiveWorkspacePath || ""
                    if (!ws)
                        ws = wsClient.currentTaskWorkspace || ""
                    var resolved = $MainViewController.resolveLocalFileLink(
                                "medclaw-local:" + encodeURIComponent(raw), ws)
                    if (!resolved) {
                        console.warn("artifact file not found:", raw)
                        return
                    }
                    var info = $MainViewController.localFileInfo(resolved)
                    if (!info || !info.absolutePath) {
                        errorToast.text = qsTr("文件不存在或已被删除")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    var file = {
                        name: info.fileName || raw.replace(/\\/g, "/").split("/").pop(),
                        path: info.absolutePath,
                        extension: info.ext || fileExtension(info.absolutePath)
                    }
                    openOfficeFile(file)
                }

                function closeOfficeDocument() {
                    var owner = currentSidebarSessionKey()
                    officeSaveRequested = false
                    officeEditPending = false
                    officePreviewPending = false
                    officeMoreMenuVisible = false
                    artifactSidebarMode = "list"
                    for (var i = officeTabs.count - 1; i >= 0; i--) {
                        var tab = officeTabs.get(i)
                        if (String(tab.sessionKey || "") !== owner)
                            continue
                        var host = officeViewsRepeater.itemAt(i)
                        if (host && host.officeClient.busy)
                            host.officeClient.cancel()
                        officeTabs.remove(i)
                    }
                    selectedOfficeFile = ({})
                    activeOfficeTabIndex = -1
                    officePanelMaximized = false
                    officePanelSizeManuallySet = false
                }

                function downloadOfficeFile() {
                    var path = String(selectedOfficeFile.path || "")
                    officeMoreMenuVisible = false
                    if (!path)
                        return
                    officeDownloadSourcePath = path
                    var host = activeOfficeTabIndex >= 0
                            ? officeViewsRepeater.itemAt(activeOfficeTabIndex) : null
                    if (host && host.officeView && host.officeView.mode === "edit") {
                        host.downloadWhenFinished = true
                        if (!host.officeClient.saving) {
                            officeSaveRequested = true
                            if (!host.officeView.saveEditor()) {
                                host.downloadWhenFinished = false
                                officeSaveRequested = false
                                officeDownloadSourcePath = ""
                            }
                        }
                        return
                    }
                    officeDownloadFolderDialog.open()
                }

                function toggleArtifactSidebar() {
                    if (officeDocumentVisible) {
                        showArtifactList()
                        return
                    }
                    artifactSidebarVisible = !artifactSidebarVisible
                    artifactSidebarMode = "list"
                }

                function rebuildSessionArtifacts() {
                    var rows = chatModel.messages ? chatModel.messages() : []
                    var files = []
                    var seen = ({})
                    for (var i = 0; i < rows.length; i++) {
                        var artifacts = rows[i].artifacts || []
                        for (var j = 0; j < artifacts.length; j++) {
                            var file = artifacts[j] || {}
                            var path = String(file.path || "")
                            if (!path || seen[path])
                                continue
                            seen[path] = true
                            files.push(file)
                        }
                    }
                    sessionArtifacts = files
                }

                property int selectedShortcutGroup: 0
                property int selectedShortcutTab: 0
                property int shortcutCardOffset: 0
                readonly property int shortcutCardsPerPage: 4
                readonly property var shortcutGroups: [
                    {
                        title: "医疗科研",
                        icon: "qrc:/images/shortcut/1.png",
                        selectedIcon: "qrc:/images/shortcut/1-selected.png",
                        tabs: [
                            {
                                title: "医疗科研基础",
                                cards: [
                                    { title: "智能文献综述", detail: "快速构建研究方向的系统性文献综述", image: "qrc:/images/shortcut/1-1-1.png", prompt: "帮我在[HFpEF的SGLT2i治疗]领域做文献综述：检索近3年RCT和Meta分析，按PRISMA流程图筛选，输出主题聚类和综述初稿" },
                                    { title: "多组学数据分析", detail: "单细胞/转录组/蛋白组等多组学整合分析", image: "qrc:/images/shortcut/1-1-2.png", prompt: "帮我分析这批scRNA-seq数据：质控→降维→聚类→差异分析→富集→多组学整合，输出UMAP图、火山图、通路富集气泡图" },
                                    { title: "临床试验方案设计", detail: "辅助设计RCT方案的统计学和操作细节", image: "qrc:/images/shortcut/1-1-3.png", prompt: "帮我设计一个RCT方案：[研究问题]，计算样本量(α=0.05, power=0.8, 效应量=0.3)，生成随机分组表和SAP框架" },
                                    { title: "系统评价与Meta分析", detail: "规范化执行Meta分析完整流程", image: "qrc:/images/shortcut/1-1-4.png", prompt: "帮我做[两种治疗方案]疗效对比的Meta分析：检索→筛选→森林图/漏斗图/亚组分析/敏感性分析，输出PRISMA流程图和GRADE证据等级" },
                                    { title: "科研基金标书撰写", detail: "辅助撰写国自然/省自然基金申请书", image: "qrc:/images/shortcut/1-1-5.png", prompt: "帮我写国自然标书：[研究方向]，基于前期基础生成立项依据(含文献引用)、研究方案框架、技术路线图、可行性分析" },
                                    { title: "文献检索", detail: "围绕我的研究主题检索高质量文献，归纳研究进展、争议与空白。", image: "qrc:/images/shortcut/1-1-6.png", prompt: "围绕我的研究主题检索高质量文献，归纳研究进展、争议与空白。" },
                                    { title: "论文撰写", detail: "根据研究材料协助撰写论文，先生成符合学术规范的详细提纲。", image: "qrc:/images/shortcut/1-1-7.png", prompt: "根据研究材料协助撰写论文，先生成符合学术规范的详细提纲。" },
                                    { title: "生信分析", detail: "请根据我的生物信息数据和研究目标，制定完整、可复现的分析方案。", image: "qrc:/images/shortcut/1-1-8.png", prompt: "请根据我的生物信息数据和研究目标，制定完整、可复现的分析方案。" }
                                ]
                            },
                            {
                                title: "公共卫生与流行病学",
                                cards: [
                                    { title: "传染病暴发调查", detail: "聚集性病例的流行病学调查全流程", image: "qrc:/images/shortcut/1-2-1.png", prompt: "某学校出现聚集性发热病例，请帮我：设计个案调查表、绘制流行曲线判断传播模式、计算罹患率和RR值、提出防控措施和溯源假设" },
                                    { title: "疾病负担估算", detail: "利用DALY/YLD/YLL估算疾病负担", image: "qrc:/images/shortcut/1-2-2.png", prompt: "基于GBD方法和本地数据，估算[疾病名称]在本地DALY、YLL和YLD，对比省级和全国平均水平，识别主要风险因素贡献排序" },
                                    { title: "疫苗犹豫分析", detail: "分析接种犹豫原因并制定干预策略", image: "qrc:/images/shortcut/1-2-3.png", prompt: "某疫苗接种率持续偏低，请按3C模型(Confidence/Complacency/Convenience)分析原因，检索近3年疫苗犹豫文献，设计针对性健康教育材料和动员策略" },
                                    { title: "健康城市评估", detail: "多维度评价健康城市建设情况", image: "qrc:/images/shortcut/1-2-4.png", prompt: "按WHO健康城市指标体系和全国评价指标体系，从环境/社会/服务/人群健康4维度评估[城市名]健康城市建设，生成评估报告和改进优先级矩阵" },
                                    { title: "突发公卫事件桌面推演", detail: "模拟突发事件应急响应推演", image: "qrc:/images/shortcut/1-2-5.png", prompt: "以[新型呼吸道传染病输入]为背景设计桌面推演：设定演练场景和时间线、设计指挥部各组职责和任务、生成情景注入节点和讨论问题、输出演练总结模板" }
                                ]
                            },
                            {
                                title: "医院药事管理与临床药学",
                                cards: [
                                    { title: "个体化给药方案设计", detail: "基于TDM结果和患者特征设计剂量", image: "qrc:/images/shortcut/1-3-1.png", prompt: "患者男性65岁，CrCl 35mL/min，万古霉素谷浓度8mg/L(目标15-20)，请结合PK/PD原理给出剂量调整方案，附带Bayesian估算和后续监测计划" },
                                    { title: "药物综合评价", detail: "按《药品临床综合评价管理指南》评估", image: "qrc:/images/shortcut/1-3-2.png", prompt: "请对SGLT2i类药物进行综合评价：安全性/有效性/经济性/创新性/适宜性/可及性6维度，生成结构化评价报告和推荐意见" },
                                    { title: "抗菌药物AMS方案", detail: "制定医院AMS体系建设和改进方案", image: "qrc:/images/shortcut/1-3-3.png", prompt: "我院碳青霉烯使用强度持续偏高，请做AMS现状诊断，设计干预措施包(处方权限+预授权+反馈+教育)，制定效果评价指标和PDCA循环计划" },
                                    { title: "处方点评与合理用药分析", detail: "指定范围处方专项点评", image: "qrc:/images/shortcut/1-3-4.png", prompt: "帮我点评上月所有门诊PPI使用合理性：提取适应症/用法用量/疗程/联合用药信息，按指南标准判断合理性，生成处方点评报告和改进建议" },
                                    { title: "医药政策影响量化分析", detail: "评估集采/国谈/DRG对药事管理影响", image: "qrc:/images/shortcut/1-3-5.png", prompt: "最新一批国采执行后，基于我院过去12个月用药数据，预测费用影响、用药结构变化、可替代品种推荐、对科室药占比影响和过渡期管理建议" }
                                ]
                            }
                        ]
                    },
                    {
                        title: "日常办公",
                        icon: "qrc:/images/shortcut/2.png",
                        selectedIcon: "qrc:/images/shortcut/2-selected.png",
                        cards: [
                            { title: "文档处理", detail: "请帮我梳理这份文档的结构，提炼核心观点，并生成一份清晰的摘要。", image: "qrc:/images/shortcut/2-1.png", prompt: "请帮我梳理这份文档的结构，提炼核心观点，并生成一份清晰的摘要。" },
                            { title: "数据分析和可视化", detail: "请分析我上传的数据，识别关键趋势，并选择合适的图表完成可视化。", image: "qrc:/images/shortcut/2-2.png", prompt: "请分析我上传的数据，识别关键趋势，并选择合适的图表完成可视化。" }
                        ]
                    },
                    {
                        title: "政务助手",
                        icon: "qrc:/images/shortcut/3.png",
                        selectedIcon: "qrc:/images/shortcut/3-selected.png",
                        cards: [
                            { title: "智能公文起草", detail: "起草通知/通报/报告/请示/批复/函/纪要", image: "qrc:/images/shortcut/3-1.png", prompt: "帮我起草一份关于[事项]的通知：按GB/T 9704-2012版式，包含发文机关/文号/标题/主送/正文(缘由+事项+要求)/落款，输出规范.docx" },
                            { title: "舆情监测与研判", detail: "重大事件/政策发布后舆情分析", image: "qrc:/images/shortcut/3-2.png", prompt: "帮我看下[XXX事件]现在的舆情怎么样：多平台舆情趋势/热词/情感倾向/意见领袖观点，生成舆情分析报告和回应口径建议" },
                            { title: "政策文件智能解读", detail: "对上级政策文件进行结构化解读", image: "qrc:/images/shortcut/3-3.png", prompt: "帮我解读国务院刚出的[文件名]：按出台背景/核心要点/适用范围/影响分析/执行口径五维度输出解读报告，对照本地现行政策标注需调整条款" },
                            { title: "会议全流程管理", detail: "政府会议从筹备到纪要整理", image: "qrc:/images/shortcut/3-4.png", prompt: "帮我准备[常务会议]：收集各部门上会议题→材料完整性预审→生成议题汇总表→会后整理会议纪要(决议事项+责任部门+完成时限)→生成督查清单.docx" },
                            { title: "综合研判决策辅助", detail: "复杂议题多角度研判支持领导决策", image: "qrc:/images/shortcut/3-5.png", prompt: "帮我就[XXX问题]做综合研判：陈述已确认事实、各方观点和立场、风险评估(政治/经济/社会/法律)、提供2-3套方案比选(含利弊+推荐意见)" },
                            { title: "政策匹配", detail: "请根据个人基本情况，匹配可能享受的相关政策与申报条件（如残疾）。", image: "qrc:/images/shortcut/3-6.png", prompt: "用户信息摘要：\n项目        内容\n家庭类型：非低保收入家庭\n子女情况：有子女\n户籍情况：本镇户籍（松江区）\n年龄：69周岁\n残疾情况：下肢残疾，二级残疾证\n交通工具：有电动残疾车\n疾病情况：患有尿毒症\n\n1、从知识库中检索：残疾人政策（含干扰项）政策\n2、根据用户信息，自动匹配可以享受的政策，并以EXCEL格式直接呈现，不需要EXCEL文件；\n3、用角标的形式标注引用政策来源，点击角标可以自动在右侧查看政策对应原文；\n4、结果输出：根据知识库的：“政策匹配模板”政策匹配模板输出结果" },
                            { title: "12345分析月报", detail: "请根据《12345市民服务热线情况专报》模板，生成专报，输出PDF文件。", image: "qrc:/images/shortcut/3-7.png", prompt: "1、分析原始数据；\n2、根据《12345市民服务热线情况专报》模板，生成专报，输出PDF文件；\n3、检查报告格式：专报要保留模板的格式。包括红头文件格式，字体大小、行间距等全文本格式" }
                        ]
                    },
                    {
                        title: "情报研究",
                        icon: "qrc:/images/shortcut/4.png",
                        selectedIcon: "qrc:/images/shortcut/4-selected.png",
                        cards: [
                            { title: "治疗领域全景扫描", detail: "对目标治疗领域进行系统性竞争格局分析", image: "qrc:/images/shortcut/4-1.png", prompt: "帮我做NSCLC领域全景分析：疾病负担/当前标准治疗/在研管线热力图(靶点×阶段)/近期关键临床数据/竞争强度评估/机会缺口分析" },
                            { title: "竞品深度剖析", detail: "对重点竞品从科学到商业的全维度分析", image: "qrc:/images/shortcut/4-2.png", prompt: "帮我分析[竞品名]竞争力：靶点机制/疗效数据(mPFS/mOS/ORR)/安全性/AE谱/专利保护/商业化布局/SWOT分析" },
                            { title: "临床开发策略设计", detail: "设计CDP：适应症顺序、试验设计、注册策略", image: "qrc:/images/shortcut/4-3.png", prompt: "帮我设计[品种]临床开发策略：适应症优先级排序(PTS/可行性/竞争)、推荐试验设计框架、注册路径(加速通道评估)、里程碑规划" },
                            { title: "市场准入策略制定", detail: "制定新药上市定价、医保谈判、渠道策略", image: "qrc:/images/shortcut/4-4.png", prompt: "[品种]上市后怎么定价：参考品定价分析、国际参考定价对标、NRDL谈判策略建议、患者可及性方案、5年销售预测模型" },
                            { title: "BD机会筛选与评估", detail: "系统化筛选license标的并做初步估值", image: "qrc:/images/shortcut/4-5.png", prompt: "帮我筛选[肿瘤免疫]领域licensing机会：标的长名单/短名单、多维评分卡、初步rNPV估值范围、优先接洽建议和交易结构参考" },
                            { title: "行业研究报告生成", detail: "深度全景式研究，一次性覆盖行业全貌。生成多维度对比 HTML 行业研究报告。", image: "qrc:/images/shortcut/4-6.png", prompt: "【行业名称】：[如：新能源汽车 / 集成电路 / 生物医药]\n【时间范围】：[近3年 / 2022-2025年 / 最新]\n【地域范围】：[全国 / 某省 / 某市]\n\n1、检索：该行业相关的政策文件、市场数据、企业资料、研报资讯；\n2、按研究重点维度组织分析，生成结构化行业研究报告，报告产能布局、技术路线、销售数据、研发投入、新产品创新等多个维度；\n3、关键结论用角标标注引用来源，点击角标可查看对应原文；\n4、结果输出：输出结果为 html 格式。" },
                            { title: "行业产业链拆解", detail: "拆解某行业的产业链上下游结构，分析各环节价值分布，输出为 HTML 可视化报告。", image: "qrc:/images/shortcut/4-7.png", prompt: "【行业名称】：[如：半导体 / 新能源汽车 / 生物医药]\n【关注重点】：[价值分布 / 利润率 / 关键玩家 / 卡脖子点 / 投资切入环节（可多选）]\n\n1、基于行业认知，拆解产业链上下游结构；\n2、分析各环节价值分布、利润率、关键玩家与卡脖子点；\n3、识别高价值环节与投资切入机会；\n4、结果输出：直接生成产业链拆解报告全文，结果为 html 格式。" }
                        ]
                    },
                    {
                        title: "设备管理",
                        icon: "qrc:/images/shortcut/5.png",
                        selectedIcon: "qrc:/images/shortcut/5-selected.png",
                        cards: [
                            { title: "设备全生命周期管理", detail: "需求论证→采购→安装→使用→维护→报废", image: "qrc:/images/shortcut/5-1.png", prompt: "帮我跟踪[XX设备]的全生命周期：生成资产全周期时间轴、TCO(总拥有成本)报告、各阶段关键文档索引、换新决策建议" },
                            { title: "设备故障预测与预警", detail: "利用维修记录进行趋势分析预警", image: "qrc:/images/shortcut/5-2.png", prompt: "帮我分析近6个月全院设备故障维修记录：按设备类型/品牌/科室统计故障频次和趋势，用时间序列预测未来30天高风险设备清单和备件需求" },
                            { title: "智能预防性维护系统", detail: "基于运行数据动态优化PM策略", image: "qrc:/images/shortcut/5-3.png", prompt: "帮我优化CT的PM计划：分析近3年故障维修记录，用FMEA方法识别高RPN项，输出RCM维护策略建议和PM周期优化方案" },
                            { title: "设备采购决策支持", detail: "多源信息汇总辅助科学采购决策", image: "qrc:/images/shortcut/5-4.png", prompt: "帮我做DSA选型分析：[品牌A vs 品牌B]，多品牌技术参数对比、TCO对比(含5年维保)、投资回收期估算、用户口碑和科室适配度评分" },
                            { title: "设备利用率与ROI分析", detail: "计算大型设备投资回报率", image: "qrc:/images/shortcut/5-5.png", prompt: "帮我们核算CT的投资回报：近12月收入-成本模型、盈亏平衡点分析、投资回收期估算、敏感性分析(检查量±20%)、设备更新时机建议" }
                        ]
                    },
                    {
                        title: "投行助手",
                        icon: "qrc:/images/shortcut/6.png",
                        selectedIcon: "qrc:/images/shortcut/6-selected.png",
                        cards: [
                            { title: "行业深度研究报告", detail: "目标行业投资级行研报告", image: "qrc:/images/shortcut/6-1.png", prompt: "帮我做一份[光伏行业]深度研究：市场规模与增速建模、竞争格局(CR5/HHI)、技术路线演进、政策环境、估值分析、投资建议和标的推荐" },
                            { title: "公司尽职调查辅助", detail: "拟投公司商业/财务/法律尽调", image: "qrc:/images/shortcut/6-2.png", prompt: "帮我做[XX公司]的尽调：商业模式验证、近3年财务分析(收入/毛利/现金流真实性)、竞争优劣势评估、关联交易和股权结构分析、风险矩阵" },
                            { title: "估值模型构建", detail: "DCF/PE/PB/PS等多方法估值", image: "qrc:/images/shortcut/6-3.png", prompt: "帮我给[XX公司]估个值：三表预测、WACC计算、DCF估值+可比公司+先例交易三种方法交叉验证、敏感性分析(收入增速±5%/WACC±1%)输出龙卷风图" },
                            { title: "财务造假识别", detail: "Beneish M-Score等财务异常检测", image: "qrc:/images/shortcut/6-4.png", prompt: "帮我查[XX公司]财务有没有问题：计算Beneish M-Score/F-Score、应收账款vs收入偏离、存货周转异常、经营现金流/净利润背离、关联交易占比分析" },
                            { title: "资产配置优化", detail: "基于风险收益目标的大类资产配置", image: "qrc:/images/shortcut/6-5.png", prompt: "帮我们优化资产配置方案：收集各资产类别历史收益/波动/相关性矩阵→均值方差优化(MVO)→绘制有效前沿→输出不同风险偏好下的最优权重方案" }
                        ]
                    }
                ]

                readonly property var selectedShortcut: selectedShortcutGroup >= 0
                                                        && selectedShortcutGroup < shortcutGroups.length
                                                        ? shortcutGroups[selectedShortcutGroup] : null
                readonly property var selectedShortcutTabs: shortcutTabsFor(selectedShortcut)
                readonly property bool selectedShortcutHasTabs: (selectedShortcutTabs || []).length > 0
                readonly property var selectedShortcutCards: shortcutCardsFor(selectedShortcut,
                                                                               selectedShortcutTab)
                readonly property var visibleShortcutCards: (selectedShortcutCards || []).slice(
                                                                shortcutCardOffset,
                                                                shortcutCardOffset + shortcutCardsPerPage)
                readonly property bool canMoveShortcutCardsLeft: shortcutCardOffset > 0
                readonly property bool canMoveShortcutCardsRight: shortcutCardOffset
                                                                   < Math.max(0, (selectedShortcutCards || []).length
                                                                              - shortcutCardsPerPage)

                function shortcutTabsFor(group) {
                    var tabs = group ? group.tabs : null
                    return tabs && typeof tabs.length === "number" ? tabs : []
                }

                function shortcutCardsFor(group, tabIndex) {
                    if (!group)
                        return []
                    var tabs = shortcutTabsFor(group)
                    if (tabs.length > 0) {
                        var safeIndex = Math.max(0, Math.min(Number(tabIndex) || 0,
                                                            tabs.length - 1))
                        var tab = tabs[safeIndex]
                        return tab && tab.cards && typeof tab.cards.length === "number"
                                ? tab.cards : []
                    }
                    var cards = group.cards
                    return cards && typeof cards.length === "number" ? cards : []
                }

                function resetShortcutSelection() {
                    selectedShortcutGroup = -1
                    selectedShortcutTab = 0
                    shortcutCardOffset = 0
                }

                function clearDocxTemplateSelection(clearMatchingPrompt) {
                    if (!hasSelectedDocxTemplate)
                        return
                    var prompt = String(selectedDocxTemplate.prompt || "")
                    selectedDocxTemplate = ({})
                    if (clearMatchingPrompt && prompt
                            && String(textInputArea.text || "") === prompt)
                        textInputArea.text = ""
                }

                function selectShortcutGroup(index) {
                    if (selectedShortcutGroup === index) {
                        resetShortcutSelection()
                        return
                    }
                    selectedShortcutGroup = index
                    selectedShortcutTab = 0
                    shortcutCardOffset = 0
                }

                function selectShortcutTab(index) {
                    selectedShortcutTab = index
                    shortcutCardOffset = 0
                }

                function moveShortcutCards(delta) {
                    var cardCount = (selectedShortcutCards || []).length
                    var maxOffset = cardCount > 0
                            ? Math.floor((cardCount - 1) / shortcutCardsPerPage)
                              * shortcutCardsPerPage
                            : 0
                    shortcutCardOffset = Math.max(0, Math.min(maxOffset,
                                                              shortcutCardOffset
                                                              + delta * shortcutCardsPerPage))
                }

                function doSendMessage(requestedText, files) {
                    var msg = (requestedText === undefined
                               ? textInputArea.text : String(requestedText)).trim()
                    var submittedFiles = files || []
                    if (submittedFiles.length === 0 && textInputArea.attachedFiles.length > 0)
                        submittedFiles = textInputArea.attachedFiles.slice(0)
                    if (msg === "") return
                    if (wsClient.connectionState !== 3)
                        return
                    if (!newTaskRec.viewingControllerSession)
                        return
                    if (window.chatKnowledgeCollection
                            && !wsClient.knowledgeBaseDataDirReady) {
                        window.kbShowError(wsClient.knowledgeBaseDataDirMessage
                                           || qsTr("当前用户的知识库目录尚未就绪"))
                        return
                    }
                    var wsPath = ""
                    if (!newTaskRec.hasActiveTask) {
                        wsPath = wsClient.prepareTaskWorkspace(
                            dropdownSelectionWorkSpace.absolutePath)
                        if (!wsPath)
                            return
                    }
                    if (newTaskRec.isNewTaskWelcome)
                        // Reset the session key while preserving the model
                        // selected for this new conversation.
                        wsClient.clearActiveAgentContext(false)
                    wsClient.setPendingCollaborationAgents(
                        newTaskRec.isNewTaskWelcome ? selectedCollaborationAgentIds : [])
                    if (newTaskRec.hasSelectedDocxTemplate) {
                        var selectedTemplate = newTaskRec.selectedDocxTemplate || ({})
                        var selectedTemplateId = String(selectedTemplate.id || "").trim()
                        var templateInstruction = ""
                        if (selectedTemplate.isUserTemplate) {
                            var selectedTemplatePath = String(
                                        selectedTemplate.templatePath || "").trim()
                            if (!selectedTemplatePath) {
                                errorToast.text = qsTr("用户模板文件路径无效")
                                errorToast.visible = true
                                errorToastTimer.restart()
                                return
                            }
                            templateInstruction = "使用模板，template_path="
                                    + selectedTemplatePath
                        } else {
                            templateInstruction = "使用模板，template_pack_id="
                                    + selectedTemplateId
                        }
                        msg += "\n\n<template-parameters>\n"
                                + templateInstruction
                                + "\n使用SKILLS：report-from-template"
                                + "\n</template-parameters>"
                    }
                    textInputArea.text = ""
                    newTaskRec.selectedDocxTemplate = ({})
                    $MainViewController.sendMessage(
                        msg, wsPath, window.chatKnowledgeCollection)
                    sessionHistoryLoading = false
                    wsClient.rememberCurrentSessionInputFiles(submittedFiles)
                    sessionInputFiles = wsClient.currentSessionInputFiles()
                }

                function startDocxTemplate(template) {
                    var isUserTemplate = !!(template && template.isUserTemplate)
                    var templateId = String((template && template.id) || "").trim()
                    if (!isUserTemplate && templateId.length === 1)
                        templateId = "0" + templateId
                    if (!templateId) {
                        errorToast.text = qsTr("模板编号无效")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    var templateName = String(template.name || template.title || qsTr("预设模板"))
                    var detail = String(template.detail || template.description || "")
                    var prompt = isUserTemplate ? "" : TemplatePrompts.promptForId(templateId)
                    var templatePath = String(template.templatePath || "")
                    if (isUserTemplate && !templatePath) {
                        errorToast.text = qsTr("用户模板文件路径无效")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    if (!isUserTemplate && !prompt) {
                        errorToast.text = qsTr("该模板暂未配置提示词")
                        errorToast.visible = true
                        errorToastTimer.restart()
                        return
                    }
                    leftMidPanel.activeAgentId = ""
                    leftMidPanel.activeSessionKey = ""
                    chatModel.clear()
                    wsClient.clearActiveAgentContext()
                    selectedCollaborationAgentIds = []
                    window.chatKnowledgeCollection = ""
                    knowledgePopup.close()
                    resetShortcutSelection()
                    selectedDocxTemplate = {
                        "id": templateId,
                        "name": templateName,
                        "detail": detail,
                        "prompt": prompt,
                        "isUserTemplate": isUserTemplate,
                        "templatePath": templatePath
                    }
                    textInputArea.text = prompt
                    window.leftSelectedIndex = 0
                    Qt.callLater(function() { textInputArea.forceActiveFocus() })
                }

                Column{
                    id: titleCol
                    visible: newTaskRec.isNewTaskWelcome
                    width: Math.min(840, Math.max(320, parent.width - 48))
                    spacing: 11
                    anchors.topMargin: 80
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image{
                        source: "qrc:/images/mainTitle.png"
                        width: Math.min(implicitWidth, parent.width)
                        height: width * 89 / 431
                        fillMode: Image.PreserveAspectFit
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                Connections {
                    target: chatModel
                    function onMessagePayloadChanged() {
                        newTaskRec.rebuildSessionArtifacts()
                    }
                }
                Connections {
                    target: wsClient
                    function onCurrentViewSessionChanged() {
                        newTaskRec.beginSidebarSessionSwitch()
                    }
                    function onHistoryLoaded(messages) {
                        newTaskRec.finishSidebarSessionLoad()
                    }
                }
                Connections {
                    target: chatModel
                    function onCountChanged() {
                        newTaskRec.rebuildSessionArtifacts()
                        if (chatModel.count === 0 && !newTaskRec.sessionHistoryLoading) {
                            newTaskRec.sessionInputFiles = []
                            newTaskRec.closeOfficeDocument()
                            newTaskRec.artifactSidebarVisible = false
                        }
                        if (chatModel.count > 0)
                            newTaskRec.resetShortcutSelection()
                    }
                }
                Connections {
                    target: chatModel
                    function onIsStreamingChanged() {
                        if (chatModel.isStreaming && chatModel.count > 0)
                            chatWebView.scrollToBottom()
                    }
                }
                Connections {
                    target: leftMidPanel
                    function onActiveAgentIdChanged() {
                        var aid = leftMidPanel.activeAgentId || ""
                        if (aid.length > 0) {
                            newTaskRec.selectedCollaborationAgentIds = [aid]
                            newTaskRec.resetShortcutSelection()
                            return
                        }
                        newTaskRec.selectedCollaborationAgentIds = []
                    }
                }
                ChatWebView {
                    id: chatWebView
                    visible: newTaskRec.hasMessages
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.bottom: chatInputContainer.top
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.right: newTaskRec.artifactSidebarVisible ? artifactSidebar.left : parent.right
                    model: chatModel
                    onLinkActivated: function(link) { window.openMarkdownLink(link) }
                    onArtifactsRequested: newTaskRec.toggleArtifactSidebar()
                    onArtifactRequested: function(path) { newTaskRec.openArtifactPath(path) }
                }

                Rectangle {
                    id: artifactSidebar
                    visible: newTaskRec.artifactSidebarVisible
                    width: newTaskRec.artifactSidebarWidth
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    color: "#FFFFFF"
                    border.width: 0
                    z: 20

                    Rectangle {
                        width: 1
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: "#14000000"
                    }

                    Rectangle {
                        id: artifactListToolbar
                        visible: newTaskRec.artifactSidebarMode === "list"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 52
                        color: "#FFFFFF"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#14000000"
                        }

                        Rectangle {
                            id: artifactSortButton
                            width: 36; height: 36; radius: 8
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: artifactSortMouse.pressed ? "#14000000"
                                 : artifactSortMouse.containsMouse ? "#F7F9FA" : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 24; height: 24
                                source: "qrc:/images/office/sidebar-sort.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: artifactSortMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: newTaskRec.showResourcePopover()
                                onExited: newTaskRec.scheduleResourcePopoverClose()
                            }
                        }

                        Rectangle {
                            id: artifactSidebarToggleButton
                            width: 36; height: 36; radius: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: artifactSidebarToggleMouse.pressed ? "#14000000"
                                 : artifactSidebarToggleMouse.containsMouse ? "#F7F9FA" : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 20; height: 20
                                source: "qrc:/images/office/sidebar-collapse.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: artifactSidebarToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    newTaskRec.hideResourcePopover()
                                    newTaskRec.artifactSidebarVisible = false
                                }
                            }
                            ToolTip.visible: artifactSidebarToggleMouse.containsMouse
                            ToolTip.text: qsTr("收起文件面板")
                        }

                        Rectangle {
                            id: artifactListMaximizeButton
                            width: 36; height: 36; radius: 8
                            anchors.right: artifactSidebarToggleButton.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: artifactListMaximizeMouse.pressed ? "#14000000"
                                 : artifactListMaximizeMouse.containsMouse ? "#F7F9FA" : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: newTaskRec.officePanelMaximized
                                        ? "qrc:/images/office/sidebar-minimize.svg"
                                        : "qrc:/images/office/sidebar-maximize.svg"
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: artifactListMaximizeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    newTaskRec.officePanelMaximized = !newTaskRec.officePanelMaximized
                                    newTaskRec.officePanelSizeManuallySet = true
                                }
                            }
                            ToolTip.visible: artifactListMaximizeMouse.containsMouse
                            ToolTip.text: newTaskRec.officePanelMaximized ? qsTr("缩小文件面板") : qsTr("放大文件面板")
                        }
                    }

                    Flickable {
                        visible: newTaskRec.artifactSidebarMode === "list"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: artifactListToolbar.bottom
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 1
                        contentWidth: width
                        contentHeight: artifactSidebarColumn.implicitHeight + 40
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: artifactSidebarColumn
                            x: 16
                            y: 20
                            width: parent.width - 32
                            spacing: 24

                            Column {
                                width: parent.width
                                spacing: 8
                                visible: newTaskRec.sessionInputFiles.length > 0

                                Item {
                                    id: inputFilesHeader
                                    width: parent.width
                                    height: 24

                                    Label {
                                        id: inputFilesHeaderLabel
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("输入文件")
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.pixelSize: 16
                                        font.weight: Font.Normal
                                        color: "#73000000"
                                    }
                                    Canvas {
                                        anchors.left: inputFilesHeaderLabel.right
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16; height: 16
                                        rotation: newTaskRec.inputFilesExpanded ? 0 : -90
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = "#73000000"
                                            ctx.lineWidth = 1.2
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.beginPath()
                                            ctx.moveTo(5, 6.5)
                                            ctx.lineTo(8, 9.5)
                                            ctx.lineTo(11, 6.5)
                                            ctx.stroke()
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newTaskRec.inputFilesExpanded = !newTaskRec.inputFilesExpanded
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 4
                                    visible: newTaskRec.inputFilesExpanded
                                    Repeater {
                                        model: newTaskRec.sortedSidebarFiles(newTaskRec.sessionInputFiles)
                                        delegate: artifactSidebarFileDelegate
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 8

                                Item {
                                    id: artifactsHeader
                                    width: parent.width
                                    height: 24

                                    Label {
                                        id: artifactsHeaderLabel
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("产物")
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.pixelSize: 16
                                        font.weight: Font.Normal
                                        color: "#73000000"
                                    }
                                    Canvas {
                                        anchors.left: artifactsHeaderLabel.right
                                        anchors.leftMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 16; height: 16
                                        rotation: newTaskRec.artifactsExpanded ? 0 : -90
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = "#73000000"
                                            ctx.lineWidth = 1.2
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.beginPath()
                                            ctx.moveTo(5, 6.5)
                                            ctx.lineTo(8, 9.5)
                                            ctx.lineTo(11, 6.5)
                                            ctx.stroke()
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newTaskRec.artifactsExpanded = !newTaskRec.artifactsExpanded
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 4
                                    visible: newTaskRec.artifactsExpanded
                                    Repeater {
                                        model: newTaskRec.sortedSidebarFiles(newTaskRec.sessionArtifacts)
                                        delegate: artifactSidebarFileDelegate
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 4
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: "#40000000"
                            }
                        }
                    }

                    Item {
                        id: officeDocumentPanel
                        visible: newTaskRec.officeDocumentVisible
                        anchors.fill: parent

                        Rectangle {
                            id: officeTabsBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 52
                            color: "#FFFFFF"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: "#14000000"
                            }

                            Rectangle {
                                id: officeBackButton
                                width: 36; height: 36; radius: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: officeBackMouse.pressed ? "#14000000"
                                     : officeBackMouse.containsMouse ? "#F7F9FA" : "transparent"

                                Image {
                                    anchors.centerIn: parent
                                    width: 24; height: 24
                                    source: "qrc:/images/office/sidebar-sort.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                MouseArea {
                                    id: officeBackMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: newTaskRec.showResourcePopover()
                                    onExited: newTaskRec.scheduleResourcePopoverClose()
                                }
                            }

                            Flickable {
                                id: officeTabsViewport
                                anchors.left: officeBackButton.right
                                anchors.leftMargin: 4
                                anchors.right: officePanelButton.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                height: 36
                                contentWidth: officeTabsRow.width
                                contentHeight: height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick

                                Row {
                                    id: officeTabsRow
                                    height: parent.height
                                    spacing: 4

                                    Repeater {
                                        model: newTaskRec.officeTabs

                                        delegate: Rectangle {
                                            id: officeTab
                                            required property int index
                                            required property string name
                                            required property string path
                                            required property string extension
                                            required property string sessionKey
                                            visible: sessionKey === newTaskRec.currentSidebarSessionKey()
                                            readonly property bool active: index === newTaskRec.activeOfficeTabIndex
                                            width: Math.max(150,
                                                   (officeTabsViewport.width
                                                    - Math.max(0, newTaskRec.currentSessionOfficeTabCount - 1)
                                                      * officeTabsRow.spacing)
                                                   / Math.max(1, newTaskRec.currentSessionOfficeTabCount))
                                            height: 36
                                            radius: 8
                                            color: active ? "#EBEDF0"
                                                  : officeTabMouse.containsMouse ? "#F7F9FA" : "transparent"

                                            Image {
                                                id: officeTabIcon
                                                width: 20; height: 20
                                                anchors.left: parent.left
                                                anchors.leftMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: newTaskRec.artifactIcon({
                                                    path: officeTab.path,
                                                    extension: officeTab.extension
                                                })
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Label {
                                                anchors.left: officeTabIcon.right
                                                anchors.leftMargin: 4
                                                anchors.right: officeTabClose.left
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: officeTab.name
                                                      || String(officeTab.path || "")
                                                         .replace(/\\/g, "/").split("/").pop()
                                                elide: Text.ElideRight
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                font.pixelSize: 16
                                                color: "#D9000000"
                                            }

                                            MouseArea {
                                                id: officeTabMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: newTaskRec.activateOfficeTab(officeTab.index)
                                            }

                                            Rectangle {
                                                id: officeTabClose
                                                z: 2
                                                width: 28; height: 28; radius: 6
                                                anchors.right: parent.right
                                                anchors.rightMargin: 4
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: officeTabCloseMouse.pressed ? "#1F000000"
                                                     : officeTabCloseMouse.containsMouse ? "#14000000" : "transparent"
                                                opacity: officeTab.active || officeTabMouse.containsMouse
                                                         || officeTabCloseMouse.containsMouse ? 1 : 0

                                                Label {
                                                    anchors.centerIn: parent
                                                    text: "\u00D7"
                                                    font.pixelSize: 18
                                                    color: "#73000000"
                                                }
                                                MouseArea {
                                                    id: officeTabCloseMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: newTaskRec.closeOfficeTab(officeTab.index)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: officeSidebarToggleButton
                                width: 36; height: 36; radius: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: officeSidebarToggleMouse.pressed ? "#14000000"
                                     : officeSidebarToggleMouse.containsMouse ? "#F7F9FA" : "transparent"

                                Image {
                                    anchors.centerIn: parent
                                    width: 20; height: 20
                                    source: "qrc:/images/office/sidebar-collapse.svg"
                                    fillMode: Image.PreserveAspectFit
                                }

                                MouseArea {
                                    id: officeSidebarToggleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        newTaskRec.hideResourcePopover()
                                        newTaskRec.artifactSidebarVisible = false
                                    }
                                }

                                ToolTip.visible: officeSidebarToggleMouse.containsMouse
                                ToolTip.text: qsTr("收起文件面板")
                            }

                            Rectangle {
                                id: officePanelButton
                                width: 36; height: 36; radius: 8
                                anchors.right: officeSidebarToggleButton.left
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: officePanelMouse.pressed ? "#14000000"
                                     : officePanelMouse.containsMouse ? "#F7F9FA" : "transparent"

                                Image {
                                    anchors.centerIn: parent
                                    width: 16; height: 16
                                    source: newTaskRec.officePanelMaximized
                                            ? "qrc:/images/office/sidebar-minimize.svg"
                                            : "qrc:/images/office/sidebar-maximize.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                MouseArea {
                                    id: officePanelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        newTaskRec.officePanelMaximized = !newTaskRec.officePanelMaximized
                                        newTaskRec.officePanelSizeManuallySet = true
                                    }
                                }

                                ToolTip.visible: officePanelMouse.containsMouse
                                ToolTip.text: newTaskRec.officePanelMaximized
                                              ? qsTr("缩小文件面板") : qsTr("放大文件面板")
                            }
                        }

                        Rectangle {
                            id: officeTitleBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: officeTabsBar.bottom
                            height: 52
                            color: "#FFFFFF"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: "#14000000"
                            }

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: officeActionButton.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: newTaskRec.selectedOfficeFile.name || ""
                                elide: Text.ElideRight
                                font.family: "Alibaba PuHuiTi 3.0"
                                font.pixelSize: 20
                                font.weight: Font.Medium
                                color: "#D9000000"
                            }

                            Rectangle {
                                id: officeMoreButton
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                height: 36
                                radius: 8
                                color: newTaskRec.officeMoreMenuVisible ? "#EBEDF0"
                                     : officeMoreMouse.pressed ? "#DDE0E5"
                                     : officeMoreMouse.containsMouse ? "#EBEDF0" : "transparent"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            width: 4; height: 4; radius: 2
                                            color: "#A6000000"
                                        }
                                    }
                                }

                                MouseArea {
                                    id: officeMoreMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: newTaskRec.officeMoreMenuVisible =
                                                   !newTaskRec.officeMoreMenuVisible
                                }
                            }

                            Rectangle {
                                id: officeActionButton
                                readonly property var activeHost:
                                    officeViewsRepeater.count > newTaskRec.activeOfficeTabIndex
                                    && newTaskRec.activeOfficeTabIndex >= 0
                                    ? officeViewsRepeater.itemAt(newTaskRec.activeOfficeTabIndex) : null
                                anchors.right: officeMoreButton.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: newTaskRec.supportsLocalViewerEdit(newTaskRec.selectedOfficeFile)
                                         && newTaskRec.artifactSidebarMode === "preview"
                                width: 68
                                height: 36
                                radius: 8
                                color: officeActionMouse.pressed ? "#14000000"
                                      : officeActionMouse.containsMouse ? "#F7F9FA" : "transparent"

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Image {
                                        width: 16; height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: true
                                        source: "qrc:/images/office/edit.svg"
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("编辑")
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.pixelSize: 14
                                        color: "#A6000000"
                                    }
                                }
                                MouseArea {
                                    id: officeActionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: officeActionButton.activeHost
                                             && officeActionButton.activeHost.officeView
                                             && !newTaskRec.officeEditPending
                                             && !newTaskRec.officePreviewPending
                                             && !newTaskRec.officeSaveRequested
                                             && !officeActionButton.activeHost.officeClient.saving
                                             && String(officeActionButton.activeHost.officeClient.editorUrl || "").length > 0
                                    onClicked: {
                                        var view = officeActionButton.activeHost
                                                   ? officeActionButton.activeHost.officeView : null
                                        if (!view)
                                            return
                                        newTaskRec.officeEditPending = true
                                        newTaskRec.officePreviewPending = false
                                        newTaskRec.officePanelMaximized = true
                                        view.switchMode("edit")
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            visible: newTaskRec.officeMoreMenuVisible
                            z: 110
                            onClicked: newTaskRec.officeMoreMenuVisible = false
                        }

                        Item {
                            id: officeMoreMenu
                            visible: newTaskRec.officeMoreMenuVisible
                            width: 200
                            height: 124
                            x: Math.max(8, parent.width - width - 12)
                            y: officeTitleBar.y + officeTitleBar.height + 4
                            z: 120

                            DropShadow {
                                anchors.fill: officeMoreMenuCard
                                source: officeMoreMenuCard
                                horizontalOffset: 0
                                verticalOffset: 10
                                radius: 20
                                samples: 41
                                color: "#1F1A1A1A"
                                transparentBorder: true
                            }

                            Rectangle {
                                id: officeMoreMenuCard
                                anchors.fill: parent
                                radius: 8
                                color: "#FFFFFF"
                                border.width: 1
                                border.color: "#14000000"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    Repeater {
                                        model: [
                                            { label: qsTr("下载"), icon: "qrc:/images/office/download.svg" },
                                            { label: qsTr("打开文件夹"), icon: "qrc:/images/office/folder.svg" },
                                            { label: qsTr("使用默认软件打开"), icon: "qrc:/images/office/othersoftware.svg" }
                                        ]

                                        delegate: Rectangle {
                                            required property int index
                                            required property var modelData
                                            width: parent.width
                                            height: 36
                                            radius: 6
                                            color: officeMenuRowMouse.pressed ? "#DDE0E5"
                                                 : officeMenuRowMouse.containsMouse ? "#EBEDF0" : "transparent"

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Image {
                                                    width: 16; height: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    source: modelData.icon
                                                    fillMode: Image.PreserveAspectFit
                                                }

                                                Label {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.label
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    font.pixelSize: 14
                                                    font.weight: Font.Normal
                                                    color: "#D9000000"
                                                }
                                            }

                                            MouseArea {
                                                id: officeMenuRowMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var path = String(newTaskRec.selectedOfficeFile.path || "")
                                                    newTaskRec.officeMoreMenuVisible = false
                                                    if (!path)
                                                        return
                                                    if (index === 0) {
                                                        newTaskRec.downloadOfficeFile()
                                                    } else if (index === 1) {
                                                        if (!$MainViewController.openContainingFolder(path)) {
                                                            errorToast.text = qsTr("无法打开文件夹")
                                                            errorToast.visible = true
                                                            errorToastTimer.restart()
                                                        }
                                                    } else if (!$MainViewController.openWithDefaultApplication(path)) {
                                                        errorToast.text = qsTr("无法使用默认软件打开文件")
                                                        errorToast.visible = true
                                                        errorToastTimer.restart()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            id: officeViewsRepeater
                            model: newTaskRec.officeTabs

                            delegate: Item {
                                id: officeViewHost
                                required property int index
                                required property string name
                                required property string path
                                required property string sessionKey
                                property bool closeWhenFinished: false
                                property bool returnToPreviewAfterSave: false
                                property bool downloadWhenFinished: false
                                readonly property bool active:
                                    index === newTaskRec.activeOfficeTabIndex
                                    && sessionKey === newTaskRec.currentSidebarSessionKey()
                                readonly property var officeClient: tabOfficeLoader.item
                                property var officeView: tabOfficeLoader.item
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: officeTitleBar.bottom
                                anchors.bottom: parent.bottom
                                visible: active
                                opacity: active && newTaskRec.officePreviewPending ? 0 : 1

                                Loader {
                                    id: tabOfficeLoader
                                    anchors.fill: parent
                                    source: "qrc:/localviewer/LocalOfficeView.qml"
                                    onLoaded: {
                                        item.open(officeViewHost.path, "view")
                                    }
                                }

                                Connections {
                                    target: tabOfficeLoader.item
                                    ignoreUnknownSignals: true
                                    function onDocumentSaved(filePath) {
                                        newTaskRec.rebuildSessionArtifacts()
                                    }
                                    function onSaveFinished(filePath, saved) {
                                        if (officeViewHost.active)
                                            newTaskRec.officeSaveRequested = false
                                        var downloading = officeViewHost.downloadWhenFinished
                                        officeViewHost.downloadWhenFinished = false
                                        var returningToPreview = officeViewHost.returnToPreviewAfterSave
                                        officeViewHost.returnToPreviewAfterSave = false
                                        if (saved) {
                                            newTaskRec.rebuildSessionArtifacts()
                                            errorToast.text = (officeViewHost.name || "文档") + " 已保存"
                                            if (officeViewHost.active && returningToPreview)
                                                newTaskRec.officePreviewPending = true
                                            if (downloading && officeViewHost.active)
                                                Qt.callLater(function() { officeDownloadFolderDialog.open() })
                                        } else {
                                            if (downloading)
                                                newTaskRec.officeDownloadSourcePath = ""
                                            if (officeViewHost.active) {
                                                newTaskRec.officePreviewPending = false
                                                newTaskRec.artifactSidebarMode = "edit"
                                            }
                                            officeViewHost.closeWhenFinished = false
                                            errorToast.text = officeViewHost.officeClient.lastError
                                                    || ((officeViewHost.name || "文档") + " 保存失败，请重试")
                                        }
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                    }
                                    function onEditorLoaded(editorMode) {
                                        if (!officeViewHost.active)
                                            return
                                        if (newTaskRec.officeEditPending && editorMode === "edit") {
                                            newTaskRec.officeEditPending = false
                                            newTaskRec.artifactSidebarMode = "edit"
                                            newTaskRec.officePanelMaximized = true
                                        } else if (newTaskRec.officePreviewPending && editorMode === "view") {
                                            newTaskRec.artifactSidebarMode = "preview"
                                            newTaskRec.officePreviewPending = false
                                        }
                                    }
                                    function onSessionClosed(filePath, saved) {
                                        if (officeViewHost.active && newTaskRec.officeSaveRequested)
                                            newTaskRec.officeSaveRequested = false
                                        if (officeViewHost.closeWhenFinished) {
                                            officeViewHost.closeWhenFinished = false
                                            if (saved || (officeViewHost.officeView
                                                          && officeViewHost.officeView.mode === "view")) {
                                                Qt.callLater(function() {
                                                    newTaskRec.closeOfficeTabNow(officeViewHost.index)
                                                })
                                            } else if (officeViewHost.officeView) {
                                                Qt.callLater(function() {
                                                    officeViewHost.officeView.open(
                                                                officeViewHost.path, "edit")
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        BusyIndicator {
                            anchors.centerIn: parent
                            running: newTaskRec.officePreviewPending
                            visible: running
                            z: 30
                        }

                    }

                    Item {
                        id: resourcePopover
                        visible: newTaskRec.resourcePopoverVisible
                        x: 8
                        y: 44
                        width: Math.min(292, artifactSidebar.width - 16)
                        height: Math.min(resourcePopoverContent.implicitHeight + 24,
                                         artifactSidebar.height - y - 12)
                        z: 100

                        DropShadow {
                            anchors.fill: resourcePopoverCard
                            source: resourcePopoverCard
                            horizontalOffset: 0
                            verticalOffset: 10
                            radius: 20
                            samples: 41
                            color: "#1F1A1A1A"
                            transparentBorder: true
                        }

                        Rectangle {
                            id: resourcePopoverCard
                            anchors.fill: parent
                            radius: 8
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: "#14000000"

                            Flickable {
                                anchors.fill: parent
                                anchors.margins: 12
                                contentWidth: width
                                contentHeight: resourcePopoverContent.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Column {
                                    id: resourcePopoverContent
                                    width: parent.width
                                    spacing: 12

                                    Column {
                                        width: parent.width
                                        spacing: 8
                                        visible: newTaskRec.sessionInputFiles.length > 0

                                        Label {
                                            width: parent.width
                                            height: 24
                                            leftPadding: 8
                                            text: qsTr("输入文件")
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            font.pixelSize: 16
                                            font.weight: Font.Normal
                                            color: "#73000000"
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 4
                                            Repeater {
                                                model: newTaskRec.sessionInputFiles
                                                delegate: artifactSidebarFileDelegate
                                            }
                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        spacing: 8
                                        visible: newTaskRec.sessionArtifacts.length > 0

                                        Label {
                                            width: parent.width
                                            height: 24
                                            leftPadding: 8
                                            text: qsTr("产物")
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            font.pixelSize: 16
                                            font.weight: Font.Normal
                                            color: "#73000000"
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 4
                                            Repeater {
                                                model: newTaskRec.sessionArtifacts
                                                delegate: artifactSidebarFileDelegate
                                            }
                                        }
                                    }
                                }

                                ScrollBar.vertical: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    width: 4
                                    contentItem: Rectangle {
                                        implicitWidth: 4
                                        radius: 2
                                        color: "#40000000"
                                    }
                                }
                            }
                        }

                        HoverHandler {
                            id: resourcePopoverHover
                            target: resourcePopoverCard
                            onHoveredChanged: {
                                if (hovered)
                                    newTaskRec.keepResourcePopoverOpen()
                                else
                                    newTaskRec.leaveResourcePopover()
                            }
                        }
                    }
                }

                Component {
                    id: artifactSidebarFileDelegate
                    Rectangle {
                        id: sidebarFileRow
                        required property var modelData
                        width: parent ? parent.width : 268
                        height: 36
                        radius: 8
                        color: sidebarFileMouse.pressed ? "#14000000"
                             : sidebarFileMouse.containsMouse ? "#EBEDF0"
                             : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Image {
                                width: 20; height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                source: newTaskRec.artifactIcon(sidebarFileRow.modelData)
                                fillMode: Image.PreserveAspectFit
                            }
                            Label {
                                width: Math.max(0, parent.width - 24)
                                anchors.verticalCenter: parent.verticalCenter
                                text: sidebarFileRow.modelData.name
                                      || String(sidebarFileRow.modelData.path || "").replace(/\\/g, "/").split("/").pop()
                                elide: Text.ElideRight
                                font.family: "Alibaba PuHuiTi 3.0"
                                font.pixelSize: 16
                                font.weight: Font.Normal
                                color: "#D9000000"
                            }
                        }

                        MouseArea {
                            id: sidebarFileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                newTaskRec.hideResourcePopover()
                                newTaskRec.openOfficeFile(sidebarFileRow.modelData)
                            }
                        }
                    }
                }

                Label {
                    visible: newTaskRec.hasActiveTask && !newTaskRec.hasMessages
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.bottom: chatInputContainer.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("暂无聊天记录")
                    font.pixelSize: 14
                    color: "#66000000"
                }

                // ListView {
                //     id: chatListView
                //     visible: false
                //     anchors.top: parent.top
                //     anchors.topMargin: 16
                //     anchors.bottom: chatInputContainer.top
                //     anchors.bottomMargin: 8
                //     width: 840
                //     anchors.horizontalCenter: parent.horizontalCenter
                //     clip: true
                //     model: null
                //     spacing: 12
                //     ScrollBar.vertical: ScrollBar {
                //         policy: ScrollBar.AsNeeded
                //     }
                //     onCountChanged: {
                //         if (count > 0)
                //             chatListView.scheduleScrollToEnd()
                //     }

                //     /// 「粘底」机制：
                //     /// dataChanged / 新增行触发后，delegate 的最终高度（尤其是
                //     /// toolResult 文本块的 Text.contentHeight）可能要再过一两个
                //     /// polish/render pass 才稳定，此时单次 Qt.callLater 调用的
                //     /// positionViewAtEnd() 会按旧 contentHeight 定位，从而漏掉
                //     /// 刚刚展开的工具结果。
                //     ///
                //     /// 解决：把「需要滚到底」标记成一段时间内的待办，期间任何
                //     /// contentHeight / 几何变化都会再次 positionViewAtEnd()，
                //     /// 直到布局稳定到时间窗口结束。
                //     property bool _pendingScrollToEnd: false
                //     property bool _scrollCallLaterQueued: false
                //     Timer {
                //         id: scrollSettleTimer
                //         interval: 220
                //         repeat: false
                //         onTriggered: chatListView._pendingScrollToEnd = false
                //     }
                //     function scheduleScrollToEnd() {
                //         if (count <= 0) return
                //         _pendingScrollToEnd = true
                //         scrollSettleTimer.restart()
                //         if (_scrollCallLaterQueued) return
                //         _scrollCallLaterQueued = true
                //         Qt.callLater(function () {
                //             chatListView._scrollCallLaterQueued = false
                //             if (chatListView.count > 0)
                //                 chatListView.positionViewAtEnd()
                //         })
                //     }
                //     onContentHeightChanged: {
                //         if (_pendingScrollToEnd && count > 0)
                //             positionViewAtEnd()
                //     }
                //     onHeightChanged: {
                //         if (_pendingScrollToEnd && count > 0)
                //             positionViewAtEnd()
                //     }

                //     /// 工具卡片折叠状态记忆：key 优先用 toolCallId（稳定），
                //     /// 缺失时回退到 "idx:<index>"。值为 true 表示「已折叠」。
                //     /// ListView 滚动时会回收/重建 delegate，局部属性会被重置，
                //     /// 故必须把状态提升到 ListView 这一层持久保存。
                //     property var toolCollapsed: ({})
                //     function isToolCollapsed(callId, idx) {
                //         var k = (callId && String(callId).length > 0)
                //                 ? ("id:" + callId) : ("idx:" + idx)
                //         return toolCollapsed[k] === true
                //     }
                //     function setToolCollapsed(callId, idx, collapsed) {
                //         var k = (callId && String(callId).length > 0)
                //                 ? ("id:" + callId) : ("idx:" + idx)
                //         // QML var 属性按引用比较是否变化，必须替换为新对象才能触发绑定刷新
                //         var m = Object.assign({}, toolCollapsed)
                //         if (collapsed) m[k] = true
                //         else delete m[k]
                //         toolCollapsed = m
                //     }
                //     /// 切换会话 / 删除任务时 chatModel.clear() 会触发 modelReset，
                //     /// 顺便清掉折叠记忆，避免遗留键无限累积。
                //     Connections {
                //         target: chatModel
                //         function onModelReset() { chatListView.toolCollapsed = ({}) }
                //     }

                //     delegate: Item {
                //         width: chatListView.width
                //         readonly property bool isCompactionMarker: {
                //             var c = String(content || "").trim().toLowerCase()
                //             return msgType !== "toolCall"
                //                 && msgType !== "toolResult"
                //                 && msgRole !== "user"
                //                 && c === "compaction"
                //         }
                //         height: {
                //             if (msgType === "toolCall") return toolBlockRoot.height
                //             if (msgType === "toolResult") return orphanToolResultRoot.height
                //             if (isCompactionMarker) return compactionDivider.height
                //             return chatBubble.height
                //         }

                //         Rectangle {
                //             id: chatBubble
                //             visible: msgType !== "toolCall" && msgType !== "toolResult" && !parent.isCompactionMarker
                //             width: parent.width
                //             height: visible ? bubbleInner.height + 4 : 0
                //             color: "transparent"
                //             readonly property bool isUser: msgRole === "user"

                //             Rectangle {
                //                 id: bubbleInner
                //                 anchors.left: chatBubble.isUser ? undefined : parent.left
                //                 anchors.right: chatBubble.isUser ? parent.right : undefined
                //                 anchors.top: parent.top
                //                 readonly property real maxBubbleWidth: chatBubble.isUser ? chatBubble.width * 0.75 : chatBubble.width
                //                 readonly property real minBubbleWidth: chatBubble.isUser ? 48 : 64
                //                 width: chatBubble.isUser
                //                        ? Math.min(maxBubbleWidth,
                //                                   Math.max(minBubbleWidth, userText.implicitWidth + 32))
                //                        : maxBubbleWidth
                //                 height: (chatBubble.isUser
                //                          ? userText.implicitHeight
                //                          : (markdownLoader.item ? markdownLoader.item.implicitHeight : 24)) + 24
                //                 radius: 12
                //                 color: chatBubble.isUser ? "#EBEDF0" : "transparent"

                //                 TextEdit {
                //                     id: userText
                //                     visible: chatBubble.isUser
                //                     width: Math.max(0, parent.width - 32)
                //                     anchors.centerIn: parent
                //                     text: content || ""
                //                     textFormat: Text.PlainText
                //                     wrapMode: Text.Wrap
                //                     font.pixelSize: 16
                //                     font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                     color: "#E5000000"
                //                     readOnly: true
                //                     selectByMouse: true
                //                 }

                //                 Loader {
                //                     id: markdownLoader
                //                     active: !chatBubble.isUser
                //                     width: Math.max(0, parent.width - 32)
                //                     anchors.centerIn: parent

                //                     sourceComponent: MarkdownWebView {
                //                         // 流式时只追加 delta；结束后由 WebEngine 本地 HTML 渲染 Markdown。
                //                         width: markdownLoader.width
                //                         sourceText: content || ""
                //                         streaming: isStreaming === true
                //                         isUser: false
                //                         isIntermediate: isIntermediate || false
                //                         maxMarkdownChars: 500000
                //                         markdownDelayMs: 100
                //                         onLinkActivated: function(link) { window.openMarkdownLink(link) }

                //                         Connections {
                //                             target: chatModel
                //                             function onStreamFlushed(row, delta) {
                //                                 if (row !== index) return
                //                                 if (!delta || delta.length === 0) return
                //                                 if (markdownLoader.item)
                //                                     markdownLoader.item.append(delta)
                //                             }
                //                         }
                //                     }
                //                 }
                //             }
                //         }

                //         Rectangle {
                //             id: compactionDivider
                //             visible: parent.isCompactionMarker
                //             width: parent.width
                //             height: visible ? 20 : 0
                //             color: "transparent"

                //             Rectangle {
                //                 anchors.verticalCenter: parent.verticalCenter
                //                 anchors.left: parent.left
                //                 anchors.right: parent.right
                //                 height: 1
                //                 color: "#14000000"
                //             }
                //         }

                //         // ── 工具调用 + 结果（合并到同一行，可折叠详情）──
                //         Item {
                //             id: toolBlockRoot
                //             visible: msgType === "toolCall"
                //             width: parent.width
                //             height: visible ? toolBlockRow.implicitHeight : 0

                //             readonly property bool toolDone: hasToolResult
                //             readonly property bool toolRunning: !hasToolResult
                //             readonly property bool toolOk: hasToolResult && !isError
                //             readonly property bool toolFail: hasToolResult && isError
                //             /// 折叠态由 chatListView.toolCollapsed 持久化记忆，
                //             /// 即便 delegate 滚出可视区被回收重建，状态也不会丢失。
                //             readonly property bool toolDetailExpanded:
                //                 !chatListView.isToolCollapsed(toolCallId, index)

                //             Column {
                //                 id: toolBlockRow
                //                 width: parent.width
                //                 spacing: 0

                //                 Row {
                //                     id: toolHeaderRow
                //                     width: parent.width
                //                     spacing: 8
                //                     height: 28

                //                     Item {
                //                         width: 20
                //                         height: 20
                //                         anchors.verticalCenter: parent.verticalCenter
                //                         Rectangle {
                //                             id: toolHeaderRunDot
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolRunning
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#006BFF"
                //                         }
                //                         SequentialAnimation {
                //                             running: toolBlockRoot.toolRunning && toolBlockRoot.visible
                //                             loops: Animation.Infinite
                //                             NumberAnimation {
                //                                 target: toolHeaderRunDot
                //                                 property: "opacity"
                //                                 from: 0.35; to: 1; duration: 650
                //                                 easing.type: Easing.InOutQuad
                //                             }
                //                             NumberAnimation {
                //                                 target: toolHeaderRunDot
                //                                 property: "opacity"
                //                                 from: 1; to: 0.35; duration: 650
                //                                 easing.type: Easing.InOutQuad
                //                             }
                //                         }
                //                         Text {
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolOk
                //                             text: "\u2713"
                //                             color: "#56CA00"
                //                             font.pixelSize: 16
                //                             font.bold: true
                //                         }
                //                         Rectangle {
                //                             anchors.centerIn: parent
                //                             visible: toolBlockRoot.toolFail
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#EF4444"
                //                         }
                //                     }

                //                     Row {
                //                         spacing: 4
                //                         anchors.verticalCenter: parent.verticalCenter

                //                         Text {
                //                             text: toolName || qsTr("工具")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             font.bold: true
                //                             color: "#D9000000"
                //                         }

                //                         Text {
                //                             id: toolChevron
                //                             text: toolBlockRoot.toolDetailExpanded ? "\u25BE" : "\u25B8"
                //                             font.pixelSize: 14
                //                             color: "#99000000"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             MouseArea {
                //                                 anchors.fill: parent
                //                                 anchors.margins: -6
                //                                 cursorShape: Qt.PointingHandCursor
                //                                 onClicked: chatListView.setToolCollapsed(
                //                                                toolCallId, index,
                //                                                toolBlockRoot.toolDetailExpanded)
                //                             }
                //                         }

                //                     }
                //                 }

                //                 Column {
                //                     width: parent.width
                //                     visible: toolBlockRoot.toolDetailExpanded
                //                     spacing: 8

                //                     Row {
                //                         id: toolBlockDetailRow
                //                         width: parent.width
                //                         spacing: 10
                //                         leftPadding: 9
                //                         Rectangle {
                //                             id: toolTimelineBar
                //                             width: 1
                //                             height: toolCallResultStack.height
                //                             radius: 1
                //                             color: "#E6E7EB"
                //                         }

                //                         Column {
                //                             id: toolCallResultStack
                //                             width: toolBlockRoot.width - toolTimelineBar.width - toolBlockDetailRow.spacing - 8
                //                             spacing: 8

                //                             Rectangle {
                //                                 id: toolArgsRect
                //                                 width: parent.width
                //                                 visible: toolArgs && String(toolArgs).length > 0
                //                                 readonly property real _toolArgsPad: 10
                //                                 readonly property real _toolArgsMaxH: 200
                //                                 height: visible ? toolArgsText.contentHeight + 2 * _toolArgsPad + 2 : 0
                //                                 radius: 8
                //                                 color: "#F3F4F6"
                //                                 border.width: 1
                //                                 border.color: "#E5E7EB"
                //                                 clip: true

                //                                 Flickable {
                //                                     id: toolArgsFlick
                //                                     anchors.fill: parent
                //                                     anchors.margins: 1
                //                                     clip: true
                //                                     flickableDirection: Flickable.AutoFlickIfNeeded
                //                                     contentWidth: toolArgsText.contentWidth + 2 * toolArgsRect._toolArgsPad
                //                                     contentHeight: toolArgsText.contentHeight + 2 * toolArgsRect._toolArgsPad
                //                                     boundsBehavior: Flickable.StopAtBounds

                //                                     ScrollBar.horizontal: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }
                //                                     ScrollBar.vertical: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }

                //                                     Text {
                //                                         id: toolArgsText
                //                                         x: toolArgsRect._toolArgsPad
                //                                         y: toolArgsRect._toolArgsPad
                //                                         width: Math.max(
                //                                                    implicitWidth,
                //                                                    toolArgsFlick.width - 2 * toolArgsRect._toolArgsPad)
                //                                         text: toolArgs || ""
                //                                         wrapMode: Text.Wrap
                //                                         font.pixelSize: 14
                //                                         font.family: "Consolas, Courier New, Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                                         color: "#A6000000"
                //                                         // selectByMouse: true
                //                                         // readOnly: true
                //                                         // textFormat: Text.MarkdownText
                //                                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                                     }
                //                                 }
                //                             }

                //                             Rectangle {
                //                                 id: toolResultRect
                //                                 width: parent.width
                //                                 visible: hasToolResult && String(toolResultText).length > 0
                //                                 readonly property real _toolResPad: 10
                //                                 readonly property real _toolResMaxH: 320
                //                                 height: visible ? toolResultBody.contentHeight + 2 * _toolResPad + 2 : 0
                //                                 radius: 8
                //                                 color: "#F3F4F6"
                //                                 border.width: 1
                //                                 border.color: isError ? "#FECACA" : "#E5E7EB"
                //                                 clip: true

                //                                 Flickable {
                //                                     id: toolResultFlick
                //                                     anchors.fill: parent
                //                                     anchors.margins: 1
                //                                     clip: true
                //                                     flickableDirection: Flickable.AutoFlickIfNeeded
                //                                     contentWidth: toolResultBody.contentWidth + 2 * toolResultRect._toolResPad
                //                                     contentHeight: toolResultBody.contentHeight + 2 * toolResultRect._toolResPad
                //                                     boundsBehavior: Flickable.StopAtBounds

                //                                     ScrollBar.horizontal: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }
                //                                     ScrollBar.vertical: ScrollBar {
                //                                         policy: ScrollBar.AsNeeded
                //                                     }

                //                                     Text {
                //                                         id: toolResultBody
                //                                         x: toolResultRect._toolResPad
                //                                         y: toolResultRect._toolResPad
                //                                         width: Math.max(
                //                                                    implicitWidth,
                //                                                    toolResultFlick.width - 2 * toolResultRect._toolResPad)
                //                                         text: toolResultText || ""
                //                                         wrapMode: Text.Wrap
                //                                         font.pixelSize: 14
                //                                         font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                                         color: isError ? "#FF3D40" : "#A6000000"
                //                                         // textFormat: Text.MarkdownText
                //                                         // readOnly: true
                //                                         // selectByMouse: true
                //                                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                                     }
                //                                 }
                //                             }
                //                         }
                //                     }

                //                     Row {
                //                         width: parent.width
                //                         visible: toolBlockRoot.toolRunning
                //                         spacing: 8
                //                         height: 24
                //                         Item {
                //                             width: 20
                //                             height: 20
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             Rectangle {
                //                                 id: toolFooterRunDot
                //                                 anchors.centerIn: parent
                //                                 width: 8
                //                                 height: 8
                //                                 radius: 4
                //                                 color: "#006BFF"
                //                             }
                //                             SequentialAnimation {
                //                                 running: toolBlockRoot.toolRunning && toolBlockRoot.visible
                //                                 loops: Animation.Infinite
                //                                 NumberAnimation {
                //                                     target: toolFooterRunDot
                //                                     property: "opacity"
                //                                     from: 0.35; to: 1; duration: 650
                //                                     easing.type: Easing.InOutQuad
                //                                 }
                //                                 NumberAnimation {
                //                                     target: toolFooterRunDot
                //                                     property: "opacity"
                //                                     from: 1; to: 0.35; duration: 650
                //                                     easing.type: Easing.InOutQuad
                //                                 }
                //                             }
                //                         }
                //                         Text {
                //                             text: qsTr("执行中…")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             color: "#006BFF"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                     }
                //                     Row {
                //                         width: parent.width
                //                         visible: hasToolResult
                //                         spacing: 8
                //                         height: 24

                //                         Item {
                //                             width: 20
                //                             height: 20
                //                             anchors.verticalCenter: parent.verticalCenter
                //                             Text {
                //                                 anchors.centerIn: parent
                //                                 visible: toolBlockRoot.toolOk
                //                                 text: "\u2713"
                //                                 color: "#56CA00"
                //                                 font.pixelSize: 16
                //                                 font.bold: true
                //                             }
                //                             Rectangle {
                //                                 anchors.centerIn: parent
                //                                 visible: toolBlockRoot.toolFail
                //                                 width: 8
                //                                 height: 8
                //                                 radius: 4
                //                                 color: "#EF4444"
                //                             }
                //                         }

                //                         Text {
                //                             text: isError ? qsTr("任务失败") : qsTr("任务完成")
                //                             font.pixelSize: 16
                //                             font.family: "Alibaba PuHuiTi 3.0"
                //                             color: isError ? "#FF3D40" : "#16A34A"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                     }
                //                 }
                //             }
                //         }

                //         // 未匹配到 toolCall 的孤立 toolResult（兼容）
                //         Item {
                //             id: orphanToolResultRoot
                //             visible: msgType === "toolResult"
                //             width: parent.width
                //             height: visible ? orphanToolCol.implicitHeight + 24 : 0

                //             Rectangle {
                //                 anchors.fill: parent
                //                 radius: 8
                //                 color: "#F3F4F6"
                //                 border.width: 1
                //                 border.color: isError ? "#FECACA" : "#E5E7EB"

                //                 Column {
                //                     id: orphanToolCol
                //                     width: parent.width - 24
                //                     x: 12
                //                     y: 12
                //                     spacing: 6

                //                     Row {
                //                         spacing: 8
                //                         Text {
                //                             visible: !isError
                //                             text: "\u2713"
                //                             color: "#56CA00"
                //                             font.pixelSize: 14
                //                             font.bold: true
                //                         }
                //                         Rectangle {
                //                             visible: isError
                //                             width: 8
                //                             height: 8
                //                             radius: 4
                //                             color: "#EF4444"
                //                             anchors.verticalCenter: parent.verticalCenter
                //                         }
                //                         Text {
                //                             text: toolName
                //                             font.pixelSize: 13
                //                             font.bold: true
                //                             color: "#D9000000"
                //                         }
                //                     }
                //                     Text {
                //                         width: parent.width
                //                         text: content || ""
                //                         wrapMode: Text.Wrap
                //                         font.pixelSize: 12
                //                         font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                //                         color: isError ? "#FF3D40" : "#A6000000"
                //                         textFormat: Text.MarkdownText
                //                         // readOnly: true
                //                         // selectByMouse: true
                //                         onLinkActivated: function(link) { window.openMarkdownLink(link) }
                //                     }
                //                 }
                //             }
                //         }
                //     }
                // }

                Rectangle{
                    id: chatInputContainer
                    readonly property int defaultTextInputHeight: 66
                    readonly property int maxTextInputHeight: 220
                    readonly property int currentTextInputHeight: newTaskRec.selectedShortcut
                                                                  ? defaultTextInputHeight
                                                                  : Math.min(maxTextInputHeight,
                                                                             Math.max(defaultTextInputHeight,
                                                                                      Math.ceil(textInputArea.textContentHeight) + 12))
                    border.color: "#40000000"
                    border.width: 1
                    radius: 20
                    height: currentTextInputHeight + 76
                    readonly property real availableWidth: Math.max(320, parent.width
                                                                    - newTaskRec.artifactSidebarWidth)
                    width: Math.min(840, Math.max(320, availableWidth - 48))
                    x: Math.max(0, (availableWidth - width) / 2)
                    y: newTaskRec.isNewTaskWelcome
                       ? shortcutTopRow.y + shortcutTopRow.height + 20
                       : newTaskRec.height - height - 24
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    clip: true
                    Column{
                        anchors.fill: parent
                        padding: 12
                        spacing: 8

                        PromptComposer {
                            id: textInputArea
                            focusedBorderColor: "transparent"
                            backgroundColor: "transparent"
                            borderWidth: 0
                            placeholderText: wsClient.connectionState === 3
                                             ? (newTaskRec.viewingControllerSession
                                                ? "分配一个任务或提问任何问题"
                                                : "当前为子 Agent 记录，仅支持查看")
                                             : "正在连接服务器，请稍候..."
                            width: parent.width - 24
                            height: chatInputContainer.currentTextInputHeight
                            readOnly: wsClient.connectionState !== 3 || !newTaskRec.viewingControllerSession
                            onSubmitRequested: function(message, files) {
                                newTaskRec.doSendMessage(message, files)
                            }
                            onLinkActivated: function(link) {
                                window.openMarkdownLink(link)
                            }
                        }
                        Rectangle{
                            height: 40
                            width: parent.width - 24
                            Row {
                                anchors.fill: parent
                                spacing: 4
                                Item {
                                    id: workspaceDialogSlot
                                    width: newTaskRec.isNewTaskWelcome
                                           ? (chatInputContainer.width < 700 ? 110 : 137) : 0
                                    height: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Item {
                                    id: modelPickerWrap
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: chatInputContainer.width < 700 ? 160 : 220
                                    height: 36
                                    property var modelIds: []

                                    function qualifyModelRef(mid, pv) {
                                        if (!mid)
                                            return ""
                                        if (!pv)
                                            return mid
                                        if (mid.indexOf(pv + "/") === 0)
                                            return mid
                                        return pv + "/" + mid
                                    }

                                    function rebuildFromGateway() {
                                        var list = wsClient.modelList || []
                                        var labels = []
                                        var ids = []
                                        for (var i = 0; i < list.length; i++) {
                                            var m = list[i]
                                            var mid = m.id || ""
                                            if (!mid)
                                                continue
                                            var nm = m.name || mid
                                            var pv = m.provider || ""
                                            labels.push(window.modelDisplayLabel(nm, pv))
                                            ids.push(qualifyModelRef(mid, pv))
                                        }
                                        modelIds = ids
                                        if (labels.length === 0) {
                                            dropdownSelectionModel.model = [qsTr("无可用模型")]
                                            dropdownSelectionModel.currentIndex = 0
                                            return
                                        }
                                        dropdownSelectionModel.model = labels
                                        if (dropdownSelectionModel.currentIndex >= labels.length)
                                            dropdownSelectionModel.currentIndex = 0
                                        syncIndexFromGateway()
                                    }

                                    function syncIndexFromGateway() {
                                        // 优先级：pending（用户最近一次点选的模型，sessions.patch 响应到达前的"意图"）
                                        //     →  currentModel（服务端已确认的运行时模型）
                                        // 否则保留 DropdownSelect 当前 currentIndex，避免下拉框被中间状态拉回旧选项。
                                        var cur = wsClient.pendingSessionModelId || ""
                                        if (!cur && wsClient.currentSessionKey && wsClient.currentSessionKey.length > 0) {
                                            var cm = wsClient.currentModel || {}
                                            cur = qualifyModelRef(cm.model || "",
                                                                  cm.modelProvider || "")
                                        }
                                        var ids = modelIds
                                        if (!cur || ids.length === 0)
                                            return
                                        for (var j = 0; j < ids.length; j++) {
                                            if (ids[j] === cur) {
                                                dropdownSelectionModel.currentIndex = j
                                                return
                                            }
                                        }
                                    }

                                    readonly property bool modelPickerEnabled: wsClient.connectionState === 3

                                    Connections {
                                        target: wsClient
                                        function onModelListChanged() { modelPickerWrap.rebuildFromGateway() }
                                        function onCurrentModelChanged() { modelPickerWrap.syncIndexFromGateway() }
                                        function onCurrentSessionChanged() { modelPickerWrap.syncIndexFromGateway() }
                                        function onPendingSessionModelIdChanged() { modelPickerWrap.syncIndexFromGateway() }
                                    }

                                    DropdownSelect {
                                        id: dropdownSelectionModel
                                        anchors.fill: parent
                                        model: [qsTr("加载中…")]
                                        icon: "qrc:/images/ai.png"
                                        iconSize: 16
                                        currentIndex: 0
                                        alignment: Qt.AlignLeft
                                        popupMaxWidth: 320
                                        popupMaxHeight: 280
                                        onSelected: function(index, text) {
                                            if (modelPickerWrap.modelIds.length === 0)
                                                return
                                            if (index < 0 || index >= modelPickerWrap.modelIds.length)
                                                return
                                            wsClient.patchSessionModel(modelPickerWrap.modelIds[index])
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        visible: !modelPickerWrap.modelPickerEnabled
                                        hoverEnabled: false
                                        onClicked: {}
                                    }
                                }
                                Item {
                                    id: templateSelectionTag
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: newTaskRec.isNewTaskWelcome
                                             && newTaskRec.hasSelectedDocxTemplate
                                    width: visible
                                           ? Math.min(chatInputContainer.width < 700 ? 180 : 240,
                                                      templateTagRow.implicitWidth + 24)
                                           : 0
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: "#F0F2F5"

                                        Row {
                                            id: templateTagRow
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Image {
                                                width: 16
                                                height: 16
                                                source: "qrc:/images/chosenTemplate.png"
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                width: Math.min(chatInputContainer.width < 700 ? 116 : 176,
                                                                implicitWidth)
                                                text: String(newTaskRec.selectedDocxTemplate.name || "")
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Image {
                                                width: 16
                                                height: 16
                                                source: "qrc:/images/close.png"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: templateTagCloseMouse.containsMouse ? 1 : 0.65
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: templateTagCloseMouse
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: newTaskRec.clearDocxTemplateSelection(true)
                                                }
                                            }
                                        }
                                    }
                                }
                                Item {
                                    id: knowledgePickerWrap
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool expertSelected:
                                            window.chatHasSelectedExpert()
                                    readonly property bool templateSelected:
                                            newTaskRec.hasSelectedDocxTemplate
                                    readonly property string selectedName: window.chatKnowledgeCollection
                                            ? window.kbCollectionName(window.chatKnowledgeCollection)
                                            : qsTr("知识库")
                                    visible: !expertSelected && !templateSelected
                                    width: visible
                                           ? Math.min(220, Math.max(104, knowledgeTriggerTextMetrics.advanceWidth + 58))
                                           : 0
                                    height: 36

                                    Rectangle {
                                        id: knowledgeTrigger
                                        anchors.fill: parent
                                        radius: 8
                                        color: knowledgeTriggerMouse.pressed ? "#14000000"
                                             : knowledgeTriggerMouse.containsMouse ? "#0A000000"
                                             : "transparent"

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Image {
                                                width: 16
                                                height: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: window.chatKnowledgeCollection
                                                        ? "qrc:/images/knowledgeSelected.png"
                                                        : "qrc:/images/knowledge.png"
                                                fillMode: Image.PreserveAspectFit
                                            }

                                            Label {
                                                width: Math.max(0, knowledgePickerWrap.width - 54)
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: knowledgePickerWrap.selectedName
                                                elide: Text.ElideRight
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                            }
                                        }

                                        Canvas {
                                            width: 16
                                            height: 16
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            rotation: knowledgePopup.visible ? 180 : 0

                                            Behavior on rotation {
                                                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                            }

                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.reset()
                                                ctx.strokeStyle = "#73000000"
                                                ctx.lineWidth = 1.2
                                                ctx.lineCap = "round"
                                                ctx.lineJoin = "round"
                                                ctx.beginPath()
                                                ctx.moveTo(5, 6.5)
                                                ctx.lineTo(8, 9.5)
                                                ctx.lineTo(11, 6.5)
                                                ctx.stroke()
                                            }
                                        }

                                        MouseArea {
                                            id: knowledgeTriggerMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (window.kbCollections.length === 0)
                                                    return
                                                if (knowledgePopup.visible)
                                                    knowledgePopup.close()
                                                else
                                                    knowledgePopup.open()
                                            }
                                        }
                                    }

                                    TextMetrics {
                                        id: knowledgeTriggerTextMetrics
                                        text: knowledgePickerWrap.selectedName
                                        font.pixelSize: 14
                                        font.family: "Alibaba PuHuiTi 3.0"
                                    }

                                    Popup {
                                        id: knowledgePopup
                                        x: 0
                                        y: -height - 8
                                        width: 212
                                        height: Math.min(260, window.kbCollections.length * 40 + 16)
                                        padding: 8
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                                        background: Rectangle {
                                            radius: 8
                                            color: "#FFFFFF"
                                            border.width: 1
                                            border.color: "#14000000"
                                        }

                                        contentItem: ListView {
                                            clip: true
                                            model: window.kbCollections
                                            boundsBehavior: Flickable.StopAtBounds
                                            ScrollBar.vertical: ScrollBar {
                                                policy: ScrollBar.AsNeeded
                                            }

                                            delegate: Rectangle {
                                                id: knowledgeOption
                                                readonly property string collectionId: String(modelData.id || "")
                                                readonly property bool selected: window.chatKnowledgeCollection === collectionId
                                                width: ListView.view.width
                                                height: 40
                                                radius: 6
                                                color: knowledgeOptionMouse.pressed ? "#14000000"
                                                     : knowledgeOptionMouse.containsMouse ? "#0A000000"
                                                     : "transparent"

                                                Image {
                                                    width: 16
                                                    height: 16
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    source: "qrc:/images/knowledge.png"
                                                    fillMode: Image.PreserveAspectFit
                                                }

                                                Label {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 38
                                                    anchors.right: knowledgeCheck.left
                                                    anchors.rightMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: String(modelData.name || qsTr("未命名知识库"))
                                                    elide: Text.ElideRight
                                                    font.pixelSize: 14
                                                    color: "#D9000000"
                                                }

                                                Canvas {
                                                    id: knowledgeCheck
                                                    width: 16
                                                    height: 16
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: knowledgeOption.selected

                                                    onPaint: {
                                                        var ctx = getContext("2d")
                                                        ctx.reset()
                                                        ctx.strokeStyle = "#D9000000"
                                                        ctx.lineWidth = 1.8
                                                        ctx.lineCap = "round"
                                                        ctx.lineJoin = "round"
                                                        ctx.beginPath()
                                                        ctx.moveTo(3.5, 8)
                                                        ctx.lineTo(6.7, 11)
                                                        ctx.lineTo(12.5, 4.8)
                                                        ctx.stroke()
                                                    }
                                                }

                                                MouseArea {
                                                    id: knowledgeOptionMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        window.kbToggleChatCollection(knowledgeOption.collectionId)
                                                        knowledgePopup.close()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                Item {
                                    id: expertSelectionTag
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property string expertId: {
                                        var ids = newTaskRec.selectedCollaborationAgentIds || []
                                        return ids.length > 0 ? String(ids[0] || "") : ""
                                    }
                                    readonly property string expertName: {
                                        var list = wsClient.agentList || []
                                        for (var i = 0; i < list.length; i++) {
                                            if (String(list[i].id || "") === expertId)
                                                return list[i].name || list[i].id || ""
                                        }
                                        return expertId
                                    }
                                    visible: newTaskRec.isNewTaskWelcome && expertId.length > 0
                                    width: visible ? Math.min(chatInputContainer.width < 700 ? 180 : 240,
                                                              expertTagRow.implicitWidth + 24) : 0
                                    height: 36

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: "#F7F9FA"

                                        Row {
                                            id: expertTagRow
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Image {
                                                width: 16
                                                height: 16
                                                source: "qrc:/images/expert.png"
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                width: Math.min(170, implicitWidth)
                                                text: expertSelectionTag.expertName
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Image {
                                                id: expertTagCloseIcon
                                                width: 20
                                                height: 20
                                                source: "qrc:/images/close.png"
                                                fillMode: Image.PreserveAspectFit
                                                opacity: expertTagCloseMouse.containsMouse ? 1 : 0.65
                                                anchors.verticalCenter: parent.verticalCenter

                                                MouseArea {
                                                    id: expertTagCloseMouse
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: newTaskRec.selectedCollaborationAgentIds = []
                                                }
                                            }
                                        }
                                    }
                                }
                                CollaborationPicker {
                                    id: collaborationPicker
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: newTaskRec.hasActiveTask
                                             && wsClient.collaborationParticipants
                                             && wsClient.collaborationParticipants.length > 1
                                    width: visible ? implicitWidth : 0
                                    height: 36
                                    participants: wsClient.collaborationParticipants || []
                                    currentSessionKey: (wsClient.currentViewSessionKey || "")
                                                       || (wsClient.currentTaskSessionKey || "")
                                    controllerRunning: chatModel.isStreaming
                                    onSessionSelected: function(sessionKey) {
                                        wsClient.switchCollaborationViewSession(sessionKey)
                                    }
                                }
                                // Item {
                                //     id: dropdownSelectionSkill
                                //     visible: false
                                //     anchors.verticalCenter: parent.verticalCenter
                                //     width: 0
                                //     height: 36

                                //     property var selectedSkills: []
                                //     property string searchText: ""

                                //     function syncFromWsClient() {
                                //         // 与工具开关一致：未在侧栏选中 agent 时默认全选；有暂存则显示暂存（待 agents.create 后写入）
                                //         var aid = leftMidPanel.activeAgentId || ""
                                //         if (aid === "") {
                                //             if (wsClient.pendingNewAgentSkillPolicySet) {
                                //                 selectedSkills = wsClient.pendingNewAgentSkillNames()
                                //                 return
                                //             }
                                //             var arr = []
                                //             var list = wsClient.skillList || []
                                //             for (var i = 0; i < list.length; i++) {
                                //                 if (list[i].enabled === false)
                                //                     continue
                                //                 var n = list[i].name || list[i].skillKey || ""
                                //                 if (n) arr.push(n)
                                //             }
                                //             selectedSkills = arr
                                //             return
                                //         }
                                //         selectedSkills = wsClient.selectedSkillNamesForAgent(aid)
                                //     }

                                //     Connections {
                                //         target: wsClient
                                //         function onSkillListChanged() {
                                //             dropdownSelectionSkill.syncFromWsClient()
                                //         }
                                //     }
                                //     Connections {
                                //         target: wsClient
                                //         function onAgentIdentityChanged() {
                                //             dropdownSelectionSkill.syncFromWsClient()
                                //         }
                                //     }
                                //     Connections {
                                //         target: leftMidPanel
                                //         function onActiveAgentIdChanged() {
                                //             dropdownSelectionSkill.syncFromWsClient()
                                //         }
                                //     }
                                //     Connections {
                                //         target: wsClient
                                //         function onPendingNewAgentSkillPolicyChanged() {
                                //             dropdownSelectionSkill.syncFromWsClient()
                                //         }
                                //     }

                                //     function isSelected(name) {
                                //         for (var i = 0; i < selectedSkills.length; i++) {
                                //             if (selectedSkills[i] === name) return true
                                //         }
                                //         return false
                                //     }

                                //     function toggleSkill(name) {
                                //         var arr = selectedSkills.slice()
                                //         var idx = -1
                                //         for (var i = 0; i < arr.length; i++) {
                                //             if (arr[i] === name) { idx = i; break }
                                //         }
                                //         if (idx >= 0) arr.splice(idx, 1)
                                //         else arr.push(name)
                                //         selectedSkills = arr

                                //         if ((leftMidPanel.activeAgentId || "") === "") {
                                //             wsClient.setPendingNewAgentSkillSelection(arr)
                                //             return
                                //         }
                                //         var aid = leftMidPanel.activeAgentId
                                //         wsClient.setAgentSkillEnabled(aid, name, idx < 0)
                                //     }

                                //     function filteredSkills() {
                                //         var list = wsClient.skillList || []
                                //         var enabledOnly = []
                                //         for (var j = 0; j < list.length; j++) {
                                //             if (list[j].enabled === false)
                                //                 continue
                                //             enabledOnly.push(list[j])
                                //         }
                                //         list = enabledOnly
                                //         if (!searchText) return list
                                //         var result = []
                                //         for (var i = 0; i < list.length; i++) {
                                //             var n = (list[i].name || list[i].skillKey || "").toLowerCase()
                                //             if (n.indexOf(searchText.toLowerCase()) >= 0)
                                //                 result.push(list[i])
                                //         }
                                //         return result
                                //     }

                                //     Rectangle {
                                //         id: skillButton
                                //         anchors.fill: parent
                                //         radius: 8
                                //         color: skillMouseArea.pressed ? "#14000000"
                                //              : skillMouseArea.containsMouse ? "#0A000000"
                                //              : "transparent"
                                //         Behavior on color { ColorAnimation { duration: 100 } }

                                //         Row {
                                //             id: skillBtnRow
                                //             spacing: 6
                                //             anchors.verticalCenter: parent.verticalCenter
                                //             anchors.left: parent.left
                                //             anchors.leftMargin: 12

                                //             Image {
                                //                 source: "qrc:/images/category.png"
                                //                 width: 16; height: 16
                                //                 anchors.verticalCenter: parent.verticalCenter
                                //                 fillMode: Image.PreserveAspectFit
                                //                 sourceSize: Qt.size(16, 16)
                                //             }
                                //             // Text {
                                //             //     text: "技能"
                                //             //     font.pixelSize: 14
                                //             //     font.family: "Alibaba PuHuiTi 3.0"
                                //             //     color: "#D9000000"
                                //             //     anchors.verticalCenter: parent.verticalCenter
                                //             // }

                                //             Text {
                                //                 id: skillsText
                                //                 text: "技能"
                                //                 font.pixelSize: 14
                                //                 font.family: "Alibaba PuHuiTi 3.0"
                                //                 color: "#D9000000"
                                //                 anchors.verticalCenter: parent.verticalCenter
                                //                 visible: skillPopup.visible
                                //             }
                                //             Rectangle {
                                //                 visible: dropdownSelectionSkill.selectedSkills.length > 0
                                //                 width: badgeText.width + 8
                                //                 height: 20
                                //                 radius: 10
                                //                 color: "#14000000"
                                //                 anchors.verticalCenter: parent.verticalCenter

                                //                 Text {
                                //                     id: badgeText
                                //                     text: dropdownSelectionSkill.selectedSkills.length
                                //                     font.pixelSize: 12
                                //                     font.family: "Alibaba PuHuiTi 3.0"
                                //                     color: "#73000000"
                                //                     anchors.centerIn: parent
                                //                 }
                                //             }
                                //         }

                                //         // Canvas {
                                //         //     id: skillChevron
                                //         //     width: 16; height: 16
                                //         //     anchors.right: parent.right
                                //         //     anchors.rightMargin: 12
                                //         //     anchors.verticalCenter: parent.verticalCenter
                                //         //     rotation: skillPopup.visible ? 180 : 0
                                //         //     Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                //         //     onPaint: {
                                //         //         var ctx = getContext("2d")
                                //         //         ctx.reset()
                                //         //         ctx.strokeStyle = "#80000000"
                                //         //         ctx.lineWidth = 1.5
                                //         //         ctx.lineCap = "round"
                                //         //         ctx.lineJoin = "round"
                                //         //         ctx.beginPath()
                                //         //         ctx.moveTo(4, 6)
                                //         //         ctx.lineTo(8, 10)
                                //         //         ctx.lineTo(12, 6)
                                //         //         ctx.stroke()
                                //         //     }
                                //         // }

                                //         MouseArea {
                                //             id: skillMouseArea
                                //             anchors.fill: parent
                                //             hoverEnabled: true
                                //             cursorShape: Qt.PointingHandCursor
                                //             onClicked: skillPopup.visible ? skillPopup.close() : skillPopup.open()
                                //         }
                                //     }

                                //     Popup {
                                //         id: skillPopup
                                //         x: 0
                                //         width: 220
                                //         padding: 8
                                //         closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                //         function calcY() {
                                //             var globalPos = dropdownSelectionSkill.mapToItem(null, 0, 0)
                                //             var windowH = window.height
                                //             var popupH = Math.min(contentItem.implicitHeight, 300 + 50) + padding * 2
                                //             if (popupH < 60)
                                //                 popupH = 360
                                //             if (globalPos.y + dropdownSelectionSkill.height + 4 + popupH > windowH)
                                //                 return -popupH - 4
                                //             return dropdownSelectionSkill.height + 4
                                //         }

                                //         y: calcY()

                                //         onAboutToShow: {
                                //             skillSearchInput.text = ""
                                //             y = calcY()
                                //         }
                                //         onOpened: Qt.callLater(function() { y = calcY() })

                                //         background: Rectangle {
                                //             radius: 8
                                //             color: "#FFFFFF"
                                //             border.color: "#14000000"
                                //             border.width: 1
                                //             layer.enabled: true
                                //             layer.effect: DropShadow {
                                //                 transparentBorder: true
                                //                 radius: 12
                                //                 samples: 25
                                //                 color: "#1A000000"
                                //             }
                                //         }

                                //         contentItem: Column {
                                //             spacing: 6

                                //             Row {
                                //                 width: parent.width
                                //                 spacing: 6

                                //                 SingleLineTextInput {
                                //                     id: skillSearchInput
                                //                     inputWidth: parent.width - skillSettingPopBtn.width - 6
                                //                     inputHeight: 32
                                //                     inputRadius: 6
                                //                     icon: "qrc:/images/search.png"
                                //                     iconSize: 14
                                //                     fontSize: 13
                                //                     placeholderText: qsTr("搜索技能")
                                //                     onTextChanged: dropdownSelectionSkill.searchText = text
                                //                 }

                                //                 ImageButton {
                                //                     id: skillSettingPopBtn
                                //                     source: "qrc:/images/setting.png"
                                //                     anchors.verticalCenter: parent.verticalCenter
                                //                     onClicked: {
                                //                         skillPopup.close()
                                //                         window.leftSelectedIndex = 3
                                //                     }
                                //                 }
                                //             }

                                //             Flickable {
                                //                 id: skillListFlick
                                //                 width: parent.width
                                //                 height: Math.min(skillListCol.height, 300)
                                //                 contentHeight: skillListCol.height
                                //                 clip: true
                                //                 boundsBehavior: Flickable.StopAtBounds

                                //                 Column {
                                //                     id: skillListCol
                                //                     width: parent.width
                                //                     spacing: 2

                                //                     Repeater {
                                //                         model: dropdownSelectionSkill.filteredSkills()

                                //                         delegate: Rectangle {
                                //                             width: skillPopup.width - 16
                                //                             height: 36
                                //                             radius: 6
                                //                             color: skillItemMouse.pressed ? "#14000000"
                                //                                  : skillItemMouse.containsMouse ? "#0A000000"
                                //                                  : "transparent"
                                //                             Behavior on color { ColorAnimation { duration: 100 } }

                                //                             Row {
                                //                                 spacing: 8
                                //                                 anchors.verticalCenter: parent.verticalCenter
                                //                                 anchors.left: parent.left
                                //                                 anchors.leftMargin: 8

                                //                                 Image {
                                //                                     width: 20; height: 20
                                //                                     visible: !modelData.emoji
                                //                                     source: "qrc:/images/skillIcon.png"

                                //                                     fillMode: Image.PreserveAspectFit
                                //                                     anchors.verticalCenter: parent.verticalCenter
                                //                                 }
                                //                                 Label {
                                //                                     width: 20
                                //                                     height: 20
                                //                                     visible: modelData.emoji
                                //                                     font.pixelSize: 14
                                //                                     text: modelData.emoji
                                //                                     horizontalAlignment: Text.AlignHCenter
                                //                                     verticalAlignment: Text.AlignVCenter
                                //                                     anchors.verticalCenter: parent.verticalCenter
                                //                                     font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                                //                                 }
                                //                                 Text {
                                //                                     id: skilPopNameLabel
                                //                                     width: skillPopup.width - 16 - 16 - 20 - 16 - 16
                                //                                     text: modelData.name || modelData.skillKey || ""
                                //                                     font.pixelSize: 14
                                //                                     font.family: "Alibaba PuHuiTi 3.0"
                                //                                     color: "#D9000000"
                                //                                     anchors.verticalCenter: parent.verticalCenter
                                //                                     elide: Text.ElideRight
                                //                                     ToolTip {
                                //                                         visible: skillItemMouse.containsMouse && skilPopNameLabel.truncated
                                //                                         text: skilPopNameLabel.text
                                //                                         delay: 500
                                //                                         x: 0
                                //                                         y: skilPopNameLabel.height + 4
                                //                                         width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                //                                         background: Rectangle {
                                //                                             color: "#A6000000"
                                //                                             radius: 4
                                //                                         }
                                //                                         contentItem: Text {
                                //                                             text: skilPopNameLabel.text
                                //                                             font.pixelSize: 14
                                //                                             color: "#FFFFFF"
                                //                                             font.family: "Alibaba PuHuiTi 3.0"
                                //                                             wrapMode: Text.Wrap
                                //                                         }
                                //                                     }
                                //                                 }
                                //                             }

                                //                             Canvas {
                                //                                 visible: dropdownSelectionSkill.isSelected(modelData.name || modelData.skillKey)
                                //                                 width: 16; height: 16
                                //                                 anchors.right: parent.right
                                //                                 anchors.rightMargin: 8
                                //                                 anchors.verticalCenter: parent.verticalCenter
                                //                                 onVisibleChanged: requestPaint()
                                //                                 onPaint: {
                                //                                     var ctx = getContext("2d")
                                //                                     ctx.reset()
                                //                                     ctx.strokeStyle = "#006BFF"
                                //                                     ctx.lineWidth = 2
                                //                                     ctx.lineCap = "round"
                                //                                     ctx.lineJoin = "round"
                                //                                     ctx.beginPath()
                                //                                     ctx.moveTo(3, 8)
                                //                                     ctx.lineTo(6.5, 11.5)
                                //                                     ctx.lineTo(13, 4.5)
                                //                                     ctx.stroke()
                                //                                 }
                                //                             }

                                //                             MouseArea {
                                //                                 id: skillItemMouse
                                //                                 anchors.fill: parent
                                //                                 hoverEnabled: true
                                //                                 cursorShape: Qt.PointingHandCursor
                                //                                 onClicked: dropdownSelectionSkill.toggleSkill(modelData.name || modelData.skillKey)
                                //                             }
                                //                         }
                                //                     }
                                //                 }

                                //                 ScrollBar.vertical: ScrollBar {
                                //                     policy: skillListFlick.contentHeight > skillListFlick.height
                                //                             ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                //                     width: 4
                                //                     contentItem: Rectangle {
                                //                         implicitWidth: 4
                                //                         radius: 2
                                //                         color: "#40000000"
                                //                     }
                                //                 }
                                //             }
                                //         }

                                //         enter: Transition {
                                //             NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                //             NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                //         }
                                //         exit: Transition {
                                //             NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                                //         }
                                //     }
                                // }
                                // Item {
                                //     id: dropdownSelectionTool
                                //     visible: false
                                //     anchors.verticalCenter: parent.verticalCenter
                                //     width: 0
                                //     height: 36

                                //     property var selectedToolIds: []
                                //     property string toolSearchText: ""

                                //     function syncToolsFromWsClient() {
                                //         var arr = []
                                //         var list = wsClient.toolList
                                //         var isExisting = leftMidPanel.activeAgentId !== ""
                                //         if (isExisting) {
                                //             for (var i = 0; i < list.length; i++) {
                                //                 if (list[i].enabled)
                                //                     arr.push(list[i].toolId)
                                //             }
                                //         } else {
                                //             for (var i = 0; i < list.length; i++)
                                //                 arr.push(list[i].toolId)
                                //         }
                                //         selectedToolIds = arr
                                //     }

                                //     Connections {
                                //         target: wsClient
                                //         function onToolListChanged() {
                                //             dropdownSelectionTool.syncToolsFromWsClient()
                                //         }
                                //     }

                                //     function isToolSelected(toolId) {
                                //         for (var i = 0; i < selectedToolIds.length; i++) {
                                //             if (selectedToolIds[i] === toolId) return true
                                //         }
                                //         return false
                                //     }

                                //     function toggleToolLocal(toolId) {
                                //         var arr = selectedToolIds.slice()
                                //         var idx = -1
                                //         for (var i = 0; i < arr.length; i++) {
                                //             if (arr[i] === toolId) { idx = i; break }
                                //         }
                                //         if (idx >= 0) arr.splice(idx, 1)
                                //         else arr.push(toolId)
                                //         selectedToolIds = arr
                                //         applyToolSelectionImmediately()
                                //     }

                                //     /// 勾选/取消后立即同步到网关（或暂存到首个 agent 创建时写入）
                                //     function applyToolSelectionImmediately() {
                                //         var aid = leftMidPanel.activeAgentId
                                //         if (aid === "") {
                                //             wsClient.setPendingNewAgentToolSelection(selectedToolIds)
                                //             return
                                //         }
                                //         wsClient.batchSetAgentToolsEnabled(aid, selectedToolIds)
                                //     }

                                //     function filteredTools() {
                                //         var list = wsClient.toolList
                                //         if (!toolSearchText) return list
                                //         var result = []
                                //         var q = toolSearchText.toLowerCase()
                                //         for (var i = 0; i < list.length; i++) {
                                //             var label = (list[i].label || list[i].toolId || "").toLowerCase()
                                //             if (label.indexOf(q) >= 0)
                                //                 result.push(list[i])
                                //         }
                                //         return result
                                //     }

                                //     Rectangle {
                                //         id: toolButton2
                                //         anchors.fill: parent
                                //         radius: 8
                                //         readonly property bool toolStripHover: toolIconMouse.containsMouse
                                //         color: toolIconMouse.pressed ? "#14000000"
                                //              : toolStripHover ? "#0A000000"
                                //              : "transparent"
                                //         Behavior on color { ColorAnimation { duration: 100 } }
                                //         MouseArea {
                                //             id: toolIconMouse
                                //             anchors.fill: parent
                                //             hoverEnabled: true
                                //             cursorShape: Qt.PointingHandCursor
                                //             onClicked: toolPopup2.visible ? toolPopup2.close() : toolPopup2.open()
                                //         }
                                //         Row {
                                //             id: toolBtnRow2
                                //             spacing: 6
                                //             anchors.verticalCenter: parent.verticalCenter
                                //             anchors.left: parent.left
                                //             anchors.leftMargin: 12

                                //             Item {
                                //                 id: toolOpenZone
                                //                 height: 36
                                //                 width: toolOpenInnerRow.width

                                //                 Row {
                                //                     id: toolOpenInnerRow
                                //                     anchors.verticalCenter: parent.verticalCenter
                                //                     spacing: 6

                                //                     Image {
                                //                         id: toolMainIcon
                                //                         source: "qrc:/images/tools.png"
                                //                         width: 16
                                //                         height: 16
                                //                         anchors.verticalCenter: parent.verticalCenter
                                //                         fillMode: Image.PreserveAspectFit
                                //                         sourceSize: Qt.size(16, 16)
                                //                     }

                                //                     Text {
                                //                         id: toolText
                                //                         text: "tools"
                                //                         font.pixelSize: 14
                                //                         font.family: "Alibaba PuHuiTi 3.0"
                                //                         color: "#D9000000"
                                //                         anchors.verticalCenter: parent.verticalCenter
                                //                         visible: toolPopup2.visible
                                //                     }

                                //                     Rectangle {
                                //                         id: toolCountBadge
                                //                         visible: dropdownSelectionTool.selectedToolIds.length > 0
                                //                         width: toolBadgeText.width + 8
                                //                         height: 20
                                //                         radius: 10
                                //                         color: "#14000000"
                                //                         anchors.verticalCenter: parent.verticalCenter

                                //                         Text {
                                //                             id: toolBadgeText
                                //                             text: dropdownSelectionTool.selectedToolIds.length
                                //                             font.pixelSize: 12
                                //                             font.family: "Alibaba PuHuiTi 3.0"
                                //                             color: "#73000000"
                                //                             anchors.centerIn: parent
                                //                         }
                                //                     }
                                //                 }
                                //             }

                                //         }
                                //     }

                                //     Popup {
                                //         id: toolPopup2
                                //         x: 0
                                //         width: 260
                                //         padding: 8
                                //         closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                //         function calcY() {
                                //             var globalPos = dropdownSelectionTool.mapToItem(null, 0, 0)
                                //             var windowH = window.height
                                //             var popupH = Math.min(contentItem.implicitHeight, 300 + 80) + padding * 2
                                //             if (popupH < 60)
                                //                 popupH = 400
                                //             if (globalPos.y + dropdownSelectionTool.height + 4 + popupH > windowH)
                                //                 return -popupH - 4
                                //             return dropdownSelectionTool.height + 4
                                //         }

                                //         y: calcY()

                                //         onAboutToShow: {
                                //             dropdownSelectionTool.syncToolsFromWsClient()
                                //             toolSearchInput2.text = ""
                                //             y = calcY()
                                //         }
                                //         onOpened: Qt.callLater(function() { y = calcY() })

                                //         background: Rectangle {
                                //             color: "#FFFFFF"
                                //             radius: 12
                                //             border.color: "#14000000"
                                //             border.width: 1
                                //             layer.enabled: true
                                //             layer.effect: DropShadow {
                                //                 transparentBorder: true
                                //                 radius: 12
                                //                 samples: 25
                                //                 color: "#1A000000"
                                //             }
                                //         }

                                //         contentItem: Column {
                                //             spacing: 6
                                //             width: toolPopup2.width - 16
                                //             Row {
                                //                 width: parent.width
                                //                 spacing: 6

                                //                 SingleLineTextInput {
                                //                     id: toolSearchInput2
                                //                     inputWidth: parent.width - toolSettingBtn2.width - 6
                                //                     inputHeight: 32
                                //                     inputRadius: 6
                                //                     icon: "qrc:/images/search.png"
                                //                     iconSize: 14
                                //                     fontSize: 13
                                //                     placeholderText: qsTr("搜索工具")
                                //                     onTextChanged: dropdownSelectionTool.toolSearchText = text
                                //                 }

                                //                 ImageButton {
                                //                     id: toolSettingBtn2
                                //                     source: "qrc:/images/setting.png"
                                //                     anchors.verticalCenter: parent.verticalCenter
                                //                     onClicked: {
                                //                         toolPopup2.close()
                                //                         window.leftSelectedIndex = 4
                                //                     }
                                //                 }
                                //             }
                                //             Flickable {
                                //                 id: toolListFlick2
                                //                 width: parent.width
                                //                 height: Math.min(toolListCol2.height, 300)
                                //                 contentHeight: toolListCol2.height
                                //                 clip: true
                                //                 boundsBehavior: Flickable.StopAtBounds

                                //                 Column {
                                //                     id: toolListCol2
                                //                     width: parent.width
                                //                     spacing: 2

                                //                     Repeater {
                                //                         model: dropdownSelectionTool.filteredTools()

                                //                         delegate: Rectangle {
                                //                             width: toolPopup2.width - 16
                                //                             height: 36
                                //                             radius: 6
                                //                             color: toolItemMouse2.pressed ? "#14000000"
                                //                                  : toolItemMouse2.containsMouse ? "#0A000000"
                                //                                  : "transparent"
                                //                             Behavior on color { ColorAnimation { duration: 100 } }

                                //                             Row {
                                //                                 spacing: 8
                                //                                 anchors.verticalCenter: parent.verticalCenter
                                //                                 anchors.left: parent.left
                                //                                 anchors.leftMargin: 8

                                //                                 Text {
                                //                                     id: toolPopNameLabel
                                //                                     width: toolPopup2.width - 16 - 16 - 16 - 16
                                //                                     text: modelData.label || modelData.toolId || ""
                                //                                     font.pixelSize: 14
                                //                                     font.family: "Alibaba PuHuiTi 3.0"
                                //                                     color: "#D9000000"
                                //                                     anchors.verticalCenter: parent.verticalCenter
                                //                                     elide: Text.ElideRight
                                //                                     ToolTip {
                                //                                         visible: toolItemMouse2.containsMouse && toolPopNameLabel.truncated
                                //                                         text: toolPopNameLabel.text
                                //                                         delay: 500
                                //                                         x: 0
                                //                                         y: toolPopNameLabel.height + 4
                                //                                         background: Rectangle {
                                //                                             color: "#A6000000"
                                //                                             radius: 4
                                //                                         }
                                //                                         contentItem: Text {
                                //                                             text: toolPopNameLabel.text
                                //                                             font.pixelSize: 14
                                //                                             color: "#FFFFFF"
                                //                                             font.family: "Alibaba PuHuiTi 3.0"
                                //                                             wrapMode: Text.Wrap
                                //                                         }
                                //                                     }
                                //                                 }
                                //                             }

                                //                             Canvas {
                                //                                 visible: dropdownSelectionTool.isToolSelected(modelData.toolId)
                                //                                 width: 16; height: 16
                                //                                 anchors.right: parent.right
                                //                                 anchors.rightMargin: 8
                                //                                 anchors.verticalCenter: parent.verticalCenter
                                //                                 onVisibleChanged: requestPaint()
                                //                                 onPaint: {
                                //                                     var ctx = getContext("2d")
                                //                                     ctx.reset()
                                //                                     ctx.strokeStyle = "#006BFF"
                                //                                     ctx.lineWidth = 2
                                //                                     ctx.lineCap = "round"
                                //                                     ctx.lineJoin = "round"
                                //                                     ctx.beginPath()
                                //                                     ctx.moveTo(3, 8)
                                //                                     ctx.lineTo(6.5, 11.5)
                                //                                     ctx.lineTo(13, 4.5)
                                //                                     ctx.stroke()
                                //                                 }
                                //                             }

                                //                             MouseArea {
                                //                                 id: toolItemMouse2
                                //                                 anchors.fill: parent
                                //                                 hoverEnabled: true
                                //                                 cursorShape: Qt.PointingHandCursor
                                //                                 onClicked: dropdownSelectionTool.toggleToolLocal(modelData.toolId)
                                //                             }
                                //                         }
                                //                     }
                                //                 }

                                //                 ScrollBar.vertical: ScrollBar {
                                //                     policy: toolListFlick2.contentHeight > toolListFlick2.height
                                //                             ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                //                     width: 4
                                //                     contentItem: Rectangle {
                                //                         implicitWidth: 4
                                //                         radius: 2
                                //                         color: "#40000000"
                                //                     }
                                //                 }
                                //             }

                                //             Text {
                                //                 visible: dropdownSelectionTool.filteredTools().length === 0
                                //                 text: dropdownSelectionTool.toolSearchText
                                //                       ? qsTr("未找到匹配的工具")
                                //                       : qsTr("暂无可用工具")
                                //                 font.pixelSize: 13
                                //                 font.family: "Alibaba PuHuiTi 3.0"
                                //                 color: "#80000000"
                                //                 width: parent.width
                                //                 horizontalAlignment: Text.AlignHCenter
                                //                 topPadding: 16
                                //                 bottomPadding: 16
                                //             }
                                //         }

                                //         enter: Transition {
                                //             NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                //             NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                //         }
                                //         exit: Transition {
                                //             NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                                //         }
                                //     }
                                // }
                                Rectangle{
                                    width: Math.max(0, parent.width - workspaceDialogSlot.width
                                                    - dropdownSelectionModel.width
                                                    - templateSelectionTag.width
                                                    - knowledgePickerWrap.width
                                                    - expertSelectionTag.width
                                                    - collaborationPicker.width
                                                    - inputLeftRow.width - 7 * 4)
                                    height: 1
                                }
                                Row{
                                    id: inputLeftRow
                                    height: parent.height
                                    spacing: 24
                                    ImageButton{
                                        id: uploadBtn
                                        btnHeight: 20
                                        btnWidth: 20
                                        source: "qrc:/images/paperclip.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: uploadMenu.open()

                                        Popup {
                                            id: uploadMenu
                                            y: -uploadMenu.height - 8
                                            x: -20
                                            width: 130
                                            padding: 4
                                            background: Rectangle {
                                                radius: 8
                                                color: "#FFFFFF"
                                                border.color: "#14000000"
                                                border.width: 1
                                                layer.enabled: true
                                                layer.effect: DropShadow {
                                                    radius: 12; samples: 25
                                                    color: "#26000000"
                                                    verticalOffset: 4
                                                }
                                            }
                                            Column {
                                                width: parent.width
                                                Rectangle {
                                                    width: parent.width; height: 34; radius: 6
                                                    color: umFile.containsMouse ? "#F0F2F5" : "transparent"
                                                    Label {
                                                        text: qsTr("上传文件")
                                                        font.pixelSize: 14; color: "#D9000000"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left; anchors.leftMargin: 10
                                                    }
                                                    MouseArea {
                                                        id: umFile; anchors.fill: parent
                                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { uploadMenu.close(); attachFileDialog.open() }
                                                    }
                                                }
                                                Rectangle {
                                                    width: parent.width; height: 34; radius: 6
                                                    color: umFolder.containsMouse ? "#F0F2F5" : "transparent"
                                                    Label {
                                                        text: qsTr("上传文件夹")
                                                        font.pixelSize: 14; color: "#D9000000"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left; anchors.leftMargin: 10
                                                    }
                                                    MouseArea {
                                                        id: umFolder; anchors.fill: parent
                                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: { uploadMenu.close(); attachFolderDialog.open() }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    FileDialog {
                                        id: attachFileDialog
                                        title: qsTr("选择文件")
                                        selectMultiple: true
                                        onAccepted: {
                                            for (var i = 0; i < fileUrls.length; i++) {
                                                var url = fileUrls[i].toString()
                                                var path = window.localFilePathFromUrl(url)
                                                var parts = path.split(/[\\\/]/)
                                                var name = parts[parts.length - 1] || path
                                                textInputArea.insertFile(name, path, false)
                                            }
                                        }
                                    }
                                    FileDialog {
                                        id: attachFolderDialog
                                        title: qsTr("选择文件夹")
                                        selectFolder: true
                                        onAccepted: {
                                            var url = fileUrl.toString()
                                            var path = window.localFilePathFromUrl(url).replace(/[\\\/]+$/, "")
                                            var parts = path.split(/[\\\/]/)
                                            var name = parts[parts.length - 1] || path
                                            textInputArea.insertFile(name, path, true)
                                        }
                                    }
                                    Rectangle{
                                        width: 1
                                        height: 16
                                        color: "#1F000000"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    CustomButton{
                                        id: sendBtnRec
                                        buttonWidth: 40
                                        buttonHeight: 40
                                        buttonRadius: 12
                                        text: ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        enabled: textInputArea.text !== "" && newTaskRec.viewingControllerSession
                                        backgroundColor: "#006BFF"
                                        iconSource: "qrc:/images/send.png"
                                        onClicked: textInputArea.submit()
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: welcomeShortcutLayer
                    visible: newTaskRec.isNewTaskWelcome
                    anchors.fill: parent
                    z: 2

                    Row {
                        id: shortcutTopRow
                        height: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: titleCol.y + titleCol.height + 60
                        spacing: 0

                        Repeater {
                            model: newTaskRec.shortcutGroups

                            delegate: Item {
                                id: shortcutTabItem
                                readonly property var group: modelData
                                readonly property bool selected: index === newTaskRec.selectedShortcutGroup
                                width: shortcutTab.width + (index < newTaskRec.shortcutGroups.length - 1 ? 25 : 0)
                                height: shortcutTopRow.height

                                Rectangle {
                                    id: shortcutTab
                                    width: tabContent.implicitWidth + 24
                                    height: 36
                                    radius: 18
                                    color: shortcutTabItem.selected ? "#006BFF"
                                          : tabMouse.containsMouse ? "#F5F7FA" : "transparent"

                                    Row {
                                        id: tabContent
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Image {
                                            width: 18
                                            height: 18
                                            source: shortcutTabItem.selected
                                                    ? shortcutTabItem.group.selectedIcon
                                                    : shortcutTabItem.group.icon
                                            fillMode: Image.PreserveAspectFit
                                            sourceSize: Qt.size(40, 40)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Label {
                                            text: shortcutTabItem.group.title
                                            font.pixelSize: 16
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            color: shortcutTabItem.selected ? "#FFFFFF" : "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newTaskRec.selectShortcutGroup(index)
                                    }
                                }

                                Rectangle {
                                    visible: index < newTaskRec.shortcutGroups.length - 1
                                    width: 1
                                    height: 16
                                    x: shortcutTab.width + 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#E6E7EB"
                                }
                            }
                        }
                    }

                    Item {
                        id: shortcutCardHeader
                        visible: !!newTaskRec.selectedShortcut
                        width: chatInputContainer.width
                        height: 30
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: chatInputContainer.y + chatInputContainer.height + 60

                        Row {
                            id: medicalShortcutTabs
                            visible: newTaskRec.selectedShortcutHasTabs
                            height: parent.height
                            spacing: 20

                            Repeater {
                                model: newTaskRec.selectedShortcutTabs

                                delegate: Item {
                                    id: medicalShortcutTab
                                    readonly property bool selected: index === newTaskRec.selectedShortcutTab
                                    width: medicalTabLabel.implicitWidth
                                    height: medicalShortcutTabs.height

                                    Label {
                                        id: medicalTabLabel
                                        text: modelData.title
                                        font.pixelSize: 16
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: medicalShortcutTab.selected ? "#006BFF" : "#73000000"
                                        anchors.top: parent.top
                                    }

                                    Rectangle {
                                        visible: medicalShortcutTab.selected
                                        width: parent.width
                                        height: 2
                                        radius: 1
                                        color: "#006BFF"
                                        anchors.bottom: parent.bottom
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newTaskRec.selectShortcutTab(index)
                                    }
                                }
                            }
                        }

                        Label {
                            visible: !newTaskRec.selectedShortcutHasTabs
                            text: "不知道做什么，试试最佳实践案例"
                            font.pixelSize: 16
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#73000000"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: leftCardArrowMouse.containsMouse
                                       && newTaskRec.canMoveShortcutCardsLeft ? "#F2F4F7" : "transparent"
                                opacity: newTaskRec.canMoveShortcutCardsLeft ? 1 : 0.35

                                Label {
                                    text: "‹"
                                    font.pixelSize: 20
                                    color: "#73000000"
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                }

                                MouseArea {
                                    id: leftCardArrowMouse
                                    anchors.fill: parent
                                    enabled: newTaskRec.canMoveShortcutCardsLeft
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: newTaskRec.moveShortcutCards(-1)
                                }
                            }

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: rightCardArrowMouse.containsMouse
                                       && newTaskRec.canMoveShortcutCardsRight ? "#F2F4F7" : "transparent"
                                opacity: newTaskRec.canMoveShortcutCardsRight ? 1 : 0.35

                                Label {
                                    text: "›"
                                    font.pixelSize: 20
                                    color: "#73000000"
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                }

                                MouseArea {
                                    id: rightCardArrowMouse
                                    anchors.fill: parent
                                    enabled: newTaskRec.canMoveShortcutCardsRight
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: newTaskRec.moveShortcutCards(1)
                                }
                            }
                        }
                    }

                    Item {
                        id: shortcutCardViewport
                        visible: shortcutCardHeader.visible
                        width: shortcutCardHeader.width
                        height: 100
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: shortcutCardHeader.bottom
                        anchors.topMargin: 10
                        clip: true

                        Row {
                            id: shortcutCardRow
                            spacing: 8

                            Repeater {
                                model: newTaskRec.visibleShortcutCards

                                delegate: Rectangle {
                                    id: shortcutLargeCard
                                    readonly property var card: modelData
                                    width: (shortcutCardViewport.width
                                            - shortcutCardRow.spacing
                                              * (newTaskRec.shortcutCardsPerPage - 1))
                                           / newTaskRec.shortcutCardsPerPage
                                    height: shortcutCardViewport.height
                                    radius: 8
                                    color: "#F7F9FC"
                                    border.width: 1
                                    border.color: largeCardMouse.containsMouse ? "#99B9FF" : "#E6E7EB"
                                    clip: true

                                    Image {
                                        id: shortcutCardImage
                                        anchors.fill: parent
                                        source: shortcutLargeCard.card.image
                                        fillMode: Image.Stretch
                                        sourceSize: Qt.size(204, 100)
                                    }

                                    FastBlur {
                                        anchors.fill: parent
                                        source: shortcutCardImage
                                        radius: 24
                                        transparentBorder: false
                                        visible: largeCardMouse.containsMouse
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#CFFFFFFF"
                                        visible: largeCardMouse.containsMouse
                                    }

                                    Label {
                                        visible: largeCardMouse.containsMouse
                                        text: shortcutLargeCard.card.detail
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        font.pixelSize: 13
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.weight: Font.Medium
                                        color: "#D9000000"
                                        wrapMode: Text.Wrap
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignLeft
                                    }

                                    MouseArea {
                                        id: largeCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            textInputArea.text = shortcutLargeCard.card.prompt
                                            textInputArea.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: workspaceHiddenSlot
                width: 1
                height: 1
                visible: false
                anchors.top: parent.top
                anchors.left: parent.left
            }

            Item {
                id: dropdownSelectionWorkSpace
                width: 137
                height: 36
                z: 10

                readonly property string wsPlaceState: newTaskRec.isNewTaskWelcome ? "dialog"
                    : ((window.leftSelectedIndex === 0 || window.leftSelectedIndex === 6) ? "topbar" : "hidden")

                state: wsPlaceState

                states: [
                    State {
                        name: "dialog"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: true }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceDialogSlot
                        }
                        AnchorChanges {
                            target: dropdownSelectionWorkSpace
                            anchors.left: workspaceDialogSlot.left
                            anchors.right: workspaceDialogSlot.right
                            anchors.top: workspaceDialogSlot.top
                            anchors.bottom: workspaceDialogSlot.bottom
                        }
                    },
                    State {
                        name: "topbar"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: true }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceTopBarSlot
                        }
                        AnchorChanges {
                            target: dropdownSelectionWorkSpace
                            anchors.verticalCenter: workspaceTopBarSlot.verticalCenter
                            anchors.horizontalCenter: workspaceTopBarSlot.horizontalCenter
                        }
                    },
                    State {
                        name: "hidden"
                        PropertyChanges { target: dropdownSelectionWorkSpace; visible: false }
                        ParentChange {
                            target: dropdownSelectionWorkSpace
                            parent: workspaceHiddenSlot
                        }
                    }
                ]

                property string currentText: qsTr("workspace")
                property string absolutePath: ""
                property var recentFolders: []

                readonly property bool pickerLocked: newTaskRec.hasMessages || window.leftSelectedIndex === 6
                readonly property string effectiveWorkspacePath: {
                    if (pickerLocked) {
                        var taskWs = wsClient.currentTaskWorkspace || ""
                        if (taskWs)
                            return String(taskWs)
                        return ""
                    }
                    return absolutePath || ""
                }

                readonly property string displayText: {
                    if (pickerLocked) {
                        var w = dropdownSelectionWorkSpace.effectiveWorkspacePath
                        w = String(w).replace(/\\/g, "/")
                        if (!w)
                            return qsTr("workspace")
                        var segs = w.split("/")
                        return segs[segs.length - 1] || w
                    }
                    return currentText
                }

                readonly property bool hasWorkspaceSelected: effectiveWorkspacePath.length > 0

                function openWorkspaceInFileSystem() {
                    var path = String(effectiveWorkspacePath || "").trim()
                    if (!path)
                        return

                    // Qt.openUrlExternally delegates the file URL to the OS file manager.
                    var normalized = path.replace(/\\/g, "/")
                    if (Qt.platform.os === "windows" && normalized.charAt(0) !== "/")
                        normalized = "/" + normalized
                    Qt.openUrlExternally(encodeURI("file://" + normalized))
                }

                function resetPicker() {
                    absolutePath = ""
                    currentText = qsTr("workspace")
                }

                Connections {
                    target: chatModel
                    function onCountChanged() {
                        if (chatModel.count === 0)
                            dropdownSelectionWorkSpace.resetPicker()
                    }
                }

                Rectangle {
                    id: wsButton
                    anchors.fill: parent
                    radius: 8
                    opacity: dropdownSelectionWorkSpace.pickerLocked ? 0.85 : 1
                    color: wsMouseArea.pressed ? "#14000000"
                         : wsMouseArea.containsMouse ? "#0A000000"
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    ToolTip {
                        id: wsToolTip
                        visible: wsMouseArea.containsMouse
                                 && (dropdownSelectionWorkSpace.hasWorkspaceSelected
                                     ? dropdownSelectionWorkSpace.pickerLocked
                                     : true)
                        text: dropdownSelectionWorkSpace.hasWorkspaceSelected
                            ? dropdownSelectionWorkSpace.effectiveWorkspacePath
                            : qsTr("input+output储存空间")
                        delay: 400
                        background: Rectangle { color: "#A6000000"; radius: 4 }
                        contentItem: Text {
                            text: wsToolTip.text
                            font.pixelSize: 14
                            color: "#FFFFFF"
                            font.family: "Alibaba PuHuiTi 3.0"
                            wrapMode: Text.Wrap
                        }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: dropdownSelectionWorkSpace.pickerLocked ? 0 : (-wsChevron.width / 2 - 2)

                        Image {
                            source: "qrc:/images/folder.png"
                            width: 16; height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            text: dropdownSelectionWorkSpace.displayText
                            width: Math.min(implicitWidth, 90)
                            elide: Text.ElideMiddle
                            font.pixelSize: 14
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#D9000000"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Canvas {
                        id: wsChevron
                        visible: !dropdownSelectionWorkSpace.pickerLocked
                        width: 16; height: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        rotation: wsPopup.visible ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#80000000"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(4, 6)
                            ctx.lineTo(8, 10)
                            ctx.lineTo(12, 6)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        id: wsMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (dropdownSelectionWorkSpace.state === "topbar"
                                      || !dropdownSelectionWorkSpace.pickerLocked)
                                     ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            // The compact top-bar control opens the selected workspace
                            // in the system file manager; the larger task-dialog control
                            // keeps the folder-selection menu behavior.
                            if (dropdownSelectionWorkSpace.state === "topbar") {
                                dropdownSelectionWorkSpace.openWorkspaceInFileSystem()
                                return
                            }
                            if (dropdownSelectionWorkSpace.pickerLocked)
                                return
                            wsPopup.visible ? wsPopup.close() : wsPopup.open()
                        }
                    }
                }

                Popup {
                    id: wsPopup
                    x: 0
                    width: 200
                    padding: 8

                    function calcY() {
                        var globalPos = dropdownSelectionWorkSpace.mapToItem(null, 0, 0)
                        var windowH = window.height
                        var popupH = contentItem.implicitHeight + padding * 2
                        if (globalPos.y + dropdownSelectionWorkSpace.height + 4 + popupH > windowH)
                            return -popupH - 4
                        return dropdownSelectionWorkSpace.height + 4
                    }

                    y: calcY()
                    onAboutToShow: y = calcY()

                    background: Rectangle {
                        radius: 8
                        color: "#FFFFFF"
                        border.color: "#14000000"
                        border.width: 1
                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            radius: 12
                            samples: 25
                            color: "#1A000000"
                        }
                    }

                    contentItem: Column {
                        spacing: 0

                        Rectangle {
                            width: wsPopup.width - 16
                            height: 36
                            radius: 6
                            color: wsOpenMouse.pressed ? "#14000000"
                                 : wsOpenMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Row {
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12

                                Image {
                                    source: "qrc:/images/folder.png"
                                    width: 18; height: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(18, 18)
                                }
                                Text {
                                    text: qsTr("打开文件夹")
                                    font.pixelSize: 14
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    color: "#D9000000"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: wsOpenMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wsPopup.close()
                                    folderDialogWorkSpace.open()
                                }
                            }
                        }
                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0}
                        Rectangle {
                            width: wsPopup.width - 16
                            height: 1
                            color: "#EBEDF0"
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                        }

                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0 }

                        Text {
                            text: qsTr("最近")
                            font.pixelSize: 12
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#73000000"
                            leftPadding: 12
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                        }

                        Item { width: 1; height: 8; visible: dropdownSelectionWorkSpace.recentFolders.length > 0}

                        Repeater {
                            visible: dropdownSelectionWorkSpace.recentFolders.length > 0
                            model: dropdownSelectionWorkSpace.recentFolders
                            delegate: Rectangle {
                                width: wsPopup.width - 8
                                height: 36
                                radius: 6
                                color: recentMouse.pressed ? "#14000000"
                                     : recentMouse.containsMouse ? "#0A000000"
                                     : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12

                                    Image {
                                        source: "qrc:/images/folder.png"
                                        width: 18; height: 18
                                        anchors.verticalCenter: parent.verticalCenter
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(18, 18)
                                    }
                                    Text {
                                        text: modelData
                                        font.pixelSize: 14
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: "#D9000000"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: recentMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        dropdownSelectionWorkSpace.currentText = modelData
                                        wsPopup.close()
                                    }
                                }
                            }
                        }
                    }

                    enter: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                        NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                    }
                    exit: Transition {
                        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                    }
                }

                FileDialog {
                    id: folderDialogWorkSpace
                    title: qsTr("选择文件夹")
                    selectFolder: true
                    onAccepted: {
                        var url = folderDialogWorkSpace.fileUrl.toString()
                        var path = decodeURIComponent(url.replace(/^file:\/{2,3}/, ""))
                        if (Qt.platform.os === "windows") {
                        if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                            path = path.substring(1)
                        path = path.replace(/\//g, "\\")
                        }else if(Qt.platform.os === "linux"){
                            path = "/" + path
                        }
                        dropdownSelectionWorkSpace.absolutePath = path
                        var parts = path.replace(/\\/g, "/").split("/")
                        dropdownSelectionWorkSpace.currentText = parts[parts.length - 1] || path
                    }
                }
            }

            Rectangle{
                id: scheduledTaskRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 1

                // 调度类型显示名映射
                function scheduleDisplay(kind, expr) {
                    if (kind === "cron") {
                        if (expr === "0 * * * *") return "每小时"
                        if (/^[\d]+ [\d]+ \* \* \*$/.test(expr)) return "每天"
                        if (/^[\d]+ [\d]+ \* \* [0-6,-]+$/.test(expr)) return "每周"
                        return "cron: " + expr
                    }
                    if (kind === "every") {
                        var ms = parseInt(expr)
                        if (ms >= 86400000) return "每 " + Math.round(ms/86400000) + " 天"
                        if (ms >= 3600000) return "每 " + Math.round(ms/3600000) + " 小时"
                        if (ms >= 60000) return "每 " + Math.round(ms/60000) + " 分钟"
                        return "每 " + Math.round(ms/1000) + " 秒"
                    }
                    if (kind === "at") return "不重复"
                    return kind || "未知"
                }

                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    topPadding: 24
                    rightPadding: 60
                    spacing: 16
                    Rectangle{
                    id: scheduledTaskTitleRec
                        height: wsClient.cronJobs.length === 0 ? 0 : scheduledTaskTitle.height
                        width: parent.width - 120
                        visible: wsClient.cronJobs.length > 0
                        Column{
                            id: scheduledTaskTitle
                            spacing: 8
                            anchors.left: parent.left
                            Label{
                                text: qsTr("定时任务")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Label{
                                text: qsTr("创建定时任务，让 AI 按计划自动执行")
                                font.pixelSize: 12
                                color: "#A6000000"
                            }
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            CustomButton {
                                width: 112
                                height: 36
                                backgroundColor: "#FFFFFF"
                                hoverBackgroundColor: "#F7F9FA"
                                pressedBackgroundColor: "#F0F2F5"
                                textColor: "#73000000"
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                iconSource: "qrc:/images/addIdea.png"
                                iconSize: 16
                                text: qsTr("从灵感添加")
                                fontSize: 14
                                onClicked: {
                                    window.selectedCronTemplateCategory = 0
                                    cronIdeaLibraryPopup.open()
                                }
                            }
                            CustomButton{
                                width: 80
                                height: 36
                                backgroundColor: "#0F006BFF"
                                textColor: "#006BFF"
                                borderWidth: 0
                                text: "+ 新建"
                                fontSize: 14
                                onClicked: {
                                    window.editingCronJobId = ""
                                    window.editingCronPayloadKind = "agentTurn"
                                    window.editingCronScheduleKind = ""
                                    window.editingCronScheduleExpr = ""
                                    window.editingCronScheduleTz   = ""
                                    window.pendingCronTemplateExpr = ""
                                    window.pendingCronTemplateTrigger = ""
                                    newTaskTitleInput.text = ""
                                    newTaskPromptInput.text = ""
                                    newTaskRepeatSelect.currentIndex = 0
                                    newTaskIntervalInput.text = ""
                                    newTaskDialog.open()
                                }
                            }
                        }
                    }
                    TabBarView{
                        id: scheduledTaskTab
                        lineWidth: parent.width - 120
                        tabs: [ { text: "任务", badge: wsClient.cronJobs.length }, { text: "历史" }]
                        onTabClicked: {
                            if (index === 1) wsClient.loadCronRuns()
                        }
                    }

                    // ═══════════ 任务 Tab ═══════════
                    ScrollView {
                        id: scheduledTaskScrollView
                        width: parent.width
                        height: parent.height - 32 - scheduledTaskTitleRec.height - scheduledTaskTab.height - 24
                        clip: true
                        visible: scheduledTaskTab.currentIndex === 0
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Column{
                            spacing: 12
                            width: parent.width
                            // 空状态与自动化任务模板
                            Column {
                                id: cronEmptyState
                                width: scheduledTaskScrollView.width - 120
                                height: Math.max(scheduledTaskScrollView.height,
                                                 emptyCronIntro.implicitHeight
                                                 + cronTemplateSection.implicitHeight + 108)
                                visible: wsClient.cronJobs.length === 0
                                spacing: 0
                                Column {
                                    id: emptyCronIntro
                                    width: parent.width
                                    spacing: 10
                                    Item {width: 1; height: 80}
                                    Image {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        source: "qrc:/images/cron/mainImage.png"
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: qsTr("开启你的第一个自动化任务吧")
                                        font.pixelSize: 14
                                        color: "#A6000000"
                                    }
                                    CustomButton {
                                        width: 80; height: 36
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        backgroundColor: "#006BFF"
                                        textColor: "#FFFFFF"
                                        borderWidth: 0
                                        text: qsTr("+ 新建")
                                        fontSize: 14
                                        onClicked: {
                                            window.editingCronJobId = ""
                                            window.editingCronPayloadKind = "agentTurn"
                                            window.editingCronScheduleKind = ""
                                            window.editingCronScheduleExpr = ""
                                            window.editingCronScheduleTz = ""
                                            window.pendingCronTemplateExpr = ""
                                            window.pendingCronTemplateTrigger = ""
                                            newTaskTitleInput.text = ""
                                            newTaskPromptInput.text = ""
                                            newTaskRepeatSelect.currentIndex = 0
                                            newTaskIntervalInput.text = ""
                                            newTaskDialog.open()
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: Math.max(24, cronEmptyState.height
                                                     - emptyCronIntro.implicitHeight
                                                     - cronTemplateSection.implicitHeight - 84)
                                }

                                Column {
                                    id: cronTemplateSection
                                    width: parent.width
                                    spacing: 12
                                    Label {
                                        text: qsTr("自动化任务灵感")
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        color: "#D9000000"
                                    }
                                    Flow {
                                        width: parent.width
                                        height: childrenRect.height
                                        spacing: 8
                                        Repeater {
                                            model: window.cronTemplateCategories
                                            delegate: Rectangle {
                                                width: categoryLabel.implicitWidth + 20
                                                height: 30
                                                radius: 6
                                                color: index === window.selectedCronTemplateCategory
                                                       ? "#0F006BFF" : (categoryMouse.containsMouse ? "#0A000000" : "#F7F9FA")
                                                Label {
                                                    id: categoryLabel
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    font.pixelSize: 14
                                                    color: index === window.selectedCronTemplateCategory ? "#006BFF" : "#A6000000"
                                                }
                                                MouseArea {
                                                    id: categoryMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        window.selectedCronTemplateCategory = index
                                                        cronTemplateCardsFlick.contentX = 0
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Flickable {
                                        id: cronTemplateCardsFlick
                                        width: parent.width
                                        height: 184
                                        clip: true
                                        contentWidth: cronTemplateCardsRow.width
                                        contentHeight: cronTemplateCardsRow.height
                                        boundsBehavior: Flickable.StopAtBounds
                                        interactive: contentWidth > width
                                        flickableDirection: Flickable.HorizontalFlick

                                        ScrollBar.horizontal: ScrollBar {
                                            policy: cronTemplateCardsFlick.contentWidth > cronTemplateCardsFlick.width
                                                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                        }

                                        Row {
                                            id: cronTemplateCardsRow
                                            spacing: 16
                                            height: 170

                                            Repeater {
                                                model: window.cronTemplateCategories[window.selectedCronTemplateCategory].tasks
                                                delegate: Item {
                                                    id: cronTemplateCard
                                                    property var task: modelData
                                                    width: 195
                                                    height: 170

                                                    DropShadow {
                                                        anchors.fill: cardImage
                                                        source: cardImage
                                                        horizontalOffset: 0
                                                        verticalOffset: 6
                                                        radius: 14
                                                        samples: 29
                                                        color: "#26000000"
                                                        visible: templateMouse.containsMouse
                                                    }

                                                    Image {
                                                        id: cardImage
                                                        anchors.fill: parent
                                                        source: "qrc:/images/cron/"
                                                                + (window.selectedCronTemplateCategory + 1)
                                                                + "-" + (index + 1) + ".png"
                                                        fillMode: Image.PreserveAspectFit
                                                        sourceSize: Qt.size(195, 170)
                                                    }

                                                    Rectangle {
                                                        width: 58
                                                        height: 38
                                                        radius: 8
                                                        anchors.centerIn: parent
                                                        color: templateMouse.pressed ? "#005CE6" : "#006BFF"
                                                        visible: templateMouse.containsMouse
                                                        z: 2
                                                        Label {
                                                            anchors.centerIn: parent
                                                            text: qsTr("使用")
                                                            font.pixelSize: 14
                                                            color: "#FFFFFF"
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: templateMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: window.openCronTemplate(cronTemplateCard.task)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item { width: parent.width; height: 60 }
                            }

                            Repeater{
                                model: wsClient.cronJobs
                                delegate: Rectangle {
                                    id: cronJobRow
                                    property var job: modelData
                                    width: scheduledTaskScrollView.width - 120
                                    height: 76
                                    radius: 8
                                    color: taskItemMouse.containsMouse ? "#F0F2F5" : "#F7F9FA"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MouseArea {
                                        id: taskItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: taskRightRow.left
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Label {
                                            text: cronJobRow.job.name || ""
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            color: cronJobRow.job.enabled ? "#D9000000" : "#80000000"
                                            width: parent.width
                                            elide: Text.ElideRight
                                        }
                                        Row {
                                            spacing: 8
                                            Label {
                                                text: scheduledTaskRec.scheduleDisplay(
                                                          cronJobRow.job.scheduleKind || "",
                                                          cronJobRow.job.scheduleExpr || "")
                                                font.pixelSize: 14
                                                color: "#73000000"
                                            }
                                            Label {
                                                text: {
                                                    var next = cronJobRow.job.nextRunAt || ""
                                                    if (next) return "下次: " + next.replace("T", " ").substring(0, 16)
                                                    var last = cronJobRow.job.lastRunAt || ""
                                                    if (last) return "上次: " + last.replace("T", " ").substring(0, 16)
                                                    return ""
                                                }
                                                font.pixelSize: 14
                                                color: "#73000000"
                                                visible: text !== ""
                                            }
                                            // 载荷类型标签
                                            Rectangle {
                                                visible: (cronJobRow.job.payloadKind || "") === "systemEvent"
                                                width: sysLabel.implicitWidth + 12
                                                height: 20
                                                radius: 4
                                                color: "#0FFF8800"
                                                anchors.verticalCenter: parent.verticalCenter
                                                Label {
                                                    id: sysLabel
                                                    text: "系统事件"
                                                    font.pixelSize: 11
                                                    color: "#FF8800"
                                                    anchors.centerIn: parent
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        id: taskRightRow
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 40
                                        height: 22

                                        ImageButton {
                                            id: cronMoreBtn
                                            source: "qrc:/images/more.png"
                                            btnHeight: 20
                                            btnWidth: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: cronRowMoreMenu.open()
                                        }

                                        Popup {
                                            id: cronRowMoreMenu
                                            parent: cronMoreBtn
                                            x: parent.width - width
                                            y: parent.height + 4
                                            width: 156
                                            padding: 8
                                            modal: false
                                            closePolicy: Popup.CloseOnPressOutside
                                            background: Rectangle {
                                                radius: 8
                                                color: "#FFFFFF"
                                                border.color: "#14000000"
                                                border.width: 1
                                            }
                                            contentItem: Column {
                                                spacing: 2
                                                // 立即运行
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miRun.pressed ? "#14000000"
                                                         : miRun.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/play.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("立即运行")
                                                            font.pixelSize: 14
                                                            color: "#D9000000"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miRun
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            wsClient.runCronJobNow(cronJobRow.job.id)
                                                        }
                                                    }
                                                }
                                                // 编辑
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miEdit.pressed ? "#14000000"
                                                         : miEdit.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/edit.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("编辑")
                                                            font.pixelSize: 14
                                                            color: "#D9000000"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miEdit
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            window.editingCronJobId = cronJobRow.job.id
                                                            window.editingCronPayloadKind = cronJobRow.job.payloadKind || "agentTurn"
                                                            window.editingCronScheduleKind = cronJobRow.job.scheduleKind || ""
                                                            window.editingCronScheduleExpr = cronJobRow.job.scheduleExpr || ""
                                                            window.editingCronScheduleTz   = cronJobRow.job.scheduleTz || ""
                                                            newTaskTitleInput.text = cronJobRow.job.name || ""
                                                            newTaskPromptInput.text = cronJobRow.job.payloadMessage || ""

                                                            var sk = window.editingCronScheduleKind
                                                            var expr = window.editingCronScheduleExpr
                                                            if (sk === "at") {
                                                                newTaskRepeatSelect.currentIndex = 0
                                                                if (expr) {
                                                                    var dt = new Date(expr)
                                                                    if (!isNaN(dt.getTime())) {
                                                                        newTaskDatePicker.selectedYear = dt.getFullYear()
                                                                        newTaskDatePicker.selectedMonth = dt.getMonth() + 1
                                                                        newTaskDatePicker.selectedDay = dt.getDate()
                                                                        newTaskTimePicker.selectedHour = dt.getHours()
                                                                        newTaskTimePicker.selectedMinute = dt.getMinutes()
                                                                    }
                                                                }
                                                            } else if (sk === "every") {
                                                                newTaskRepeatSelect.currentIndex = 4
                                                                var sec = Math.round(parseInt(expr) / 1000)
                                                                newTaskIntervalInput.text = sec > 0 ? String(sec) : ""
                                                            } else if (sk === "cron" && expr) {
                                                                var parts = expr.split(" ")
                                                                var mm = parseInt(parts[0]) || 0
                                                                var hh = parseInt(parts[1]) || 0
                                                                if (parts.length >= 5 && parts[4] !== "*") {
                                                                    newTaskRepeatSelect.currentIndex = 2
                                                                } else if (parts[1] === "*") {
                                                                    newTaskRepeatSelect.currentIndex = 3
                                                                } else {
                                                                    newTaskRepeatSelect.currentIndex = 1
                                                                }
                                                                newTaskTimePicker.selectedHour = hh
                                                                newTaskTimePicker.selectedMinute = mm
                                                            }
                                                            newTaskDialog.open()
                                                        }
                                                    }
                                                }
                                                // 删除
                                                Rectangle {
                                                    width: 140
                                                    height: 36
                                                    radius: 6
                                                    color: miDel.pressed ? "#14000000"
                                                         : miDel.containsMouse ? "#EBEDF0" : "transparent"
                                                    Row {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 8
                                                        Image{
                                                            width: 16
                                                            height: 16
                                                            source: "qrc:/images/delete.png"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                        Label {
                                                            text: qsTr("删除")
                                                            font.pixelSize: 14
                                                            color: "#FF3D40"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: miDel
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cronRowMoreMenu.close()
                                                            window.pendingDeleteCronJobId = cronJobRow.job.id
                                                            window.pendingDeleteCronJobName = cronJobRow.job.name || ""
                                                            deleteCronJobPopup.open()
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 开关（checked 不能绑定 model，否则与点击互斥；用 guard 与列表刷新同步）
                                        Switch {
                                            id: taskSwitch
                                            property bool _syncGuard: false
                                            function syncFromModel() {
                                                _syncGuard = true
                                                checked = (cronJobRow.job.enabled === true)
                                                _syncGuard = false
                                            }
                                            Component.onCompleted: syncFromModel()
                                            Connections {
                                                target: wsClient
                                                function onCronJobsChanged() {
                                                    taskSwitch.syncFromModel()
                                                }
                                            }
                                            onCheckedChanged: {
                                                if (_syncGuard)
                                                    return
                                                wsClient.setCronJobEnabled(cronJobRow.job.id, checked)
                                            }
                                            anchors.verticalCenter: parent.verticalCenter
                                            HoverHandler {
                                                cursorShape: taskSwitch.enabled
                                                             ? Qt.PointingHandCursor
                                                             : Qt.ArrowCursor
                                            }
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                x: taskSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                color: taskSwitch.checked ? "#006BFF" : "#D9D9D9"

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }

                                                Rectangle {
                                                    x: taskSwitch.checked ? parent.width - width - 3 : 3
                                                    y: parent.height / 2 - height / 2
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: "#FFFFFF"

                                                    Behavior on x {
                                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ═══════════ 历史 Tab ═══════════
                    ScrollView {
                        id: cronHistoryScrollView
                        width: parent.width
                        height: parent.height - 32 - scheduledTaskTitleRec.height - scheduledTaskTab.height - 24
                        clip: true
                        visible: scheduledTaskTab.currentIndex === 1
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Column {
                            spacing: 8
                            width: parent.width

                            Rectangle {
                                width: cronHistoryScrollView.width - 120
                                height: 120
                                visible: cronRunsModel.count === 0
                                color: "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: qsTr("暂无执行记录")
                                    font.pixelSize: 14
                                    color: "#A6000000"
                                }
                            }

                            Repeater {
                                model: cronRunsModel

                                delegate: Rectangle {
                                    id: historyRow
                                    property var run: model
                                    width: cronHistoryScrollView.width - 120
                                    height: 76
                                    radius: 8
                                    color: historyHover.containsMouse ? "#F0F2F5" : "#F7F9FA"

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    MouseArea {
                                        id: historyHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.right: historyRightCol.left
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        Rectangle {
                                            width: 10; height: 10; radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: {
                                                var s = historyRow.run.status || ""
                                                if (s === "ok") return "#22C55E"
                                                if (s === "error") return "#EF4444"
                                                if (s === "skipped") return "#F59E0B"
                                                return "#D9D9D9"
                                            }
                                        }

                                        Column {
                                            spacing: 4
                                            width: parent.width - 22

                                            Label {
                                                text: historyRow.run.jobName || historyRow.run.jobId || ""
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                width: parent.width
                                                elide: Text.ElideRight
                                            }

                                            Row {
                                                spacing: 8

                                                Rectangle {
                                                    width: historyStatusText.implicitWidth + 12
                                                    height: 20
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var s = historyRow.run.status || ""
                                                        if (s === "ok") return "#0F22C55E"
                                                        if (s === "error") return "#0FEF4444"
                                                        if (s === "skipped") return "#0FF59E0B"
                                                        return "#0A000000"
                                                    }
                                                Label {
                                                        id: historyStatusText
                                                        anchors.centerIn: parent
                                                    text: {
                                                            var s = historyRow.run.status || ""
                                                        if (s === "ok") return "成功"
                                                        if (s === "error") return "失败"
                                                        if (s === "skipped") return "跳过"
                                                        return s
                                                    }
                                                        font.pixelSize: 11
                                                    color: {
                                                            var s = historyRow.run.status || ""
                                                        if (s === "ok") return "#22C55E"
                                                        if (s === "error") return "#EF4444"
                                                            if (s === "skipped") return "#F59E0B"
                                                        return "#73000000"
                                                    }
                                                }
                                                }

                                                Rectangle {
                                                    visible: {
                                                        var d = historyRow.run.deliveryStatus || ""
                                                        return d !== "" && d !== "not-requested"
                                                    }
                                                    width: deliveryLabel.implicitWidth + 12
                                                    height: 20
                                                    radius: 4
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: {
                                                        var d = historyRow.run.deliveryStatus || ""
                                                        if (d === "delivered") return "#0F006BFF"
                                                        return "#0A000000"
                                                }
                                                Label {
                                                        id: deliveryLabel
                                                        anchors.centerIn: parent
                                                        text: {
                                                            var d = historyRow.run.deliveryStatus || ""
                                                            if (d === "delivered") return "已投递"
                                                            if (d === "not-delivered") return "未投递"
                                                            if (d === "unknown") return "投递未知"
                                                            return d
                                                        }
                                                        font.pixelSize: 11
                                                        color: {
                                                            var d = historyRow.run.deliveryStatus || ""
                                                            if (d === "delivered") return "#006BFF"
                                                            return "#73000000"
                                                        }
                                                    }
                                                }

                                                Label {
                                                    text: (historyRow.run.startedAt || "").replace("T", " ").substring(0, 19)
                                                    font.pixelSize: 14
                                                    color: "#73000000"
                                                    visible: (historyRow.run.startedAt || "") !== ""
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Label {
                                                    text: {
                                                        var ms = historyRow.run.durationMs || 0
                                                        if (ms <= 0) return ""
                                                        if (ms < 1000) return ms + " ms"
                                                        var sec = (ms / 1000).toFixed(1)
                                                        return sec + " s"
                                                    }
                                                    font.pixelSize: 14
                                                    color: "#A6000000"
                                                    visible: text !== ""
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }
                                    }

                                    Column {
                                        id: historyRightCol
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: historyErrorLabel.visible ? Math.min(historyErrorLabel.implicitWidth, 240) : 0
                                        spacing: 0

                                        Label {
                                            id: historyErrorLabel
                                            text: historyRow.run.error || ""
                                        font.pixelSize: 12
                                        color: "#EF4444"
                                            visible: (historyRow.run.error || "") !== ""
                                            width: parent.width
                                        elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignRight

                                            ToolTip {
                                                visible: historyErrorHover.containsMouse && historyErrorLabel.truncated
                                                text: historyErrorLabel.text
                                                delay: 500
                                                x: -width + historyErrorLabel.width
                                                y: -height - 4
                                                width: Math.min(implicitContentWidth + 20, 360)
                                                background: Rectangle {
                                                    color: "#A6000000"
                                                    radius: 4
                                                }
                                                contentItem: Text {
                                                    text: historyErrorLabel.text
                                                    font.pixelSize: 14
                                                    color: "#FFFFFF"
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                            MouseArea {
                                                id: historyErrorHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: capabilityHubHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 64
                visible: window.leftSelectedIndex >= 2 && window.leftSelectedIndex <= 4
                z: 2

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [qsTr("专家"), qsTr("技能"), qsTr("工具")]
                        delegate: Rectangle {
                            readonly property int pageIndex: index + 2
                            width: 76
                            height: 36
                            radius: 6
                            color: window.leftSelectedIndex === pageIndex ? "#F0F1F4"
                                 : hubTabMouse.containsMouse ? "#F7F8FA" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 16
                                font.weight: window.leftSelectedIndex === parent.pageIndex
                                             ? Font.Bold : Font.Medium
                                color: window.leftSelectedIndex === parent.pageIndex
                                     ? "#D9000000" : "#99000000"
                            }

                            MouseArea {
                                id: hubTabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.leftSelectedIndex = parent.pageIndex
                            }
                        }
                    }
                }

                SingleLineTextInput {
                    visible: window.leftSelectedIndex === 2
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                    inputHeight: 36
                    icon: "qrc:/images/search.png"
                    iconSize: 16
                    placeholderText: qsTr("搜索专家...")
                    onTextChanged: agentManageRec.searchText = text
                }

                SingleLineTextInput {
                    visible: window.leftSelectedIndex === 4
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                    inputHeight: 36
                    icon: "qrc:/images/search.png"
                    iconSize: 16
                    placeholderText: qsTr("搜索工具...")
                    onTextChanged: toolsSettingRec.toolSearchText = text
                }

                Row {
                    visible: window.leftSelectedIndex === 3
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    SingleLineTextInput {
                        inputWidth: Math.min(220, capabilityHubHeader.width * 0.24)
                        inputHeight: 36
                        icon: "qrc:/images/search.png"
                        iconSize: 16
                        placeholderText: qsTr("搜索技能...")
                        onTextChanged: skillSettingRec.skillSearchText = text
                    }

                    Item {
                        width: 80
                        height: 36

                        CustomButton {
                            id: addSkillBtn
                            anchors.fill: parent
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 添加"
                            fontSize: 14
                            onClicked: addSkillMenu.visible ? addSkillMenu.close() : addSkillMenu.open()
                        }

                        Popup {
                            id: addSkillMenu
                            y: addSkillBtn.height + 4
                            x: parent.width - width
                            width: 180
                            padding: 4

                            background: Rectangle {
                                radius: 8
                                color: "#FFFFFF"
                                border.color: "#14000000"
                                border.width: 1
                                layer.enabled: true
                                layer.effect: DropShadow {
                                    transparentBorder: true
                                    radius: 12
                                    samples: 25
                                    color: "#1A000000"
                                }
                            }

                            contentItem: Column {
                                spacing: 2

                                Repeater {
                                    model: [
                                        { text: "上传 .ZIP", icon: "qrc:/images/upload.png" },
                                        { text: "上传文件夹", icon: "qrc:/images/folder.png" },
                                        { text: "从 GitHub 导入", icon: "qrc:/images/link.png" }
                                    ]

                                    delegate: Rectangle {
                                        width: 172
                                        height: 36
                                        radius: 6
                                        color: menuItemMouse.pressed ? "#14000000"
                                             : menuItemMouse.containsMouse ? "#0A000000"
                                             : "transparent"

                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Image {
                                                width: 16
                                                height: 16
                                                source: modelData.icon
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Label {
                                                text: modelData.text
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: menuItemMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addSkillMenu.close()
                                                if (index === 0) {
                                                    zipFileDialog.open()
                                                } else if (index === 1) {
                                                    folderDialog.open()
                                                } else if (index === 2) {
                                                    githubImportDialog.open()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            enter: Transition {
                                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                NumberAnimation { property: "scale"; from: 0.95; to: 1; duration: 150; easing.type: Easing.OutCubic }
                            }
                            exit: Transition {
                                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: agentManageRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 2
                property string searchText: ""

                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshAgents()
                }

                function filteredAgents() {
                    var list = wsClient.agentList || []
                    var kw = searchText.toLowerCase()
                    var out = []
                    for (var i = 0; i < list.length; i++) {
                        var a = list[i]
                        var name = String(a.name || "").trim().toLowerCase()
                        var id = String(a.id || "").trim().toLowerCase()
                        if (id === "main" || name === "默认")
                            continue
                        var detail = String(a.description || "").toLowerCase()
                        if (!kw || name.indexOf(kw) >= 0 || id.indexOf(kw) >= 0
                                || detail.indexOf(kw) >= 0)
                            out.push(a)
                    }
                    return out
                }

                ExpertPage {
                    anchors.fill: parent
                    agentList: wsClient.agentList || []
                    searchText: agentManageRec.searchText
                    installBusy: wsClient.agentInstallBusy
                    installProgress: wsClient.agentInstallProgress
                    installMessage: wsClient.agentInstallMessage
                    installingId: wsClient.agentInstallingId
                    hostWidth: window.width
                    hostHeight: window.height
                    onSummonRequested: function(agentId, promptText) {
                        window.summonExpert(agentId, promptText)
                    }
                }
            }

            Rectangle{
                id: skillSettingRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 3
                property string skillSearchText: ""
                property string selectedSkillCategory: "全部"
                property var skillCategories: [
                    "全部", "政务技能", "平台基础", "临床科研", "科学计算",
                    "开发者工具", "第三方服务集成", "场景调度"
                ]
                property var skillCategoryById: ({
                    "gov-assessment": "政务技能",
                    "gov-briefing": "政务技能",
                    "gov-data-analysis": "政务技能",
                    "gov-doc-drafting": "政务技能",
                    "gov-doc-summary": "政务技能",
                    "gov-enterprise-report": "政务技能",
                    "gov-hotline-report": "政务技能",
                    "gov-kb-qa": "政务技能",
                    "gov-meeting-minutes": "政务技能",
                    "gov-policy-drafting": "政务技能",
                    "gov-policy-interpret": "政务技能",
                    "gov-policy-lookup": "政务技能",
                    "gov-policy-match": "政务技能",
                    "gov-work-summary": "政务技能",
                    "_shared": "平台基础",
                    "node-connect": "平台基础",
                    "model-usage": "平台基础",
                    "skill-creator": "平台基础",
                    "session-logs": "平台基础",
                    "healthcheck": "平台基础",
                    "coding-agent": "平台基础",
                    "summarize": "平台基础",
                    "apple-notes": "平台基础",
                    "apple-reminders": "平台基础",
                    "bear-notes": "平台基础",
                    "notion": "平台基础",
                    "obsidian": "平台基础",
                    "things-mac": "平台基础",
                    "trello": "平台基础",
                    "biomcp-server": "临床科研",
                    "scma-analyzer": "临床科研",
                    "medical-intelligence": "临床科研",
                    "medical-research-toolkit": "临床科研",
                    "mlp-intelligence": "临床科研",
                    "radiology-skills": "临床科研",
                    "spatial-transcriptomics-agent": "临床科研",
                    "spatial-transcriptomics-analysis": "临床科研",
                    "precision-medicine": "临床科研",
                    "data-analysis": "科学计算",
                    "github": "开发者工具",
                    "gh-issues": "开发者工具",
                    "gitgrep": "开发者工具",
                    "blucl": "开发者工具",
                    "tmux": "开发者工具",
                    "wacli": "开发者工具",
                    "1password": "第三方服务集成",
                    "canva": "第三方服务集成",
                    "discord": "第三方服务集成",
                    "gemini": "第三方服务集成",
                    "gog": "第三方服务集成",
                    "goplaces": "第三方服务集成",
                    "himalaya": "第三方服务集成",
                    "imsg": "第三方服务集成",
                    "mcporter": "第三方服务集成",
                    "openai-whisper": "第三方服务集成",
                    "openai-whisper-api": "第三方服务集成",
                    "opennlue": "第三方服务集成",
                    "oracle": "第三方服务集成",
                    "ordercli": "第三方服务集成",
                    "peekaboo": "第三方服务集成",
                    "sag": "第三方服务集成",
                    "sherpa-onnx-tts": "第三方服务集成",
                    "slack": "第三方服务集成",
                    "songsee": "第三方服务集成",
                    "sonoscli": "第三方服务集成",
                    "spotify-player": "第三方服务集成",
                    "video-frames": "第三方服务集成",
                    "video-call": "第三方服务集成",
                    "weather": "第三方服务集成",
                    "xurl": "第三方服务集成",
                    "camsnap": "第三方服务集成",
                    "bluebubbles": "第三方服务集成",
                    "blogwatcher": "第三方服务集成",
                    "eighthtctl": "第三方服务集成",
                    "paper-writing": "场景调度",
                    "deep-research": "场景调度",
                    "fact-forensics": "场景调度",
                    "clawhub": "场景调度"
                })

                function visibleSkillCategories() {
                    var present = {}
                    var list = wsClient.skillList || []
                    for (var i = 0; i < list.length; i++) {
                        var id = String(list[i].skillKey || list[i].name || "").toLowerCase()
                        var category = skillCategoryById[id] || ""
                        if (category)
                            present[category] = true
                    }
                    var result = ["全部"]
                    for (var j = 1; j < skillCategories.length; j++) {
                        if (present[skillCategories[j]])
                            result.push(skillCategories[j])
                    }
                    return result
                }

                function ensureSelectedSkillCategory() {
                    var categories = visibleSkillCategories()
                    if (categories.indexOf(selectedSkillCategory) < 0)
                        selectedSkillCategory = "全部"
                }

                onVisibleChanged: {
                    if (visible)
                        ensureSelectedSkillCategory()
                }

                Connections {
                    target: wsClient
                    function onSkillListChanged() {
                        skillSettingRec.ensureSelectedSkillCategory()
                    }
                }

                function filteredSkillList() {
                    var list = wsClient.skillList || []
                    var kw = skillSearchText.trim().toLowerCase()
                    var result = []
                    for (var i = 0; i < list.length; i++) {
                        var name = String(list[i].name || list[i].skillKey || "").toLowerCase()
                        var id = String(list[i].skillKey || list[i].name || "").toLowerCase()
                        var category = skillCategoryById[id] || ""
                        if (selectedSkillCategory !== "全部" && category !== selectedSkillCategory)
                            continue
                        if (kw && name.indexOf(kw) < 0)
                            continue
                        result.push(list[i])
                    }
                    return result
                }
                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    rightPadding: 60
                    spacing: 16

                    Flickable {
                        id: skillCategoryBar
                        width: parent.width - 120
                        height: 36
                        contentWidth: skillCategoryRow.width
                        contentHeight: height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: skillCategoryRow
                            spacing: 8

                            Repeater {
                                model: skillSettingRec.visibleSkillCategories()

                                delegate: Rectangle {
                                    readonly property bool selected: skillSettingRec.selectedSkillCategory === modelData
                                    width: categoryLabel.implicitWidth + 24
                                    height: 32
                                    radius: 6
                                    color: selected ? "#0F006BFF"
                                         : categoryMouse.containsMouse ? "#F7F8FA" : "#F7F9FA"

                                    Label {
                                        id: categoryLabel
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: 14
                                        font.weight: parent.selected ? Font.Medium : Font.Normal
                                        color: parent.selected ? "#006BFF" : "#A6000000"
                                    }

                                    MouseArea {
                                        id: categoryMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: skillSettingRec.selectedSkillCategory = modelData
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: skillScrollView
                        width: parent.width - 120
                        height: skillSettingRec.height - skillCategoryBar.height - 16 - 16
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Grid {
                            id: skillGrid
                            columns: width >= 680 ? 2 : 1
                            spacing: 12
                            width: skillScrollView.width

                            property real cellWidth: columns === 2 ? (width - spacing) / 2 : width

                            Repeater {
                                model: skillSettingRec.filteredSkillList()

                                delegate: Rectangle {
                                    width: skillGrid.cellWidth
                                    height: 68
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.right: installedSkillButton.left
                                        anchors.rightMargin: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        height: 28

                                        Image {
                                            width: 28
                                            height: 28
                                            visible: !modelData.emoji
                                            source: "qrc:/images/skillIcon.png"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Label {
                                            width: 28
                                            height: 28
                                            visible: modelData.emoji
                                            font.pixelSize: 20
                                            text: modelData.emoji
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "Alibaba PuHuiTi 3.0, Noto Color Emoji"
                                        }

                                        Label {
                                            id: skillNameLabel
                                            width: parent.width - 36
                                            text: modelData.name || modelData.skillKey || ""
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                        }
                                    }

                                    CustomButton {
                                        id: installedSkillButton
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 72
                                        height: 32
                                        buttonRadius: 8
                                        fontSize: 13
                                        text: qsTr("已安装")
                                        enabled: false
                                        disabledBackgroundColor: "#F7F9FA"
                                        disabledTextColor: "#73000000"
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle{
                id: toolsSettingRec
                anchors.top: capabilityHubHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: window.leftSelectedIndex === 4
                property string toolSearchText: ""
                property string selectedToolCategory: "深度问数"
                property var toolCategories: ["深度问数", "生信分析", "政务助手", "系统自带"]
                property var deepDataToolIds: ({
                    "data_execute_code": true,
                    "data_explore": true,
                    "data_clean": true,
                    "echarts_transform": true,
                    "file_extract": true,
                    "file_list_archive": true,
                    "ml_export_model": true,
                    "ml_recommend_models": true,
                    "ml_run_pipeline": true,
                    "read_file_content": true,
                    "stats_association": true,
                    "stats_comparative": true,
                    "stats_correlation": true,
                    "stats_crosstab": true,
                    "stats_linear_regression": true,
                    "stats_logistic_regression": true,
                    "stats_tableone": true
                })
                property var bioinformaticsToolIds: ({
                    "scrna_annotate": true,
                    "scrna_cluster": true,
                    "scrna_preprocess": true,
                    "scrna_validate": true,
                    "spatial_cluster": true,
                    "spatial_deg": true,
                    "spatial_enrichment": true,
                    "spatial_load": true,
                    "spatial_qc": true
                })
                property var governmentToolIds: ({
                    "docx_generate": true,
                    "docx_install_font": true,
                    "docx_check_fonts": true,
                    "data_profile": true,
                    "policy_eligibility_match": true,
                    "enterprise_profile_query": true,
                    "policy_document_drafting": true,
                    "12345_monthly_analysis_report": true,
                    "knowledge_base_qa": true,
                    "document_summary": true,
                    "policy_law_fast_search": true,
                    "comprehensive_judgment_analysis": true,
                    "data_analysis": true,
                    "policy_interpretation": true,
                    "official_document_draft": true,
                    "report_material": true,
                    "work_summary": true,
                    "meeting_minutes": true
                })
                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshToolsCatalog("main")
                }

                function toolIdMatches(id, idMap) {
                    if (idMap[id])
                        return true
                    for (var knownId in idMap) {
                        if (id.length > knownId.length
                                && id.lastIndexOf(knownId) === id.length - knownId.length)
                            return true
                    }
                    return false
                }

                function categoryForTool(tool) {
                    var id = String(tool.toolId || "").trim().toLowerCase()
                    if (toolIdMatches(id, deepDataToolIds))
                        return "深度问数"
                    if (toolIdMatches(id, bioinformaticsToolIds))
                        return "生信分析"
                    if (toolIdMatches(id, governmentToolIds))
                        return "政务助手"
                    return "系统自带"
                }

                function filteredTools(category) {
                    var result = []
                    var list = wsClient.toolList || []
                    var search = toolSearchText.toLowerCase()
                    for (var i = 0; i < list.length; i++) {
                        var t = list[i]
                        if (categoryForTool(t) !== category)
                            continue
                        if (search && (t.label || "").toLowerCase().indexOf(search) < 0)
                            continue
                        result.push(t)
                    }
                    return result
                }

                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    rightPadding: 60
                    spacing: 16

                    Row {
                        id: toolsTab
                        spacing: 8

                        Repeater {
                            model: toolsSettingRec.toolCategories

                            delegate: Rectangle {
                                readonly property bool selected:
                                    toolsSettingRec.selectedToolCategory === modelData
                                width: toolCategoryLabel.implicitWidth + 24
                                height: 32
                                radius: 6
                                color: selected ? "#0F006BFF"
                                     : toolCategoryMouse.containsMouse ? "#F7F8FA" : "#F7F9FA"

                                Label {
                                    id: toolCategoryLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 14
                                    font.weight: parent.selected ? Font.Medium : Font.Normal
                                    color: parent.selected ? "#006BFF" : "#A6000000"
                                }

                                MouseArea {
                                    id: toolCategoryMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: toolsSettingRec.selectedToolCategory = modelData
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: toolsScrollView
                        width: parent.width - 120
                        height: toolsSettingRec.height - 16 - toolsTab.height - 16
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Column {
                            id: toolsScrollContent
                            width: toolsScrollView.width
                            spacing: 12

                            Label {
                                visible: toolsSettingRec.filteredTools(
                                    toolsSettingRec.selectedToolCategory).length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("暂无%1工具").arg(toolsSettingRec.selectedToolCategory)
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Grid {
                                id: toolCardGrid
                                columns: width >= 680 ? 2 : 1
                                spacing: 12
                                width: parent.width
                                property real cellWidth: columns === 2 ? (width - spacing) / 2 : width

                                Repeater {
                                    model: toolsSettingRec.filteredTools(
                                        toolsSettingRec.selectedToolCategory)

                                    delegate: Rectangle {
                                        width: toolCardGrid.cellWidth
                                        height: toolsLabelColumn.height
                                        radius: 8
                                        border.color: "#E1E4EA"
                                        border.width: 1
                                        color: "#FFFFFF"

                                        Column {
                                            id: toolsLabelColumn
                                            width: parent.width
                                            padding: 20
                                            spacing: 10

                                            Item {
                                                width: parent.width - 40
                                                height: 44

                                                Image {
                                                    id: toolIcon
                                                    anchors.left: parent.left
                                                    width: 28
                                                    height: 28
                                                    source: "qrc:/images/skillIcon.png"
                                                    fillMode: Image.PreserveAspectFit
                                                }

                                                Column {
                                                    anchors.left: toolIcon.right
                                                    anchors.leftMargin: 12
                                                    anchors.right: toolEnabledSwitch.left
                                                    anchors.rightMargin: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2

                                                    Label {
                                                        width: parent.width
                                                        text: modelData.label || modelData.toolId || ""
                                                        font.pixelSize: 14
                                                        font.weight: Font.DemiBold
                                                        color: "#D9000000"
                                                        elide: Text.ElideRight
                                                    }

                                                    Label {
                                                        width: parent.width
                                                        text: modelData.pluginId || modelData.toolId || ""
                                                        font.pixelSize: 14
                                                        color: "#40000000"
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Switch {
                                                    id: toolEnabledSwitch
                                                    checked: modelData.enabled === true
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    enabled: wsClient.connectionState === 3
                                                             && !wsClient.toolInstallBusy
                                                             && !wsClient.agentInstallBusy
                                                    onToggled: {
                                                        wsClient.setAgentToolEnabled(
                                                            "main",
                                                            modelData.toolId || "",
                                                            checked,
                                                            modelData.pluginId || "")
                                                    }
                                                    HoverHandler {
                                                        cursorShape: toolEnabledSwitch.enabled
                                                                     ? Qt.PointingHandCursor
                                                                     : Qt.ArrowCursor
                                                    }
                                                    indicator: Rectangle {
                                                        implicitWidth: 44
                                                        implicitHeight: 22
                                                        x: toolEnabledSwitch.leftPadding
                                                        radius: 11
                                                        color: toolEnabledSwitch.checked ? "#006BFF" : "#D9D9D9"
                                                        opacity: toolEnabledSwitch.enabled ? 1 : 0.55
                                                        Behavior on color { ColorAnimation { duration: 150 } }
                                                        Rectangle {
                                                            x: toolEnabledSwitch.checked ? parent.width - width - 3 : 3
                                                            y: parent.height / 2 - height / 2
                                                            width: 18
                                                            height: 18
                                                            radius: 9
                                                            color: "#FFFFFF"
                                                            Behavior on x {
                                                                NumberAnimation {
                                                                    duration: 150
                                                                    easing.type: Easing.OutCubic
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Label {
                                                id: toolDescLabel
                                                width: parent.width - 40
                                                text: modelData.description || ""
                                                font.pixelSize: 14
                                                lineHeight: 1.35
                                                color: "#73000000"
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight

                                                ToolTip {
                                                    visible: toolDescHover.containsMouse && toolDescLabel.truncated
                                                    text: toolDescLabel.text
                                                    delay: 500
                                                    x: 0
                                                    y: -height - 4
                                                    width: Math.min(implicitContentWidth + 20,
                                                                    toolsScrollView.width / 2 - 40)
                                                    background: Rectangle {
                                                        color: "#A6000000"
                                                        radius: 4
                                                    }
                                                    contentItem: Text {
                                                        text: toolDescLabel.text
                                                        font.pixelSize: 14
                                                        color: "#FFFFFF"
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                                MouseArea {
                                                    id: toolDescHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }

                                            Column {
                                                width: parent.width - 40
                                                spacing: 5
                                                visible: wsClient.toolInstallBusy
                                                         && wsClient.toolInstallingId === (modelData.toolId || "")
                                                height: visible ? implicitHeight : 0

                                                Rectangle {
                                                    width: parent.width
                                                    height: 6
                                                    radius: 3
                                                    color: "#E6E7EB"
                                                    Rectangle {
                                                        width: parent.width * Math.max(0, Math.min(100,
                                                            wsClient.toolInstallProgress)) / 100
                                                        height: parent.height
                                                        radius: 3
                                                        color: "#006BFF"
                                                        Behavior on width {
                                                            enabled: wsClient.toolInstallBusy
                                                                     && wsClient.toolInstallProgress > 0
                                                            NumberAnimation { duration: 180 }
                                                        }
                                                    }
                                                }
                                                Label {
                                                    width: parent.width
                                                    text: (wsClient.toolInstallMessage || "")
                                                          + "  " + wsClient.toolInstallProgress + "%"
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            TemplateLibraryPage {
                id: templateLibraryPage
                anchors.fill: parent
                visible: window.leftSelectedIndex === 8
                templates: wsClient.docxTemplates
                userTemplates: window.uploadedDocxTemplates
                loading: wsClient.docxTemplatesLoading
                gatewayHttpBaseUrl: wsClient.gatewayHttpBaseUrl

                onRefreshRequested: wsClient.refreshDocxTemplates()
                onUploadTemplateRequested: function(name, description,
                                                     templateFileUrl, coverFileUrl) {
                    if (!authController.loggedIn || !authController.userId) {
                        templateLibraryPage.finishUpload(qsTr("当前用户未登录"))
                        return
                    }
                    var result = $MainViewController.uploadUserTemplate(
                                String(authController.userId), name, description,
                                templateFileUrl, coverFileUrl) || ({})
                    if (!result.success) {
                        templateLibraryPage.finishUpload(
                                    String(result.error || qsTr("模板上传失败")))
                        return
                    }
                    window.reloadUploadedDocxTemplates()
                    templateLibraryPage.finishUpload("")
                }
                onUseTemplateRequested: function(template) {
                    newTaskRec.startDocxTemplate(template)
                }
                onMessageRequested: function(message) {
                    errorToast.text = message
                    errorToast.visible = true
                    errorToastTimer.restart()
                }
            }

            Rectangle {
                id: knowledgeBaseRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 7
                color: "#FFFFFF"
                property string pendingDeleteName: ""
                property string pendingDeleteKey: ""
                property string pendingDeleteCollectionId: ""
                property string pendingDeleteCollectionName: ""
                property bool busy: window.kbLoading

                function toggleEntrySelection(key) {
                    window.kbToggleSelected(String(key || ""))
                }

                function isEntrySelected(key) {
                    return window.kbIsSelected(String(key || ""))
                }

                function fileIconFor(name) {
                    return window.kbFileIcon(String(name || ""))
                }

                function formatAddedAt(value) {
                    return window.kbFormatTime(value)
                }

                Column {
                    anchors.fill: parent
                    anchors.leftMargin: 60
                    anchors.rightMargin: 60
                    anchors.topMargin: 24
                    anchors.bottomMargin: 28
                    spacing: 16

                    Item {
                        id: kbTopBar
                        width: parent.width
                        height: 40

                        Item {
                            id: kbTabsCluster
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: 40
                            readonly property real availableWidth: Math.max(
                                44, kbSearchInput.x - x - 24)
                            width: Math.min(availableWidth,
                                            Math.max(44, kbCollectionTabs.contentWidth + 48))

                            ListView {
                                id: kbCollectionTabs
                                anchors.left: parent.left
                                anchors.right: kbAddCollectionButton.left
                                anchors.rightMargin: 8
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                orientation: ListView.Horizontal
                                spacing: 4
                                clip: true
                                interactive: contentWidth > width
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick
                                model: window.kbCollections
                                onMovementStarted: kbCollectionActionPopup.close()

                                delegate: Rectangle {
                                    id: kbCollectionTab
                                    readonly property string collectionId: String(modelData.id || "")
                                    readonly property bool selected: collectionId === window.kbSelectedCollection
                                    readonly property bool hovered: kbCollectionTabMouse.containsMouse
                                                                             || kbCollectionTabMoreMouse.containsMouse
                                    readonly property bool actionMenuOpen: kbCollectionActionPopup.visible
                                                                                 && knowledgeBaseRec.pendingDeleteCollectionId === collectionId
                                    width: Math.min(180, Math.max(94, kbCollectionTabTextMetrics.advanceWidth + 52))
                                    height: 40
                                    radius: 4
                                    color: selected ? "#F2F3F5"
                                                    : hovered || actionMenuOpen ? "#F7F8FA" : "transparent"

                                    TextMetrics {
                                        id: kbCollectionTabTextMetrics
                                        text: String(modelData.name || "")
                                        font.pixelSize: 20
                                        font.family: "Alibaba PuHuiTi 3.0"
                                    }

                                    Label {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 14
                                        anchors.right: kbCollectionTabMore.left
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(modelData.name || "")
                                        elide: Text.ElideRight
                                        font.pixelSize: 20
                                        font.weight: kbCollectionTab.selected ? Font.Bold : Font.Medium
                                        color: kbCollectionTab.selected ? "#D9000000" : "#A6000000"
                                    }

                                    MouseArea {
                                        id: kbCollectionTabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        enabled: !window.kbLoading
                                        onClicked: {
                                            kbCollectionActionPopup.close()
                                            window.kbSelectCollection(kbCollectionTab.collectionId)
                                        }
                                        onWheel: {
                                            var delta = wheel.angleDelta.y !== 0
                                                    ? wheel.angleDelta.y : wheel.angleDelta.x
                                            var maxContentX = Math.max(0,
                                                kbCollectionTabs.contentWidth - kbCollectionTabs.width)
                                            kbCollectionTabs.contentX = Math.max(0, Math.min(maxContentX,
                                                kbCollectionTabs.contentX - delta * 0.5))
                                            wheel.accepted = true
                                        }
                                    }

                                    Rectangle {
                                        id: kbCollectionTabMore
                                        width: 28
                                        height: 28
                                        radius: 4
                                        anchors.right: parent.right
                                        anchors.rightMargin: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        z: 2
                                        visible: kbCollectionTab.hovered || kbCollectionTab.actionMenuOpen
                                        color: kbCollectionTabMoreMouse.containsMouse ? "#14000000" : "#0A000000"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: "qrc:/images/more.png"
                                        }

                                        MouseArea {
                                            id: kbCollectionTabMoreMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !window.kbLoading
                                            onClicked: {
                                                knowledgeBaseRec.pendingDeleteCollectionId = kbCollectionTab.collectionId
                                                knowledgeBaseRec.pendingDeleteCollectionName = String(modelData.name || "")
                                                var point = kbCollectionTabMore.mapToItem(
                                                    kbTopBar,
                                                    kbCollectionTabMore.width - kbCollectionActionPopup.width,
                                                    kbCollectionTabMore.height + 6)
                                                kbCollectionActionPopup.popupX = Math.max(0, Math.min(
                                                    kbTopBar.width - kbCollectionActionPopup.width, point.x))
                                                kbCollectionActionPopup.popupY = point.y
                                                kbCollectionActionPopup.open()
                                            }
                                            onWheel: {
                                                var delta = wheel.angleDelta.y !== 0
                                                        ? wheel.angleDelta.y : wheel.angleDelta.x
                                                var maxContentX = Math.max(0,
                                                    kbCollectionTabs.contentWidth - kbCollectionTabs.width)
                                                kbCollectionTabs.contentX = Math.max(0, Math.min(maxContentX,
                                                    kbCollectionTabs.contentX - delta * 0.5))
                                                wheel.accepted = true
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: kbAddCollectionButton
                                width: 32
                                height: 32
                                radius: 4
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: kbAddCollectionMouse.pressed ? "#F0F1F4"
                                       : kbAddCollectionMouse.containsMouse ? "#F7F8FA" : "#FFFFFF"
                                border.width: 1
                                border.color: "#D7D9DE"

                                Label {
                                    anchors.centerIn: parent
                                    text: "+"
                                    font.pixelSize: 20
                                    color: "#73000000"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    id: kbAddCollectionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: {
                                        kbCollectionActionPopup.close()
                                        kbCollectionNameInput.text = ""
                                        kbCreateCollectionPopup.open()
                                    }
                                }

                                ToolTip {
                                    id: kbAddCollectionTip
                                    visible: kbAddCollectionMouse.containsMouse
                                    text: qsTr("新建知识库")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: kbAddCollectionTip.text
                                        font.pixelSize: 13
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                    }
                                }
                            }
                        }

                        Popup {
                            id: kbCollectionActionPopup
                            property real popupX: 0
                            property real popupY: 0
                            x: popupX
                            y: popupY
                            width: 76
                            height: 40
                            padding: 0
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                            background: Rectangle {
                                color: "#FFFFFF"
                                radius: 6
                                border.width: 1
                                border.color: "#E1E3E8"
                            }
                            contentItem: Rectangle {
                                color: kbCollectionActionDeleteMouse.containsMouse ? "#FFF2F2" : "transparent"
                                radius: 6
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Image {
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: "qrc:/images/delete.png"
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("删除")
                                        font.pixelSize: 14
                                        color: "#FF3D40"
                                    }
                                }
                                MouseArea {
                                    id: kbCollectionActionDeleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        kbCollectionActionPopup.close()
                                        kbDeleteCollectionConfirm.open()
                                    }
                                }
                            }
                        }

                        SingleLineTextInput {
                            id: kbSearchInput
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            inputWidth: Math.min(240, knowledgeBaseRec.width * 0.28)
                            inputHeight: 36
                            icon: "qrc:/images/search.png"
                            iconSize: 16
                            placeholderText: qsTr("搜索知识库文件...")
                            text: window.kbSearchText
                            onTextChanged: {
                                window.kbSearchText = text
                                window.kbSelectedKeys = []
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 40

                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 52
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("全部文件") + " " + window.kbVisibleEntries().length + qsTr(" 个")
                            font.pixelSize: 14
                            color: "#73000000"
                        }
                        CheckBox {
                            id: kbSelectAll
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24
                            checked: window.kbVisibleEntries().length > 0
                                     && window.kbSelectedKeys.length === window.kbVisibleEntries().length
                            onClicked: window.kbToggleSelectAll()
                            indicator: Rectangle {
                                width: 22; height: 22; radius: 5
                                anchors.centerIn: parent
                                color: kbSelectAll.checked ? "#006BFF" : "#FFFFFF"
                                border.width: 1
                                border.color: kbSelectAll.checked ? "#006BFF" : "#D7D9DE"
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: kbSelectAll.checked
                                    color: "#FFFFFF"
                                    font.pixelSize: 14
                                }
                            }
                        }

                        Row {
                            id: kbActionsRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                visible: window.kbSelectedKeys.length > 0
                                width: visible ? 125 : 0
                                height: 36
                                radius: 6
                                color: kbBatchDeleteMouse.pressed ? "#E72F33" : "#FF3D40"
                                Row {
                                    height: parent.height
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 6
                                    Image { source: "qrc:/images/delete-white.png";anchors.verticalCenter: parent.verticalCenter;width:16;height:16}
                                    Label {
                                        text: qsTr("批量删除") + "(" + window.kbSelectedKeys.length + ")"
                                        color: "#FFFFFF"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    id: kbBatchDeleteMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                    onClicked: {
                                        knowledgeBaseRec.pendingDeleteName = window.kbSelectedKeys.length + qsTr(" 个项目")
                                        knowledgeBaseRec.pendingDeleteKey = "batch"
                                        kbDeleteConfirm.open()
                                    }
                                }
                            }

                            Rectangle {
                                id: kbUploadButton
                                width: 124
                                height: 36
                                radius: 6
                                color: kbUploadMouse.pressed ? "#075BCC" : "#006BFF"
                                opacity: kbUploadMouse.enabled ? 1 : 0.5
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    height: parent.height
                                    spacing: 7
                                    Image {
                                        width: 16; height: 16
                                        source: "qrc:/images/upload-white.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("上传文件")
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                    }
                                }
                                MouseArea {
                                    id: kbUploadMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !window.kbLoading
                                             && wsClient.knowledgeBaseDataDirReady
                                             && window.kbSelectedCollection.length > 0
                                    onClicked: kbFileDialog.open()
                                }
                                ToolTip {
                                    id: kbUploadTip
                                    visible: kbUploadMouse.containsMouse
                                    text: qsTr("仅支持PDF，Word，TXT，MD，XLSX格式")
                                    delay: 400
                                    background: Rectangle { color: "#A6000000"; radius: 4 }
                                    contentItem: Text {
                                        text: kbUploadTip.text
                                        font.pixelSize: 14
                                        color: "#FFFFFF"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        wrapMode: Text.NoWrap
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - 40 - 40 - 32

                        Column {
                            anchors.fill: parent

                            ScrollView {
                                id: kbFileScroll
                                width: parent.width
                                height: parent.height
                                clip: true
                                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                                Column {
                                    width: kbFileScroll.width

                                    Repeater {
                                        model: window.kbVisibleEntries()
                                        delegate: Rectangle {
                                            id: kbFileRow
                                            readonly property var pageController: knowledgeBaseRec
                                            readonly property string sourceName: String(modelData.name || "")
                                            readonly property string entryKey: String(modelData.key || "")
                                            width: kbFileScroll.width
                                            height: 56
                                            color: kbRowMouse.containsMouse ? "#F7F9FA" : "#FFFFFF"

                                            MouseArea {
                                                id: kbRowMouse
                                                anchors.fill: parent
                                                acceptedButtons: Qt.NoButton
                                                hoverEnabled: true
                                            }

                                            CheckBox {
                                                id: kbRowCheck
                                                x: 16; anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24
                                                checked: kbFileRow.pageController.isEntrySelected(kbFileRow.entryKey)
                                                onClicked: kbFileRow.pageController.toggleEntrySelection(kbFileRow.entryKey)
                                                indicator: Rectangle {
                                                    width: 22; height: 22; radius: 5
                                                    anchors.centerIn: parent
                                                    color: kbRowCheck.checked ? "#006BFF" : "#FFFFFF"
                                                    border.width: 1
                                                    border.color: kbRowCheck.checked ? "#006BFF" : "#D7D9DE"
                                                    Label {
                                                        anchors.centerIn: parent; text: "✓"
                                                        visible: kbRowCheck.checked; color: "#FFFFFF"; font.pixelSize: 14
                                                    }
                                                }
                                            }
                                            Image {
                                                x: 52; width: 24; height: 24
                                                anchors.verticalCenter: parent.verticalCenter
                                                source: kbFileRow.pageController.fileIconFor(kbFileRow.sourceName)
                                            }
                                            Label {
                                                x: 88
                                                width: parent.width * 0.64 - x - 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: kbFileRow.sourceName
                                                elide: Text.ElideMiddle
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                            }
                                            Label {
                                                x: parent.width * 0.64; width: 170
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: kbFileRow.pageController.formatAddedAt(modelData.addedAt)
                                                font.pixelSize: 14; color: "#73000000"
                                            }
                                            Label {
                                                x: parent.width * 0.83; width: 100
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: String(modelData.size || "--")
                                                font.pixelSize: 14; color: "#73000000"
                                            }
                                            Rectangle {
                                                id: kbDeleteButton
                                                width: 36; height: 36; radius: 6
                                                anchors.right: parent.right
                                                anchors.rightMargin: 16
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: kbRowMouse.containsMouse || kbDeleteMouse.containsMouse
                                                color: kbDeleteMouse.containsMouse ? "#0FFF3D40" : "transparent"
                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 16; height: 16
                                                    source: "qrc:/images/delete.png"
                                                }
                                                MouseArea {
                                                    id: kbDeleteMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !kbFileRow.pageController.busy
                                                    onClicked: {
                                                        knowledgeBaseRec.pendingDeleteName = kbFileRow.sourceName
                                                        knowledgeBaseRec.pendingDeleteKey = kbFileRow.entryKey
                                                        kbDeleteConfirm.open()
                                                    }
                                                }
                                                ToolTip.visible: kbDeleteMouse.containsMouse
                                                ToolTip.text: qsTr("删除")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            visible: !window.kbLoading && window.kbVisibleEntries().length === 0
                            text: !window.kbSelectedCollection ? qsTr("请先新建知识库")
                                  : window.kbSearchText ? qsTr("未找到匹配文件") : qsTr("暂无知识库文件")
                            font.pixelSize: 14
                            color: "#73000000"
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: window.kbLoading
                            color: "#CCFFFFFF"
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                BusyIndicator {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    running: window.kbLoading
                                    width: 32; height: 32
                                }
                                Label {
                                    text: window.kbBusyText
                                    color: "#73000000"
                                    font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: kbCreateCollectionPopup
                    anchors.centerIn: parent
                    width: Math.min(484, parent.width - 32)
                    height: 202
                    modal: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    padding: 0
                    onOpened: kbCollectionNameInput.forceActiveFocus()
                    background: Rectangle {
                        color: "#FFFFFF"; radius: 14
                        border.width: 1; border.color: "#E1E3E8"
                    }
                    contentItem: Item {
                        anchors.fill: parent

                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.top: parent.top
                            anchors.topMargin: 16
                            text: qsTr("新建知识库")
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            color: "#D9000000"
                        }

                        Rectangle {
                            id: kbCreateCloseButton
                            width: 28
                            height: 28
                            radius: 4
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            color: kbCreateCloseMouse.containsMouse ? "#F2F3F5" : "transparent"

                            Label {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 20
                                color: "#A6000000"
                            }
                            MouseArea {
                                id: kbCreateCloseMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: kbCreateCollectionPopup.close()
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 49
                            height: 1
                            color: "#E8E9ED"
                        }

                        Rectangle {
                            id: kbCollectionNameFrame
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            anchors.top: parent.top
                            anchors.topMargin: 75
                            height: 32
                            radius: 6
                            color: "#FFFFFF"
                            border.width: 1
                            border.color: kbCollectionNameInput.activeFocus ? "#006BFF" : "#D7D9DE"

                            TextField {
                                id: kbCollectionNameInput
                                anchors.left: parent.left
                                anchors.right: kbCollectionNameCounter.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                leftPadding: 10
                                rightPadding: 6
                                topPadding: 0
                                bottomPadding: 0
                                maximumLength: 40
                                placeholderText: qsTr("请输入新建知识库名称")
                                placeholderTextColor: "#40000000"
                                selectByMouse: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.pixelSize: 13
                                color: "#D9000000"
                                background: Item {}
                                onAccepted: {
                                    if (window.kbCreateCollection(text))
                                        kbCreateCollectionPopup.close()
                                }
                            }

                            Label {
                                id: kbCollectionNameCounter
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: kbCollectionNameInput.text.length + "/40"
                                font.pixelSize: 13
                                color: "#40000000"
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 18
                            spacing: 10
                            CustomButton {
                                width: 77; height: 33; text: qsTr("取消"); fontSize: 13
                                buttonRadius: 4
                                backgroundColor: "#F7F8FA"; textColor: "#73000000"
                                borderWidth: 1; borderColor: "#E1E3E8"
                                onClicked: kbCreateCollectionPopup.close()
                            }
                            CustomButton {
                                width: 77; height: 33; text: qsTr("导入"); fontSize: 13
                                buttonRadius: 4
                                backgroundColor: "#006BFF"; textColor: "#FFFFFF"; borderWidth: 0
                                onClicked: {
                                    if (window.kbCreateCollection(kbCollectionNameInput.text))
                                        kbCreateCollectionPopup.close()
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: kbDeleteCollectionConfirm
                    anchors.centerIn: parent
                    width: Math.min(400, parent.width - 32); height: 190
                    modal: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        color: "#FFFFFF"; radius: 8
                        border.width: 1; border.color: "#E1E3E8"
                    }
                    contentItem: Column {
                        anchors.fill: parent; anchors.margins: 24; spacing: 20
                        Label {
                            width: parent.width
                            text: qsTr("删除知识库")
                            font.pixelSize: 17; font.weight: Font.Bold; color: "#D9000000"
                        }
                        Label {
                            width: parent.width
                            text: qsTr("删除后知识库内所有文件将无法恢复，确定删除“")
                                  + knowledgeBaseRec.pendingDeleteCollectionName + qsTr("”？")
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14; color: "#A6000000"
                        }
                        Row {
                            anchors.right: parent.right; spacing: 8
                            CustomButton {
                                width: 72; height: 34; text: qsTr("取消"); fontSize: 13
                                backgroundColor: "#F0F1F4"; textColor: "#D9000000"; borderWidth: 0
                                onClicked: kbDeleteCollectionConfirm.close()
                            }
                            CustomButton {
                                width: 72; height: 34; text: qsTr("删除"); fontSize: 13
                                backgroundColor: "#FF3D40"; textColor: "#FFFFFF"; borderWidth: 0
                                onClicked: {
                                    var collection = knowledgeBaseRec.pendingDeleteCollectionId
                                    kbDeleteCollectionConfirm.close()
                                    window.kbDeleteCollection(collection)
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: kbDeleteConfirm
                    anchors.centerIn: parent
                    width: 380
                    height: 180
                    modal: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                    background: Rectangle {
                        color: "#FFFFFF"
                        radius: 8
                        border.width: 1
                        border.color: "#E1E3E8"
                    }
                    contentItem: Column {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 20
                        Label {
                            width: parent.width
                            text: knowledgeBaseRec.pendingDeleteKey === "batch"
                                  ? qsTr("批量删除") : qsTr("删除知识库项目")
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            color: "#D9000000"
                        }
                        Label {
                            width: parent.width
                            text: qsTr("确定删除“") + knowledgeBaseRec.pendingDeleteName + qsTr("”？")
                            elide: Text.ElideMiddle
                            font.pixelSize: 14
                            color: "#A6000000"
                        }
                        Row {
                            anchors.right: parent.right
                            spacing: 8
                            CustomButton {
                                width: 72; height: 34
                                text: qsTr("取消")
                                fontSize: 13
                                backgroundColor: "#F0F1F4"
                                textColor: "#D9000000"
                                borderWidth: 0
                                onClicked: kbDeleteConfirm.close()
                            }
                            CustomButton {
                                width: 72; height: 34
                                text: qsTr("删除")
                                fontSize: 13
                                backgroundColor: "#FF3D40"
                                textColor: "#FFFFFF"
                                borderWidth: 0
                                onClicked: {
                                    kbDeleteConfirm.close()
                                    if (knowledgeBaseRec.pendingDeleteKey === "batch")
                                        window.kbDeleteEntries(window.kbSelectedKeys)
                                    else
                                        window.kbDeleteEntries([knowledgeBaseRec.pendingDeleteKey])
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: mcpSettingRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 5
                property string mcpSearchText: ""

                function filteredMcpList() {
                    var list = wsClient.mcpList
                    var q = (mcpSearchText || "").trim().toLowerCase()
                    if (!q)
                        return list
                    var result = []
                    for (var i = 0; i < list.length; i++) {
                        var e = list[i]
                        var name = String(e.name || e.title || "").toLowerCase()
                        var desc = String(e.description || e.desc || "").toLowerCase()
                        var url = String(e.url || "").toLowerCase()
                        var cmd = String(e.command || "").toLowerCase()
                        var args = String(e.argsText || "").toLowerCase()
                        if (name.indexOf(q) >= 0 || desc.indexOf(q) >= 0
                                || url.indexOf(q) >= 0 || cmd.indexOf(q) >= 0
                                || args.indexOf(q) >= 0)
                            result.push(e)
                    }
                    return result
                }

                onVisibleChanged: {
                    if (visible && wsClient.connectionState === 3)
                        wsClient.refreshMcpList()
                }
                Column {
                    anchors.fill: parent
                    leftPadding: 60
                    topPadding: 24
                    rightPadding: 60
                    spacing: 16
                    Rectangle {
                        id: mcpTitleRec
                        height: mcpTitle.height
                        width: parent.width - 120
                        Column {
                            id: mcpTitle
                            spacing: 8
                            anchors.left: parent.left
                            Label {
                                text: qsTr("MCP")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Label {
                                text: qsTr("配置和管理 MCP（Model Context Protocol）服务器，为您的智能体扩展工具能力")
                                font.pixelSize: 14
                                color: "#A6000000"
                            }
                            SingleLineTextInput {
                                id: mcpSearchInput
                                inputHeight: 36
                                inputWidth: mcpTitleRec.width
                                icon: "qrc:/images/search.png"
                                iconSize: 16
                                placeholderText: qsTr("搜索 MCP")
                                onTextChanged: mcpSettingRec.mcpSearchText = text
                            }
                        }
                        CustomButton {
                            width: 80
                            height: 36
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 添加"
                            fontSize: 14
                            anchors.right: parent.right
                            onClicked: {
                                window.mcpEditEntry = null
                                mcpServiceDialog.isEdit = false
                                mcpServiceDialog.open()
                            }
                        }
                    }
                    TabBarView {
                        id: mcpTab
                        lineWidth: parent.width - 120
                        tabs: [{ text: "已安装", badge: wsClient.mcpList.length }]
                    }

                    ScrollView {
                        id: mcpInstalledScrollView
                        width: parent.width - 120
                        height: mcpSettingRec.height - 24 - mcpTitleRec.height - mcpTab.height - 32
                        clip: true
                        visible: mcpTab.currentIndex === 0
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Grid {
                            id: mcpInstalledGrid
                            columns: width >= 680 ? 2 : 1
                            spacing: 12
                            width: mcpInstalledScrollView.width
                            property real cellWidth: columns === 2 ? (width - spacing) / 2 : width

                            Label {
                                visible: wsClient.mcpList.length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("暂无 MCP 服务，请点击「+ 添加」从网关配置写入 mcp.servers")
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                visible: wsClient.mcpList.length > 0 && mcpSettingRec.filteredMcpList().length === 0
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: 40
                                text: qsTr("未找到匹配的 MCP 服务，请尝试其他关键词")
                                font.pixelSize: 14
                                color: "#73000000"
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: mcpSettingRec.filteredMcpList()

                                delegate: Rectangle {
                                    width: mcpInstalledGrid.cellWidth
                                    height: 100
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    HoverHandler {
                                        id: mcpCardHover
                                    }

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        width: parent.width - 40
                                        spacing: 12
                                        Row {
                                            spacing: 12
                                            height: 28
                                            Image {
                                                width: 28; height: 28
                                                source: modelData.icon || "qrc:/images/skillIcon.png"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            Label {
                                                text: modelData.title || modelData.name || ""
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        Label {
                                            text: modelData.desc || ""
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        spacing: 8
                                        height: 28

                                        ImageButton {
                                            source: "qrc:/images/edit.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                            onClicked: {
                                                window.mcpEditEntry = modelData
                                                mcpServiceDialog.isEdit = true
                                                mcpServiceDialog.open()
                                            }
                                        }
                                        ImageButton {
                                            btnHeight: 16
                                            btnWidth: 16
                                            source: "qrc:/images/delete.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                            onClicked: {
                                                window.pendingDeleteMcpName = modelData.name || ""
                                                deleteMcpPopup.open()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: cronIdeaLibraryPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: "#59000000" }
        background: Rectangle { color: "transparent" }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: cronIdeaLibraryPopup.close()
            }

            Rectangle {
                id: cronIdeaDialogCard
                width: Math.min(980, parent.width - 64)
                height: Math.min(640, parent.height - 80)
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"
                clip: true

                MouseArea { anchors.fill: parent; onClicked: {} }

                Item {
                    id: cronIdeaDialogHeader
                    width: parent.width
                    height: 56

                    Label {
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("灵感库")
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: "#D9000000"
                    }

                    ImageButton {
                        btnWidth: 20
                        btnHeight: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: cronIdeaLibraryPopup.close()
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        anchors.bottom: parent.bottom
                        color: "#14000000"
                    }
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: cronIdeaDialogHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.margins: 20

                    Flow {
                        id: cronIdeaCategoryFlow
                        width: parent.width
                        height: childrenRect.height
                        spacing: 8

                        Repeater {
                            model: window.cronTemplateCategories
                            delegate: Rectangle {
                                width: ideaCategoryLabel.implicitWidth + 20
                                height: 30
                                radius: 6
                                color: index === window.selectedCronTemplateCategory
                                       ? "#0F006BFF"
                                       : (ideaCategoryMouse.containsMouse ? "#0A000000" : "#F7F9FA")

                                Label {
                                    id: ideaCategoryLabel
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    font.pixelSize: 14
                                    color: index === window.selectedCronTemplateCategory
                                           ? "#006BFF" : "#A6000000"
                                }

                                MouseArea {
                                    id: ideaCategoryMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.selectedCronTemplateCategory = index
                                        cronIdeaCardsScroll.contentItem.contentY = 0
                                    }
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: cronIdeaCardsScroll
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: cronIdeaCategoryFlow.bottom
                        anchors.topMargin: 14
                        anchors.bottom: parent.bottom
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Grid {
                            id: cronIdeaCardsGrid
                            width: cronIdeaCardsScroll.width
                            property int cardColumns: Math.max(1, Math.min(5,
                                Math.floor((width + spacing) / 170)))
                            property real cardWidth: (width - (cardColumns - 1) * spacing) / cardColumns
                            property real cardHeight: cardWidth * 170 / 196
                            columns: cardColumns
                            spacing: 14
                            height: Math.ceil(window.cronTemplateCategories[window.selectedCronTemplateCategory].tasks.length
                                              / cardColumns) * cardHeight
                                    + Math.max(0, Math.ceil(window.cronTemplateCategories[window.selectedCronTemplateCategory].tasks.length
                                                          / cardColumns) - 1) * spacing

                            Repeater {
                                model: window.cronTemplateCategories[window.selectedCronTemplateCategory].tasks
                                delegate: Item {
                                    id: cronIdeaCard
                                    property var task: modelData
                                    width: cronIdeaCardsGrid.cardWidth
                                    height: cronIdeaCardsGrid.cardHeight

                                    DropShadow {
                                        anchors.fill: ideaCardImage
                                        source: ideaCardImage
                                        horizontalOffset: 0
                                        verticalOffset: 6
                                        radius: 14
                                        samples: 29
                                        color: "#26000000"
                                        visible: ideaCardMouse.containsMouse
                                    }

                                    Image {
                                        id: ideaCardImage
                                        anchors.fill: parent
                                        source: "qrc:/images/cron/"
                                                + (window.selectedCronTemplateCategory + 1)
                                                + "-" + (index + 1) + ".png"
                                        fillMode: Image.PreserveAspectFit
                                        sourceSize: Qt.size(196, 170)
                                    }

                                    Rectangle {
                                        width: 58
                                        height: 38
                                        radius: 8
                                        anchors.centerIn: parent
                                        color: ideaCardMouse.pressed ? "#005CE6" : "#006BFF"
                                        visible: ideaCardMouse.containsMouse
                                        z: 2
                                        Label {
                                            anchors.centerIn: parent
                                            text: qsTr("使用")
                                            font.pixelSize: 14
                                            color: "#FFFFFF"
                                        }
                                    }

                                    MouseArea {
                                        id: ideaCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            cronIdeaLibraryPopup.close()
                                            window.openCronTemplate(cronIdeaCard.task)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 130 }
        }
    }

    Popup {
        id: newTaskDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        onVisibleChanged: {
            if (!visible) {
                window.editingCronJobId = ""
                window.editingCronPayloadKind = "agentTurn"
                window.editingCronScheduleKind = ""
                window.editingCronScheduleExpr = ""
                window.editingCronScheduleTz   = ""
                window.pendingCronTemplateExpr = ""
                window.pendingCronTemplateTrigger = ""
                newTaskWorkDirInput.text = ""
            }
        }

        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
        }
        exit: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
            }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: newTaskDialog.close()
            }

            Rectangle {
                id: dialogCard
                width: Math.min(600, parent.width - 32)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: dialogTitleBar.height + dialogContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // 阻止点击穿透关闭
                }

                Item {
                    id: dialogTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        id: newTaskDialogTitleLabel
                        text: window.editingCronJobId ? qsTr("编辑定时任务") : qsTr("新建任务")
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: newTaskDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: dialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: dialogTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("标题")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: newTaskTitleInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            placeholderText: qsTr("请输入任务标题")
                            fontSize: 14
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("提示词")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        MultiLineTextInput {
                            id: newTaskPromptInput
                            width: parent.width
                            inputHeight: 120
                            placeholderText: qsTr("请输入要执行的提示词")
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("计划")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Row {
                            width: parent.width
                            spacing: 12
                            DropdownSelect {
                                id: newTaskRepeatSelect
                                width: (parent.width - 24) / 3
                                height: 40
                                model: ["不重复", "每天", "每周", "每小时", "自定义间隔"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                                onSelected: {
                                    window.pendingCronTemplateExpr = ""
                                    window.pendingCronTemplateTrigger = ""
                                }
                            }
                            DatePicker {
                                id: newTaskDatePicker
                                width: (parent.width - 24) / 3
                                height: 40
                                onDateSelected: {
                                    window.pendingCronTemplateExpr = ""
                                    window.pendingCronTemplateTrigger = ""
                                }
                            }
                            TimePicker {
                                id: newTaskTimePicker
                                width: (parent.width - 24) / 3
                                height: 40
                                onTimeSelected: {
                                    window.pendingCronTemplateExpr = ""
                                    window.pendingCronTemplateTrigger = ""
                                }
                            }
                        }
                        Label {
                            visible: window.pendingCronTemplateExpr !== ""
                            text: qsTr("触发时间：") + window.pendingCronTemplateTrigger
                            font.pixelSize: 12
                            color: "#73000000"
                        }
                        Label {
                            visible: window.pendingCronTemplateExpr !== ""
                            text: qsTr("Cron：") + window.pendingCronTemplateExpr
                            font.pixelSize: 12
                            color: "#73000000"
                        }
                    }

                    // 自定义间隔输入（仅当选择"自定义间隔"时显示）
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: newTaskRepeatSelect.currentIndex === 4
                                 && window.pendingCronTemplateExpr === ""
                        Label {
                            text: qsTr("执行间隔（秒）")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: newTaskIntervalInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            placeholderText: qsTr("例如: 3600 = 每小时")
                            fontSize: 14
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: window.editingCronJobId === ""
                        Label {
                            text: qsTr("工作目录")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            SingleLineTextInput {
                                id: newTaskWorkDirInput
                                width: parent.width - 88
                                inputHeight: 40
                                inputRadius: 8
                                placeholderText: ""
                                readOnly: true
                                fontSize: 14
                            }
                            CustomButton {
                                width: 80
                                height: 40
                                backgroundColor: "#F7F9FA"
                                textColor: "#A6000000"
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                text: qsTr("浏览")
                                fontSize: 14
                                onClicked: workDirDialog.open()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: window.editingCronJobId ? qsTr("保存") : qsTr("创建")
                            fontSize: 14
                            onClicked: {
                                var title = newTaskTitleInput.text.trim()
                                var prompt = newTaskPromptInput.text.trim()
                                if (window.editingCronJobId) {
                                    if (!title) {
                                        errorToast.text = "请输入任务标题"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }
                                    if (!prompt) {
                                        errorToast.text = "请输入要执行的提示词"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }

                                    var repeatIdx = newTaskRepeatSelect.currentIndex
                                    var schedKind = 0
                                    var schedExpr = ""
                                    var schedTz   = "Asia/Shanghai"
                                    function pad2(n) { return n < 10 ? "0" + n : "" + n }

                                    var ehh = newTaskTimePicker.selectedHour
                                    var emm = newTaskTimePicker.selectedMinute

                                    if (repeatIdx === 0) {
                                        schedKind = 3
                                        var ey = newTaskDatePicker.selectedYear
                                        var emo = newTaskDatePicker.selectedMonth
                                        var ed = newTaskDatePicker.selectedDay
                                        schedExpr = ey + "-" + pad2(emo) + "-" + pad2(ed)
                                                  + "T" + pad2(ehh) + ":" + pad2(emm) + ":00"
                                    } else if (repeatIdx === 1) {
                                        schedKind = 1
                                        schedExpr = emm + " " + ehh + " * * *"
                                    } else if (repeatIdx === 2) {
                                        schedKind = 1
                                        var eDate = new Date(newTaskDatePicker.selectedYear,
                                                             newTaskDatePicker.selectedMonth - 1,
                                                             newTaskDatePicker.selectedDay)
                                        var eDow = eDate.getDay()
                                        schedExpr = emm + " " + ehh + " * * " + eDow
                                    } else if (repeatIdx === 3) {
                                        schedKind = 1
                                        schedExpr = emm + " * * * *"
                                    } else if (repeatIdx === 4) {
                                        schedKind = 2
                                        var eSec = parseInt(newTaskIntervalInput.text) || 0
                                        if (eSec <= 0) {
                                            errorToast.text = "间隔须大于 0 秒"
                                            errorToast.visible = true
                                            errorToastTimer.restart()
                                            return
                                        }
                                        schedExpr = String(eSec * 1000)
                                    }

                                    wsClient.updateCronJobContent(
                                        window.editingCronJobId, title, prompt,
                                        window.editingCronPayloadKind,
                                        schedKind, schedExpr, schedTz)
                                    newTaskDialog.close()
                                    return
                                }
                                console.log("[CronAdd] title='" + title + "' prompt='" + prompt.substring(0,50) + "' repeat=" + newTaskRepeatSelect.currentIndex)
                                if (!title) {
                                    errorToast.text = "请输入任务标题"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }
                                if (!prompt) {
                                    errorToast.text = "请输入要执行的提示词"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }

                                var repeatIdx = newTaskRepeatSelect.currentIndex
                                var y = newTaskDatePicker.selectedYear
                                var m = newTaskDatePicker.selectedMonth
                                var d = newTaskDatePicker.selectedDay
                                var hh = newTaskTimePicker.selectedHour
                                var mm = newTaskTimePicker.selectedMinute
                                var cronWorkspace = newTaskWorkDirInput.text.trim()

                                function pad(n) { return n < 10 ? "0" + n : "" + n }

                                if (window.pendingCronTemplateExpr) {
                                    console.log("[CronAdd] template cron=" + window.pendingCronTemplateExpr)
                                    wsClient.prepareCronJobWithDedicatedAgent(
                                                1, title, prompt, window.pendingCronTemplateExpr,
                                                window.pendingCronTemplateTz, 0, "", cronWorkspace)
                                } else if (repeatIdx === 0) {
                                    var dt = y + "-" + pad(m) + "-" + pad(d) + "T" + pad(hh) + ":" + pad(mm) + ":00"
                                    console.log("[CronAdd] oneTime dateTime=" + dt)
                                    wsClient.prepareCronJobWithDedicatedAgent(3, title, prompt, "", "", 0, dt, cronWorkspace)
                                } else if (repeatIdx === 1) {
                                    var cronExpr = mm + " " + hh + " * * *"
                                    console.log("[CronAdd] daily cron=" + cronExpr)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 2) {
                                    var dateObj = new Date(y, m - 1, d)
                                    var dow = dateObj.getDay()
                                    var cronExpr2 = mm + " " + hh + " * * " + dow
                                    console.log("[CronAdd] weekly cron=" + cronExpr2)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr2, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 3) {
                                    var cronExpr3 = mm + " * * * *"
                                    console.log("[CronAdd] hourly cron=" + cronExpr3)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr3, "Asia/Shanghai", 0, "", cronWorkspace)
                                } else if (repeatIdx === 4) {
                                    var sec = parseInt(newTaskIntervalInput.text) || 3600
                                    if (sec <= 0) {
                                        errorToast.text = "间隔须大于 0 秒"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }
                                    console.log("[CronAdd] interval sec=" + sec)
                                    wsClient.prepareCronJobWithDedicatedAgent(2, title, prompt, "", "", sec, "", cronWorkspace)
                                }
                                newTaskDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: {
                                window.editingCronJobId = ""
                                window.pendingCronTemplateExpr = ""
                                window.pendingCronTemplateTrigger = ""
                                newTaskDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    /// 任务记录右键菜单：当前仅一项「删除」
    Popup {
        id: agentContextMenu
        parent: window.contentItem
        padding: 4
        width: 132
        height: agentContextMenuCol.implicitHeight + 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnReleaseOutside
        background: Rectangle {
            radius: 8
            color: "#FFFFFF"
            border.color: "#E6E7EB"
            border.width: 1
        }
        contentItem: Column {
            id: agentContextMenuCol
            spacing: 0
            width: parent.width

            Rectangle {
                id: agentContextDeleteItem
                width: parent.width
                height: 32
                radius: 6
                color: agentContextDeleteMouse.containsMouse ? "#0A000000" : "transparent"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Label {
                        text: qsTr("删除")
                        font.pixelSize: 14
                        color: "#E54545"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: agentContextDeleteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        agentContextMenu.close()
                        if (window.pendingDeleteTaskSessionId.length > 0)
                            deleteSessionPopup.open()
                    }
                }
            }
        }
    }

    /// 删除任务会话确认弹窗（参考 deleteCronJobPopup 的视觉风格）
    Popup {
        id: deleteSessionPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            window.pendingDeleteTaskSessionId = ""
            window.pendingDeleteTaskSessionName = ""
        }
        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除此任务？\n此操作会从任务列表移除该会话，不会删除 Agent。")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        var sid = window.pendingDeleteTaskSessionId
                        var deletingCurrent = sid.length > 0
                                && sid === String(wsClient.currentTaskSessionKey || "")
                        if (sid.length > 0)
                            wsClient.deleteTaskSession(sid)
                        if (deletingCurrent) {
                            leftMidPanel.activeAgentId = ""
                            leftMidPanel.activeSessionKey = ""
                            chatModel.clear()
                            window.leftSelectedIndex = 0
                        }
                        deleteSessionPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteSessionPopup.close()
                }
            }
        }
    }

    Popup {
        id: deleteCronJobPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除定时任务「") + window.pendingDeleteCronJobName + qsTr("」？")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        if (window.pendingDeleteCronJobId)
                            wsClient.removeCronJob(window.pendingDeleteCronJobId)
                        window.pendingDeleteCronJobId = ""
                        window.pendingDeleteCronJobName = ""
                        deleteCronJobPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteCronJobPopup.close()
                }
            }
        }
    }

    Popup {
        id: agentEditorPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        Overlay.modal: Rectangle { color: "#40000000" }
        background: Rectangle { color: "transparent" }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: agentEditorPopup.close()
            }

            Rectangle {
                width: Math.min(560, parent.width - 32)
                anchors.centerIn: parent
                height: agentEditorTitleBar.height + agentEditorContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: agentEditorTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: window.agentEditorIsEdit ? qsTr("编辑专家") : qsTr("新增专家")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: agentEditorPopup.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: agentEditorContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: agentEditorTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 16

                    Column {
                        width: parent.width
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("专家名称")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        SingleLineTextInput {
                            id: agentEditorNameInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("例如：researcher")
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: window.agentEditorIsEdit
                                  ? qsTr("IDENTITY.md（留空不修改）")
                                  : qsTr("IDENTITY.md（可选）")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        MultiLineTextInput {
                            id: agentEditorIdentityInput
                            inputWidth: parent.width
                            inputHeight: 160
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("描述该专家的角色、能力边界和协作方式")
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var name = agentEditorNameInput.text.trim()
                                var identity = agentEditorIdentityInput.text
                                if (name.length === 0) {
                                    errorToast.text = "请输入专家名称"
                                    errorToast.visible = true
                                    errorToastTimer.restart()
                                    return
                                }
                                if (window.agentEditorIsEdit) {
                                    wsClient.updateAgent(window.agentEditorAgentId, name, "", "")
                                    if (identity.trim().length > 0)
                                        wsClient.updateAgentIdentity(window.agentEditorAgentId, identity)
                                } else {
                                    wsClient.createAgent(name, "", false, identity)
                                }
                                agentEditorPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: agentEditorPopup.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deleteAgentPopup
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        width: 360
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            window.pendingDeleteAgentId = ""
            window.pendingDeleteAgentName = ""
        }
        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }
        contentItem: Column {
            spacing: 16
            width: parent.width
            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: qsTr("确定删除专家「") + window.pendingDeleteAgentName + qsTr("」？")
                font.pixelSize: 15
                color: "#D9000000"
            }
            Row {
                spacing: 12
                layoutDirection: Qt.RightToLeft
                anchors.right: parent.right
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#E54545"
                    textColor: "#FFFFFF"
                    borderWidth: 0
                    text: qsTr("删除")
                    fontSize: 14
                    onClicked: {
                        if (window.pendingDeleteAgentId.length > 0)
                            wsClient.deleteAgent(window.pendingDeleteAgentId, true)
                        deleteAgentPopup.close()
                    }
                }
                CustomButton {
                    width: 88
                    height: 36
                    backgroundColor: "#F7F9FA"
                    textColor: "#A6000000"
                    borderColor: "#E6E7EB"
                    borderWidth: 1
                    text: qsTr("取消")
                    fontSize: 14
                    onClicked: deleteAgentPopup.close()
                }
            }
        }
    }

    FileDialog {
        id: kbFileDialog
        title: qsTr("选择知识库文件")
        nameFilters: [qsTr("支持的文件 (*.pdf *.doc *.docx *.txt *.md *.xlsx)")]
        selectMultiple: true
        onAccepted: window.kbStartUpload(kbFileDialog.fileUrls)
    }

    FileDialog {
        id: zipFileDialog
        title: qsTr("选择 ZIP 文件")
        nameFilters: ["ZIP files (*.zip)"]
        selectMultiple: false
        onAccepted: {
            wsClient.addSkillFromZip(window.localFilePathFromUrl(zipFileDialog.fileUrl))
        }
    }

    FileDialog {
        id: folderDialog
        title: qsTr("选择文件夹")
        selectFolder: true
        onAccepted: {
            wsClient.addSkillFromFolder(window.localFilePathFromUrl(folderDialog.fileUrl))
        }
    }

    FileDialog {
        id: workDirDialog
        title: qsTr("选择工作目录")
        selectFolder: true
        onAccepted: {
            var path = decodeURIComponent(workDirDialog.fileUrl.toString().replace(/^file:\/{2,3}/, ""))
            if (Qt.platform.os === "windows") {
                if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                    path = path.substring(1)
                path = path.replace(/\//g, "\\")
            }else if(Qt.platform.os === "linux"){
                path = "/" + path
            }
            newTaskWorkDirInput.text = path
        }
    }

    Popup {
        id: githubImportDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: githubImportDialog.close()
            }

            Rectangle {
                width: Math.min(600, parent.width - 32)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: githubTitleBar.height + githubDialogContent.implicitHeight + 24 + 16
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: githubTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: qsTr("从 GitHub 导入")
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: githubImportDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Column {
                    id: githubDialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: githubTitleBar.bottom
                    anchors.margins: 24
                    anchors.topMargin: 16
                    spacing: 20

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: "URL"
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        SingleLineTextInput {
                            id: githubUrlInput
                            width: parent.width
                            inputHeight: 36
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: "https://github.com/owner/repo/tree/main/SKILLs/my-skil"
                        }
                    }
                    Label {
                        text: qsTr("支持仓库链接与子目录链接，owner/repo 或 GitHub tree/blob 链接；\n若仓库内有多个技能，将自动全部导入。")
                        font.pixelSize: 14
                        color: "#73000000"
                        lineHeight: 1.5
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("导入")
                            fontSize: 14
                            onClicked: {
                                wsClient.addSkillFromGit(githubUrlInput.text)
                                githubImportDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: githubImportDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: mcpServiceDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property bool isEdit: false

        onOpened: {
            if (isEdit && window.mcpEditEntry) {
                var e = window.mcpEditEntry
                mcpNameInput.text = e.name || ""
                mcpDescInput.text = e.description || ""
                mcpTransportSelect.currentIndex = e.transportHttp ? 1 : 0
                // 匹配命令下拉
                var cmdList = ["node", "npx", "uvx", "python"]
                var ci = cmdList.indexOf(e.command || "")
                mcpCommandSelect.currentIndex = ci >= 0 ? ci : 0
                mcpArgsInput.text = e.argsText || ""
                mcpHttpUrlInput.text = e.url || ""
                // 恢复环境变量
                envVarModel.clear()
                var envMap = e.env || {}
                var keys = Object.keys(envMap)
                if (keys.length > 0) {
                    for (var i = 0; i < keys.length; i++)
                        envVarModel.append({ key: keys[i], value: String(envMap[keys[i]]) })
                } else {
                    envVarModel.append({ key: "", value: "" })
                }
            } else {
                mcpNameInput.text = ""
                mcpDescInput.text = ""
                mcpTransportSelect.currentIndex = 0
                mcpCommandSelect.currentIndex = 0
                mcpArgsInput.text = ""
                mcpHttpUrlInput.text = ""
                envVarModel.clear()
                envVarModel.append({ key: "", value: "" })
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: mcpServiceDialog.close()
            }

            Rectangle {
                width: Math.min(560, parent.width - 32)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                height: mcpDialogTitleBar.height + mcpDialogScrollView.height + mcpDialogFooter.height
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: mcpDialogTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: mcpServiceDialog.isEdit ? qsTr("编辑 MCP 服务") : qsTr("添加 MCP 服务")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: mcpServiceDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                ScrollView {
                    id: mcpDialogScrollView
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: mcpDialogTitleBar.bottom
                    height: Math.min(mcpDialogContentCol.implicitHeight, window.height - 280)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    Column {
                        id: mcpDialogContentCol
                        width: mcpDialogScrollView.width
                        leftPadding: 24
                        rightPadding: 24
                        topPadding: 16
                        bottomPadding: 16
                        spacing: 16

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("服务名称")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            SingleLineTextInput {
                                id: mcpNameInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("请输入")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Label {
                                text: qsTr("描述")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            SingleLineTextInput {
                                id: mcpDescInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("描述此 MCP 服务的用途")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("传输类型")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            DropdownSelect {
                                id: mcpTransportSelect
                                width: parent.width
                                height: 40
                                model: ["标准输入输出（stdio）", "HTTP (SSE)"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 1
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("服务地址")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            SingleLineTextInput {
                                id: mcpHttpUrlInput
                                width: parent.width
                                inputHeight: 40
                                inputRadius: 8
                                fontSize: 14
                                placeholderText: qsTr("https://example.com/mcp")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Row {
                                spacing: 2
                                Label {
                                    text: qsTr("命令")
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                }
                                Label {
                                    text: "*"
                                    font.pixelSize: 14
                                    color: "#FF4D4F"
                                }
                            }
                            DropdownSelect {
                                id: mcpCommandSelect
                                width: parent.width
                                height: 40
                                model: ["node", "npx", "uvx", "python"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment: Qt.AlignLeft
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Label {
                                text: qsTr("参数")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            MultiLineTextInput {
                                id: mcpArgsInput
                                width: parent.width
                                inputHeight: 80
                                placeholderText: qsTr("每行一个参数")
                            }
                        }

                        Column {
                            width: parent.width - 48
                            spacing: 8
                            visible: mcpTransportSelect.currentIndex === 0
                            Label {
                                text: qsTr("环境变量")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }

                            Column {
                                width: parent.width
                                spacing: 8

                                Repeater {
                                    id: envVarRepeater
                                    model: ListModel {
                                        id: envVarModel
                                        ListElement { key: ""; value: "" }
                                    }

                                    delegate: Row {
                                        width: parent.width
                                        spacing: 8

                                        property bool isLast: index === envVarModel.count - 1

                                        SingleLineTextInput {
                                            width: (parent.width - 96) / 2
                                            inputHeight: 40
                                            inputRadius: 8
                                            fontSize: 14
                                            placeholderText: qsTr("键")
                                            text: model.key
                                            onTextChanged: {
                                                if (index >= 0 && index < envVarModel.count)
                                                    envVarModel.setProperty(index, "key", text)
                                            }
                                        }
                                        SingleLineTextInput {
                                            width: (parent.width - 96) / 2
                                            inputHeight: 40
                                            inputRadius: 8
                                            fontSize: 14
                                            placeholderText: qsTr("值")
                                            text: model.value
                                            onTextChanged: {
                                                if (index >= 0 && index < envVarModel.count)
                                                    envVarModel.setProperty(index, "value", text)
                                            }
                                        }
                                        CustomButton{
                                            width: 36
                                            height: 36
                                            borderColor: "#E6E7EB"
                                            borderWidth: 1
                                            buttonRadius: 8
                                            backgroundColor: "#FFFFFF"
                                            textColor: "#73000000"
                                            text: "-"
                                            visible: envVarModel.count !== 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                envVarModel.remove(index)
                                            }
                                        }
                                        CustomButton{
                                            width: 36
                                            height: 36
                                            borderColor: "#E6E7EB"
                                            borderWidth: 1
                                            buttonRadius: 8
                                            backgroundColor: "#FFFFFF"
                                            text: "+"
                                            textColor: "#73000000"
                                            visible: isLast
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                envVarModel.append({ key: "", value: "" })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: mcpDialogFooter
                    width: parent.width
                    height: 64
                    anchors.top: mcpDialogScrollView.bottom

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.top: parent.top
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var envObj = {}
                                for (var i = 0; i < envVarModel.count; i++) {
                                    var k = envVarModel.get(i).key.trim()
                                    var v = envVarModel.get(i).value
                                    if (k.length > 0)
                                        envObj[k] = v
                                }
                                var envStr = Object.keys(envObj).length > 0
                                    ? JSON.stringify(envObj) : ""

                                wsClient.applyMcpServer(
                                    mcpServiceDialog.isEdit,
                                    mcpServiceDialog.isEdit ? (window.mcpEditEntry ? (window.mcpEditEntry.name || "") : "") : "",
                                    mcpNameInput.text,
                                    mcpTransportSelect.currentIndex === 1,
                                    mcpCommandSelect.currentText,
                                    mcpArgsInput.text,
                                    mcpHttpUrlInput.text,
                                    mcpDescInput.text,
                                    envStr
                                )
                                mcpServiceDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: mcpServiceDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: deleteMcpPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }
        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: deleteMcpPopup.close()
            }
            Rectangle {
                width: Math.min(400, parent.width - 32)
                height: deleteMcpCol.implicitHeight
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    id: deleteMcpCol
                    width: parent.width
                    padding: 24
                    spacing: 20

                    Label {
                        text: qsTr("确认删除")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                    }

                    Label {
                        text: qsTr("确定要删除此 MCP 服务吗？此操作不可撤销。")
                        font.pixelSize: 14
                        color: "#A6000000"
                        wrapMode: Text.Wrap
                        width: parent.width - 48
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        spacing: 12
                        layoutDirection: Qt.RightToLeft

                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#FF4D4F"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("删除")
                            fontSize: 14
                            onClicked: {
                                wsClient.removeMcpServer(window.pendingDeleteMcpName)
                                deleteMcpPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: deleteMcpPopup.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: settingsDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property int settingsTabIndex: 0

        onOpened: {
            if (wsClient.connectionState === 3)
                wsClient.refreshModels()
            memorySwitch.checked = wsClient.memoryEnabled
            llmSwitch.checked = wsClient.llmJudgmentEnabled
            sandboxPage.sandboxMode = wsClient.sandboxMode
            wsClient.loadMemoryEntries()
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }

        Overlay.modal: Rectangle {
            color: "#40000000"
        }

        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: settingsDialog.close()
            }

            Rectangle {
                width: Math.min(720, parent.width - 32)
                height: Math.min(600, Math.max(360, parent.height - 32))
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Item {
                    id: settingsTitleBar
                    width: parent.width
                    height: 64

                    Label {
                        text: qsTr("设置")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ImageButton {
                        btnHeight: 20
                        btnWidth: 20
                        source: "qrc:/images/close.png"
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: settingsDialog.close()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.bottom: parent.bottom
                    }
                }

                Row {
                    anchors.top: settingsTitleBar.bottom
                    anchors.bottom: settingsFooter.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Rectangle {
                        id: settingsLeftNav
                        width: 180
                        height: parent.height
                        color: "#FFFFFF"

                        Column {
                            anchors.fill: parent
                            padding: 16
                            spacing: 8

                            Repeater {
                                model: [
                                    { text: "模型", icon: "qrc:/images/category.png" },
                                    { text: "记忆", icon: "qrc:/images/category.png" },
                                    { text: "沙箱", icon: "qrc:/images/category.png" }
                                ]

                                delegate: Rectangle {
                                    width: settingsLeftNav.width - 32
                                    height: 36
                                    radius: 8
                                    color: index === settingsDialog.settingsTabIndex ? "#E6E7EB"
                                         : settingsNavMouse.containsMouse ? "#E6E7EB"
                                         : "transparent"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8

                                        Image {
                                            width: 16; height: 16
                                            source: modelData.icon
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Label {
                                            text: modelData.text
                                            font.pixelSize: 14
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: settingsNavMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settingsDialog.settingsTabIndex = index
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: "#14000000"
                    }

                    ScrollView {
                        id: settingsContentScroll1
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 0
                        Column {
                            width: settingsContentScroll1.width
                            padding: 16
                            spacing: 12
                            Label {
                                text: qsTr("模型")
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }

                            Label {
                                visible: wsClient.modelList.length === 0
                                width: parent.width - 32
                                wrapMode: Text.WordWrap
                                text: wsClient.connectionState === 3
                                      ? qsTr("暂无可用模型，请稍后重试或检查网关配置。")
                                      : qsTr("未连接服务器，连接成功后将自动加载模型列表。")
                                font.pixelSize: 14
                                color: "#73000000"
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 4

                                Repeater {
                                    model: wsClient.modelList

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: modelRow.implicitHeight + 20
                                        radius: 8
                                        color: "transparent"

                                        Row {
                                            id: modelRow
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Image {
                                                width: 28; height: 28
                                                source: "qrc:/images/ai.png"
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Column {
                                                spacing: 2
                                                width: parent.width - 28 - 8 - 60
                                                anchors.verticalCenter: parent.verticalCenter

                                            Label {
                                                    width: parent.width
                                                    wrapMode: Text.WordWrap
                                                    text: {
                                                        var nm = modelData.name || modelData.id || ""
                                                        var pv = modelData.provider || ""
                                                        return window.modelDisplayLabel(nm, pv)
                                                    }
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                }
                                                Label {
                                                    visible: (modelData.id || "") !== ""
                                                    width: parent.width
                                                    elide: Text.ElideMiddle
                                                    text: modelData.id || ""
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                            }
                                        }

                                        Switch {
                                                id: settingsModelSwitch
                                                enabled: false
                                                checked: true
                                            anchors.verticalCenter: parent.verticalCenter
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                    x: settingsModelSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                    color: settingsModelSwitch.checked ? "#006BFF" : "#D9D9D9"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Rectangle {
                                                        x: settingsModelSwitch.checked ? parent.width - width - 3 : 3
                                                    y: parent.height / 2 - height / 2
                                                    width: 18; height: 18; radius: 9
                                                    color: "#FFFFFF"
                                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: settingsContentScroll2
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 1
                        Column {
                            width: settingsContentScroll2.width
                            padding: 16
                            spacing: 20
                            Label {
                                text: qsTr("记忆")
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Row {
                                width: parent.width - 32
                                Item {
                                    width: parent.width - 60
                                    height: memoryToggleCol1.height
                                    Column {
                                        id: memoryToggleCol1
                                        spacing: 4
                                        Label {
                                            text: qsTr("启用用户记忆")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                        }
                                        Label {
                                            text: qsTr("将稳定事实注入到系统提示词中的 <userMemories> 区块。\n建议开启后直接使用下方“记忆条目管理”，无需额外配置。")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                                Switch {
                                    id: memorySwitch
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: memorySwitch.toggle()
                                    }
                                    indicator: Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 22
                                        x: memorySwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 12
                                        color: memorySwitch.checked ? "#006BFF" : "#D9D9D9"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Rectangle {
                                            x: memorySwitch.checked ? parent.width - width - 3 : 3
                                            y: parent.height / 2 - height / 2
                                            width: 18; height: 18; radius: 9
                                            color: "#FFFFFF"
                                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }
                            Row {
                                width: parent.width - 32
                                Item {
                                    width: parent.width - 60
                                    height: memoryToggleCol2.height
                                    Column {
                                        id: memoryToggleCol2
                                        spacing: 4
                                        Label {
                                            text: qsTr("启用 LLM 二级判定")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                        }
                                        Label {
                                            text: qsTr("仅对规则边界样本调用模型复核，提升准确率（会增加少量 API 调用）")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            lineHeight: 1.4
                                        }
                                    }
                                }
                                Switch {
                                    id: llmSwitch
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: llmSwitch.toggle()
                                    }
                                    indicator: Rectangle {
                                        implicitWidth: 44
                                        implicitHeight: 22
                                        x: llmSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 12
                                        color: llmSwitch.checked ? "#006BFF" : "#D9D9D9"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Rectangle {
                                            x: llmSwitch.checked ? parent.width - width - 3 : 3
                                            y: parent.height / 2 - height / 2
                                            width: 18; height: 18; radius: 9
                                            color: "#FFFFFF"
                                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - 32
                                height: 1
                                color: "#14000000"
                            }

                            Item {
                                width: parent.width - 32
                                height: memoryMgmtTitle.height

                                Column {
                                    id: memoryMgmtTitle
                                    spacing: 4
                                    Label {
                                        text: qsTr("记忆条目管理")
                                        font.pixelSize: 16
                                        font.weight: Font.Bold
                                        color: "#D9000000"
                                    }
                                    Label {
                                        text: qsTr("你可以在这里查看、搜索、新增、编辑或删除记忆内容。")
                                        font.pixelSize: 14
                                        color: "#73000000"
                                    }
                                }

                                CustomButton {
                                    width: 80
                                    height: 32
                                    backgroundColor: "#0F006BFF"
                                    textColor: "#006BFF"
                                    borderWidth: 0
                                    text: "+ 新增"
                                    fontSize: 14
                                    anchors.right: parent.right
                                    onClicked: {
                                        memoryEditPopup.editId = ""
                                        memoryEditPopup.open()
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 4

                                property string memorySearchText: ""

                                function filteredMemoryEntries() {
                                    var list = wsClient.memoryEntries
                                    var q = (memorySearchText || "").trim().toLowerCase()
                                    if (!q) return list
                                    var result = []
                                    for (var i = 0; i < list.length; i++) {
                                        var e = list[i]
                                        var t = String(e.title || "").toLowerCase()
                                        var c = String(e.content || "").toLowerCase()
                                        if (t.indexOf(q) >= 0 || c.indexOf(q) >= 0)
                                            result.push(e)
                                    }
                                    return result
                                }

                                SingleLineTextInput {
                                    width: parent.width
                                    inputHeight: 36
                                    inputRadius: 8
                                    icon: "qrc:/images/search.png"
                                    iconSize: 16
                                    fontSize: 14
                                    placeholderText: qsTr("搜索记忆内容/来源")
                                    onTextChanged: parent.memorySearchText = text
                                }

                                Label {
                                    visible: wsClient.memoryEntries.length === 0
                                    width: parent.width
                                    topPadding: 20
                                    horizontalAlignment: Text.AlignHCenter
                                    text: qsTr("暂无记忆条目，点击「+ 新增」添加")
                                    font.pixelSize: 14
                                    color: "#73000000"
                                }

                                Repeater {
                                    model: parent.filteredMemoryEntries()

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 48
                                        color: memoryItemHover.hovered ? "#F7F9FA" : "transparent"
                                        radius: 8
                                        HoverHandler {
                                            id: memoryItemHover
                                        }

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.right: memoryItemActions.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 12
                                            clip: true
                                            Label {
                                                text: modelData.title || ""
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 200)
                                            }
                                            Label {
                                                text: modelData.content || ""
                                                font.pixelSize: 13
                                                color: "#73000000"
                                                elide: Text.ElideRight
                                                width: Math.min(implicitWidth, 180)
                                            }
                                            Label {
                                                text: modelData.date || ""
                                                font.pixelSize: 12
                                                color: "#40000000"
                                            }
                                        }

                                        Row {
                                            id: memoryItemActions
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            visible: memoryItemHover.hovered

                                            ImageButton {
                                                btnHeight: 16
                                                btnWidth: 16
                                                source: "qrc:/images/edit.png"
                                                onClicked: {
                                                    memoryEditPopup.editId = modelData.id || ""
                                                    memoryEditPopup.editTitle = modelData.title || ""
                                                    memoryEditPopup.editContent = modelData.content || ""
                                                    memoryEditPopup.open()
                                                }
                                            }
                                            ImageButton {
                                                btnHeight: 16
                                                btnWidth: 16
                                                source: "qrc:/images/delete.png"
                                                onClicked: {
                                                    wsClient.deleteMemoryEntry(modelData.id || "")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: settingsContentScroll3
                        width: parent.width - settingsLeftNav.width - 1
                        height: parent.height
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
                        visible: settingsDialog.settingsTabIndex === 2
                        Column {
                            id: sandboxPage
                            width: settingsContentScroll3.width
                            padding: 16
                            spacing: 12

                            property int sandboxMode: 0

                            Label {
                                text: qsTr("沙箱")
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }

                            Label {
                                text: qsTr("执行模式")
                                font.pixelSize: 14
                                color: "#73000000"
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 16

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 0 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 0
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 0
                                            }
                                        }
                                        Label {
                                            text: qsTr("自动（优先沙箱）")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("优先使用内置 VM 沙箱，不可用时回退本地")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 1 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 1
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 1
                                            }
                                        }
                                        Label {
                                            text: qsTr("本地运行")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("始终在本机运行")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 2
                                    Row {
                                        spacing: 4
                                        Rectangle {
                                            width: 20; height: 20
                                            radius: 10
                                            border.color: sandboxPage.sandboxMode === 2 ? "#006BFF" : "#D9D9D9"
                                            border.width: 2
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Rectangle {
                                                width: 10; height: 10; radius: 5
                                                color: "#006BFF"
                                                anchors.centerIn: parent
                                                visible: sandboxPage.sandboxMode === 2
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sandboxPage.sandboxMode = 2
                                            }
                                        }
                                        Label {
                                            text: qsTr("仅沙箱（内置VM）")
                                            font.pixelSize: 16
                                            color: "#D9000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                    }
                                    Label {
                                        text: qsTr("要求内置 VM 沙箱可用，否则报错")
                                        font.pixelSize: 16
                                        color: "#73000000"
                                        leftPadding: 24
                                    }
                                    Rectangle{
                                        width: parent.width
                                        height: 2
                                    }
                                    Row {
                                        leftPadding: 24
                                        spacing: 4
                                        Label {
                                            text: qsTr("未检测到沙箱VM，")
                                            font.pixelSize: 14
                                            color: "#73000000"
                                        }
                                        Label {
                                            text: qsTr("立即安装")
                                            font.pixelSize: 14
                                            font.underline: true
                                            color: "#006BFF"
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: settingsFooter
                    width: parent.width
                    height: 64
                    anchors.bottom: parent.bottom

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#14000000"
                        anchors.top: parent.top
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        layoutDirection: Qt.RightToLeft
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                wsClient.saveGeneralSettings(
                                    memorySwitch.checked,
                                    llmSwitch.checked,
                                    sandboxPage.sandboxMode
                                )
                                settingsDialog.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: settingsDialog.close()
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: memoryEditPopup
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0
        z: 200

        property string editId: ""
        property string editTitle: ""
        property string editContent: ""
        property bool isEdit: editId.length > 0

        onOpened: {
            memEditTitleInput.text = isEdit ? editTitle : ""
            memEditContentInput.text = isEdit ? editContent : ""
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InCubic }
        }
        Overlay.modal: Rectangle {
            color: "#40000000"
        }
        background: Rectangle {
            color: "transparent"
        }

        contentItem: Item {
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                onClicked: memoryEditPopup.close()
            }
            Rectangle {
                width: Math.min(480, parent.width - 32)
                height: memEditCol.implicitHeight
                anchors.centerIn: parent
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    id: memEditCol
                    width: parent.width
                    padding: 24
                    spacing: 16

                    Label {
                        text: memoryEditPopup.isEdit ? qsTr("编辑记忆") : qsTr("新增记忆")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#D9000000"
                    }

                    Column {
                        width: parent.width - 48
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("标题")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        SingleLineTextInput {
                            id: memEditTitleInput
                            width: parent.width
                            inputHeight: 40
                            inputRadius: 8
                            fontSize: 14
                            placeholderText: qsTr("如：我的名字、偏好语言")
                        }
                    }

                    Column {
                        width: parent.width - 48
                        spacing: 8
                        Row {
                            spacing: 2
                            Label {
                                text: qsTr("内容")
                                font.pixelSize: 14
                                color: "#D9000000"
                            }
                            Label {
                                text: "*"
                                font.pixelSize: 14
                                color: "#FF4D4F"
                            }
                        }
                        MultiLineTextInput {
                            id: memEditContentInput
                            width: parent.width
                            inputHeight: 100
                            placeholderText: qsTr("记忆的具体内容")
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        spacing: 12
                        layoutDirection: Qt.RightToLeft

                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#006BFF"
                            textColor: "#FFFFFF"
                            borderWidth: 0
                            text: qsTr("保存")
                            fontSize: 14
                            onClicked: {
                                var t = memEditTitleInput.text.trim()
                                var c = memEditContentInput.text.trim()
                                if (t.length === 0) return
                                if (memoryEditPopup.isEdit)
                                    wsClient.updateMemoryEntry(memoryEditPopup.editId, t, c)
                                else
                                    wsClient.addMemoryEntry(t, c)
                                memoryEditPopup.close()
                            }
                        }
                        CustomButton {
                            width: 96
                            height: 40
                            backgroundColor: "#F7F9FA"
                            textColor: "#A6000000"
                            borderColor: "#E6E7EB"
                            borderWidth: 1
                            text: qsTr("取消")
                            fontSize: 14
                            onClicked: memoryEditPopup.close()
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: rightTopPanel.height
        anchors.bottom: parent.bottom
        visible: window.configurationUpdateActive
        enabled: visible
        z: 19000

        Rectangle {
            anchors.fill: parent
            color: "#26000000"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: wheel.accepted = true
        }

        Rectangle {
            width: 220
            height: 64
            radius: 8
            color: "#FFFFFF"
            border.width: 1
            border.color: "#14000000"
            anchors.centerIn: parent

            Row {
                spacing: 12
                anchors.centerIn: parent

                BusyIndicator {
                    width: 28
                    height: 28
                    running: window.configurationUpdateActive
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: qsTr("正在修改配置")
                    color: "#A6000000"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    LoginPage {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: rightTopPanel.height
        anchors.bottom: parent.bottom
        initializing: authController.loggedIn && window.userSessionInitializing
        initializingText: wsClient.knowledgeBaseDataDirMessage
        visible: !window.userSessionReady
        enabled: visible
        z: 20000
    }

    Rectangle {
        anchors.fill: parent
        radius: window.windowCornerRadius
        color: "transparent"
        border.width: 1
        border.color: "#1A000000"
        visible: window.visibility !== Window.Maximized
                 && window.visibility !== Window.FullScreen
        z: 30000
    }

    // Frameless windows need explicit native resize handles.
    Item {
        anchors.fill: parent
        visible: window.visibility === Window.Windowed
        z: 30001

        readonly property int edgeSize: 6
        readonly property int cornerSize: 12

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.edgeSize
            cursorShape: Qt.SizeHorCursor
            onPressed: window.startSystemResize(Qt.LeftEdge)
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.edgeSize
            cursorShape: Qt.SizeHorCursor
            onPressed: window.startSystemResize(Qt.RightEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.edgeSize
            cursorShape: Qt.SizeVerCursor
            onPressed: window.startSystemResize(Qt.TopEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.edgeSize
            cursorShape: Qt.SizeVerCursor
            onPressed: window.startSystemResize(Qt.BottomEdge)
        }

        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.cornerSize
            height: parent.cornerSize
            cursorShape: Qt.SizeFDiagCursor
            z: 1
            onPressed: window.startSystemResize(Qt.LeftEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.right: parent.right
            anchors.top: parent.top
            width: parent.cornerSize
            height: parent.cornerSize
            cursorShape: Qt.SizeBDiagCursor
            z: 1
            onPressed: window.startSystemResize(Qt.RightEdge | Qt.TopEdge)
        }
        MouseArea {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.cornerSize
            height: parent.cornerSize
            cursorShape: Qt.SizeBDiagCursor
            z: 1
            onPressed: window.startSystemResize(Qt.LeftEdge | Qt.BottomEdge)
        }
        MouseArea {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: parent.cornerSize
            height: parent.cornerSize
            cursorShape: Qt.SizeFDiagCursor
            z: 1
            onPressed: window.startSystemResize(Qt.RightEdge | Qt.BottomEdge)
        }
    }
}
