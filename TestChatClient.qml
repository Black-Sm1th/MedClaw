/**
 * @file TestChatClient.qml
 * @brief WebSocket 连接与对话功能的独立测试页面
 *
 * ═══════════════════════════════════════════════════════════════
 *  测试覆盖范围
 * ═══════════════════════════════════════════════════════════════
 *   ① 连接测试：  testConnect()     → wsClient.connectToServer()
 *   ② 断开测试：  testDisconnect()  → wsClient.disconnectFromServer()
 *   ③ 发送消息：  testSendMessage() → wsClient.sendChatMessage()
 *   ④ 接收消息：  通过 chatModel 自动展示（含流式 streaming）
 *   ⑤ 重置对话：  testResetConversation() → wsClient.createNewSession()
 *   ⑥ 刷新会话：  testRefreshSessions()  → wsClient.refreshSessions()
 *   ⑦ 加载历史：  testLoadHistory()      → wsClient.loadHistory()
 *
 * ═══════════════════════════════════════════════════════════════
 *  maincontrol 调用说明
 * ═══════════════════════════════════════════════════════════════
 *   本测试通过 wsClient（GatewayClient 实例）作为主控制器（maincontrol），
 *   所有 WebSocket 操作均通过 wsClient 的 Q_INVOKABLE 方法完成：
 *
 *     wsClient.connectToServer(url)     — 发起连接 + 握手
 *     wsClient.disconnectFromServer()   — 断开连接
 *     wsClient.sendChatMessage(msg)     — 发送聊天消息
 *     wsClient.createNewSession()       — 重置/新建会话
 *     wsClient.refreshSessions()        — 刷新会话列表
 *     wsClient.loadHistory()            — 加载当前会话历史
 *     wsClient.setCurrentSessionKey(k)  — 切换会话
 *     wsClient.deleteSession(k)         — 删除会话
 *
 *   wsClient 和 chatModel 均由 main.cpp 通过 setContextProperty 注入。
 *
 * ═══════════════════════════════════════════════════════════════
 *  启动方式
 * ═══════════════════════════════════════════════════════════════
 *   在 main.cpp 中将 QUrl 改为 "qrc:/TestChatClient.qml"
 *   或使用命令行参数 --test 自动切换（需 main.cpp 支持）。
 */
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: testWindow
    width: 960
    height: 720
    visible: true
    title: qsTr("WebSocket Test Client — MedClaw")
    color: "#F5F6FA"

    // ═══════════════════════════════════════════════════════════════
    //  测试服务器配置
    // ═══════════════════════════════════════════════════════════════

    /// 默认 WebSocket 服务器地址
    property string testServerUrl: "ws://127.0.0.1:18789"

    // ═══════════════════════════════════════════════════════════════
    //  操作日志模型
    // ═══════════════════════════════════════════════════════════════

    ListModel {
        id: testLogModel
    }

    // ═══════════════════════════════════════════════════════════════
    //  测试函数定义（所有 WebSocket 操作的入口）
    //
    //  每个函数对应一个测试操作，内部调用 wsClient（maincontrol）
    //  的 Q_INVOKABLE 方法，并将操作记录写入日志面板。
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 添加一条带时间戳的操作日志
     * @param msg 日志内容
     */
    function testAddLog(msg) {
        var now = new Date()
        var ts = Qt.formatTime(now, "HH:mm:ss.zzz")
        testLogModel.append({ text: "[" + ts + "] " + msg })

        // 自动滚动到最新日志
        if (testLogView.count > 0)
            testLogView.positionViewAtEnd()
    }

    /**
     * @brief 测试连接 —— 发起 WebSocket 连接并执行握手
     *
     * maincontrol 调用：wsClient.connectToServer(url)
     * 连接流程：TCP → WebSocket 升级 → challenge → connect req → hello-ok
     */
    function testConnect() {
        var url = testUrlInput.text.trim()
        if (url.length === 0) url = testServerUrl
        testAddLog("▶ testConnect() → 正在连接: " + url)
        wsClient.connectToServer(url)
    }

    /**
     * @brief 测试断开连接 —— 主动关闭 WebSocket
     *
     * maincontrol 调用：wsClient.disconnectFromServer()
     * 触发正常的 WebSocket Close 帧握手
     */
    function testDisconnect() {
        testAddLog("▶ testDisconnect() → 断开连接")
        wsClient.disconnectFromServer()
    }

    /**
     * @brief 测试发送消息 —— 向当前会话发送聊天文本
     * @param text 消息内容
     *
     * maincontrol 调用：wsClient.sendChatMessage(text)
     * 发送后服务器通过 event 帧推送 agent 的流式回复
     */
    function testSendMessage(text) {
        if (text.trim().length === 0) {
            testAddLog("⚠ testSendMessage() → 消息为空，已忽略")
            return
        }
        testAddLog("▶ testSendMessage() → 发送: " + text.substring(0, 80))

        // 先在 chatModel 中添加用户消息，再通过 maincontrol 发送
        chatModel.addMessage("user", text)
        wsClient.sendChatMessage(text)
        testMessageInput.text = ""
    }

    /**
     * @brief 测试重置对话 —— 创建新会话（发送 /new 命令）
     *
     * maincontrol 调用：wsClient.createNewSession()
     * 服务器会重置当前 session，响应后自动刷新会话列表
     */
    function testResetConversation() {
        testAddLog("▶ testResetConversation() → 重置对话")
        wsClient.createNewSession()
    }

    /**
     * @brief 测试刷新会话列表
     *
     * maincontrol 调用：wsClient.refreshSessions()
     */
    function testRefreshSessions() {
        testAddLog("▶ testRefreshSessions() → 刷新会话列表")
        wsClient.refreshSessions()
    }

    /**
     * @brief 测试加载历史消息（通过 WebSocket）
     *
     * maincontrol 调用：wsClient.loadHistory()
     */
    function testLoadHistory() {
        testAddLog("▶ testLoadHistory() → 加载历史消息（WebSocket）")
        wsClient.loadHistory()
    }

    // ═══════════════════════════════════════════════════════════════
    //  本地会话扫描（已注释 — 改为 Agent 在线切换）
    // ═══════════════════════════════════════════════════════════════
    // function testScanLocalSessions() { ... }

    // ═══════════════════════════════════════════════════════════════
    //  Agent 切换测试函数
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 刷新 Agent 列表（通过 WebSocket agents.list RPC）
     */
    function testRefreshAgents() {
        testAddLog("\u25b6 testRefreshAgents() \u2192 \u83b7\u53d6 Agent \u5217\u8868")
        wsClient.refreshAgents()
    }

    /**
     * @brief 创建新 Agent（agents.create RPC）
     */
    function testCreateAgent(name, workspace) {
        testAddLog("\u25b6 testCreateAgent() \u2192 name=" + name
                   + " workspace=" + workspace)
        wsClient.createAgent(name, workspace)
    }

    /**
     * @brief 删除 Agent（agents.delete RPC）
     */
    function testDeleteAgent(agentId) {
        testAddLog("\u25b6 testDeleteAgent() \u2192 " + agentId)
        wsClient.deleteAgent(agentId, true)
    }

    /**
     * @brief 切换到指定 Agent
     * @param agentId agent ID（如 "main"、"coder"）
     *
     * maincontrol 调用：wsClient.switchAgent(agentId)
     * 依次发送：agent.identity.get + chat.history + sessions.list
     */
    function testSwitchAgent(agentId) {
        testAddLog("\u25b6 testSwitchAgent() \u2192 \u5207\u6362\u5230 agent: " + agentId)
        wsClient.switchAgent(agentId)
    }

    // ═══════════════════════════════════════════════════════════════
    //  技能管理测试函数
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 测试获取技能列表
     *
     * maincontrol 调用：wsClient.refreshSkills()
     * 发送 skills.status RPC，响应后更新 wsClient.skillList
     */
    function testRefreshSkills() {
        testAddLog("\u25b6 testRefreshSkills() \u2192 \u83b7\u53d6\u6280\u80fd\u5217\u8868")
        wsClient.refreshSkills()
    }

    /**
     * @brief 测试启用/禁用技能
     * @param skillKey 技能标识
     * @param enabled  true=启用, false=禁用
     *
     * maincontrol 调用：wsClient.setSkillEnabled(skillKey, enabled)
     */
    function testToggleSkill(skillKey, enabled) {
        var action = enabled ? "\u542f\u7528" : "\u7981\u7528"
        testAddLog("\u25b6 testToggleSkill() \u2192 " + action + " [" + skillKey + "]")
        wsClient.setSkillEnabled(skillKey, enabled)
    }

    // ═══════════════════════════════════════════════════════════════
    //  模型管理测试函数
    // ═══════════════════════════════════════════════════════════════

    /**
     * @brief 刷新可用模型列表（models.list RPC）
     */
    function testRefreshModels() {
        testAddLog("\u25b6 testRefreshModels() \u2192 \u83b7\u53d6\u53ef\u7528\u6a21\u578b\u5217\u8868")
        wsClient.refreshModels()
    }

    /**
     * @brief 切换当前会话的模型（sessions.patch RPC）
     * @param modelId 目标模型 ID（如 "deepseek-chat"）
     */
    function testChangeModel(modelId) {
        testAddLog("\u25b6 testChangeModel() \u2192 \u5207\u6362\u5230\u6a21\u578b: " + modelId)
        wsClient.patchSessionModel(modelId)
    }

    // ═══════════════════════════════════════════════════════════════
    //  本地文件加载测试函数（已注释 — 改为在线 chat.history）
    // ═══════════════════════════════════════════════════════════════
    // function testLoadLocalMessages(filePath, displayName) { ... }
    // function testLoadCaptureFile() { ... }

    /**
     * @brief 测试读取 sessions.json 完整内容
     *
     * maincontrol 调用：sessionReader.readSessionsJson()
     * 在日志面板输出关键字段
     */
    function testReadSessionsJson() {
        testAddLog("▶ testReadSessionsJson() → 读取 sessions.json")
        var data = sessionReader.readSessionsJson()
        var keys = Object.keys(data)
        for (var i = 0; i < keys.length; i++) {
            var sk = keys[i]
            var session = data[sk]
            testAddLog("  sessionKey: " + sk)
            testAddLog("  sessionId: " + (session.sessionId || "N/A"))
            testAddLog("  updatedAt: " + new Date(session.updatedAt || 0).toLocaleString())
            testAddLog("  chatType: " + (session.chatType || "N/A"))
            testAddLog("  model: " + (session.modelProvider || "") + "/" + (session.model || ""))
            testAddLog("  inputTokens: " + (session.inputTokens || 0)
                       + " outputTokens: " + (session.outputTokens || 0))
            testAddLog("  contextTokens: " + (session.contextTokens || 0))
            testAddLog("  compactionCount: " + (session.compactionCount || 0))
            testAddLog("  sessionFile: " + (session.sessionFile || "N/A"))
            testAddLog("  authProfile: " + (session.authProfileOverride || "N/A"))
            testAddLog("  lastChannel: " + (session.lastChannel || "N/A"))
        }
    }

    /**
     * @brief 测试读取指定会话的摘要信息
     * @param filePath .jsonl 文件路径
     */
    function testReadSessionSummary(filePath) {
        testAddLog("▶ testReadSessionSummary()")
        var s = sessionReader.readSessionSummary(filePath)
        testAddLog("  sessionId: " + (s.sessionId || "N/A"))
        testAddLog("  createdAt: " + (s.createdAt || "N/A"))
        testAddLog("  model: " + (s.modelProvider || "") + "/" + (s.modelId || ""))
        testAddLog("  thinkingLevel: " + (s.thinkingLevel || "N/A"))
        testAddLog("  cwd: " + (s.cwd || "N/A"))
        testAddLog("  消息数: " + (s.messageCount || 0)
                   + " (用户:" + (s.userMsgCount || 0)
                   + " 助手:" + (s.assistantMsgCount || 0)
                   + " 工具:" + (s.toolCallCount || 0) + ")")
        testAddLog("  预览: " + (s.firstUserMsg || "(无)"))
    }

    // ═══════════════════════════════════════════════════════════════
    //  信号监听 —— 监听 wsClient（maincontrol）的所有关键信号
    //  将状态变化记录到日志面板，验证通信是否正常
    // ═══════════════════════════════════════════════════════════════

    Connections {
        target: wsClient

        /// 连接状态变化
        function onConnectionStateChanged() {
            testAddLog("◆ 状态变更 → " + wsClient.statusText
                       + " (code=" + wsClient.connectionState + ")")
        }

        /// 流式输出开始
        function onStreamingStarted() {
            testAddLog("◆ streamingStarted → Agent 开始流式回复")
        }

        /// 流式输出结束
        function onStreamingFinished() {
            testAddLog("◆ streamingFinished → Agent 回复完成")
        }

        /// 发生错误
        function onErrorOccurred(message) {
            testAddLog("✖ errorOccurred → " + message)
        }

        /// 会话列表更新
        function onSessionsChanged() {
            var count = wsClient.sessions.length
            testAddLog("◆ sessionsChanged → 共 " + count + " 个会话")
        }

        /// 当前会话切换
        function onCurrentSessionChanged() {
            testAddLog("◆ currentSessionChanged → " + wsClient.currentSessionKey)
        }

        /// 新会话创建成功
        function onSessionCreated() {
            testAddLog("◆ sessionCreated → 新会话已创建")
        }

        /// 历史消息加载完成
        function onHistoryLoaded(messages) {
            testAddLog("◆ historyLoaded → 加载了 " + messages.length + " 条历史消息")
        }

        /// 工具调用
        function onToolCallReceived(toolName, toolArgs, toolCallId) {
            testAddLog("◆ toolCall → " + toolName + " (id:" + toolCallId.substring(0, 12) + "...)")
        }

        /// 工具结果
        function onToolResultReceived(toolName, content, toolCallId, isError) {
            var tag = isError ? "ERROR" : "OK"
            testAddLog("◆ toolResult → " + toolName + " [" + tag + "] "
                       + content.substring(0, 60))
        }

        /// 技能列表更新
        function onSkillListChanged() {
            var count = wsClient.skillList.length
            testAddLog("\u25c6 skillListChanged \u2192 \u5171 " + count + " \u4e2a\u6280\u80fd")
        }

        /// 技能状态变更
        function onSkillUpdated(skillKey, enabled) {
            var action = enabled ? "\u5df2\u542f\u7528" : "\u5df2\u7981\u7528"
            testAddLog("\u25c6 skillUpdated \u2192 [" + skillKey + "] " + action)
        }

        /// Agent 身份信息更新
        function onAgentIdentityChanged() {
            var id = wsClient.agentIdentity
            var name = id.name || ""
            var emoji = id.emoji || ""
            testAddLog("\u25c6 agentIdentity \u2192 " + emoji + " " + name
                       + " model=" + (id.model || ""))
        }

        /// Agent 列表更新
        function onAgentListChanged() {
            var list = wsClient.agentList
            testAddLog("\u25c6 agentListChanged \u2192 " + list.length
                       + " \u4e2a agent, \u9ed8\u8ba4: " + wsClient.defaultAgentId)
            for (var i = 0; i < list.length; i++) {
                var a = list[i]
                testAddLog("  [" + i + "] id=" + a.id + " name=" + a.name
                           + " key=" + a.sessionKey
                           + (a.isDefault ? " (\u9ed8\u8ba4)" : ""))
            }
        }

        /// Agent 创建结果
        function onAgentCreated(agentId, success, message) {
            var tag = success ? "\u2714" : "\u2716"
            testAddLog("\u25c6 agentCreated \u2192 " + tag + " " + message)
        }

        /// Agent 删除结果
        function onAgentDeleted(agentId, success, message) {
            var tag = success ? "\u2714" : "\u2716"
            testAddLog("\u25c6 agentDeleted \u2192 " + tag + " " + message)
        }

        /// 可用模型列表更新
        function onModelListChanged() {
            var list = wsClient.modelList
            testAddLog("\u25c6 modelListChanged \u2192 " + list.length + " \u4e2a\u53ef\u7528\u6a21\u578b")
            for (var i = 0; i < list.length; i++) {
                testAddLog("  [" + i + "] " + list[i].id
                           + " (" + list[i].name + ") - " + list[i].provider)
            }
        }

        /// 当前会话模型变更
        function onCurrentModelChanged() {
            var m = wsClient.currentModel
            testAddLog("\u25c6 currentModelChanged \u2192 "
                       + (m.modelProvider || "") + " / " + (m.model || ""))
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  UI 布局
    // ═══════════════════════════════════════════════════════════════

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ─────────────────────────────────────────────────────────
        //  顶部：标题 + 连接状态
        // ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 10
            color: "#FFFFFF"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Label {
                    text: "WebSocket Test Client"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#1A1A2E"
                }

                Item { Layout.fillWidth: true }

                // 连接状态指示灯
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: {
                        switch (wsClient.connectionState) {
                        case 0: return "#D32F2F"  // Disconnected = 红
                        case 1: return "#FF9800"  // Connecting = 橙
                        case 2: return "#FF9800"  // Handshaking = 橙
                        case 3: return "#4CAF50"  // Connected = 绿
                        default: return "#9E9E9E"
                        }
                    }
                }

                Label {
                    text: wsClient.statusText
                    font.pixelSize: 14
                    color: "#555555"
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        //  服务器地址输入 + 控制按钮
        // ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            radius: 10
            color: "#FFFFFF"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 地址栏
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        text: "服务器:"
                        font.pixelSize: 13
                        color: "#666666"
                    }

                    TextField {
                        id: testUrlInput
                        Layout.fillWidth: true
                        text: testServerUrl
                        placeholderText: "ws://host:port"
                        font.pixelSize: 13
                        selectByMouse: true
                        background: Rectangle {
                            radius: 6
                            border.color: testUrlInput.activeFocus ? "#006BFF" : "#D0D0D0"
                            border.width: 1
                            color: "#FAFAFA"
                        }
                    }

                    Label {
                        text: "会话: " + wsClient.currentSessionKey
                        font.pixelSize: 12
                        color: "#888888"
                    }
                }

                // 操作按钮行
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    /// 连接按钮 → testConnect()
                    Button {
                        text: "连接服务器"
                        enabled: wsClient.connectionState === 0
                        onClicked: testConnect()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#1565C0" : "#1976D2")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 100
                    }

                    /// 断开按钮 → testDisconnect()
                    Button {
                        text: "断开连接"
                        enabled: wsClient.connectionState !== 0
                        onClicked: testDisconnect()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#C62828" : "#D32F2F")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 100
                    }

                    /// 重置对话按钮 → testResetConversation()
                    Button {
                        text: "重置对话"
                        enabled: wsClient.connectionState === 3
                        onClicked: testResetConversation()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#E65100" : "#EF6C00")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 100
                    }

                    /// 刷新会话列表 → testRefreshSessions()
                    Button {
                        text: "刷新会话"
                        enabled: wsClient.connectionState === 3
                        onClicked: testRefreshSessions()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#2E7D32" : "#388E3C")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 100
                    }

                    /// 加载历史（WebSocket） → testLoadHistory()
                    Button {
                        text: "WS历史"
                        enabled: wsClient.connectionState === 3
                        onClicked: testLoadHistory()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#4527A0" : "#5E35B1")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 80
                    }

                    /// 刷新 Agent 列表 → testRefreshAgents()
                    Button {
                        text: "\u5237\u65b0Agent"
                        enabled: wsClient.connectionState === 3
                        onClicked: testRefreshAgents()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#00695C" : "#00897B")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 90
                    }

                    /// 刷新技能列表 → testRefreshSkills()
                    Button {
                        text: "\u6280\u80fd\u5217\u8868"
                        enabled: wsClient.connectionState === 3
                        onClicked: testRefreshSkills()
                        background: Rectangle {
                            radius: 6
                            color: parent.enabled
                                   ? (parent.down ? "#BF360C" : "#E65100")
                                   : "#BDBDBD"
                        }
                        contentItem: Label {
                            text: parent.text
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        implicitHeight: 34
                        implicitWidth: 80
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        //  中部：聊天消息列表 + 会话列表（左右分栏）
        // ─────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            // ── 会话列表（左侧窄栏） ──
            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                radius: 10
                color: "#FFFFFF"

                ColumnLayout {
                    id: testSessionPanel
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    // ── 标签页切换：会话 / Agent / 技能 ──
                    property int testTabIndex: 0  // 0=会话, 1=Agent, 2=技能

                    // ── Agent 身份显示栏 ──
                    Rectangle {
                        Layout.fillWidth: true
                        height: wsClient.agentIdentity.name ? 32 : 0
                        visible: wsClient.agentIdentity.name ? true : false
                        radius: 6
                        color: "#E8EAF6"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Label {
                                text: wsClient.agentIdentity.emoji || "\u{1F916}"
                                font.pixelSize: 16
                            }
                            Label {
                                text: wsClient.agentIdentity.name || ""
                                font.pixelSize: 12
                                font.bold: true
                                color: "#283593"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // 会话标签
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: testSessionPanel.testTabIndex === 0 ? "#1976D2" : "#F0F0F0"
                            Label {
                                anchors.centerIn: parent
                                text: "\u4f1a\u8bdd"
                                font.pixelSize: 12
                                font.bold: true
                                color: testSessionPanel.testTabIndex === 0 ? "#FFFFFF" : "#666666"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: testSessionPanel.testTabIndex = 0
                            }
                        }

                        // Agent 标签
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: testSessionPanel.testTabIndex === 1 ? "#388E3C" : "#F0F0F0"
                            Label {
                                anchors.centerIn: parent
                                text: "Agent"
                                font.pixelSize: 12
                                font.bold: true
                                color: testSessionPanel.testTabIndex === 1 ? "#FFFFFF" : "#666666"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    testSessionPanel.testTabIndex = 1
                                    if (wsClient.agentList.length === 0
                                            && wsClient.connectionState === 3)
                                        testRefreshAgents()
                                }
                            }
                        }

                        // 技能标签
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: testSessionPanel.testTabIndex === 2 ? "#E65100" : "#F0F0F0"
                            Label {
                                anchors.centerIn: parent
                                text: "\u6280\u80fd"
                                font.pixelSize: 12
                                font.bold: true
                                color: testSessionPanel.testTabIndex === 2 ? "#FFFFFF" : "#666666"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    testSessionPanel.testTabIndex = 2
                                    if (wsClient.connectionState === 3)
                                        testRefreshSkills()
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#E0E0E0"
                    }

                    // ── 在线会话列表（通过 WebSocket 获取） ──
                    ListView {
                        id: testSessionList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: testSessionPanel.testTabIndex === 0
                        model: wsClient.sessions
                        spacing: 2

                        delegate: Rectangle {
                            width: testSessionList.width
                            height: 36
                            radius: 6
                            color: {
                                var key = modelData.sessionKey || ""
                                if (key === wsClient.currentSessionKey)
                                    return "#E3F2FD"
                                return testOnlineDelegateArea.containsMouse
                                       ? "#F5F5F5" : "transparent"
                            }

                            Label {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                text: modelData.displayName || "未命名"
                                font.pixelSize: 12
                                color: "#333333"
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: testOnlineDelegateArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var key = modelData.sessionKey || ""
                                    if (key !== wsClient.currentSessionKey) {
                                        testAddLog("\u25b6 \u5207\u6362\u5728\u7ebf\u4f1a\u8bdd \u2192 " + key)
                                        wsClient.currentSessionKey = key
                                        wsClient.getAgentIdentity(key)
                                        wsClient.loadChatHistory(key, 200)
                                        wsClient.patchSessionModel("")
                                    }
                                }
                            }
                        }
                    }

                    // ── Agent 切换面板 ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: testSessionPanel.testTabIndex === 1
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Button {
                                text: "\u5237\u65b0"
                                implicitHeight: 26
                                implicitWidth: 50
                                font.pixelSize: 11
                                enabled: wsClient.connectionState === 3
                                onClicked: testRefreshAgents()
                                background: Rectangle {
                                    radius: 4
                                    color: parent.enabled
                                           ? (parent.down ? "#2E7D32" : "#43A047")
                                           : "#BDBDBD"
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                text: wsClient.agentList.length + " \u4e2a Agent"
                                font.pixelSize: 10
                                color: "#999999"
                            }
                        }

                        Label {
                            text: "\u5f53\u524d: " + wsClient.currentSessionKey
                            font.pixelSize: 9
                            color: "#666666"
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        // ── 新建 Agent ──
                        Rectangle {
                            Layout.fillWidth: true
                            height: testCreateAgentCol.implicitHeight + 12
                            radius: 6
                            color: "#FFF3E0"
                            border.color: "#FFB74D"
                            border.width: 1

                            ColumnLayout {
                                id: testCreateAgentCol
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3

                                Label {
                                    text: "\u65b0\u5efa Agent"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#E65100"
                                }

                                TextField {
                                    id: testNewAgentIdInput
                                    Layout.fillWidth: true
                                    placeholderText: "Agent 名称 (e.g. writer)"
                                    font.pixelSize: 10
                                    implicitHeight: 24
                                }

                                TextField {
                                    id: testNewAgentWorkspaceInput
                                    Layout.fillWidth: true
                                    placeholderText: "工作空间路径 (留空则自动生成)"
                                    font.pixelSize: 10
                                    implicitHeight: 24
                                }

                                Button {
                                    text: "\u521b\u5efa"
                                    implicitHeight: 24
                                    Layout.fillWidth: true
                                    enabled: wsClient.connectionState === 3
                                             && testNewAgentIdInput.text.trim().length > 0
                                    onClicked: {
                                        testCreateAgent(
                                            testNewAgentIdInput.text.trim(),
                                            testNewAgentWorkspaceInput.text.trim())
                                        testNewAgentIdInput.text = ""
                                        testNewAgentWorkspaceInput.text = ""
                                    }
                                    background: Rectangle {
                                        radius: 4
                                        color: parent.enabled
                                               ? (parent.down ? "#BF360C" : "#E65100")
                                               : "#BDBDBD"
                                    }
                                    contentItem: Label {
                                        text: parent.text
                                        color: "#FFFFFF"
                                        font.pixelSize: 10
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#E0E0E0"
                        }

                        ListView {
                            id: testAgentListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: wsClient.agentList
                            spacing: 2

                            delegate: Rectangle {
                                width: testAgentListView.width
                                height: testAgentDelegateCol.implicitHeight + 12
                                radius: 6
                                color: {
                                    var key = modelData.sessionKey || ""
                                    if (key === wsClient.currentSessionKey)
                                        return "#E8F5E9"
                                    return testAgentDelegateArea.containsMouse
                                           ? "#F5F5F5" : "transparent"
                                }

                                ColumnLayout {
                                    id: testAgentDelegateCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.topMargin: 6
                                    spacing: 2

                                    RowLayout {
                                        spacing: 6

                                        Label {
                                            text: "\u{1F916}"
                                            font.pixelSize: 16
                                        }

                                        Label {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: {
                                                var key = modelData.sessionKey || ""
                                                return key === wsClient.currentSessionKey
                                                       ? "#1B5E20" : "#333333"
                                            }
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            text: modelData.isDefault ? "\u9ed8\u8ba4" : ""
                                            font.pixelSize: 9
                                            color: "#FF8F00"
                                            visible: modelData.isDefault === true
                                        }

                                        // 删除按钮（main 不可删）
                                        Label {
                                            text: "\u2716"
                                            font.pixelSize: 12
                                            color: testDelArea.containsMouse ? "#D32F2F" : "#BDBDBD"
                                            visible: modelData.id !== "main"
                                            MouseArea {
                                                id: testDelArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: testDeleteAgent(modelData.id)
                                            }
                                        }
                                    }

                                    Label {
                                        text: "sessionKey: " + (modelData.sessionKey || "")
                                        font.pixelSize: 9
                                        color: "#888888"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: modelData.workspace || ""
                                        font.pixelSize: 8
                                        color: "#AAAAAA"
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                        visible: (modelData.workspace || "").length > 0
                                    }
                                }

                                MouseArea {
                                    id: testAgentDelegateArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (wsClient.connectionState !== 3) {
                                            testAddLog("\u26a0 \u8bf7\u5148\u8fde\u63a5\u670d\u52a1\u5668")
                                            return
                                        }
                                        testSwitchAgent(modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // ── 技能管理面板 ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: testSessionPanel.testTabIndex === 2
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Button {
                                text: "\u5237\u65b0\u6280\u80fd"
                                implicitHeight: 26
                                implicitWidth: 70
                                font.pixelSize: 11
                                enabled: wsClient.connectionState === 3
                                onClicked: testRefreshSkills()
                                background: Rectangle {
                                    radius: 4
                                    color: parent.enabled
                                           ? (parent.down ? "#BF360C" : "#E65100")
                                           : "#BDBDBD"
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Label {
                                text: wsClient.skillList.length + " \u4e2a"
                                font.pixelSize: 10
                                color: "#999999"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#E0E0E0"
                        }

                        // 技能列表
                        ListView {
                            id: testSkillListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: wsClient.skillList
                            spacing: 2

                            delegate: Rectangle {
                                width: testSkillListView.width
                                height: testSkillDelegateCol.implicitHeight + 12
                                radius: 6
                                color: testSkillHoverArea.containsMouse
                                       ? "#FFF3E0" : "transparent"

                                ColumnLayout {
                                    id: testSkillDelegateCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    anchors.topMargin: 6
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        // 启用/禁用开关
                                        Rectangle {
                                            width: 36
                                            height: 18
                                            radius: 9
                                            color: modelData.enabled ? "#4CAF50" : "#BDBDBD"

                                            Rectangle {
                                                width: 14
                                                height: 14
                                                radius: 7
                                                y: 2
                                                x: modelData.enabled ? 20 : 2
                                                color: "#FFFFFF"

                                                Behavior on x {
                                                    NumberAnimation { duration: 150 }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    testToggleSkill(
                                                        modelData.skillKey,
                                                        !modelData.enabled)
                                                }
                                            }
                                        }

                                        // 技能名称
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.name || modelData.skillKey
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: modelData.enabled ? "#333333" : "#999999"
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // 技能描述
                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.description || ""
                                        font.pixelSize: 10
                                        color: "#777777"
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: (modelData.description || "").length > 0
                                    }

                                    // 来源 + 主页链接
                                    RowLayout {
                                        spacing: 8
                                        Label {
                                            text: modelData.source || ""
                                            font.pixelSize: 9
                                            color: "#AAAAAA"
                                        }
                                        Label {
                                            text: modelData.always ? "[\u59cb\u7ec8\u542f\u7528]" : ""
                                            font.pixelSize: 9
                                            color: "#FF8F00"
                                            visible: modelData.always === true
                                        }
                                        Label {
                                            text: !modelData.eligible ? "[\u4e0d\u53ef\u7528]" : ""
                                            font.pixelSize: 9
                                            color: "#EF5350"
                                            visible: modelData.eligible === false
                                        }
                                    }
                                }

                                MouseArea {
                                    id: testSkillHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }

            // ── 聊天消息区域（右侧主栏） ──
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                color: "#FFFFFF"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        spacing: 8

                        Label {
                            text: {
                                var title = (wsClient.agentIdentity.emoji || "") + " "
                                title += wsClient.agentIdentity.name
                                         || wsClient.currentSessionKey
                                title += "  (" + chatModel.count + " \u6761)"
                                return title
                            }
                            font.pixelSize: 13
                            font.bold: true
                            color: "#333333"
                        }

                        Item { Layout.fillWidth: true }

                        // ── 模型选择器按钮 ──
                        Rectangle {
                            id: testModelBtn
                            height: 24
                            width: testModelBtnRow.implicitWidth + 20
                            radius: 12
                            color: testModelBtnArea.containsMouse ? "#E3F2FD" : "#F5F5F5"
                            border.color: "#BBDEFB"
                            border.width: 1

                            RowLayout {
                                id: testModelBtnRow
                                anchors.centerIn: parent
                                spacing: 4

                                Label {
                                    text: "\u2699"
                                    font.pixelSize: 11
                                }
                                Label {
                                    text: {
                                        var m = wsClient.currentModel.model || ""
                                        return m.length > 0 ? m : "\u9009\u62e9\u6a21\u578b"
                                    }
                                    font.pixelSize: 10
                                    color: "#1565C0"
                                }
                                Label {
                                    text: "\u25BC"
                                    font.pixelSize: 7
                                    color: "#90A4AE"
                                }
                            }

                            MouseArea {
                                id: testModelBtnArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (wsClient.modelList.length === 0
                                            && wsClient.connectionState === 3)
                                        wsClient.refreshModels()
                                    testModelPopup.open()
                                }
                            }

                            // ── 模型选择弹出框 ──
                            Popup {
                                id: testModelPopup
                                y: parent.height + 4
                                x: parent.width - width
                                width: 320
                                height: Math.min(testModelPopupCol.implicitHeight + 20, 400)
                                padding: 10

                                background: Rectangle {
                                    radius: 8
                                    color: "#FFFFFF"
                                    border.color: "#E0E0E0"
                                    border.width: 1
                                }

                                Column {
                                    id: testModelPopupCol
                                    width: parent.width
                                    spacing: 6

                                    // 弹窗标题
                                    RowLayout {
                                        width: parent.width
                                        Label {
                                            text: "\u53ef\u7528\u6a21\u578b"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: "#333333"
                                        }
                                        Item { Layout.fillWidth: true }
                                        Label {
                                            text: "\u5237\u65b0"
                                            font.pixelSize: 10
                                            color: "#1976D2"
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: wsClient.refreshModels()
                                            }
                                        }
                                    }

                                    // 当前模型信息
                                    Rectangle {
                                        width: parent.width
                                        height: 28
                                        radius: 6
                                        color: "#E8EAF6"
                                        visible: (wsClient.currentModel.model || "").length > 0
                                        Label {
                                            anchors.centerIn: parent
                                            text: "\u5f53\u524d: "
                                                  + (wsClient.currentModel.modelProvider || "")
                                                  + " / "
                                                  + (wsClient.currentModel.model || "")
                                            font.pixelSize: 10
                                            color: "#283593"
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: "#E0E0E0"
                                    }

                                    // 模型列表
                                    Repeater {
                                        model: wsClient.modelList

                                        Rectangle {
                                            width: testModelPopupCol.width
                                            height: testMItemCol.implicitHeight + 12
                                            radius: 6
                                            color: {
                                                var isActive = modelData.id
                                                    === (wsClient.currentModel.model || "")
                                                if (isActive) return "#E3F2FD"
                                                return testMItemArea.containsMouse
                                                       ? "#F5F5F5" : "transparent"
                                            }

                                            Column {
                                                id: testMItemCol
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.margins: 6
                                                spacing: 2

                                                Row {
                                                    spacing: 6
                                                    Label {
                                                        text: modelData.name || modelData.id
                                                        font.pixelSize: 12
                                                        font.bold: true
                                                        color: modelData.id
                                                            === (wsClient.currentModel.model || "")
                                                            ? "#1565C0" : "#333333"
                                                    }
                                                    Label {
                                                        text: modelData.id
                                                            === (wsClient.currentModel.model || "")
                                                            ? "\u2714" : ""
                                                        font.pixelSize: 14
                                                        color: "#1565C0"
                                                    }
                                                }

                                                Row {
                                                    spacing: 8
                                                    Label {
                                                        text: modelData.provider || ""
                                                        font.pixelSize: 9
                                                        color: "#888888"
                                                    }
                                                    Label {
                                                        text: modelData.contextWindow > 0
                                                            ? (Math.floor(
                                                                modelData.contextWindow / 1024)
                                                                + "K context")
                                                            : ""
                                                        font.pixelSize: 9
                                                        color: "#888888"
                                                        visible: modelData.contextWindow > 0
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                id: testMItemArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    testChangeModel(modelData.id)
                                                    testModelPopup.close()
                                                }
                                            }
                                        }
                                    }

                                    // 空状态
                                    Label {
                                        visible: wsClient.modelList.length === 0
                                        text: wsClient.connectionState === 3
                                              ? "\u52a0\u8f7d\u4e2d..."
                                              : "\u8bf7\u5148\u8fde\u63a5\u670d\u52a1\u5668"
                                        font.pixelSize: 11
                                        color: "#999999"
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#E0E0E0"
                    }

                    // ── 消息列表 ──
                    ListView {
                        id: testChatListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: chatModel
                        spacing: 6

                        onCountChanged: {
                            if (count > 0)
                                positionViewAtEnd()
                        }

                        delegate: Item {
                            width: testChatListView.width
                            height: {
                                if (msgType === "toolCall") return testToolCallBox.height
                                if (msgType === "toolResult") return testToolResBox.height
                                return testTextBox.height
                            }

                            // ═══ 普通文本气泡 ═══
                            Rectangle {
                                id: testTextBox
                                visible: msgType !== "toolCall" && msgType !== "toolResult"
                                width: parent.width
                                height: visible ? (testBubbleInner.height + 4) : 0

                                readonly property bool testIsUser: msgRole === "user"
                                readonly property bool testIsSystem: msgRole === "system"
                                color: "transparent"

                                Rectangle {
                                    id: testBubbleInner
                                    anchors {
                                        left: testTextBox.testIsUser ? undefined : parent.left
                                        right: testTextBox.testIsUser ? parent.right : undefined
                                        top: parent.top
                                        leftMargin: testTextBox.testIsSystem ? 0 : 8
                                        rightMargin: 8
                                    }
                                    width: Math.min(testBubbleCol.implicitWidth + 28,
                                                    testTextBox.width * 0.75)
                                    height: testBubbleCol.implicitHeight + 20
                                    radius: 10
                                    color: testTextBox.testIsSystem ? "#FFF3E0"
                                         : testTextBox.testIsUser   ? "#1976D2"
                                                                    : "#F0F0F0"

                                    ColumnLayout {
                                        id: testBubbleCol
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 2

                                        Label {
                                            text: testTextBox.testIsUser ? "You"
                                                : testTextBox.testIsSystem ? "System"
                                                : "Assistant"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: testTextBox.testIsUser ? "#B3FFFFFF" : "#999999"
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: content
                                            wrapMode: Text.Wrap
                                            font.pixelSize: 13
                                            color: testTextBox.testIsUser ? "#FFFFFF" : "#1A1A1A"
                                            textFormat: Text.PlainText
                                        }
                                    }
                                }
                            }

                            // ═══ 工具调用卡片（黄色） ═══
                            Rectangle {
                                id: testToolCallBox
                                visible: msgType === "toolCall"
                                width: parent.width
                                height: visible ? (testToolCallInner.height + 8) : 0
                                color: "transparent"

                                Rectangle {
                                    id: testToolCallInner
                                    anchors {
                                        left: parent.left; right: parent.right
                                        top: parent.top
                                        leftMargin: 24; rightMargin: 24
                                    }
                                    height: testToolCallCol.implicitHeight + 16
                                    radius: 8
                                    color: "#FFF8E1"
                                    border.color: "#FFD54F"
                                    border.width: 1

                                    ColumnLayout {
                                        id: testToolCallCol
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        RowLayout {
                                            spacing: 6
                                            Label { text: "\u2699"; font.pixelSize: 14 }
                                            Label {
                                                text: "Tool: " + toolName
                                                font.pixelSize: 12; font.bold: true
                                                color: "#F57F17"
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                id: testToolToggle
                                                property bool expanded: false
                                                text: expanded ? "\u6536\u8D77 \u25B2" : "\u5C55\u5F00 \u25BC"
                                                font.pixelSize: 10; color: "#9E9E9E"
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: testToolToggle.expanded = !testToolToggle.expanded
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: testToolToggle.expanded
                                            Layout.fillWidth: true
                                            implicitHeight: testArgsText.implicitHeight + 12
                                            radius: 4; color: "#FFFDE7"

                                            Label {
                                                id: testArgsText
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                text: toolArgs || "{}"
                                                wrapMode: Text.Wrap
                                                font.pixelSize: 11
                                                font.family: "Consolas"
                                                color: "#5D4037"
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "CallId: " + (toolCallId || "-")
                                            font.pixelSize: 10
                                            color: "#8D6E63"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            // ═══ 工具结果卡片（绿色/红色） ═══
                            Rectangle {
                                id: testToolResBox
                                visible: msgType === "toolResult"
                                width: parent.width
                                height: visible ? (testToolResInner.height + 8) : 0
                                color: "transparent"

                                Rectangle {
                                    id: testToolResInner
                                    anchors {
                                        left: parent.left; right: parent.right
                                        top: parent.top
                                        leftMargin: 24; rightMargin: 24
                                    }
                                    height: testToolResCol.implicitHeight + 16
                                    radius: 8
                                    color: isError ? "#FFEBEE" : "#E8F5E9"
                                    border.color: isError ? "#EF9A9A" : "#A5D6A7"
                                    border.width: 1

                                    ColumnLayout {
                                        id: testToolResCol
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        RowLayout {
                                            spacing: 6
                                            Label {
                                                text: isError ? "\u274C" : "\u2705"
                                                font.pixelSize: 14
                                            }
                                            Label {
                                                text: (isError ? "Error: " : "Result: ") + toolName
                                                font.pixelSize: 12; font.bold: true
                                                color: isError ? "#C62828" : "#2E7D32"
                                            }
                                            Item { Layout.fillWidth: true }
                                            Label {
                                                id: testResToggle
                                                property bool expanded: false
                                                text: expanded ? "\u6536\u8D77 \u25B2" : "\u5C55\u5F00 \u25BC"
                                                font.pixelSize: 10; color: "#9E9E9E"
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: testResToggle.expanded = !testResToggle.expanded
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: testResToggle.expanded
                                            Layout.fillWidth: true
                                            implicitHeight: Math.min(testResText.implicitHeight + 12, 300)
                                            radius: 4; clip: true
                                            color: isError ? "#FFF5F5" : "#F1F8E9"

                                            Flickable {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                contentHeight: testResText.implicitHeight
                                                clip: true

                                                Label {
                                                    id: testResText
                                                    width: parent.width
                                                    text: content || "(\u7A7A)"
                                                    wrapMode: Text.Wrap
                                                    font.pixelSize: 11
                                                    font.family: "Consolas"
                                                    color: isError ? "#B71C1C" : "#33691E"
                                                }
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: "CallId: " + (toolCallId || "-")
                                            font.pixelSize: 10
                                            color: isError ? "#B71C1C" : "#33691E"
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#E0E0E0"
                    }

                    // ── 消息输入区域 ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: testMessageInput
                            Layout.fillWidth: true
                            placeholderText: wsClient.connectionState === 3
                                             ? "输入测试消息..."
                                             : "请先连接服务器"
                            enabled: wsClient.connectionState === 3
                            font.pixelSize: 13
                            selectByMouse: true

                            background: Rectangle {
                                radius: 6
                                border.color: testMessageInput.activeFocus
                                              ? "#006BFF" : "#D0D0D0"
                                border.width: 1
                                color: testMessageInput.enabled ? "#FAFAFA" : "#EEEEEE"
                            }

                            // 回车键发送
                            Keys.onReturnPressed: testSendMessage(text)
                            Keys.onEnterPressed: testSendMessage(text)
                        }

                        /// 发送按钮 → testSendMessage()
                        Button {
                            text: "发送"
                            enabled: wsClient.connectionState === 3
                                     && testMessageInput.text.trim().length > 0
                            onClicked: testSendMessage(testMessageInput.text)
                            implicitHeight: 36
                            implicitWidth: 72

                            background: Rectangle {
                                radius: 6
                                color: parent.enabled
                                       ? (parent.down ? "#1565C0" : "#1976D2")
                                       : "#BDBDBD"
                            }
                            contentItem: Label {
                                text: parent.text
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────────────────
        //  底部：操作日志面板
        // ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            radius: 10
            color: "#1A1A2E"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "操作日志"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#B0BEC5"
                    }

                    Item { Layout.fillWidth: true }

                    /// 清空日志
                    Label {
                        text: "清空"
                        font.pixelSize: 12
                        color: "#78909C"

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: testLogModel.clear()
                        }
                    }
                }

                ListView {
                    id: testLogView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: testLogModel
                    spacing: 1

                    delegate: Label {
                        width: testLogView.width
                        text: model.text
                        font.pixelSize: 11
                        font.family: "Consolas, Courier New, monospace"
                        color: {
                            if (model.text.indexOf("✖") >= 0) return "#EF5350"
                            if (model.text.indexOf("⚠") >= 0) return "#FFC107"
                            if (model.text.indexOf("▶") >= 0) return "#4FC3F7"
                            if (model.text.indexOf("◆") >= 0) return "#81C784"
                            return "#B0BEC5"
                        }
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //  初始化
    // ═══════════════════════════════════════════════════════════════

    Component.onCompleted: {
        testAddLog("\u2550\u2550\u2550 TestChatClient \u542f\u52a8 \u2550\u2550\u2550")
        testAddLog("maincontrol: wsClient (GatewayClient)")
        testAddLog("\u670d\u52a1\u5668\u5730\u5740: " + testServerUrl)
        testAddLog("\u5f53\u524d\u4f1a\u8bdd: " + wsClient.currentSessionKey)
        testAddLog("\u8fde\u63a5\u72b6\u6001: " + wsClient.statusText)
        testAddLog("\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
        testAddLog("\u64cd\u4f5c\u6307\u5f15:")
        testAddLog("  \u8fde\u63a5 \u2192 \u70b9\u51fb\u300c\u8fde\u63a5\u670d\u52a1\u5668\u300d")
        testAddLog("  \u5207\u6362 Agent \u2192 \u5de6\u4fa7\u300cAgent\u300d\u6807\u7b7e\u9875\uff0c\u70b9\u51fb\u67d0\u4e2a Agent")
        testAddLog("  \u6280\u80fd\u7ba1\u7406 \u2192 \u5de6\u4fa7\u300c\u6280\u80fd\u300d\u6807\u7b7e\u9875")

        // Agent 列表在连接成功后由 GatewayClient 自动请求（agents.list RPC）
    }
}
