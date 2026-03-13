import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.2
import "./components"
ApplicationWindow {
    id: window
    width: 1440
    height: 800
    visible: true
    title: qsTr("MedClaw")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    property int leftSelectedIndex: 0
    Rectangle{
        id: leftContainer
        width: 280
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        color: "#F7F9FA"
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
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56
                color: "transparent"
                Column{
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
                                        source: isSelected ? "qrc:/images/leftSelectionSelected.png"
                                                           : "qrc:/images/leftSelection.png"
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
                                    onClicked: window.leftSelectedIndex = index
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

            Row{
                rightPadding: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                ImageButton{
                    id: settingBtn
                    source: "qrc:/images/setting.png"
                    onClicked: {

                    }
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
                Column{
                    id: titleCol
                    width: 840
                    spacing: 11
                    anchors.topMargin: 100
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    Label{
                        text: "MedClaw"
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
                Rectangle{
                    anchors.top: titleCol.bottom
                    anchors.topMargin: 76
                    border.color: "#40000000"
                    border.width: 1
                    radius: 20
                    height: 142
                    width: 840
                    anchors.horizontalCenter: parent.horizontalCenter
                    Column{
                        anchors.fill: parent
                        padding: 12
                        spacing: 12
                        MultiLineTextInput{
                            focusedBorderColor: "transparent"
                            backgroundColor: "transparent"
                            placeholderText: "分配一个任务或提问任何问题"
                            width: parent.width - 24
                            height: 66
                        }
                        Rectangle{
                            height: 40
                            width: parent.width - 24
                            Row {
                                anchors.fill: parent
                                spacing: 10
                                DropdownSelect {
                                    id: dropdownSelection
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 144
                                    height: 40
                                    model: ["DeepSeek", "ChatGPT", "Claude"]
                                    currentIndex: 0
                                }
                                ImageButton{
                                    id: paperclipBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/images/paperclip.png"
                                }
                                ImageButton{
                                    id: categoryBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: "qrc:/images/category.png"
                                }
                                Rectangle{
                                    width: parent.width - dropdownSelection.width - paperclipBtn.width - categoryBtn.width - sendBtnRec.width - 4 * 10
                                    height: 1
                                }
                                Rectangle{
                                    id: sendBtnRec
                                    width: 40
                                    height: 40
                                    radius: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: "#1F000000"
                                    Image{
                                        anchors.centerIn: parent
                                        source: "qrc:/images/send.png"
                                    }
                                    MouseArea{
                                        anchors.fill: parent
                                        onClicked: {
                                            $MainViewController.sendMessage()
                                        }
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
                                font.pixelSize: 16
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
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded
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
                height: dialogContent.implicitHeight + 48
                radius: 16
                color: "#FFFFFF"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {} // 阻止点击穿透关闭
                }

                Column {
                    id: dialogContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 16

                    Item {
                        width: parent.width
                        height: 48
                        Label {
                            text: qsTr("新建任务")
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: "#D9000000"
                            anchors.left: parent.left
                        }
                        ImageButton {
                            source: "qrc:/images/close.png"
                            anchors.right: parent.right
                            onClicked: newTaskDialog.close()
                        }
                        Rectangle{
                            height: 1
                            width: parent.width
                            color: "#14000000"
                            anchors.bottom: parent.bottom
                        }
                    }

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
                            borderColor: "#E6E7EB"
                            focusedBorderColor: "#006BFF"
                            backgroundColor: "#FFFFFF"
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
                            inputRadius: 8
                            borderColor: "#E6E7EB"
                            focusedBorderColor: "#006BFF"
                            backgroundColor: "#FFFFFF"
                            placeholderText: qsTr("请输入要执行的提示词")
                            fontSize: 14
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
                                borderColor: "#E6E7EB"
                                focusedBorderColor: "#006BFF"
                                backgroundColor: "#FFFFFF"
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
}
