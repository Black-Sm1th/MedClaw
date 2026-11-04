import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects

/**
 * ask_user 提问卡（Figma 5305-58906）。
 *
 * 为什么要画在 QML 层：聊天正文是 WebEngineView，它的底边停在输入框上方，
 * 页面里再怎么 position:fixed 也只能贴到 WebView 自己的底边，
 * 永远盖不住下面那个 QML 输入框 —— 这就是之前"两个框同时存在"的根因。
 *
 * 一张卡片承载多个待答问题：右上角 ‹ 1/2 › 翻页；✕ 表示跳过当前问题。
 * 数值取自设计稿：卡片 798×260 r8、描边 rgba(0,0,0,.08)、shadow(0,10,blur20)，
 * 内边距 12/16，子块间距 8；选项行 36 高 r8 描边 #E6E7EB，序号 Poppins 14 w600
 * #006BFF；输入行 36 高、铅笔 16×16 #006BFF；发送键 32×32 圆形 #006BFF 白箭头。
 */
Item {
    id: root

    /// 待答问题列表：每项 { questionId, questionText, questionOptions, questionMulti, questionAllowText }
    property var questions: []
    property int currentIndex: 0
    /// 每个问题各自的草稿 { id: { selected: [], text: "" } }
    property var drafts: ({})

    signal answered(string id, string answer)
    signal skipped(string id)

    readonly property var activeQuestion: (questions.length > 0 && currentIndex >= 0
                                   && currentIndex < questions.length)
                                  ? questions[currentIndex] : null
    readonly property string activeId: activeQuestion ? String(activeQuestion.questionId || "") : ""
    readonly property var activeOptions: {
        if (!activeQuestion)
            return []
        var list = activeQuestion.questionOptions
        return (list && list.length !== undefined) ? list : []
    }
    readonly property bool activeMulti: activeQuestion ? activeQuestion.questionMulti === true : false
    readonly property bool activeAllowText: activeQuestion ? activeQuestion.questionAllowText !== false : true

    readonly property var activeDraft: {
        var d = drafts[activeId]
        return d ? d : { selected: [], text: "" }
    }
    readonly property bool canSend: {
        var d = activeDraft
        var hasSel = d.selected && d.selected.length > 0
        var hasText = String(d.text || "").trim().length > 0
        return hasSel || hasText
    }
    /// 输入框里有没有内容（只有空白算没有）
    readonly property bool draftHasText: String(activeDraft.text || "").trim().length > 0
    /// 输入框空着才显示「跳过」；一打字就让位给发送键
    readonly property bool skipVisible: !draftHasText

    implicitWidth: 798
    implicitHeight: body.implicitHeight + 24

    function optionLabel(option) {
        if (option === null || option === undefined)
            return ""
        if (typeof option === "string")
            return option
        return String(option.label || "")
    }

    function isSelected(label) {
        var sel = activeDraft.selected || []
        return sel.indexOf(label) >= 0
    }

    function cloneDrafts(dropId) {
        var copy = {}
        for (var key in drafts) {
            if (dropId !== undefined && key === dropId)
                continue
            copy[key] = drafts[key]
        }
        return copy
    }

    function setDraft(next) {
        var copy = cloneDrafts(-1)
        copy[activeId] = next
        drafts = copy
    }

    function toggleOption(label) {
        if (!activeId)
            return
        var d = activeDraft
        var sel = (d.selected ? d.selected.slice(0) : [])
        if (activeMulti) {
            var at = sel.indexOf(label)
            if (at >= 0)
                sel.splice(at, 1)
            else
                sel.push(label)
        } else {
            sel = [label]
        }
        setDraft({ selected: sel, text: d.text || "" })
    }

    function setText(value) {
        if (!activeId)
            return
        var d = activeDraft
        setDraft({ selected: d.selected ? d.selected.slice(0) : [], text: String(value || "") })
    }

    function submit() {
        if (!activeId || !canSend)
            return
        var d = activeDraft
        var parts = d.selected ? d.selected.slice(0) : []
        var typed = String(d.text || "").trim()
        if (typed)
            parts.push(typed)
        if (parts.length === 0)
            return
        var id = activeId
        drafts = cloneDrafts(id)
        answered(id, parts.join("、"))
    }

    function skip() {
        if (!activeId)
            return
        var id = activeId
        drafts = cloneDrafts(id)
        skipped(id)
    }

    function goPrev() {
        if (currentIndex > 0)
            currentIndex -= 1
    }

    function goNext() {
        if (currentIndex + 1 < questions.length)
            currentIndex += 1
    }

    // 问题列表变化（答完一个就少一个）后把页码夹回合法范围
    onQuestionsChanged: {
        if (currentIndex >= questions.length)
            currentIndex = Math.max(0, questions.length - 1)
        if (currentIndex < 0)
            currentIndex = 0
    }

    DropShadow {
        anchors.fill: card
        source: card
        horizontalOffset: 0
        verticalOffset: 10
        radius: 20
        samples: 41
        color: "#0F000000"
        transparentBorder: true
    }

    Rectangle {
        id: card

        anchors.fill: parent
        radius: 8
        color: "#FFFFFF"
        border.width: 1
        border.color: "#14000000"
    }

    Column {
        id: body

        x: 16
        y: 12
        width: parent.width - 32
        spacing: 8

        // ── 标题行：问题文本 + 翻页 + 关闭 ──
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.right: pagerRow.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.activeQuestion ? String(root.activeQuestion.questionText || "") : ""
                color: "#D9000000"
                font.family: "Alibaba PuHuiTi 3.0"
                font.pixelSize: 16
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Row {
                id: pagerRow

                anchors.right: closeButton.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: root.questions.length > 1

                Item {
                    width: 24
                    height: 24

                    Canvas {
                        anchors.fill: parent
                        opacity: root.currentIndex > 0 ? 1 : 0

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#73000000"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(14.5, 6.5)
                            ctx.lineTo(9, 12)
                            ctx.lineTo(14.5, 17.5)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.currentIndex > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.goPrev()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.currentIndex + 1) + " / " + root.questions.length
                    color: "#40000000"
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 14
                    font.weight: Font.Normal
                }

                Item {
                    width: 24
                    height: 24

                    Canvas {
                        anchors.fill: parent
                        opacity: root.currentIndex + 1 < root.questions.length ? 1 : 0

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.strokeStyle = "#73000000"
                            ctx.lineWidth = 1.5
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(9.5, 6.5)
                            ctx.lineTo(15, 12)
                            ctx.lineTo(9.5, 17.5)
                            ctx.stroke()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.currentIndex + 1 < root.questions.length
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.goNext()
                    }
                }
            }

            Rectangle {
                id: closeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 8
                color: closeMouse.containsMouse ? "#0A000000" : "transparent"

                Canvas {
                    anchors.centerIn: parent
                    width: 20
                    height: 20

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = "#D9000000"
                        ctx.lineWidth = 1.4
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.moveTo(5, 5)
                        ctx.lineTo(15, 15)
                        ctx.moveTo(15, 5)
                        ctx.lineTo(5, 15)
                        ctx.stroke()
                    }
                }

                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.skip()
                }
            }
        }

        // ── 选项列表 ──
        ListView {
            id: optionList

            width: parent.width
            // 高度吸附到整行（36 + 8 间距），最多 4 行；再多就滚动。
            // 设计稿固定 152 会正好截断第 4 行，看起来像是坏了。
            height: Math.min(contentHeight, 36 * 4 + 8 * 3)
            visible: root.activeOptions.length > 0
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: root.activeOptions

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: optionRow

                required property int index
                required property var modelData

                readonly property string label: root.optionLabel(modelData)
                readonly property bool selected: root.isSelected(label)

                width: optionList.width
                height: 36
                radius: 8
                color: selected ? "#F2F7FF" : (optionMouse.containsMouse ? "#F7F9FA" : "#FFFFFF")
                border.width: 1
                border.color: selected ? "#006BFF" : "#E6E7EB"

                // 单选：蓝序号（Poppins 14 w600 #006BFF）
                Text {
                    id: optionIndex

                    visible: !root.activeMulti
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(optionRow.index + 1)
                    color: "#006BFF"
                    font.family: "Poppins, Alibaba PuHuiTi 3.0"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                // 多选：复选框（Figma 5305-59218）。槽位 24×24，方块 20×20 r5；
                // 未选白底 + 1px 黑 @12% 描边，选中蓝底 + 白勾。
                Item {
                    id: checkSlot

                    visible: root.activeMulti
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24

                    Rectangle {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 5
                        color: optionRow.selected ? "#006BFF" : "#FFFFFF"
                        border.width: optionRow.selected ? 0 : 1
                        border.color: "#1F000000"

                        Canvas {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            visible: optionRow.selected

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.strokeStyle = "#FFFFFF"
                                ctx.lineWidth = 1.6
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.beginPath()
                                ctx.moveTo(1.5, 6.2)
                                ctx.lineTo(4.6, 9.3)
                                ctx.lineTo(10.5, 2.8)
                                ctx.stroke()
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // 起点留给序号/复选框，宽度撑到行尾（只锚右边界会让文字贴右）
                    x: root.activeMulti
                       ? checkSlot.x + checkSlot.width + 4
                       : optionIndex.x + optionIndex.width + 8
                    width: parent.width - x - 8
                    text: optionRow.label
                    color: "#D9000000"
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 16
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleOption(optionRow.label)
                }
            }
        }

        // ── 输入行 + 跳过 + 发送 ──
        // 「跳过」只在输入框空着时出现：一旦开始打字，这个位置让给发送键，
        // 避免用户手上有明确答案时还看得见"放弃作答"的入口。
        Item {
            width: parent.width
            height: 36

            Rectangle {
                id: inputBox

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // 输入框让出右侧：发送键 32 + 间距 8，跳过可见时再让出 56 + 8
                width: parent.width - 32 - 8 - (root.skipVisible ? 56 + 8 : 0)
                visible: root.activeAllowText
                radius: 8
                color: "#FFFFFF"
                border.width: 1
                border.color: "#E6E7EB"

                Canvas {
                    id: pencilIcon

                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = "#006BFF"
                        ctx.lineWidth = 1.4
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        ctx.moveTo(11.2, 2.3)
                        ctx.lineTo(13.7, 4.8)
                        ctx.moveTo(3, 13)
                        ctx.lineTo(3.5, 10.4)
                        ctx.lineTo(10.7, 3.2)
                        ctx.lineTo(12.8, 5.3)
                        ctx.lineTo(5.6, 12.5)
                        ctx.closePath()
                        ctx.stroke()
                    }
                }

                TextInput {
                    id: inputField

                    anchors.left: pencilIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.activeDraft.text || ""
                    color: "#D9000000"
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 16
                    selectByMouse: true
                    clip: true
                    onTextEdited: root.setText(text)
                    onAccepted: root.submit()
                }

                Text {
                    anchors.left: inputField.left
                    anchors.right: inputField.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: inputField.text.length === 0
                    text: root.activeOptions.length > 0 ? qsTr("其他 / 自己输入") : qsTr("输入你的回答")
                    color: "#40000000"
                    font.family: inputField.font.family
                    font.pixelSize: inputField.font.pixelSize
                    elide: Text.ElideRight
                }
            }

            // 「跳过」胶囊：输入框为空时才出现，样式取自设计稿
            // （56×32、圆角 111、描边 #EBEDF0、14px）
            Rectangle {
                id: skipButton

                anchors.right: sendButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 32
                radius: 111
                color: skipMouse.containsMouse ? "#F7F9FA" : "transparent"
                border.width: 1
                border.color: "#EBEDF0"
                visible: root.skipVisible

                Text {
                    anchors.centerIn: parent
                    text: qsTr("跳过")
                    color: "#D9000000"
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 14
                }

                MouseArea {
                    id: skipMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.skip()
                }
            }

            Rectangle {
                id: sendButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                radius: 16
                color: "#006BFF"
                opacity: root.canSend ? 1 : 0.4

                Canvas {
                    anchors.centerIn: parent
                    width: 16
                    height: 16

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = "#FFFFFF"
                        ctx.lineWidth = 1.4
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        ctx.moveTo(3, 8)
                        ctx.lineTo(12, 8)
                        ctx.moveTo(8.5, 4.5)
                        ctx.lineTo(12, 8)
                        ctx.lineTo(8.5, 11.5)
                        ctx.stroke()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.canSend
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.submit()
                }
            }
        }
    }
}
