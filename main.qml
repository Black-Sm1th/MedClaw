import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.2
import QtQuick.Dialogs 1.3
import QtGraphicalEffects 1.0
import "./components"
ApplicationWindow {
    id: window
    width: 1440
    height: 800
    visible: true
    title: qsTr("AetherMED_ClawDESK")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    property int leftSelectedIndex: 0
    property bool sidebarCollapsed: false
    // 默认 WebSocket 服务器地址（与 TestChatClient.qml 保持一致）
    property string wsServerUrl: "ws://192.168.124.58:18789"
    /// 非空表示「编辑」已有定时任务；空为新建
    property string editingCronJobId: ""
    property string editingCronPayloadKind: "agentTurn"
    property string pendingDeleteCronJobId: ""
    property string pendingDeleteCronJobName: ""
    property string pendingDeleteMcpName: ""
    /// 编辑 MCP 弹窗预填（由列表 delegate 写入）
    property var mcpEditEntry: null

    // 启动时自动连接 WebSocket 服务器
    Component.onCompleted: {
        wsClient.connectToServer(wsServerUrl)
    }
    Connections{
        target: wsClient
        function onConnectionStateChanged(){
            if(wsClient.connectionState === 3){
                wsClient.refreshSkills()
                wsClient.refreshCronJobs(true)
                wsClient.refreshCronStatus()
                wsClient.refreshMcpList()
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
        function onAgentCreated(agentId, success, message){
            if (success) {
                leftMidPanel.activeAgentId = agentId
                window.leftSelectedIndex = 5
                // 首条消息自动建 agent 时已在 C++ 内 switchAgent + send；此处不再重复 switch
            }
        }
        function onAgentDeleted(agentId, success, message){
            if (success && leftMidPanel.activeAgentId === agentId) {
                leftMidPanel.activeAgentId = ""
                chatModel.clear()
                wsClient.clearActiveAgentContext()
            }
        }
        function onErrorOccurred(message){
            console.warn("[Gateway Error]", message)
            errorToast.text = message
            errorToast.visible = true
            errorToastTimer.restart()
        }
    }
    ListModel { id: cronRunsModel }

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
        width: window.sidebarCollapsed ? 68 : 280
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
                    source: "qrc:/images/titleIcon.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                ImageButton{
                    source: "qrc:/images/sidebarMinimalistic.png"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    visible: !window.sidebarCollapsed
                    onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56
                color: "transparent"

                // 当前选中的 agent ID（用于高亮）
                property string activeAgentId: ""

                Column{
                    id: leftMenuColumn
                    spacing: 12
                    width: parent.width
                    ImageButton{
                        source: "qrc:/images/sidebarMinimalistic.png"
                        visible: window.sidebarCollapsed
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: !window.sidebarCollapsed
                        Repeater {
                            id: selectionRepeater
                            model: ["新建任务", "定时任务", "技能", "MCP"]
                            delegate: Rectangle{
                                property bool isSelected: index === window.leftSelectedIndex
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
                                            }else if(modelData === "技能"){
                                                return "qrc:/images/category.png"
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
                                        window.leftSelectedIndex = index
                                        if (modelData === "新建任务") {
                                            leftMidPanel.activeAgentId = ""
                                            chatModel.clear()
                                            wsClient.clearActiveAgentContext()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Column{
                        spacing: 4
                        width: parent.width
                        visible: window.sidebarCollapsed
                        Repeater {
                            id: selectionRepeaterCollapsed
                            model: ["新建任务", "定时任务", "技能", "MCP", "history"]
                            delegate: Rectangle{
                                property bool isSelected: index === window.leftSelectedIndex
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
                                        }else if(modelData === "技能"){
                                            return "qrc:/images/category.png"
                                        }else if(modelData === "MCP"){
                                            return "qrc:/images/puzzle.png"
                                        }else if(modelData === "history"){
                                            return "qrc:/images/history.png"
                                        }
                                    }
                                }
                                MouseArea {
                                    id: selItemMouseCollapse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.leftSelectedIndex = index
                                        if (modelData === "新建任务") {
                                            leftMidPanel.activeAgentId = ""
                                            chatModel.clear()
                                            wsClient.clearActiveAgentContext()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ═══════════════════════════════════════════════
                //  任务记录列表（agent 列表）
                // ═══════════════════════════════════════════════
                Item {
                    visible: !window.sidebarCollapsed
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

                    // 可滚动的 agent 列表
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
                                model: wsClient.agentList

                                delegate: Rectangle {
                                    id: agentItemRect
                                    width: agentListScrollView.width
                                    height: 55
                                    radius: 8
                                    color: {
                                        var isActive = (modelData.id === leftMidPanel.activeAgentId)
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
                                                // 主标题：首条用户问话（chat.history）；未拉到前用 agent 名
                                                text: {
                                                    var t = modelData.activeSessionTitle || ""
                                                    if (t.length > 0) return t
                                                    return modelData.name || modelData.id || ""
                                                }
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                width: parent.width
                                                // elide: Text.ElideRight
                                            }
                                        }

                                        // 最近活跃会话的更新时间（与上行标题为同一条 session）
                                        Label {
                                            text: {
                                                // 使用会话 startedAt / task-创建时间，不用 updatedAt（点击会刷新）
                                                var ms = Number(modelData.activeSessionDisplayAt || 0)
                                                if (!ms || ms <= 0) return ""
                                                return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm")
                                            }
                                            font.pixelSize: 12
                                            color: "#73000000"
                                        }
                                    }

                                    MouseArea {
                                        id: agentItemMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            leftMidPanel.activeAgentId = modelData.id
                                            window.leftSelectedIndex = 5
                                            wsClient.switchAgent(modelData.id)
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
                ImageButton{
                    id: settingBtn
                    source: "qrc:/images/setting.png"
                    onClicked: settingsDialog.open()
                }
                Rectangle{
                    width: 20
                    height: 1
                    color: "transparent"
                }
                Rectangle{
                    width: 1
                    height: 16
                    color: "#1F000000"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle{
                    width: 20
                    height: 1
                    color: "transparent"
                }
                ImageButton{
                    id: minusBtn
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
                    source: "qrc:/images/close.png"
                    onClicked: {
                        Qt.quit()
                    }
                }
            }
        }
        Rectangle{
            id: rightMainPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rightTopPanel.bottom
            anchors.bottom: parent.bottom
            Rectangle{
                id: newTaskRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 0 || window.leftSelectedIndex === 5
                property bool hasMessages: chatModel.count > 0

                function doSendMessage() {
                    var msg = textInputArea.text.trim()
                    if (msg === "") return
                    // 未连接时不发送，防止消息丢失
                    if (wsClient.connectionState !== 3)
                        return
                    textInputArea.text = ""
                    $MainViewController.sendMessage(msg)
                }

                Column{
                    id: titleCol
                    visible: !newTaskRec.hasMessages
                    width: 840
                    spacing: 11
                    anchors.topMargin: 80
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    Image{
                        source: "qrc:/images/largeIcon.png"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Label{
                        text: "AetherMED_ClawDESK"
                        font.family: "Alimama ShuHeiTi"
                        font.pixelSize: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Label{
                        text: "7×24 小时在线的专属智能伙伴"
                        font.pixelSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                ListView {
                    id: chatListView
                    visible: newTaskRec.hasMessages
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.bottom: chatInputContainer.top
                    anchors.bottomMargin: 8
                    width: 840
                    anchors.horizontalCenter: parent.horizontalCenter
                    clip: true
                    model: chatModel
                    spacing: 12

                    onCountChanged: {
                        if (count > 0)
                            Qt.callLater(positionViewAtEnd)
                    }

                    delegate: Item {
                        width: chatListView.width
                        height: {
                            if (msgType === "toolCall") return toolBlockRoot.height
                            if (msgType === "toolResult") return orphanToolResultRoot.height
                            return chatBubble.height
                        }

                        Rectangle {
                            id: chatBubble
                            visible: msgType !== "toolCall" && msgType !== "toolResult"
                            width: parent.width
                            height: visible ? bubbleInner.height + 4 : 0
                            color: "transparent"
                            readonly property bool isUser: msgRole === "user"

                            Rectangle {
                                id: bubbleInner
                                anchors.left: chatBubble.isUser ? undefined : parent.left
                                anchors.right: chatBubble.isUser ? parent.right : undefined
                                anchors.top: parent.top
                                width: Math.min(bubbleText.implicitWidth + 32, chatBubble.isUser ? chatBubble.width * 0.75 : chatBubble.width)
                                height: bubbleText.implicitHeight + 24
                                radius: 12
                                color: chatBubble.isUser ? "#EBEDF0" : "transparent"

                                Text {
                                    id: bubbleText
                                    text: content
                                    width: Math.min(implicitWidth, chatBubble.isUser ? chatBubble.width * 0.75 - 32 : chatBubble.width)
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 16
                                    anchors.centerIn: parent
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    color: chatBubble.isUser ? "#E5000000" : "#D9000000"
                                    textFormat: Text.MarkdownText
                                }
                            }
                        }

                        // ── 工具调用 + 结果（合并到同一行，可折叠详情）──
                        Item {
                            id: toolBlockRoot
                            visible: msgType === "toolCall"
                            width: parent.width
                            height: visible ? toolBlockRow.implicitHeight : 0

                            readonly property bool toolDone: hasToolResult
                            readonly property bool toolOk: hasToolResult && !isError
                            readonly property bool toolFail: hasToolResult && isError
                            property bool toolDetailExpanded: true

                            Row {
                                id: toolBlockRow
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    id: toolTimelineBar
                                    width: 2
                                    height: toolBlockContent.height
                                    radius: 1
                                    color: "#D0D0D0"
                                }

                                Column {
                                    id: toolBlockContent
                                    width: toolBlockRoot.width - toolTimelineBar.width - toolBlockRow.spacing
                                    spacing: 0

                                    Row {
                                        id: toolHeaderRow
                                        width: parent.width
                                        spacing: 8
                                        height: 28

                                        Item {
                                            width: 20
                                            height: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text {
                                                anchors.centerIn: parent
                                                visible: toolBlockRoot.toolOk
                                                text: "\u2713"
                                                color: "#22C55E"
                                                font.pixelSize: 16
                                                font.bold: true
                                            }
                                            Rectangle {
                                                anchors.centerIn: parent
                                                visible: !toolBlockRoot.toolOk
                                                width: 8
                                                height: 8
                                                radius: 4
                                                color: "#EF4444"
                                            }
                                        }

                                        Row {
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: toolName || qsTr("工具")
                                                font.pixelSize: 14
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                font.bold: true
                                                color: "#D9000000"
                                            }

                                            Text {
                                                id: toolChevron
                                                text: toolBlockRoot.toolDetailExpanded ? "\u25BE" : "\u25B8"
                                                font.pixelSize: 12
                                                color: "#99000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -6
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: toolBlockRoot.toolDetailExpanded = !toolBlockRoot.toolDetailExpanded
                                                }
                                            }

                                        }
                                    }

                                    Column {
                                        width: parent.width
                                        visible: toolBlockRoot.toolDetailExpanded
                                        spacing: 8

                                        Rectangle {
                                            width: parent.width
                                            visible: toolArgs && String(toolArgs).length > 0
                                            height: visible ? Math.min(toolArgsText.implicitHeight + 20, 200) : 0
                                            radius: 8
                                            color: "#F3F4F6"
                                            border.width: 1
                                            border.color: "#E5E7EB"
                                            clip: true

                                            Text {
                                                id: toolArgsText
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: toolArgs || ""
                                                wrapMode: Text.Wrap
                                                font.pixelSize: 12
                                                font.family: "Consolas, Courier New, Alibaba PuHuiTi 3.0"
                                                color: "#374151"
                                                textFormat: Text.MarkdownText
                                            }
                                        }

                                        Rectangle {
                                            width: parent.width
                                            visible: hasToolResult && String(toolResultText).length > 0
                                            height: visible ? Math.min(toolResultBody.implicitHeight + 20, 320) : 0
                                            radius: 8
                                            color: "#F3F4F6"
                                            border.width: 1
                                            border.color: isError ? "#FECACA" : "#E5E7EB"
                                            clip: true

                                            Text {
                                                id: toolResultBody
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                text: toolResultText || ""
                                                wrapMode: Text.Wrap
                                                font.pixelSize: 12
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: isError ? "#DC2626" : "#374151"
                                                textFormat: Text.MarkdownText
                                            }
                                        }

                                        Row {
                                            width: parent.width
                                            visible: hasToolResult
                                            spacing: 8
                                            height: 24

                                            Item {
                                                width: 20
                                                height: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: toolBlockRoot.toolOk
                                                    text: "\u2713"
                                                    color: "#22C55E"
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                }
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    visible: !toolBlockRoot.toolOk
                                                    width: 8
                                                    height: 8
                                                    radius: 4
                                                    color: "#EF4444"
                                                }
                                            }

                                            Text {
                                                text: isError ? qsTr("任务失败") : qsTr("任务完成")
                                                font.pixelSize: 13
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: isError ? "#DC2626" : "#16A34A"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 未匹配到 toolCall 的孤立 toolResult（兼容）
                        Item {
                            id: orphanToolResultRoot
                            visible: msgType === "toolResult"
                            width: parent.width
                            height: visible ? orphanToolCol.implicitHeight + 24 : 0

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#F3F4F6"
                                border.width: 1
                                border.color: isError ? "#FECACA" : "#E5E7EB"

                                Column {
                                    id: orphanToolCol
                                    width: parent.width - 24
                                    x: 12
                                    y: 12
                                    spacing: 6

                                    Row {
                                        spacing: 8
                                        Text {
                                            visible: !isError
                                            text: "\u2713"
                                            color: "#22C55E"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }
                                        Rectangle {
                                            visible: isError
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: "#EF4444"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: toolName
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: "#D9000000"
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        text: content || ""
                                        wrapMode: Text.Wrap
                                        font.pixelSize: 12
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: isError ? "#DC2626" : "#374151"
                                        textFormat: Text.MarkdownText
                                    }
                                }
                            }
                        }
                    }
                }

                ListModel {
                    id: attachmentModel
                }

                Rectangle{
                    id: chatInputContainer
                    border.color: "#40000000"
                    border.width: 1
                    radius: 20
                    height: attachmentModel.count > 0 ? 142 + 60 : 142
                    width: 840
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: newTaskRec.hasMessages
                       ? newTaskRec.height - height - 24
                       : titleCol.y + titleCol.height + 76
                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Column{
                        anchors.fill: parent
                        padding: 12
                        spacing: 8

                        Row {
                            id: attachmentRow
                            visible: attachmentModel.count > 0
                            width: parent.width - 24
                            height: visible ? 48 : 0
                            clip: true
                            spacing: 8

                            Repeater {
                                model: attachmentModel

                                delegate: Rectangle {
                                    width: 148
                                    height: 48
                                    radius: 12
                                    color: "#F7F9FA"

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        spacing: 4

                                        Rectangle {
                                            width: 36
                                            height: 36
                                            radius: 6
                                            color: "transparent"
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                source: model.filePath || ""
                                                fillMode: Image.PreserveAspectCrop
                                                visible: model.isImage || false
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                source: "qrc:/images/filePicture.png"
                                                fillMode: Image.PreserveAspectCrop
                                                visible: !(model.isImage || false)
                                            }

                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 36 - 20 - 8
                                            spacing: 2

                                            Text {
                                                id:fileNameText
                                                width: parent.width
                                                text: model.fileName || ""
                                                font.pixelSize: 14
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#D9000000"
                                                elide: Text.ElideRight
                                                ToolTip {
                                                    visible: fileNameHover.containsMouse && fileNameText.truncated
                                                    text: fileNameText.text
                                                    delay: 500
                                                    x: 0
                                                    y: fileNameText.height + 4
                                                    width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                                    background: Rectangle {
                                                        color: "#A6000000"
                                                        radius: 4
                                                    }
                                                    contentItem: Text {
                                                        text: fileNameText.text
                                                        font.pixelSize: 14
                                                        color: "#FFFFFF"
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                                MouseArea {
                                                    id: fileNameHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }
                                            Text {
                                                text: model.fileSize || ""
                                                font.pixelSize: 12
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#40000000"
                                            }
                                        }

                                        Text {
                                            text: "\u2715"
                                            font.pixelSize: 12
                                            color: "#80000000"
                                            anchors.verticalCenter: parent.verticalCenter

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: attachmentModel.remove(index)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MultiLineTextInput{
                            id: textInputArea
                            focusedBorderColor: "transparent"
                            backgroundColor: "transparent"
                            borderWidth: 0
                            placeholderText: wsClient.connectionState === 3
                                             ? "分配一个任务或提问任何问题"
                                             : "正在连接服务器，请稍候..."
                            width: parent.width - 24
                            height: 66
                            readOnly: wsClient.connectionState !== 3
                            onEnterPressed: newTaskRec.doSendMessage()
                        }
                        Rectangle{
                            height: 40
                            width: parent.width - 24
                            Row {
                                anchors.fill: parent
                                spacing: 4
                                Item {
                                    id: dropdownSelectionWorkSpace
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 137
                                    height: 36

                                    property string currentText: "workspace"
                                    property var recentFolders: []

                                    Rectangle {
                                        id: wsButton
                                        anchors.fill: parent
                                        radius: 8
                                        color: wsMouseArea.pressed ? "#14000000"
                                             : wsMouseArea.containsMouse ? "#0A000000"
                                             : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            spacing: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.horizontalCenterOffset: -wsChevron.width / 2 - 2

                                            Image {
                                                source: "qrc:/images/folder.png"
                                                width: 20; height: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(20, 20)
                                            }
                                            Text {
                                                text: dropdownSelectionWorkSpace.currentText
                                                font.pixelSize: 14
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Canvas {
                                            id: wsChevron
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
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wsPopup.visible ? wsPopup.close() : wsPopup.open()
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
                                            // 如果底部空间不足，则显示在上方
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
                                            var path = folderDialogWorkSpace.fileUrl.toString()
                                            path = path.replace(/^file:\/\/\//, "")
                                            var parts = path.split("/")
                                            dropdownSelectionWorkSpace.currentText = parts[parts.length - 1] || path
                                        }
                                    }
                                }
                                Item {
                                    id: dropdownSelectionSkill
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: skillBtnRow.width + 12 + skillChevron.width + 12
                                    height: 36

                                    property var selectedSkills: []
                                    property string searchText: ""

                                    function syncFromWsClient() {
                                        var arr = []
                                        var list = wsClient.skillList
                                        for (var i = 0; i < list.length; i++) {
                                            if (list[i].enabled)
                                                arr.push(list[i].name || list[i].skillKey)
                                        }
                                        selectedSkills = arr
                                    }

                                    Connections {
                                        target: wsClient
                                        function onSkillListChanged() {
                                            dropdownSelectionSkill.syncFromWsClient()
                                        }
                                    }

                                    function isSelected(name) {
                                        for (var i = 0; i < selectedSkills.length; i++) {
                                            if (selectedSkills[i] === name) return true
                                        }
                                        return false
                                    }

                                    function toggleSkill(name) {
                                        var arr = selectedSkills.slice()
                                        var idx = -1
                                        for (var i = 0; i < arr.length; i++) {
                                            if (arr[i] === name) { idx = i; break }
                                        }
                                        if (idx >= 0) arr.splice(idx, 1)
                                        else arr.push(name)
                                        selectedSkills = arr

                                        var list = wsClient.skillList
                                        for (var j = 0; j < list.length; j++) {
                                            var key = list[j].skillKey || list[j].name
                                            if ((list[j].name || key) === name) {
                                                wsClient.setSkillEnabled(key, idx < 0)
                                                break
                                            }
                                        }
                                    }

                                    function filteredSkills() {
                                        var list = wsClient.skillList
                                        if (!searchText) return list
                                        var result = []
                                        for (var i = 0; i < list.length; i++) {
                                            var n = (list[i].name || list[i].skillKey || "").toLowerCase()
                                            if (n.indexOf(searchText.toLowerCase()) >= 0)
                                                result.push(list[i])
                                        }
                                        return result
                                    }

                                    Rectangle {
                                        id: skillButton
                                        anchors.fill: parent
                                        radius: 8
                                        color: skillMouseArea.pressed ? "#14000000"
                                             : skillMouseArea.containsMouse ? "#0A000000"
                                             : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Row {
                                            id: skillBtnRow
                                            spacing: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12

                                            Image {
                                                source: "qrc:/images/category.png"
                                                width: 20; height: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                fillMode: Image.PreserveAspectFit
                                                sourceSize: Qt.size(20, 20)
                                            }
                                            Text {
                                                text: "技能"
                                                font.pixelSize: 14
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Rectangle {
                                                visible: dropdownSelectionSkill.selectedSkills.length > 0
                                                width: badgeText.width + 8
                                                height: 20
                                                radius: 10
                                                color: "#14000000"
                                                anchors.verticalCenter: parent.verticalCenter

                                                Text {
                                                    id: badgeText
                                                    text: dropdownSelectionSkill.selectedSkills.length
                                                    font.pixelSize: 12
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    color: "#73000000"
                                                    anchors.centerIn: parent
                                                }
                                            }
                                        }

                                        Canvas {
                                            id: skillChevron
                                            width: 16; height: 16
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            rotation: skillPopup.visible ? 180 : 0
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
                                            id: skillMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: skillPopup.visible ? skillPopup.close() : skillPopup.open()
                                        }
                                    }

                                    Popup {
                                        id: skillPopup
                                        x: 0
                                        width: 220
                                        padding: 8
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                        function calcY() {
                                            var globalPos = dropdownSelectionSkill.mapToItem(null, 0, 0)
                                            var windowH = window.height
                                            var popupH = contentItem.implicitHeight + padding * 2
                                            // 如果底部空间不足，则显示在上方
                                            if (globalPos.y + dropdownSelectionSkill.height + 4 + popupH > windowH)
                                                return -popupH - 4
                                            return dropdownSelectionSkill.height + 4
                                        }

                                        y: calcY()

                                        onAboutToShow: {
                                            skillSearchInput.text = ""
                                            y = calcY()
                                        }

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
                                            spacing: 6

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                SingleLineTextInput {
                                                    id: skillSearchInput
                                                    inputWidth: parent.width - skillSettingPopBtn.width - 6
                                                    inputHeight: 32
                                                    inputRadius: 6
                                                    icon: "qrc:/images/search.png"
                                                    iconSize: 14
                                                    fontSize: 13
                                                    placeholderText: qsTr("搜索技能")
                                                    onTextChanged: dropdownSelectionSkill.searchText = text
                                                }

                                                ImageButton {
                                                    id: skillSettingPopBtn
                                                    source: "qrc:/images/setting.png"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    onClicked: {
                                                        skillPopup.close()
                                                        window.leftSelectedIndex = 2
                                                    }
                                                }
                                            }

                                            Flickable {
                                                id: skillListFlick
                                                width: parent.width
                                                height: Math.min(skillListCol.height, 300)
                                                contentHeight: skillListCol.height
                                                clip: true
                                                boundsBehavior: Flickable.StopAtBounds

                                                Column {
                                                    id: skillListCol
                                                    width: parent.width
                                                    spacing: 2

                                                    Repeater {
                                                        model: dropdownSelectionSkill.filteredSkills()

                                                        delegate: Rectangle {
                                                            width: skillPopup.width - 16
                                                            height: 36
                                                            radius: 6
                                                            color: skillItemMouse.pressed ? "#14000000"
                                                                 : skillItemMouse.containsMouse ? "#0A000000"
                                                                 : "transparent"
                                                            Behavior on color { ColorAnimation { duration: 100 } }

                                                            Row {
                                                                spacing: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                anchors.left: parent.left
                                                                anchors.leftMargin: 8

                                                                Image {
                                                                    source: modelData.icon || "qrc:/images/skillIcon.png"
                                                                    width: 20; height: 20
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    fillMode: Image.PreserveAspectFit
                                                                    sourceSize: Qt.size(20, 20)
                                                                }
                                                                Text {
                                                                    id: skilPopNameLabel
                                                                    width: skillPopup.width - 16 - 16 - 20 - 16 - 16
                                                                    text: modelData.name || modelData.skillKey || ""
                                                                    font.pixelSize: 14
                                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                                    color: "#D9000000"
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    elide: Text.ElideRight
                                                                    ToolTip {
                                                                        visible: skillItemMouse.containsMouse && skilPopNameLabel.truncated
                                                                        text: skilPopNameLabel.text
                                                                        delay: 500
                                                                        x: 0
                                                                        y: skilPopNameLabel.height + 4
                                                                        width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                                                        background: Rectangle {
                                                                            color: "#A6000000"
                                                                            radius: 4
                                                                        }
                                                                        contentItem: Text {
                                                                            text: skilPopNameLabel.text
                                                                            font.pixelSize: 14
                                                                            color: "#FFFFFF"
                                                                            font.family: "Alibaba PuHuiTi 3.0"
                                                                            wrapMode: Text.Wrap
                                                                        }
                                                                    }
                                                                }
                                                            }

                                                            Canvas {
                                                                visible: dropdownSelectionSkill.isSelected(modelData.name || modelData.skillKey)
                                                                width: 16; height: 16
                                                                anchors.right: parent.right
                                                                anchors.rightMargin: 8
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                onVisibleChanged: requestPaint()
                                                                onPaint: {
                                                                    var ctx = getContext("2d")
                                                                    ctx.reset()
                                                                    ctx.strokeStyle = "#006BFF"
                                                                    ctx.lineWidth = 2
                                                                    ctx.lineCap = "round"
                                                                    ctx.lineJoin = "round"
                                                                    ctx.beginPath()
                                                                    ctx.moveTo(3, 8)
                                                                    ctx.lineTo(6.5, 11.5)
                                                                    ctx.lineTo(13, 4.5)
                                                                    ctx.stroke()
                                                                }
                                                            }

                                                            MouseArea {
                                                                id: skillItemMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: dropdownSelectionSkill.toggleSkill(modelData.name || modelData.skillKey)
                                                            }
                                                        }
                                                    }
                                                }

                                                ScrollBar.vertical: ScrollBar {
                                                    policy: skillListFlick.contentHeight > skillListFlick.height
                                                            ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                                                    width: 4
                                                    contentItem: Rectangle {
                                                        implicitWidth: 4
                                                        radius: 2
                                                        color: "#40000000"
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
                                DropdownSelect {
                                    id: dropdownSelectionModel
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 137
                                    height: 36
                                    model: ["Qwen3-32B"]
                                    icon: "qrc:/images/ai.png"
                                    iconSize: 20
                                    currentIndex: 0
                                }
                                Rectangle{
                                    width: parent.width - dropdownSelectionWorkSpace.width - dropdownSelectionSkill.width - dropdownSelectionModel.width - inputLeftRow.width - 4 * 4
                                    height: 1
                                }
                                Row{
                                    id: inputLeftRow
                                    height: parent.height
                                    spacing: 24
                                    ImageButton{
                                        id: uploadBtn
                                        source: "qrc:/images/paperclip.png"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: attachFileDialog.open()
                                    }

                                    FileDialog {
                                        id: attachFileDialog
                                        title: qsTr("选择文件")
                                        selectMultiple: true
                                        onAccepted: {
                                            for (var i = 0; i < fileUrls.length; i++) {
                                                var url = fileUrls[i].toString()
                                                var path = url.replace(/^file:\/\/\//, "")
                                                var parts = path.split("/")
                                                var name = parts[parts.length - 1] || ""
                                                var dotIdx = name.lastIndexOf(".")
                                                var ext = dotIdx >= 0 ? name.substring(dotIdx + 1).toUpperCase() : ""
                                                var imgExts = ["JPG", "JPEG", "PNG", "GIF", "BMP", "WEBP"]
                                                var isImg = imgExts.indexOf(ext) >= 0
                                                attachmentModel.append({
                                                    fileName: name,
                                                    filePath: isImg ? url : "",
                                                    fileSize: "",
                                                    ext: ext,
                                                    isImage: isImg
                                                })
                                            }
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
                                        enabled: textInputArea.text !== ""
                                        backgroundColor: "#006BFF"
                                        iconSource: "qrc:/images/send.png"
                                        onClicked: newTaskRec.doSendMessage()
                                    }
                                }
                            }
                        }
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
                        height: scheduledTaskTitle.height
                        width: parent.width - 120
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
                                    newTaskTitleInput.text = ""
                                    newTaskPromptInput.text = ""
                                    newTaskRepeatSelect.currentIndex = 0
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

                            // 空状态
                            Rectangle {
                                width: scheduledTaskScrollView.width - 120
                                height: 120
                                visible: wsClient.cronJobs.length === 0
                                color: "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: qsTr("暂无定时任务，点击「+ 新建」创建第一个任务")
                                    font.pixelSize: 14
                                    color: "#A6000000"
                                }
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
                                            width: 20; height: 20
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
                                                            newTaskTitleInput.text = cronJobRow.job.name || ""
                                                            newTaskPromptInput.text = cronJobRow.job.payloadMessage || ""
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
                                    width: cronHistoryScrollView.width - 120
                                    height: 64
                                    radius: 8
                                    color: "#F7F9FA"

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 12

                                        // 状态指示圆点
                                        Rectangle {
                                            width: 10; height: 10; radius: 5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: {
                                                var s = model.status || ""
                                                if (s === "ok") return "#22C55E"
                                                if (s === "error") return "#EF4444"
                                                if (s === "skipped") return "#F59E0B"
                                                return "#D9D9D9"
                                            }
                                        }

                                        Column {
                                            spacing: 4
                                            Label {
                                                text: model.jobName || model.jobId || ""
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                color: "#D9000000"
                                            }
                                            Row {
                                                spacing: 12
                                                Label {
                                                    text: {
                                                        var s = model.status || ""
                                                        if (s === "ok") return "成功"
                                                        if (s === "error") return "失败"
                                                        if (s === "skipped") return "跳过"
                                                        return s
                                                    }
                                                    font.pixelSize: 12
                                                    color: {
                                                        var s = model.status || ""
                                                        if (s === "ok") return "#22C55E"
                                                        if (s === "error") return "#EF4444"
                                                        return "#73000000"
                                                    }
                                                }
                                                Label {
                                                    text: (model.startedAt || "").replace("T", " ").substring(0, 19)
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                                    visible: (model.startedAt || "") !== ""
                                                }
                                                Label {
                                                    text: model.durationMs ? (model.durationMs + " ms") : ""
                                                    font.pixelSize: 12
                                                    color: "#73000000"
                                                    visible: text !== ""
                                                }
                                            }
                                        }
                                    }

                                    // 错误信息
                                    Label {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: model.error || ""
                                        font.pixelSize: 12
                                        color: "#EF4444"
                                        visible: (model.error || "") !== ""
                                        width: Math.min(implicitWidth, 200)
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle{
                id: skillSettingRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 2
                property string skillSearchText: ""

                function filteredSkillList() {
                    var list = wsClient.skillList
                    if (!skillSearchText) return list
                    var kw = skillSearchText.toLowerCase()
                    var result = []
                    for (var i = 0; i < list.length; i++) {
                        var name = (list[i].name || list[i].skillKey || "").toLowerCase()
                        var desc = (list[i].description || "").toLowerCase()
                        if (name.indexOf(kw) >= 0 || desc.indexOf(kw) >= 0)
                            result.push(list[i])
                    }
                    return result
                }
                Column{
                    anchors.fill: parent
                    leftPadding: 60
                    topPadding: 24
                    rightPadding: 60
                    spacing: 16
                    Rectangle{
                        id: skillSettingTitleRec
                        height: skillSettingTitle.height
                        width: parent.width - 120
                        Column{
                            id: skillSettingTitle
                            spacing: 8
                            anchors.left: parent.left
                            Label{
                                text: qsTr("技能")
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                color: "#D9000000"
                            }
                            Label{
                                text: qsTr("为您的智能体提供预封装且可重复的最佳实践与工具")
                                font.pixelSize: 14
                                color: "#A6000000"
                            }
                            SingleLineTextInput {
                                id: skillSettingSearchInput
                                inputHeight: 36
                                inputWidth: skillSettingTitleRec.width
                                icon: "qrc:/images/search.png"
                                iconSize: 16
                                placeholderText: "搜索技能"
                                onTextChanged: skillSettingRec.skillSearchText = text
                            }
                        }
                        Item {
                            width: 80
                            height: 36
                            anchors.right: parent.right

                            CustomButton{
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

                                            Behavior on color {
                                                ColorAnimation { duration: 100 }
                                            }

                                            Row {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 8

                                                Image {
                                                    width: 16
                                                    height: 16
                                                    source: modelData.icon
                                                    sourceSize: Qt.size(16, 16)
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
                    TabBarView{
                        id: skillSettingTaskTab
                        lineWidth: parent.width - 120
                        tabs: [ { text: "已安装", badge: wsClient.skillList.length }, { text: "技能市场" }]
                    }
                    ScrollView {
                        id: skillScrollView
                        width: parent.width - 120
                        height: skillSettingRec.height - 24 - skillSettingTitleRec.height - skillSettingTaskTab.height - 32
                        clip: true
                        visible: skillSettingTaskTab.currentIndex === 0
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Grid {
                            id: skillGrid
                            columns: 2
                            spacing: 12
                            width: skillScrollView.width

                            property real cellWidth: (width - spacing) / 2

                            Repeater {
                                model: skillSettingRec.filteredSkillList()

                                delegate: Rectangle {
                                    width: skillGrid.cellWidth
                                    height: 100
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    Column {
                                        anchors.fill: parent
                                        padding: 20
                                        spacing: 12

                                        Row{
                                            spacing: 8
                                            width: parent.width - 40
                                            height: 28
                                            Image {
                                                width: 28
                                                height: 28
                                                source: modelData.icon || "qrc:/images/skillIcon.png"
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            Label {
                                                id: skillNameLabel
                                                width: parent.width - 36
                                                text: modelData.name ? modelData.name : ""
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight

                                                ToolTip {
                                                    visible: skillNameHover.containsMouse && skillNameLabel.truncated
                                                    text: skillNameLabel.text
                                                    delay: 500
                                                    x: 0
                                                    y: skillNameLabel.height + 4
                                                    width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                                    background: Rectangle {
                                                        color: "#A6000000"
                                                        radius: 4
                                                    }
                                                    contentItem: Text {
                                                        text: skillNameLabel.text
                                                        font.pixelSize: 14
                                                        color: "#FFFFFF"
                                                        font.family: "Alibaba PuHuiTi 3.0"
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                                MouseArea {
                                                    id: skillNameHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.NoButton
                                                }
                                            }
                                        }
                                        Label {
                                            id: skillDescLabel
                                            text: modelData.description || ""
                                            width: parent.width - 40
                                            height: parent.height - 40 - 28 - 12
                                            font.pixelSize: 14
                                            color: "#73000000"
                                            visible: (modelData.description || "").length > 0
                                            elide: Text.ElideRight

                                            ToolTip {
                                                visible: skillDescHover.containsMouse && skillDescLabel.truncated
                                                text: skillDescLabel.text
                                                delay: 500
                                                x: 0
                                                y: -height - 4
                                                width: Math.min(implicitContentWidth + 20, skillGrid.cellWidth - 40)
                                                background: Rectangle {
                                                    color: "#A6000000"
                                                    radius: 4
                                                }
                                                contentItem: Text {
                                                    text: skillDescLabel.text
                                                    font.pixelSize: 14
                                                    color: "#FFFFFF"
                                                    font.family: "Alibaba PuHuiTi 3.0"
                                                    wrapMode: Text.Wrap
                                                }
                                            }
                                            MouseArea {
                                                id: skillDescHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                acceptedButtons: Qt.NoButton
                                            }
                                        }
                                    }

                                    // Switch {
                                    //     id: skillSwitch
                                    //     checked: modelData.enabled
                                    //     anchors.right: parent.right
                                    //     anchors.rightMargin: 20
                                    //     anchors.top: parent.top
                                    //     anchors.topMargin: 20

                                    //     MouseArea {
                                    //         anchors.fill: parent
                                    //         cursorShape: Qt.PointingHandCursor
                                    //         onClicked: {
                                    //         }
                                    //     }

                                    //     indicator: Rectangle {
                                    //         implicitWidth: 44
                                    //         implicitHeight: 22
                                    //         x: skillSwitch.leftPadding
                                    //         y: parent.height / 2 - height / 2
                                    //         radius: 12
                                    //         color: skillSwitch.checked ? "#006BFF" : "#1F000000"

                                    //         Behavior on color {
                                    //             ColorAnimation { duration: 150 }
                                    //         }

                                    //         Rectangle {
                                    //             x: skillSwitch.checked ? parent.width - width - 3 : 3
                                    //             y: parent.height / 2 - height / 2
                                    //             width: 18
                                    //             height: 18
                                    //             radius: 9
                                    //             color: "#FFFFFF"

                                    //             Behavior on x {
                                    //                 NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    //             }
                                    //         }
                                    //     }
                                    // }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: skillMarketScrollView
                        width: parent.width - 120
                        height: skillSettingRec.height - 24 - skillSettingTitleRec.height - skillSettingTaskTab.height - 32
                        clip: true
                        visible: skillSettingTaskTab.currentIndex === 1
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                        Grid {
                            id: skillMarketGrid
                            columns: 2
                            spacing: 12
                            width: skillMarketScrollView.width

                            property real cellWidth: (width - spacing) / 2

                            Repeater {
                                model: ListModel {
                                    ListElement { title: "深度问数"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "生信分析"; desc: "单细胞数据分析，空间转录数据分析"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "pdf"; desc: "PDF 文本提取、表单填写与文档处理"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "note-taker"; desc: "自动笔记整理与知识沉淀"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "docx"; desc: "Word 文档创建、编辑与格式分析"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "file-organizer"; desc: "本地文件智能分类与整理"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "pptx"; desc: "演示文稿编辑与内容生成"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                    ListElement { title: "xlsx"; desc: "电子表格创建、公式计算与可视化"; icon: "qrc:/images/skillIcon.png"; installed: false }
                                }

                                delegate: Rectangle {
                                    width: skillMarketGrid.cellWidth
                                    height: 100
                                    radius: 8
                                    border.color: "#E6E7EB"
                                    border.width: 1
                                    color: "#FFFFFF"

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        spacing: 12

                                        Row {
                                            spacing: 12
                                            height: 28
                                            Image {
                                                width: 28
                                                height: 28
                                                source: model.icon
                                                fillMode: Image.PreserveAspectFit
                                            }
                                            Label {
                                                text: model.title
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        Label {
                                            text: model.desc
                                            font.pixelSize: 14
                                            color: "#73000000"
                                        }
                                    }

                                    CustomButton {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20
                                        width: 80
                                        height: 36
                                        buttonRadius: 8
                                        fontSize: 14
                                        iconSource: model.installed ? "" : "qrc:/images/download.png"
                                        text: model.installed ? "已安装" : "安装"
                                        backgroundColor: "#006BFF"
                                        textColor: "#FFFFFF"
                                        borderWidth: 0
                                        enabled: !model.installed
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: mcpSettingRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 3
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
                                inputHeight: 36
                                inputWidth: mcpTitleRec.width
                                icon: "qrc:/images/search.png"
                                iconSize: 16
                                placeholderText: qsTr("搜索 MCP")
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
                            columns: 2
                            spacing: 12
                            width: mcpInstalledScrollView.width
                            property real cellWidth: (width - spacing) / 2

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

                            Repeater {
                                model: wsClient.mcpList

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
                width: 600
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
                        visible: window.editingCronJobId === ""
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
                            }
                            DatePicker {
                                id: newTaskDatePicker
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                            TimePicker {
                                id: newTaskTimePicker
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                        }
                    }

                    // 自定义间隔输入（仅当选择"自定义间隔"时显示）
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: window.editingCronJobId === "" && newTaskRepeatSelect.currentIndex === 4
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
                                    wsClient.updateCronJobContent(window.editingCronJobId, title, prompt,
                                                                  window.editingCronPayloadKind)
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

                                function pad(n) { return n < 10 ? "0" + n : "" + n }

                                var workPath = newTaskWorkDirInput.text.trim()
                                var agentDisplay = wsClient.cronDedicatedAgentDisplayName(title)

                                if (repeatIdx === 0) {
                                    var dt = y + "-" + pad(m) + "-" + pad(d) + "T" + pad(hh) + ":" + pad(mm) + ":00"
                                    console.log("[CronAdd] oneTime dateTime=" + dt)
                                    wsClient.createAgent(agentDisplay, workPath)
                                    wsClient.prepareCronJobWithDedicatedAgent(3, title, prompt, "", "", 0, dt)
                                } else if (repeatIdx === 1) {
                                    var cronExpr = mm + " " + hh + " * * *"
                                    console.log("[CronAdd] daily cron=" + cronExpr)
                                    wsClient.createAgent(agentDisplay, workPath)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr, "Asia/Shanghai", 0, "")
                                } else if (repeatIdx === 2) {
                                    var dateObj = new Date(y, m - 1, d)
                                    var dow = dateObj.getDay()
                                    var cronExpr2 = mm + " " + hh + " * * " + dow
                                    console.log("[CronAdd] weekly cron=" + cronExpr2)
                                    wsClient.createAgent(agentDisplay, workPath)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr2, "Asia/Shanghai", 0, "")
                                } else if (repeatIdx === 3) {
                                    var cronExpr3 = mm + " * * * *"
                                    console.log("[CronAdd] hourly cron=" + cronExpr3)
                                    wsClient.createAgent(agentDisplay, workPath)
                                    wsClient.prepareCronJobWithDedicatedAgent(1, title, prompt, cronExpr3, "Asia/Shanghai", 0, "")
                                } else if (repeatIdx === 4) {
                                    var sec = parseInt(newTaskIntervalInput.text) || 3600
                                    if (sec <= 0) {
                                        errorToast.text = "间隔须大于 0 秒"
                                        errorToast.visible = true
                                        errorToastTimer.restart()
                                        return
                                    }
                                    console.log("[CronAdd] interval sec=" + sec)
                                    wsClient.createAgent(agentDisplay, workPath)
                                    wsClient.prepareCronJobWithDedicatedAgent(2, title, prompt, "", "", sec, "")
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
                                newTaskDialog.close()
                            }
                        }
                    }
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
                text: qsTr("确定删除定时任务「") + window.pendingDeleteCronJobName + "」？"
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

    FileDialog {
        id: zipFileDialog
        title: qsTr("选择 ZIP 文件")
        nameFilters: ["ZIP files (*.zip)"]
        selectMultiple: false
        onAccepted: {
        }
    }

    FileDialog {
        id: folderDialog
        title: qsTr("选择文件夹")
        selectFolder: true
        onAccepted: {
        }
    }

    FileDialog {
        id: workDirDialog
        title: qsTr("选择工作目录")
        selectFolder: true
        onAccepted: {
            var path = workDirDialog.fileUrl.toString()
            path = path.replace(/^file:\/\/\//, "")
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
                width: 600
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
                width: 560
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
                                        }
                                        SingleLineTextInput {
                                            width: (parent.width - 96) / 2
                                            inputHeight: 40
                                            inputRadius: 8
                                            fontSize: 14
                                            placeholderText: qsTr("值")
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
                            onClicked: mcpServiceDialog.close()
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
        id: settingsDialog
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        padding: 0

        property int settingsTabIndex: 0

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
                width: 720
                height: Math.min(600, window.height - 100)
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
                                            sourceSize: Qt.size(16, 16)
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

                            Column {
                                width: parent.width - 32
                                spacing: 4

                                Repeater {
                                    model: ListModel {
                                        id: modelListModel
                                        ListElement { name: "Qwen3-32B"; enabled: true }
                                    }

                                    delegate: Rectangle {
                                        width: parent.width
                                        height: 56
                                        radius: 8
                                        color: "transparent"

                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 8

                                            Image {
                                                width: 28; height: 28
                                                source: "qrc:/images/ai.png"
                                                sourceSize: Qt.size(28, 28)
                                                fillMode: Image.PreserveAspectFit
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Label {
                                                text: model.name
                                                font.pixelSize: 14
                                                color: "#D9000000"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Switch {
                                            id: modelItemSwitch
                                            checked: model.enabled
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: modelItemSwitch.toggle()
                                            }
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                x: modelItemSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                color: modelItemSwitch.checked ? "#006BFF" : "#D9D9D9"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Rectangle {
                                                    x: modelItemSwitch.checked ? parent.width - width - 3 : 3
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
                                }
                            }

                            Column {
                                width: parent.width - 32
                                spacing: 4
                                SingleLineTextInput {
                                    width: parent.width
                                    inputHeight: 36
                                    inputRadius: 8
                                    icon: "qrc:/images/search.png"
                                    iconSize: 16
                                    fontSize: 14
                                    placeholderText: qsTr("搜索记忆内容/来源")
                                }
                                Repeater {
                                    model: ListModel {
                                        id: memoryListModel
                                        ListElement { memTitle: "记忆标题"; memDate: "更新于 2026/3/13 09:00"; memContent: "记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆" }
                                        ListElement { memTitle: "记忆标题"; memDate: "更新于 2026/3/13 09:00"; memContent: "记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆" }
                                        ListElement { memTitle: "记忆标题"; memDate: "更新于 2026/3/13 09:00"; memContent: "记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆" }
                                        ListElement { memTitle: "记忆标题"; memDate: "更新于 2026/3/13 09:00"; memContent: "记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆记忆" }
                                    }

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
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 12
                                            Label {
                                                text: model.memTitle
                                                font.pixelSize: 16
                                                color: "#D9000000"
                                            }
                                            Label {
                                                text: model.memDate
                                                font.pixelSize: 16
                                                color: "#73000000"
                                                anchors.baseline: parent.children[0].baseline
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 16
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4
                                            visible: memoryItemHover.hovered

                                            ImageButton {
                                                source: "qrc:/images/edit.png"
                                            }
                                            ImageButton {
                                                source: "qrc:/images/delete.png"
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
                            onClicked: settingsDialog.close()
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
}
