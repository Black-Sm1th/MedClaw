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
    title: qsTr("AetherMedClaw_Desk")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    property int leftSelectedIndex: 0
    property bool sidebarCollapsed: false
    // 默认 WebSocket 服务器地址（与 TestChatClient.qml 保持一致）
    property string wsServerUrl: "ws://127.0.0.1:18789"

    // 启动时自动连接 WebSocket 服务器
    function loadLocalMessages(filePath, displayName, sessionId) {
        var msgs = sessionReader.readSessionMessages(filePath)
        chatModel.clear()
        window.isNewTask = false
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
        if (sessionId && wsClient.connectionState === 3) {
            wsClient.setCurrentSessionKey(sessionId)
        }
    }

    Component.onCompleted: {
        wsClient.connectToServer(wsServerUrl)
        sessionReader.scanSessions()
        var list = sessionReader.sessionList
        for (var i = 0; i < list.length; i++) {
            if (list[i].isActive) {
                taskRecordListView.selectedFilePath = list[i].filePath
                loadLocalMessages(list[i].filePath, list[i].displayName, list[i].sessionId || "")
                break
            }
        }
    }
    Connections{
        target: wsClient
        function onConnectionStateChanged(){
            if(wsClient.connectionState === 3){
                wsClient.refreshSkills()
            }
        }
        function onSessionCreated(){
            sessionReader.scanSessions()
        }
    }
    Rectangle{
        id: leftContainer
        width: window.sidebarCollapsed ? 0 : 280
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
                    onClicked: window.sidebarCollapsed = !window.sidebarCollapsed
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56
                color: "transparent"
                Column{
                    id: menuColumn
                    spacing: 12
                    width: parent.width
                    Column{
                        spacing: 4
                        width: parent.width
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
                                                return "qrc:/images/clock.png"
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
                                        if (index === 0) {
                                            chatModel.clear()
                                            taskRecordListView.selectedFilePath = ""
                                            window.isNewTask = true
                                            if (wsClient.connectionState === 3)
                                                wsClient.createNewSession()
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                Rectangle {
                    id: taskSeparator
                    anchors.top: menuColumn.bottom
                    anchors.topMargin: 16
                    width: parent.width
                    height: 1
                    color: "#14000000"
                }

                Label {
                    id: taskRecordTitle
                    anchors.top: taskSeparator.bottom
                    anchors.topMargin: 12
                    text: "任务记录"
                    font.pixelSize: 12
                    color: "#80000000"
                }

                ListView {
                    id: taskRecordListView
                    anchors.top: taskRecordTitle.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    model: sessionReader.sessionList
                    spacing: 0

                    property string selectedFilePath: ""

                    delegate: Rectangle {
                        width: taskRecordListView.width
                        height: taskItemCol.implicitHeight + 20
                        radius: 8
                        color: {
                            if (modelData.filePath === taskRecordListView.selectedFilePath)
                                return "#E6E7EB"
                            return taskItemMouse.containsMouse ? "#0A000000" : "transparent"
                        }

                        Column {
                            id: taskItemCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 4

                            Label {
                                width: parent.width
                                text: {
                                    var name = modelData.preview
                                              || modelData.displayName
                                              || "未命名任务"
                                    if (modelData.isActive)
                                        return "[定时] " + name
                                    return name
                                }
                                font.pixelSize: 14
                                color: "#D9000000"
                                elide: Text.ElideRight
                            }

                            Row {
                                spacing: 6

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: "#006BFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: modelData.isActive
                                }

                                Label {
                                    text: {
                                        var ts = modelData.resetTime || modelData.timestamp || ""
                                        if (ts && ts.length >= 16) {
                                            return ts.substring(11, 16)
                                        }
                                        return Qt.formatTime(new Date(), "HH:mm")
                                    }
                                    font.pixelSize: 12
                                    color: "#80000000"
                                }
                            }
                        }

                        MouseArea {
                            id: taskItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                taskRecordListView.selectedFilePath = modelData.filePath
                                loadLocalMessages(modelData.filePath, modelData.displayName, modelData.sessionId || "")
                                window.leftSelectedIndex = 0
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
                visible: !window.sidebarCollapsed
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
            Row {
                leftPadding: 16
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                visible: window.sidebarCollapsed

                opacity: window.sidebarCollapsed ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                Image {
                    source: "qrc:/images/titleIcon.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                ImageButton {
                    source: "qrc:/images/sidebarMinimalistic.png"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: window.sidebarCollapsed = false
                }
                ImageButton {
                    source: "qrc:/images/chatLine.png"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        window.leftSelectedIndex = 0
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
                visible: window.leftSelectedIndex === 0
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
                    anchors.topMargin: 100
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    Label{
                        text: "AetherMedClaw_Desk"
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
                            if (msgType === "toolCall") return toolCallCard.height
                            if (msgType === "toolResult") return toolResCard.height
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
                                width: Math.min(bubbleText.implicitWidth + 32, chatBubble.width)
                                height: bubbleText.implicitHeight + 24
                                radius: 12
                                color: chatBubble.isUser ? "#EBEDF0" : "transparent"

                                Text {
                                    id: bubbleText
                                    text: content
                                    width: Math.min(implicitWidth, chatBubble.width * 0.75 - 32)
                                    wrapMode: Text.Wrap
                                    font.pixelSize: 16
                                    anchors.centerIn: parent
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    color: chatBubble.isUser ? "#E5000000" : "#D9000000"
                                    textFormat: Text.MarkdownText
                                }
                            }
                        }

                        Rectangle {
                            id: toolCallCard
                            visible: msgType === "toolCall"
                            width: parent.width
                            height: visible ? toolCallInner.height + 8 : 0
                            color: "transparent"

                            Rectangle {
                                id: toolCallInner
                                width: parent.width
                                anchors.top: parent.top
                                height: toolCallCol.implicitHeight + 16
                                radius: 10
                                color: "#FFF8E1"
                                border.color: "#FFE082"
                                border.width: 1

                                Column {
                                    id: toolCallCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Row {
                                        spacing: 6
                                        Text { text: "\u2699"; font.pixelSize: 14 }
                                        Text {
                                            text: qsTr("工具调用: ") + toolName
                                            font.pixelSize: 13
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            font.bold: true
                                            color: "#F57F17"
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: toolResCard
                            visible: msgType === "toolResult"
                            width: parent.width
                            height: visible ? toolResInner.height + 8 : 0
                            color: "transparent"

                            Rectangle {
                                id: toolResInner
                                width: parent.width
                                anchors.top: parent.top
                                height: toolResCol.implicitHeight + 16
                                radius: 10
                                color: isError ? "#FFEBEE" : "#E8F5E9"
                                border.color: isError ? "#EF9A9A" : "#A5D6A7"
                                border.width: 1

                                Column {
                                    id: toolResCol
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 4

                                    Row {
                                        spacing: 6
                                        Text { text: isError ? "\u274C" : "\u2705"; font.pixelSize: 14 }
                                        Text {
                                            text: (isError ? qsTr("错误: ") : qsTr("结果: ")) + toolName
                                            font.pixelSize: 13
                                            font.family: "Alibaba PuHuiTi 3.0"
                                            font.bold: true
                                            color: isError ? "#C62828" : "#2E7D32"
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: content || ""
                                        wrapMode: Text.Wrap
                                        font.pixelSize: 12
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        color: isError ? "#B71C1C" : "#33691E"
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
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
                                            Item { width: 1; height: 8 }
                                            Rectangle {
                                                width: wsPopup.width - 16
                                                height: 1
                                                color: "#EBEDF0"
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }

                                            Item { width: 1; height: 8 }

                                            Text {
                                                text: qsTr("最近")
                                                font.pixelSize: 12
                                                font.family: "Alibaba PuHuiTi 3.0"
                                                color: "#73000000"
                                                leftPadding: 12
                                            }

                                            Item { width: 1; height: 8 }

                                            Repeater {
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
                        CustomButton{
                            width: 80
                            height: 36
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 新建"
                            fontSize: 14
                            anchors.right: parent.right
                            onClicked: newTaskDialog.open()
                        }
                    }
                    TabBarView{
                        id: scheduledTaskTab
                        lineWidth: parent.width - 120
                        tabs: [ { text: "任务"}, { text: "历史" }]
                    }
                    ScrollView {
                        id: scheduledTaskScrollView
                        width: parent.width
                        height: parent.height - 32 - scheduledTaskTitleRec.height - scheduledTaskTab.height - 24
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        Column{
                            spacing: 12
                            width: parent.width
                            Repeater{
                                model: ListModel {
                                    ListElement { title: "标题标题标题"; repeat: "不重复"; time: "2026/3/13 09:00"; enabled: true }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                    ListElement { title: "每日摘要推送"; repeat: "每天"; time: "2026/3/14 08:00"; enabled: false }
                                }
                                delegate: Rectangle {
                                    width: scheduledTaskScrollView.width - 120
                                    height: 76
                                    radius: 8
                                    color: "#F7F9FA"

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4

                                        Label {
                                            text: model.title
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            color: "#D9000000"
                                        }
                                        Row {
                                            spacing: 8
                                            Label {
                                                text: model.repeat
                                                font.pixelSize: 16
                                                color: "#73000000"
                                            }
                                            Label {
                                                text: model.time
                                                font.pixelSize: 16
                                                color: "#73000000"
                                            }
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 40
                                        height: 22
                                        ImageButton {
                                            source: "qrc:/images/more.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Switch {
                                            id: taskSwitch
                                            checked: model.enabled
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: taskSwitch.toggle()
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
                                placeholderText: "搜索技能"
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
                                mcpServiceDialog.isEdit = false
                                mcpServiceDialog.open()
                            }
                        }
                    }
                    TabBarView {
                        id: mcpTab
                        lineWidth: parent.width - 120
                        tabs: [{ text: "已安装", badge: 13 }]
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

                            Repeater {
                                model: ListModel {
                                    ListElement { title: "Tavily"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "GitHub"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "GitLab"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Context7"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "Google Drive"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                }

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
                                                mcpServiceDialog.isEdit = true
                                                mcpServiceDialog.open()
                                            }
                                        }
                                        ImageButton {
                                            source: "qrc:/images/delete.png"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                        }
                                        Rectangle {
                                            height: 16
                                            width: 1
                                            color: "#1F000000"
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: mcpCardHover.hovered
                                        }
                                        Switch {
                                            id: mcpSwitch
                                            checked: model.enabled
                                            anchors.verticalCenter: parent.verticalCenter
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: mcpSwitch.toggle()
                                            }
                                            indicator: Rectangle {
                                                implicitWidth: 44
                                                implicitHeight: 22
                                                x: mcpSwitch.leftPadding
                                                y: parent.height / 2 - height / 2
                                                radius: 12
                                                color: mcpSwitch.checked ? "#006BFF" : "#1F000000"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Rectangle {
                                                    x: mcpSwitch.checked ? parent.width - width - 3 : 3
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
                        text: qsTr("新建任务")
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
                                width: (parent.width - 24) / 3
                                height: 40
                                model: ["不重复", "每天", "每周"]
                                currentIndex: 0
                                borderColor: "#E6E7EB"
                                borderWidth: 1
                                alignment:Qt.AlignLeft
                            }
                            DatePicker {
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                            TimePicker {
                                width: (parent.width - 24) / 3
                                height: 40
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: qsTr("工作目录")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            SingleLineTextInput {
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
                                onClicked: {

                                }
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
                            text: qsTr("重新生成")
                            fontSize: 14
                            onClicked: newTaskDialog.close()
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
                            onClicked: newTaskDialog.close()
                        }
                    }
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
