import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.0

Item {
    id: root

    property var participants: []
    property string currentSessionKey: ""
    property bool controllerRunning: false
    signal sessionSelected(string sessionKey)

    readonly property var activeParticipant: findActiveParticipant()
    readonly property var optionParticipants: buildOptionParticipants()
    readonly property bool teamRunning: controllerRunning || hasRunningParticipant()
    readonly property string activeName: activeParticipant
        ? String(activeParticipant.agentName || activeParticipant.title
                 || activeParticipant.agentId || "Agent")
        : "Agent"

    implicitWidth: Math.min(220, Math.max(146, activeNameMetrics.width + 86))
    implicitHeight: 36

    function findActiveParticipant() {
        var list = participants || []
        var key = String(currentSessionKey || "")
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].sessionKey || "") === key)
                return list[i]
        }
        for (var j = 0; j < list.length; j++) {
            if (list[j].isController)
                return list[j]
        }
        return list.length > 0 ? list[0] : null
    }

    function buildOptionParticipants() {
        var list = participants || []
        var result = []
        for (var i = 0; i < list.length; i++)
            result.push(list[i])
        return result
    }

    function isActiveParticipant(participant) {
        var active = activeParticipant
        if (!participant || !active)
            return false
        return String(participant.sessionKey || "") === String(active.sessionKey || "")
            && String(participant.agentId || "") === String(active.agentId || "")
    }

    function statusKind(participant) {
        if (!participant)
            return "pending"
        if (participant.isController)
            return teamRunning ? "running" : "complete"
        if (participant.isPending)
            return "pending"
        if (participant.isRunning)
            return "running"
        return "complete"
    }

    function hasRunningParticipant() {
        var list = participants || []
        for (var i = 0; i < list.length; i++) {
            if (!list[i].isController && list[i].isRunning)
                return true
        }
        return false
    }

    function participantIdentity(participant) {
        return participant && participant.identity ? participant.identity : ({})
    }

    function participantEmoji(participant) {
        if (!participant)
            return ""
        var identity = participantIdentity(participant)
        return String(identity.emoji || participant.emoji || "")
    }

    function avatarSource(participant) {
        if (!participant)
            return "qrc:/images/expert/1.png"
        var identity = participantIdentity(participant)
        var avatar = String(identity.avatar || participant.avatar || "")
        if (/^(qrc:|file:|https?:|data:)/i.test(avatar))
            return avatar

        var agentId = String(participant.agentId || "")
        var orchestrators = [
            "paper-orchestrator", "data-orchestrator", "omics-orchestrator",
            "mi-orchestrator", "research-orchestrator", "forensics-orchestrator"
        ]
        if (orchestrators.indexOf(agentId) >= 0)
            return "qrc:/images/expert/" + agentId + ".png"

        var hash = 0
        for (var i = 0; i < agentId.length; i++)
            hash = ((hash * 31) + agentId.charCodeAt(i)) & 0x7fffffff
        return "qrc:/images/expert/" + ((hash % 8) + 1) + ".png"
    }

    Rectangle {
        id: trigger
        anchors.fill: parent
        radius: 8
        color: triggerMouse.pressed ? "#14000000"
             : triggerMouse.containsMouse || participantPopup.visible ? "#0A000000"
             : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7

            Item {
                width: 24
                height: 24
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: "#EEF2F6"
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.avatarSource(root.activeParticipant)
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(32, 32)
                        visible: root.participantEmoji(root.activeParticipant).length === 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.participantEmoji(root.activeParticipant)
                        visible: text.length > 0
                        font.pixelSize: 15
                    }
                }
            }

            Text {
                width: Math.max(0, parent.width - 24 - 16 - 12 - parent.spacing * 3)
                text: root.activeName
                elide: Text.ElideRight
                font.pixelSize: 14
                font.family: "Alibaba PuHuiTi 3.0"
                color: "#D9000000"
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusIndicator {
                status: root.statusKind(root.activeParticipant)
                anchors.verticalCenter: parent.verticalCenter
            }

            Canvas {
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                rotation: participantPopup.visible ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = "#73000000"
                    ctx.lineWidth = 1.4
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    ctx.moveTo(3, 4.5)
                    ctx.lineTo(6, 7.5)
                    ctx.lineTo(9, 4.5)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: participantPopup.visible ? participantPopup.close()
                                                : participantPopup.open()
        }
    }

    Popup {
        id: participantPopup
        x: 0
        y: -height - 6
        width: Math.max(root.width, 232)
        height: Math.min(280, root.optionParticipants.length * 44 + 16)
        padding: 8
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

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
                verticalOffset: 4
                color: "#1A000000"
            }
        }

        contentItem: ListView {
            id: participantList
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.optionParticipants
            spacing: 0
            ScrollBar.vertical: ScrollBar {
                policy: participantList.contentHeight > participantList.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Rectangle {
                id: participantRow
                readonly property bool selected: root.isActiveParticipant(modelData)
                width: participantList.width
                height: 44
                radius: 6
                color: rowMouse.pressed ? "#14000000"
                     : selected ? "#0A006BFF"
                     : rowMouse.containsMouse ? "#0A000000"
                     : "transparent"

                Behavior on color { ColorAnimation { duration: 100 } }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: "#EEF2F6"
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            anchors.fill: parent
                            source: root.avatarSource(modelData)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(34, 34)
                            visible: root.participantEmoji(modelData).length === 0
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.participantEmoji(modelData)
                            visible: text.length > 0
                            font.pixelSize: 16
                        }
                    }

                    Text {
                        width: Math.max(0, parent.width - 26 - 16 - parent.spacing * 2)
                        text: modelData.agentName || modelData.title || modelData.agentId || "Agent"
                        elide: Text.ElideRight
                        font.pixelSize: 14
                        font.family: "Alibaba PuHuiTi 3.0"
                        color: "#D9000000"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StatusIndicator {
                        status: root.statusKind(modelData)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: modelData.isPending ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.isPending)
                            return
                        participantPopup.close()
                        root.sessionSelected(modelData.sessionKey || "")
                    }
                }
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 140; easing.type: Easing.OutCubic }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 }
        }
    }

    TextMetrics {
        id: activeNameMetrics
        text: root.activeName
        font.pixelSize: 14
        font.family: "Alibaba PuHuiTi 3.0"
    }

    component StatusIndicator: Item {
        property string status: "pending"
        width: 16
        height: 16

        Rectangle {
            width: 6
            height: 6
            radius: 3
            anchors.centerIn: parent
            color: "#D8DADF"
            visible: parent.status === "pending"
        }

        Canvas {
            anchors.fill: parent
            visible: parent.status === "complete"
            onVisibleChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#28B446"
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(3.2, 8.2)
                ctx.lineTo(6.5, 11.3)
                ctx.lineTo(12.8, 4.8)
                ctx.stroke()
            }
        }

        Canvas {
            id: spinner
            anchors.fill: parent
            visible: parent.status === "running"
            onVisibleChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#3387FF"
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.arc(8, 8, 5.2, -Math.PI * 0.25, Math.PI * 1.25, false)
                ctx.stroke()
            }
            RotationAnimation on rotation {
                running: spinner.visible
                from: 0
                to: 360
                duration: 850
                loops: Animation.Infinite
            }
        }
    }
}
