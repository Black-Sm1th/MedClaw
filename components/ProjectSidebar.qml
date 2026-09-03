import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property var projects: []
    property string currentSessionKey: ""
    property var sessionTitleFormatter: null
    signal newProjectRequested()
    signal newChatRequested(string projectId)
    signal moreRequested(string projectId, string title, string workspace,
                         real sceneX, real sceneY)
    signal sessionRequested(string sessionId)
    signal sessionMoreRequested(string sessionId, string title, string workspace,
                                bool pinned, real sceneX, real sceneY)

    implicitHeight: contentColumn.implicitHeight

    function sessionTitle(session) {
        if (root.sessionTitleFormatter)
            return String(root.sessionTitleFormatter(session) || "")
        var title = String((session && session.title) || "").trim()
        return title.length > 0 ? title : qsTr("新对话")
    }

    Column {
        id: contentColumn
        width: parent.width
        spacing: 2

        Rectangle {
            visible: !root.projects || root.projects.length === 0
            width: parent.width
            height: visible ? 36 : 0
            radius: 8
            color: emptyProjectMouse.pressed ? "#D9DCE1"
                 : emptyProjectMouse.containsMouse ? "#E6E7EB"
                 : "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Label {
                    text: "+"
                    font.pixelSize: 16
                    color: emptyProjectMouse.containsMouse ? "#D9000000" : "#73000000"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    text: qsTr("新建项目")
                    font.pixelSize: 14
                    color: emptyProjectMouse.containsMouse ? "#D9000000" : "#73000000"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: emptyProjectMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.newProjectRequested()
            }
        }

        Repeater {
            model: root.projects || []

            delegate: Item {
                id: projectDelegate
                width: contentColumn.width
                height: projectRow.height + (expanded ? sessionColumn.implicitHeight : 0)
                property bool expanded: true
                property var projectSessions: modelData.sessions || []
                property bool hovered: projectMouse.containsMouse
                                       || moreMouse.containsMouse
                                       || newChatMouse.containsMouse

                Rectangle {
                    id: projectRow
                    width: parent.width
                    height: 36
                    radius: 7
                    color: projectDelegate.hovered ? "#0A000000" : "transparent"

                    Label {
                        id: disclosure
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u203a"
                        rotation: projectDelegate.expanded ? 90 : 0
                        font.pixelSize: 18
                        color: "#73000000"
                        Behavior on rotation { NumberAnimation { duration: 120 } }
                    }

                    Label {
                        id: projectTitleLabel
                        anchors.left: disclosure.right
                        anchors.leftMargin: 8
                        anchors.right: projectActions.visible ? projectActions.left : parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.title || qsTr("未命名项目")
                        font.pixelSize: 14
                        color: "#D9000000"
                        elide: Text.ElideRight

                        ToolTip {
                            visible: projectMouse.containsMouse
                                     && projectTitleLabel.truncated
                            text: projectTitleLabel.text
                            delay: 500
                            x: 0
                            y: -height - 4
                            width: Math.min(implicitContentWidth + 20, 260)
                            background: Rectangle {
                                color: "#A6000000"
                                radius: 4
                            }
                            contentItem: Text {
                                text: projectTitleLabel.text
                                font.pixelSize: 14
                                color: "#FFFFFF"
                                font.family: "Alibaba PuHuiTi 3.0"
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Row {
                        id: projectActions
                        opacity: projectDelegate.hovered ? 1 : 0
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        z: 3

                        Behavior on opacity { NumberAnimation { duration: 80 } }

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: moreMouse.containsMouse ? "#10000000" : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: "qrc:/images/more.png"
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: moreMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var point = parent.mapToItem(null, 0, parent.height + 4)
                                    root.moreRequested(String(modelData.project_id || ""),
                                                       String(modelData.title || ""),
                                                       String(modelData.workspace || ""),
                                                       point.x, point.y)
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 6
                            color: newChatMouse.containsMouse ? "#10000000" : "transparent"
                            Image {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: "qrc:/images/chatNew.png"
                                fillMode: Image.PreserveAspectFit
                            }
                            MouseArea {
                                id: newChatMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.newChatRequested(String(modelData.project_id || ""))
                            }
                        }
                    }

                    MouseArea {
                        id: projectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: projectDelegate.expanded = !projectDelegate.expanded
                    }
                }

                Column {
                    id: sessionColumn
                    visible: projectDelegate.expanded
                    anchors.top: projectRow.bottom
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: projectDelegate.projectSessions
                        delegate: Rectangle {
                            id: projectSessionRow
                            width: sessionColumn.width
                            height: 55
                            radius: 8
                            color: String(modelData.session_id || "") === root.currentSessionKey
                                   ? "#E6E7EB"
                                   : projectSessionRow.hovered ? "#0A000000" : "transparent"
                            property bool hovered: sessionMouse.containsMouse
                                                   || projectSessionStatus.moreHovered

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 30
                                anchors.right: projectSessionStatus.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: 4

                                    Label {
                                        id: projectSessionCronTag
                                        visible: String(modelData.session_id || "").indexOf(":cron:") >= 0
                                        text: qsTr("[定时]")
                                        font.pixelSize: 14
                                        color: "#73000000"
                                        height: 21
                                    }

                                    Label {
                                        text: root.sessionTitle(modelData)
                                        font.pixelSize: 14
                                        color: "#D9000000"
                                        height: 21
                                        elide: Text.ElideRight
                                        width: projectSessionCronTag.visible
                                               ? Math.max(0, parent.width
                                                          - projectSessionCronTag.width
                                                          - parent.spacing)
                                               : parent.width
                                    }
                                }

                                Label {
                                    text: {
                                        var ms = Number(modelData.updated_at
                                                        || modelData.created_at || 0)
                                        if (!ms || ms <= 0)
                                            return ""
                                        return Qt.formatDateTime(new Date(ms),
                                                                 "yyyy-MM-dd hh:mm")
                                    }
                                    font.pixelSize: 12
                                    color: "#73000000"
                                }
                            }

                            TaskSessionStatusIndicator {
                                id: projectSessionStatus
                                running: modelData.isRunning || false
                                hovered: projectSessionRow.hovered
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                z: 2
                                onMoreClicked: function(sceneX, sceneY) {
                                    root.sessionMoreRequested(
                                                String(modelData.session_id || ""),
                                                root.sessionTitle(modelData),
                                                String(modelData.workspace || ""),
                                                modelData.pinned || false,
                                                sceneX, sceneY)
                                }
                            }

                            MouseArea {
                                id: sessionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sessionRequested(String(modelData.session_id || ""))
                            }
                        }
                    }
                }
            }
        }
    }
}
