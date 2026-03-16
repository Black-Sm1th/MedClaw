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

    /**
     * @brief 测试扫描本地会话文件
     *
     * maincontrol 调用：sessionReader.scanSessions()
     * 扫描 ~/.openclaw/agents/main/sessions/ 目录
     */
    function testScanLocalSessions() {
        testAddLog("▶ testScanLocalSessions() → 扫描本地会话目录")
        testAddLog("  路径: " + sessionReader.sessionsDir)
        sessionReader.scanSessions()
        var list = sessionReader.sessionList
        testAddLog("  发现 " + list.length + " 个会话文件")
        for (var i = 0; i < list.length; i++) {
            testAddLog("  [" + i + "] " + list[i].displayName
                       + " | " + list[i].modelId
                       + " | active=" + list[i].isActive)
        }
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

    /**
     * @brief 测试加载本地会话的聊天消息
     * @param filePath .jsonl 文件路径
     * @param displayName 会话显示名（用于日志）
     *
     * 从本地文件系统直接读取 .jsonl，不需要 WebSocket 连接
     */
    function testLoadLocalMessages(filePath, displayName) {
        testAddLog("▶ testLoadLocalMessages() → " + displayName)
        var msgs = sessionReader.readSessionMessages(filePath)
        testAddLog("  解析到 " + msgs.length + " 条条目")

        chatModel.clear()
        chatModel.addMessage("system", "本地历史: " + displayName)
        for (var i = 0; i < msgs.length; i++) {
            var m = msgs[i]
            var mt = m.msgType || "text"
            if (mt === "toolCall") {
                chatModel.addToolCall(m.toolName || "", m.toolArgs || "", m.toolCallId || "")
            } else if (mt === "toolResult") {
                chatModel.addToolResult(m.toolName || "", m.content || "",
                                        m.toolCallId || "", m.isError || false)
            } else {
                chatModel.addMessage(m.role, m.content)
            }
        }
    }

    /**
     * @brief 加载 WebSocket 抓包文件（messages.list 响应格式）
     *
     * 直接使用桌面上的抓包文件测试工具调用显示
     * maincontrol 调用：sessionReader.parseResponseFile()
     */
    function testLoadCaptureFile() {
        // 自动检测文件路径（桌面上的抓包文件）
        var homePath = sessionReader.sessionsDir.replace(
            "/.openclaw/agents/main/sessions", "")
        var capturePath = homePath + "/Desktop/接受的流式数据.txt"

        testAddLog("▶ testLoadCaptureFile() → " + capturePath)
        var msgs = sessionReader.parseResponseFile(capturePath)
        testAddLog("  解析到 " + msgs.length + " 条条目")

        // 统计各类型数量
        var textCount = 0, toolCallCount = 0, toolResultCount = 0
        for (var i = 0; i < msgs.length; i++) {
            var mt = msgs[i].msgType || "text"
            if (mt === "toolCall") toolCallCount++
            else if (mt === "toolResult") toolResultCount++
            else textCount++
        }
        testAddLog("  文本:" + textCount + " 工具调用:" + toolCallCount
                   + " 工具结果:" + toolResultCount)

        chatModel.clear()
        chatModel.addMessage("system", "抓包数据: " + capturePath)
        for (var j = 0; j < msgs.length; j++) {
            var m = msgs[j]
            var type = m.msgType || "text"
            if (type === "toolCall") {
                chatModel.addToolCall(m.toolName || "", m.toolArgs || "",
                                      m.toolCallId || "")
            } else if (type === "toolResult") {
                chatModel.addToolResult(m.toolName || "", m.content || "",
                                        m.toolCallId || "", m.isError || false)
            } else {
                chatModel.addMessage(m.role || "system", m.content || "")
            }
        }
        testAddLog("  ✓ 已加载到聊天区域")
    }

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

                    /// 扫描本地会话 → testScanLocalSessions()
                    Button {
                        text: "扫描本地"
                        onClicked: testScanLocalSessions()
                        background: Rectangle {
                            radius: 6
                            color: parent.down ? "#00695C" : "#00897B"
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

                    /// 加载 WebSocket 抓包文件 → testLoadCaptureFile()
                    Button {
                        text: "\u52a0\u8f7d\u6293\u5305"
                        onClicked: testLoadCaptureFile()
                        background: Rectangle {
                            radius: 6
                            color: parent.down ? "#BF360C" : "#E64A19"
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

                    // ── 标签页切换：在线 / 本地 / 技能 ──
                    property int testTabIndex: 0  // 0=在线, 1=本地, 2=技能

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        // 在线会话标签
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: testSessionPanel.testTabIndex === 0 ? "#1976D2" : "#F0F0F0"
                            Label {
                                anchors.centerIn: parent
                                text: "\u5728\u7ebf"
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

                        // 本地历史标签
                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            radius: 6
                            color: testSessionPanel.testTabIndex === 1 ? "#388E3C" : "#F0F0F0"
                            Label {
                                anchors.centerIn: parent
                                text: "\u672c\u5730"
                                font.pixelSize: 12
                                font.bold: true
                                color: testSessionPanel.testTabIndex === 1 ? "#FFFFFF" : "#666666"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    testSessionPanel.testTabIndex = 1
                                    testScanLocalSessions()
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
                                        testAddLog("▶ 切换在线会话 → " + key)
                                        wsClient.currentSessionKey = key
                                        wsClient.loadHistory()
                                    }
                                }
                            }
                        }
                    }

                    // ── 本地历史会话列表（从文件系统读取） ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: testSessionPanel.testTabIndex === 1
                        spacing: 4

                        // 操作按钮
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Button {
                                text: "刷新"
                                implicitHeight: 26
                                implicitWidth: 50
                                font.pixelSize: 11
                                onClicked: testScanLocalSessions()
                                background: Rectangle {
                                    radius: 4
                                    color: parent.down ? "#2E7D32" : "#43A047"
                                }
                                contentItem: Label {
                                    text: parent.text
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Button {
                                text: "sessions.json"
                                implicitHeight: 26
                                font.pixelSize: 11
                                onClicked: testReadSessionsJson()
                                background: Rectangle {
                                    radius: 4
                                    color: parent.down ? "#4527A0" : "#5E35B1"
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
                        }

                        // 路径显示
                        Label {
                            text: sessionReader.sessionsDir
                            font.pixelSize: 9
                            color: "#999999"
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        // 本地会话列表
                        ListView {
                            id: testLocalSessionList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: sessionReader.sessionList
                            spacing: 2

                            // 当前选中的本地会话文件路径
                            property string testSelectedFilePath: ""

                            delegate: Rectangle {
                                width: testLocalSessionList.width
                                height: 52
                                radius: 6
                                color: {
                                    if (modelData.filePath === testLocalSessionList.testSelectedFilePath)
                                        return "#E8F5E9"
                                    return testLocalDelegateArea.containsMouse
                                           ? "#F5F5F5" : "transparent"
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.topMargin: 4
                                    anchors.bottomMargin: 4
                                    spacing: 2

                                    // 第一行：活跃/归档标记 + 预览
                                    Label {
                                        Layout.fillWidth: true
                                        text: {
                                            var tag = modelData.isActive ? "[活跃]" : "[归档]"
                                            var preview = modelData.preview || modelData.sessionId.substring(0, 8)
                                            return tag + " " + preview
                                        }
                                        font.pixelSize: 11
                                        font.bold: modelData.isActive
                                        color: modelData.isActive ? "#1B5E20" : "#333333"
                                        elide: Text.ElideRight
                                    }

                                    // 第二行：模型 + 消息数 + 时间
                                    Label {
                                        Layout.fillWidth: true
                                        text: {
                                            var info = (modelData.modelId || "unknown")
                                            info += " | " + (modelData.messageCount || 0) + "条"
                                            if (modelData.resetTime)
                                                info += " | " + modelData.resetTime.substring(5, 16)
                                            else if (modelData.timestamp)
                                                info += " | " + modelData.timestamp.substring(0, 16)
                                            return info
                                        }
                                        font.pixelSize: 9
                                        color: "#888888"
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: testLocalDelegateArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        testLocalSessionList.testSelectedFilePath = modelData.filePath
                                        testLoadLocalMessages(modelData.filePath, modelData.displayName)
                                    }
                                    onDoubleClicked: {
                                        testReadSessionSummary(modelData.filePath)
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

                    Label {
                        text: "对话内容  (chatModel: " + chatModel.count + " 条)"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#333333"
                        Layout.leftMargin: 4
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
        testAddLog("═══ TestChatClient 启动 ═══")
        testAddLog("maincontrol: wsClient (GatewayClient)")
        testAddLog("服务器地址: " + testServerUrl)
        testAddLog("当前会话: " + wsClient.currentSessionKey)
        testAddLog("连接状态: " + wsClient.statusText)
        testAddLog("本地 sessions 目录: " + sessionReader.sessionsDir)
        testAddLog("───────────────────────────────────")
        testAddLog("操作指引:")
        testAddLog("  在线功能 → 点击「连接服务器」")
        testAddLog("  本地历史 → 点击「扫描本地」或切换左侧「本地历史」标签")
        testAddLog("  双击本地会话条目可查看会话摘要详情")
    }
}
