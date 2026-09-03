import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#FFFFFF"

    property var agentList: []
    property string searchText: ""
    property bool installBusy: false
    property int installProgress: 0
    property string installMessage: ""
    property string installingId: ""
    property real hostWidth: width
    property real hostHeight: height
    property var selectedAgent: null
    property var selectedProfile: null
    property bool detailPopupActive: false
    readonly property bool selectedInstalling: installBusy && selectedAgent
                                                && installingId
                                                   === String(selectedAgent.id || "")

    onSelectedInstallingChanged: {
        if (selectedInstalling) {
            expertDetailPopup.close()
        }
        // Installation progress is rendered in the active card so the rest of
        // the capability hub remains available while the process runs.
        expertInstallPopup.close()
    }

    signal summonRequested(string agentId, string promptText)

    readonly property var expertProfiles: [
        {
            id: "paper-orchestrator", name: "论文写作专家", domain: "医学研究领域",
            image: "qrc:/images/expert/paper-orchestrator.png",
            categories: ["论文撰写", "文献综述", "申报辅助"],
            intro: "围绕研究问题完成文献检索、证据核实、内容合成，输出符合SCI期刊规范的结构化文稿，适配多类科研写作场景",
            ability: "聚焦医学科研写作全流程，围绕研究问题完成定向文献检索、学术声明核实、高质量文献筛选与系统阅读，最终合成符合学术规范的文稿提案，适配SCI论文、综述、基金标书等多类写作场景。",
            questions: ["帮我完成一篇肺癌方向SCI论文的结果与讨论章节", "生成一份肿瘤免疫方向的系统综述框架与参考文献", "辅助撰写国自然青年基金申报书的研究方案部分"],
            promptTemplate: "研究想法（自然语言）：\n  \"我想研究XX药物对YY疾病的疗效\"\n\n期望输出语言：中文/英文\n研究问题类型（可选）：RCT/Meta/队列/病例对照\n目标数据库：PubMed + Embase + WOS + Cochrane"
        },
        {
            id: "data-orchestrator", name: "数据分析专家", domain: "医学 / 通用领域",
            image: "qrc:/images/expert/data-orchestrator.png",
            categories: ["数据清洗", "可视化", "建模评估"],
            intro: "自动完成数据清洗、探索分析、可视化与建模全流程，覆盖医学统计场景，输出可直接引用的分析结论与图表集",
            ability: "支持CSV/Excel/JSON等多格式数据上传，自动化完成从数据清洗、探索性分析、批量可视化到建模评估的全链路分析，覆盖医学统计与通用商业分析场景，输出可直接复用的分析结论与标准化图表集。",
            questions: ["上传这份临床随访数据，帮我做生存分析并输出可视化图表", "分析这份医疗运营数据，找出核心影响因素并给出归因结论", "对患者分组数据做统计检验，生成符合论文规范的统计结果"],
            promptTemplate: "数据文件：[upload .csv / .xlsx]\n分析目标：\"找出XX与YY的关联\"\n变量角色（可选）：\n  - 自变量：col_A, col_B\n  - 因变量：col_C\n  - 分组变量：col_D\n统计方法偏好（可选）：参数/非参数"
        },
        {
            id: "omics-orchestrator", name: "精准医学专家", domain: "生信领域",
            image: "qrc:/images/expert/omics-orchestrator.png",
            categories: ["单细胞分析", "通路富集", "多组学整合"],
            intro: "覆盖单细胞、转录组、蛋白组到多组学整合全流程自动化分析，输出可发表级图表、生物学解读与研究假说",
            ability: "覆盖单细胞、转录组、蛋白组、代谢组全组学分析链路，从原始数据质控到多组学整合分析全流程自动化，输出可发表级分析图表、生物学解读与可验证研究假说，支撑基础医学与药物研发场景。",
            questions: ["处理这份scRNA-seq数据，完成细胞分群与注释分析", "做差异基因表达分析并输出GO/KEGG富集结果与火山图", "整合转录组与蛋白组数据，生成潜在靶点研究假说"],
            promptTemplate: "物种：mouse (mm10) / human (hg38)\n数据类型：scRNA-seq / Bulk RNA / 蛋白 / 代谢\n实验设计：\n  - 对照组：sample_1, 2, 3\n  - 处理组：sample_4, 5, 6\n  - 处理条件：药物XX 50mg/kg\n参考基因组：GRCm39 / GRCh38\n比对工具：STAR / HISAT2（可选）"
        },
        {
            id: "mi-orchestrator", name: "医学情报专家", domain: "竞争情报领域",
            image: "qrc:/images/expert/mi-orchestrator.png",
            categories: ["竞品监控", "威胁预警", "策略报告"],
            intro: "多源扫描医药情报并交叉验证，完成威胁评级后输出决策级策略简报，支撑医学事务与产品立项决策",
            ability: "支持自定义竞品目标池与监控维度，自动扫描NMPA/FDA获批、临床试验、SCI论文、指南修订等多源医药情报，交叉验证后完成威胁评级，输出决策级策略简报，支撑医学事务与产品立项决策。",
            questions: ["监控某靶点肺癌药物的全球注册与临床进展，输出周报", "对比3款同类医疗器械的技术路径与临床数据，做威胁评级", "汇总本月领域指南更新，生成医学部汇报用简报"],
            promptTemplate: "竞品名单：\n  · 波科：FARAPULSE / FARAWAVE\n  · 锦江电子：LEAD-PFA / Pulsed FA\n  · 强生：TRUPULSE / VARIPULSE\n\n关键词表：\n  PFA, 脉冲电场消融, 心脏消融,\n  pulsed field ablation\n\n重点临床试验：\n  NCT05501873, NCT07162597,\n  NCT05072964, NCT06431815, NCT06808217\n\n监控维度：\n  · NMPA/FDA 注册获批\n  · 最新 SCI 论文\n  · 指南更新\n  · 临床试验入排标准差异\n\n报告关注字段：\n  发布时间 | 来源 | 竞品型号 |\n  核心结论 | 有效性更新 | 安全性更新 |\n  威胁评级(高/中/低) | 应对建议"
        },
        {
            id: "research-orchestrator", name: "深度研究专家", domain: "通用高频",
            image: "qrc:/images/expert/research-orchestrator.png",
            categories: ["行业调研", "可行性分析", "知识沉淀"],
            intro: "完成问题拆解、多源检索、交叉验证到综合报告全流程深度研究，同步结构化知识沉淀，支撑体系化决策",
            ability: "面向复杂调研类问题，完成从问题结构化拆解、多渠道信息检索、多源交叉验证到综合报告输出的全流程深度研究，同步完成结构化知识沉淀，支撑体系化业务决策。",
            questions: ["调研国内医疗AI影像赛道的竞争格局与发展趋势", "分析某创新技术的商业化落地可行性与风险点", "整理医疗大模型政策监管要求，形成合规知识库"],
            promptTemplate: "研究主题：[自然语言描述]\n\n研究深度：\n  · 快速（3-5分钟，5个子问题）\n  · 标准（10-15分钟，10个子问题）\n  · 深度（30分钟+，20+子问题）\n\n检索范围：\n  [x] Web 搜索\n  [x] 学术文献\n  [x] 新闻资讯\n  [ ] 内部知识库\n\n输出语言：中文\n报告框架（可选）：\n  背景 → 现状 → 关键发现 →\n  争议点 → 趋势预测 → 结论\n\n特别关注（可选）：\n  \"重点关注XX公司的融资情况\"\n  \"注意区分XX和YY的区别\""
        },
        {
            id: "forensics-orchestrator", name: "事实链法证专家", domain: "通用高频",
            image: "qrc:/images/expert/forensics-orchestrator.png",
            categories: ["事实核验", "溯源追踪", "可信度评级"],
            intro: "拆解待核验声明，完成信息溯源、原始证据校验与可信度评级，输出完整可追溯的事实核验报告",
            ability: "针对待核验声明进行结构化拆解，完成信息源头追溯、原始证据校验与可信度分级，输出完整可追溯的事实核验报告，精准识别不实信息、证据漏洞与传播偏差。",
            questions: ["核验这篇医学科普文章中的核心结论是否有循证依据", "追踪这个行业数据的原始来源，验证数据真实性", "对这份竞品分析报告做事实核查，输出可信度评级报告"],
            promptTemplate: "待核验内容：\n  [粘贴一段AI输出/论文段落/新闻文本]\n\n核验范围：\n  · 全量核验（提取所有事实性声明）\n  · 重点核验（仅检查标记为 [?] 的声明）\n  · 单条核验（只验证一句话）\n\n核验深度：\n  · 快速（一级溯源，5分钟）\n  · 标准（二级溯源+原文比对，15分钟）\n  · 深度（完整引用链追溯+语境分析，30分钟+）\n\n检索源偏好：\n  [x] 学术文献\n  [x] Web 搜索\n  [x] 新闻/官方文件\n  [ ] 内部知识库\n\n输出要求：\n  · 可信度评级表\n  · 失真类型标注\n  · 保守版修正表述（用于论文写作）\n  · 引用链全链路展示"
        }
    ]

    readonly property var subagentCatalog: ({
        "question-refiner": { name: "临床问题精炼专员", skills: ["联网检索", "网页抓取", "知识库检索", "文件内容读取"], desc: "联网检索 + 知识库查询，识别问题类型并匹配 PICO/PECO/PICOTS 框架，输出三版本问题陈述", avatar: 1 },
        "search-strategist": { name: "检索策略专员", skills: ["PubMed检索", "联网检索", "知识库检索"], desc: "调用 PubMed 检索接口完成 MeSH 映射、布尔式构建与多数据库适配，生成四库检索式", avatar: 2 },
        "claim-verifier": { name: "论文观点核实专员", skills: ["PubMed检索", "PubMed全文获取", "Semantic Scholar检索", "引用链追溯", "事实核查缓存"], desc: "具备完整引用链追溯与事实核查缓存能力，识别引用漂移、夸大宣称、相关性冒充因果三类失真", avatar: 3 },
        "paper-screener": { name: "高价值论文筛选专员", skills: ["PubMed检索", "PubMed全文获取", "Semantic Scholar检索", "引用链追溯", "知识库检索"], desc: "执行五维评估矩阵打分，筛选高价值论文并生成精读清单", avatar: 4 },
        "knowledge-synth": { name: "文献知识合成专员", skills: ["知识库检索", "知识库写入", "PubMed全文获取", "文件内容读取"], desc: "完成结构化笔记、跨会话追踪与知识库写入，通过 /propose 输出研究提案文档", avatar: 5 },
        "data-cleaner-agent": { name: "数据清洗专员", skills: ["数据清洗", "数据画像", "数据探索", "代码执行"], desc: "执行类型推断、缺失值处理、异常值检测与标准化，输出可审计的操作日志", avatar: 6 },
        "eda-agent": { name: "探索性分析专员", skills: ["基线表生成", "相关性分析", "组间比较", "线性回归", "逻辑回归", "数据探索"], desc: "完成描述统计、分布检验、相关性矩阵与分组对比，覆盖 TableOne 与回归分析", avatar: 7 },
        "data-viz-agent": { name: "数据可视化专员", skills: ["ECharts渲染", "ECharts转换", "代码执行"], desc: "自动选图并生成 ECharts 交互式图表，输出图注与统计标注", avatar: 8 },
        "data-modeler-agent": { name: "数据建模专员", skills: ["机器学习流水线", "模型推荐", "模型导出", "模型解释"], desc: "执行回归/分类/聚类机器学习流水线、交叉验证、特征重要性分析与模型可解释性输出", avatar: 1 },
        "scrna-agent": { name: "单细胞分析专员", skills: ["单细胞质控", "单细胞预处理", "单细胞聚类", "单细胞注释", "ECharts渲染"], desc: "完成质控→降维→聚类→marker gene→细胞注释全流程并输出 UMAP 图与注释结果", avatar: 2 },
        "bulkrna-agent": { name: "转录组分析专员", skills: ["读段质控", "序列比对", "差异表达", "富集分析", "共表达网络", "生存分析"], desc: "覆盖 Bulk RNA 全流程，输出 DEG 报告与火山图", avatar: 3 },
        "proteomics-agent": { name: "蛋白组分析专员", skills: ["数据导入", "质谱质控", "蛋白定量", "差异丰度分析", "通路富集", "结构分析"], desc: "完成蛋白定量、差异蛋白、通路富集、PTM 翻译后修饰与结构分析全流程", avatar: 4 },
        "metabolomics-agent": { name: "代谢组分析专员", skills: ["XCMS预处理", "峰检测", "代谢物注释", "定量分析", "差异分析", "通路富集"], desc: "执行 XCMS 预处理、峰检测、差异代谢物与通路映射全流程", avatar: 5 },
        "multiomics-agent": { name: "多组学整合专员", skills: ["组学整合", "ECharts渲染", "ECharts转换", "数据探索"], desc: "执行跨组学关联、整合可视化与生物学假说生成", avatar: 6 },
        "target-configurator": { name: "目标池配置专员", skills: ["目标配置"], desc: "配置竞品名单、关键词表、临床试验 NCT 号与监控维度", avatar: 7 },
        "intel-crawler": { name: "情报捕获专员", skills: ["PubMed检索", "法规检索", "临床试验检索", "URL抓取", "联网检索", "归一化去重"], desc: "定时扫描 Top 15 数据源，语义匹配关键词并去重去噪", avatar: 8 },
        "threat-assessor": { name: "威胁评级专员", skills: ["威胁评分", "威胁评分汇总"], desc: "执行高/中/低威胁评级与多维度对比（有效性/安全性/技术指标）", avatar: 1 },
        "strategy-reporter": { name: "策略报告专员", skills: ["报告启动", "阶段验证", "竞品分析保存", "KOL分析保存", "ECharts渲染", "文件写入"], desc: "生成情报卡片、趋势分析与应对建议，支持竞品/KOL 分析持久化与可视化", avatar: 2 },
        "question-decomposer": { name: "研究问题拆解专员", skills: ["联网检索", "网页抓取", "知识库检索"], desc: "将模糊问题拆解为 3-7 个可检索子问题，标注检索策略与预期答案类型", avatar: 3 },
        "multi-searcher": { name: "多源检索专员", skills: ["联网检索", "PubMed检索", "PubMed全文获取", "Semantic Scholar检索", "引用链追溯", "知识库检索", "URL抓取"], desc: "并行调度 Web/学术/知识库多源检索，返回 Top-K 结果摘要", avatar: 4 },
        "cross-validator": { name: "交叉验证专员", skills: ["联网检索", "PubMed检索", "PubMed全文获取", "Semantic Scholar检索", "事实核查缓存", "知识库检索"], desc: "提取关键声明、检测矛盾点、标注置信度并触发补充检索", avatar: 5 },
        "synth-writer": { name: "综合报告专员", skills: ["网页抓取", "知识库检索", "文件内容读取"], desc: "按研究框架合成报告，每条声明附引用编号，矛盾点显式标注", avatar: 6 },
        "knowledge-distiller": { name: "知识沉淀专员", skills: ["知识库检索", "知识库写入"], desc: "提取结构化知识卡片写入持久化知识库，支持后续研究复用", avatar: 7 },
        "claim-decomposer": { name: "声明拆解专员", skills: ["联网检索", "网页抓取", "知识库检索"], desc: "从文本中提取可验证事实性声明，区分核心/次要声明并识别三类失真信号", avatar: 8 },
        "provenance-tracer": { name: "溯源追踪专员", skills: ["PubMed检索", "PubMed全文获取", "Semantic Scholar检索", "引用链追溯", "联网检索", "URL抓取"], desc: "执行一级→二级→原始来源的引用链追溯，标注每级可追溯深度", avatar: 1 },
        "evidence-examiner": { name: "原始证据检验专员", skills: ["PubMed全文获取", "引用链追溯", "Semantic Scholar检索", "网页抓取"], desc: "获取原始证据全文并逐句比对支持度，识别语境剥离与选择性引用", avatar: 2 },
        "confidence-rater": { name: "可信度评级专员", skills: ["事实核查缓存", "联网检索", "知识库检索"], desc: "综合输出四级可信度评定，并对失真声明生成保守版修正表述", avatar: 3 },
        "verification-reporter": { name: "核验报告专员", skills: ["知识库检索", "网页抓取", "文件内容读取"], desc: "合成核验报告，含声明评定表、证据摘要、引用链全链路展示与修正建议", avatar: 4 },
        "report-writer": { name: "报告撰写专员", skills: ["整合", "排版", "交付"], desc: "分析产出的\"最后一公里\"整合者。将前面所有专家的产出组装为结构化分析报告，按目标格式排版。确保从数据到结论的逻辑链条连贯、引用规范、表述精准。", avatar: 5 }
    })

    function profileForAgent(agent) {
        var id = String(agent && agent.id || "")
        for (var i = 0; i < expertProfiles.length; i++) {
            if (expertProfiles[i].id === id)
                return expertProfiles[i]
        }
        return null
    }

    function filteredAgents() {
        var kw = searchText.trim().toLowerCase()
        var result = []
        for (var i = 0; i < agentList.length; i++) {
            var agent = agentList[i]
            var profile = profileForAgent(agent)
            var subagents = agent.subagents || []
            if (!profile || subagents.length === 0)
                continue
            var haystack = (profile.name + " " + profile.domain + " " + profile.intro + " " + agent.id).toLowerCase()
            if (!kw || haystack.indexOf(kw) >= 0)
                result.push(agent)
        }
        return result
    }

    function expertSubagents(agent) {
        var configured = agent && agent.subagents || []
        var result = []
        for (var i = 0; i < configured.length; i++) {
            var id = String(configured[i] || "")
            var known = subagentCatalog[id]
            result.push({ id: id, name: known ? known.name : id, desc: known ? known.desc : "",
                            skills: known ? known.skills : [], avatar: known ? known.avatar : (i % 8) + 1 })
        }
        return result
    }

    function estimatedSkillWidth(text) {
        var value = String(text || "")
        var width = 14
        for (var i = 0; i < value.length; i++)
            width += value.charCodeAt(i) > 255 ? 11 : 7
        return width
    }

    function visibleSkillTabs(skills, availableWidth) {
        var source = skills || []
        var result = []
        var used = 0
        var spacing = 5
        var overflowWidth = 30
        for (var i = 0; i < source.length; i++) {
            var width = estimatedSkillWidth(source[i])
            var leadingSpacing = result.length > 0 ? spacing : 0
            var reserveOverflow = i < source.length - 1 ? spacing + overflowWidth : 0
            if (used + leadingSpacing + width + reserveOverflow > availableWidth) {
                result.push({ text: "...", overflow: true })
                break
            }
            result.push({ text: source[i], overflow: false })
            used += leadingSpacing + width
        }
        return result
    }

    function openExpert(agent) {
        selectedAgent = agent
        selectedProfile = profileForAgent(agent)
        root.detailPopupActive = true
        detailPopupOpenTimer.restart()
    }

    Timer {
        id: detailPopupOpenTimer
        interval: 0
        repeat: false
        onTriggered: expertDetailPopup.open()
    }

    ScrollView {
        id: expertListScroll
        anchors.fill: parent
        anchors.leftMargin: 60
        anchors.rightMargin: 60
        anchors.bottomMargin: 24
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        Grid {
            id: cardGrid
            width: expertListScroll.availableWidth
            columns: width >= 760 ? 2 : 1
            spacing: 16
            property real cardWidth: columns === 2 ? (width - spacing) / 2 : width

            Repeater {
                model: root.filteredAgents()
                Rectangle {
                    id: expertCard
                    property var agent: modelData
                    property var profile: root.profileForAgent(agent)
                    readonly property bool installingThisCard: root.installBusy
                                                               && root.installingId
                                                                  === String(agent.id || "")
                    readonly property bool activeHover: cardHover.hovered
                                                        && !root.detailPopupActive
                                                        && !expertInstallPopup.visible
                    width: cardGrid.cardWidth
                    height: 206
                    radius: 8
                    clip: true
                    color: activeHover ? "#F7FAFF" : "#FFFFFF"
                    border.width: 1
                    border.color: activeHover ? "#8AB9FF" : "#E4E7EC"

                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: 174; height: 174
                        source: expertCard.profile ? expertCard.profile.image : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(348, 348)
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 208
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        spacing: 6
                        Label { width: parent.width; text: expertCard.profile ? expertCard.profile.name : ""; font.pixelSize: 20; font.weight: Font.Bold; color: "#D9000000"; elide: Text.ElideRight }
                        Label { width: parent.width; text: expertCard.profile ? expertCard.profile.domain : ""; font.pixelSize: 14; color: "#73000000"; elide: Text.ElideRight }
                        Row {
                            spacing: 6
                            Repeater {
                                model: expertCard.profile ? expertCard.profile.categories : []
                                Rectangle {
                                    width: categoryText.implicitWidth + 14; height: 26
                                    color: "#F7F8FA"; border.width: 1; border.color: "#E6E7EB"
                                    Label { id: categoryText; anchors.centerIn: parent; text: modelData; font.pixelSize: 12; color: "#73000000" }
                                }
                            }
                        }
                        Label {
                            width: parent.width; height: 58
                            text: expertCard.profile ? expertCard.profile.intro : ""
                            font.pixelSize: 14; lineHeight: 1.35; color: "#99000000"
                            wrapMode: Text.Wrap
                        }
                    }

                    CustomButton {
                        anchors.right: parent.right; anchors.rightMargin: 16
                        anchors.top: parent.top; anchors.topMargin: 16
                        width: 72; height: 38
                        visible: expertCard.activeHover && !expertCard.installingThisCard
                        text: "召唤"; fontSize: 14; buttonRadius: 6
                        backgroundColor: "#006BFF"; textColor: "#FFFFFF"; borderWidth: 0
                        onClicked: root.openExpert(expertCard.agent)
                    }

                    Rectangle {
                        id: expertCardInstallOverlay
                        visible: expertCard.installingThisCard
                        anchors.fill: parent
                        color: "#DFFFFFFF"
                        z: 2

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Row {
                                width: parent.width
                                height: 20
                                Label {
                                    width: parent.width - expertCardInstallPercent.width - 12
                                    text: root.installMessage || qsTr("专家安装中...")
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: "#A6000000"
                                    elide: Text.ElideRight
                                }
                                Label {
                                    id: expertCardInstallPercent
                                    text: root.installProgress + "%"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: "#006BFF"
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 8
                                radius: 4
                                color: "#E6E7EB"
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100,
                                        root.installProgress)) / 100
                                    height: parent.height
                                    radius: 4
                                    color: "#006BFF"
                                    Behavior on width {
                                        NumberAnimation { duration: 180 }
                                    }
                                }
                            }
                        }
                    }
                    HoverHandler {
                        id: cardHover
                        enabled: !root.detailPopupActive
                                 && !expertInstallPopup.visible
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }

            Label {
                visible: root.filteredAgents().length === 0
                width: cardGrid.width; height: 120
                text: "未找到匹配的专家"
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14; color: "#73000000"
            }
        }
    }

    Popup {
        id: expertDetailPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(920, root.hostWidth - 72)
        height: Math.min(700, root.hostHeight - 56)
        x: Math.round((root.hostWidth - width) / 2)
        y: Math.round((root.hostHeight - height) / 2)
        padding: 0
        onOpened: root.detailPopupActive = true
        onClosed: root.detailPopupActive = false
        Overlay.modal: Rectangle { color: "#99000000" }
        background: Rectangle { radius: 8; color: "#FFFFFF" }

        contentItem: Item {
            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Column {
                    width: expertDetailPopup.width
                    padding: 40
                    spacing: 8

                    Row {
                        width: parent.width - 80; height: 62; spacing: 14
                        Image { width: 62; height: 62; source: root.selectedProfile ? root.selectedProfile.image : ""; fillMode: Image.PreserveAspectCrop }
                        Column {
                            width: parent.width - 210; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            Label { width: parent.width; text: root.selectedProfile ? root.selectedProfile.name : ""; font.pixelSize: 21; font.weight: Font.Bold; color: "#D9000000"; elide: Text.ElideRight }
                            Rectangle {
                                width: expertDomainText.implicitWidth + 14; height: 26; radius: 3; color: "#0F006BFF"
                                Label { id: expertDomainText; anchors.centerIn: parent; text: root.selectedProfile ? "专家团 · " + root.selectedProfile.domain : ""; font.pixelSize: 12; color: "#006BFF" }
                            }
                        }
                        CustomButton {
                            width: 120; height: 42; anchors.verticalCenter: parent.verticalCenter
                            text: "召唤"; fontSize: 16; buttonRadius: 6
                            backgroundColor: "#006BFF"; textColor: "#FFFFFF"; borderWidth: 0
                            enabled: !root.installBusy
                            onClicked: {
                                var prompt = root.selectedProfile ? root.selectedProfile.promptTemplate || "" : ""
                                root.summonRequested(root.selectedAgent.id, prompt)
                            }
                        }
                    }

                    Label { width: parent.width - 80; text: root.selectedProfile ? root.selectedProfile.ability : ""; font.pixelSize: 14; color: "#A6000000"; wrapMode: Text.Wrap }
                    Item { width: 1; height: 12; }
                    Label { width: parent.width - 80; text: "子专员团队 · 技能清单"; font.pixelSize: 16; font.weight: Font.Bold; color: "#D9000000" }

                    Grid {
                        width: parent.width - 80
                        columns: width >= 700 ? 2 : 1
                        spacing: 12
                        property real cellWidth: columns === 2 ? (width - spacing) / 2 : width
                        Repeater {
                            model: root.expertSubagents(root.selectedAgent)
                            Rectangle {
                                width: parent.cellWidth; height: 130; radius: 8
                                color: "#FFFFFF"; border.width: 1; border.color: "#E4E7EC"
                                Image { anchors.left: parent.left; anchors.leftMargin: 12; anchors.top: parent.top; anchors.topMargin: 12; width: 42; height: 42; source: "qrc:/images/expert/" + modelData.avatar + ".png"; fillMode: Image.PreserveAspectCrop }
                                Column {
                                    anchors.left: parent.left; anchors.leftMargin: 66; anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: parent.top; anchors.topMargin: 12; spacing: 4
                                    Label { width: parent.width; text: modelData.name; font.pixelSize: 14; font.weight: Font.Bold; color: "#D9000000"; elide: Text.ElideRight }
                                    Text { width: parent.width; height: 40; text: modelData.desc; font.pixelSize: 14; lineHeight: 1; color: "#73000000"; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; font.family: "Alibaba PuHuiTi 3.0"; maximumLineCount: 2}
                                    Rectangle{
                                        width: 1
                                        height: 12
                                        color: "transparent"
                                    }
                                    Row {
                                        width: parent.width; height: 24; spacing: 5; clip: true
                                        Repeater {
                                            model: root.visibleSkillTabs(modelData.skills, parent.width)
                                            Rectangle {
                                                width: modelData.overflow ? 30 : chipText.implicitWidth + 12
                                                height: 24
                                                color: "#F7F8FA"
                                                Label { id: chipText; anchors.centerIn: parent; text: modelData.text; font.pixelSize: 12; color: "#A6000000" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 12; }
                    Label { width: parent.width - 80; text: "试试这样问我"; font.pixelSize: 16; font.weight: Font.Bold; color: "#D9000000" }
                    Item { width: 1; height: 4; }
                    Column {
                        width: parent.width - 80; spacing: 12
                        Repeater {
                            model: root.selectedProfile ? root.selectedProfile.questions : []
                            Rectangle {
                                width: parent.width; height: 50; radius: 4
                                color: questionMouse.containsMouse ? "#F0F5FF" : "#F7F8FA"
                                border.width: 1; border.color: questionMouse.containsMouse ? "#8AB9FF" : "#E4E7EC"
                                Label { anchors.left: parent.left; anchors.leftMargin: 18; anchors.right: questionArrow.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "\"" + modelData + "\""; font.pixelSize: 14; color: "#D9000000"; elide: Text.ElideRight }
                                Label { id: questionArrow; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: "→"; font.pixelSize: 20; color: "#73000000" }
                                MouseArea { id: questionMouse; anchors.fill: parent; hoverEnabled: true; enabled: !root.installBusy; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { var prompt = modelData; root.summonRequested(root.selectedAgent.id, prompt) } }
                            }
                        }
                        Item { width: 1; height: 18 }
                    }
                }
            }

            Label {
                anchors.right: parent.right; anchors.rightMargin: 14; anchors.top: parent.top; anchors.topMargin: 10
                width: 28; height: 28; text: "×"; font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                color: closeMouse.containsMouse ? "#D9000000" : "#73000000"
                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: expertDetailPopup.close() }
            }
        }
    }

    Popup {
        id: expertInstallPopup
        parent: Overlay.overlay
        modal: false
        focus: true
        closePolicy: Popup.NoAutoClose
        width: Math.min(560, root.hostWidth - 48)
        height: 112
        x: Math.round((root.hostWidth - width) / 2)
        y: Math.round((root.hostHeight - height) / 2)
        padding: 0
        Overlay.modal: Rectangle { color: "transparent" }
        background: Rectangle {
            radius: 8
            color: "#FFFFFF"
            border.width: 1
            border.color: "#E4E7EC"
        }

        contentItem: Column {
            leftPadding: 24
            rightPadding: 24
            topPadding: 22
            bottomPadding: 20
            spacing: 14

            Row {
                width: parent.width - 48
                height: 20

                Label {
                    width: parent.width - installPercentLabel.width - 16
                    text: root.installMessage || qsTr("专家召唤中...")
                    font.pixelSize: 14
                    color: "#A6000000"
                    elide: Text.ElideRight
                }

                Label {
                    id: installPercentLabel
                    text: root.installProgress + "%"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: "#006BFF"
                }
            }

            Rectangle {
                width: parent.width - 48
                height: 8
                radius: 4
                color: "#E6E7EB"

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100,
                        root.installProgress)) / 100
                    height: parent.height
                    radius: 4
                    color: "#006BFF"
                    Behavior on width {
                        enabled: root.selectedInstalling
                                 && root.installProgress > 0
                        NumberAnimation { duration: 180 }
                    }
                }
            }
        }
    }
}
