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
                            borderWidth: 0
                            placeholderText: "分配一个任务或提问任何问题"
                            width: parent.width - 24
                            height: 66
                        }
                        Rectangle{
                            height: 40
                            width: parent.width - 24
                            Row {
                                anchors.fill: parent
                                spacing: 4
                                DropdownSelect {
                                    id: dropdownSelectionWorkSpace
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 137
                                    height: 36
                                    model: ["workspace"]
                                    icon: "qrc:/images/folder.png"
                                    iconSize: 20
                                    currentIndex: 0
                                }
                                DropdownSelect {
                                    id: dropdownSelectionSkill
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 96
                                    height: 36
                                    model: ["技能"]
                                    icon: "qrc:/images/category.png"
                                    iconSize: 20
                                    currentIndex: 0
                                }
                                DropdownSelect {
                                    id: dropdownSelectionModel
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 137
                                    height: 36
                                    model: ["DeepSeek", "ChatGPT", "Gemini"]
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
                                        onClicked: {

                                        }
                                    }
                                    Rectangle{
                                        width: 1
                                        height: 16
                                        color: "#1F000000"
                                        anchors.verticalCenter: parent.verticalCenter
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
            Rectangle{
                id: skillSettingRec
                anchors.fill: parent
                visible: window.leftSelectedIndex === 2
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
                                inputHeight: 36
                                inputWidth: skillSettingTitleRec.width
                                icon: "qrc:/images/search.png"
                                iconSize: 16
                                placeholderText: "搜索技能"
                            }
                        }
                        CustomButton{
                            width: 80
                            height: 36
                            backgroundColor: "#0F006BFF"
                            textColor: "#006BFF"
                            borderWidth: 0
                            text: "+ 添加"
                            fontSize: 14
                            anchors.right: parent.right
                            onClicked: {

                            }
                        }
                    }
                    TabBarView{
                        id: skillSettingTaskTab
                        lineWidth: parent.width - 120
                        tabs: [ { text: "已安装", badge: 12}, { text: "技能市场" }]
                    }
                    ScrollView {
                        id: skillScrollView
                        width: parent.width - 120
                        height: skillSettingRec.height - 24 - skillSettingTitleRec.height - skillSettingTaskTab.height - 32
                        clip: true
                        visible: skillSettingTaskTab.currentIndex === 0

                        Grid {
                            id: skillGrid
                            columns: 2
                            spacing: 12
                            width: skillScrollView.width

                            property real cellWidth: (width - spacing) / 2

                            Repeater {
                                model: ListModel {
                                    ListElement { title: "深度问数"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "生信分析"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "pdf"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "note-taker"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "docx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "file-organizer"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "pptx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                    ListElement { title: "xlsx"; desc: "数据分析，图表生成，清洗数据"; icon: "qrc:/images/skillIcon.png"; enabled: true }
                                }

                                delegate: Rectangle {
                                    width: skillGrid.cellWidth
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

                                        Row{
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

                                    Switch {
                                        id: skillSwitch
                                        checked: model.enabled
                                        anchors.right: parent.right
                                        anchors.rightMargin: 20
                                        anchors.top: parent.top
                                        anchors.topMargin: 20

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: skillSwitch.toggle()
                                        }

                                        indicator: Rectangle {
                                            implicitWidth: 44
                                            implicitHeight: 22
                                            x: skillSwitch.leftPadding
                                            y: parent.height / 2 - height / 2
                                            radius: 12
                                            color: skillSwitch.checked ? "#006BFF" : "#1F000000"

                                            Behavior on color {
                                                ColorAnimation { duration: 150 }
                                            }

                                            Rectangle {
                                                x: skillSwitch.checked ? parent.width - width - 3 : 3
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
}
