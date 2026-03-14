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
     * @brief 测试加载历史消息
     *
     * maincontrol 调用：wsClient.loadHistory()
     */
    function testLoadHistory() {
        testAddLog("▶ testLoadHistory() → 加载历史消息")
        wsClient.loadHistory()
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

                    /// 加载历史 → testLoadHistory()
                    Button {
                        text: "加载历史"
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
                        implicitWidth: 100
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
                Layout.preferredWidth: 180
                Layout.fillHeight: true
                radius: 10
                color: "#FFFFFF"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Label {
                        text: "会话列表"
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

                    ListView {
                        id: testSessionList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
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
                                return testSessionDelegateArea.containsMouse
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
                                id: testSessionDelegateArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var key = modelData.sessionKey || ""
                                    if (key !== wsClient.currentSessionKey) {
                                        testAddLog("▶ 切换会话 → " + key)
                                        wsClient.currentSessionKey = key
                                        wsClient.loadHistory()
                                    }
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

                        // 新消息到达时自动滚动到底部
                        onCountChanged: {
                            if (count > 0)
                                positionViewAtEnd()
                        }

                        delegate: Rectangle {
                            id: testMsgBubble
                            width: testChatListView.width

                            // 根据角色计算气泡高度
                            readonly property bool testIsUser: msgRole === "user"
                            readonly property bool testIsSystem: msgRole === "system"

                            height: testMsgContent.implicitHeight + 24
                            color: "transparent"

                            // 气泡背景
                            Rectangle {
                                id: testBubbleBg
                                anchors {
                                    left: testMsgBubble.testIsUser ? undefined : parent.left
                                    right: testMsgBubble.testIsUser ? parent.right : undefined
                                    top: parent.top
                                    leftMargin: testMsgBubble.testIsSystem ? 0 : 8
                                    rightMargin: 8
                                }
                                width: Math.min(
                                    testMsgContent.implicitWidth + 28,
                                    testMsgBubble.width * 0.75)
                                height: testMsgContent.implicitHeight + 20
                                radius: 10
                                color: {
                                    if (testMsgBubble.testIsSystem) return "#FFF3E0"
                                    if (testMsgBubble.testIsUser)   return "#1976D2"
                                    return "#F0F0F0"
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 2

                                    // 角色标签
                                    Label {
                                        text: {
                                            if (testMsgBubble.testIsUser) return "You"
                                            if (testMsgBubble.testIsSystem) return "System"
                                            return "Assistant"
                                        }
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: testMsgBubble.testIsUser ? "#B3FFFFFF" : "#999999"
                                    }

                                    // 消息正文
                                    Label {
                                        id: testMsgContent
                                        Layout.fillWidth: true
                                        text: content
                                        wrapMode: Text.Wrap
                                        font.pixelSize: 13
                                        color: testMsgBubble.testIsUser ? "#FFFFFF" : "#1A1A1A"
                                        textFormat: Text.PlainText
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
        testAddLog("───────────────────────────────────")
        testAddLog("操作指引: 点击「连接服务器」开始测试")
    }
}
