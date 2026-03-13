import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Item {
    id: root

    property int selectedHour: 9
    property int selectedMinute: 0
    property string displayText: pad(selectedHour) + ":" + pad(selectedMinute)
    property color borderColor: "#E6E7EB"
    property color textColor: "#D9000000"
    property int fontSize: 14

    signal timeSelected(int hour, int minute)

    function pad(n) { return n < 10 ? "0" + n : "" + n }

    implicitWidth: 160
    implicitHeight: 40

    Rectangle {
        id: trigger
        anchors.fill: parent
        radius: 8
        border.color: root.borderColor
        border.width: 1
        color: triggerMouse.pressed ? "#14000000"
             : triggerMouse.containsMouse ? "#0A000000"
             : "transparent"

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            text: root.displayText
            font.pixelSize: root.fontSize
            font.family: "Alibaba PuHuiTi 3.0"
            color: root.textColor
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
        }

        Canvas {
            width: 16; height: 16
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "#80000000"
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                ctx.moveTo(4, 6); ctx.lineTo(8, 10); ctx.lineTo(12, 6)
                ctx.stroke()
            }
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.visible ? popup.close() : popup.open()
        }
    }

    Popup {
        id: popup
        x: 0
        width: 200
        height: 240
        padding: 0

        function calcY() {
            var globalPos = root.mapToItem(null, 0, 0)
            var windowH = root.Window.height || 800
            if (globalPos.y + root.height + 4 + 240 > windowH)
                return -244
            return root.height + 4
        }

        y: calcY()
        onAboutToShow: y = calcY()

        background: Rectangle {
            radius: 12
            color: "#FFFFFF"
            border.color: "#14000000"
            border.width: 1
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 }
        }

        contentItem: Item {
            anchors.fill: parent

            Row {
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.bottom: confirmBtn.top
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                spacing: 0

                ListView {
                    id: hourList
                    width: parent.width / 2
                    height: parent.height
                    clip: true
                    model: 24
                    currentIndex: root.selectedHour
                    highlightMoveDuration: 200
                    preferredHighlightBegin: height / 2 - 16
                    preferredHighlightEnd: height / 2 + 16
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapToItem

                    delegate: Item {
                        width: hourList.width
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: hourList.currentIndex === index ? "#0A006BFF"
                                 : hourItemMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.pad(index)
                            font.pixelSize: 14
                            font.family: "Alibaba PuHuiTi 3.0"
                            font.weight: hourList.currentIndex === index ? Font.DemiBold : Font.Normal
                            color: hourList.currentIndex === index ? "#006BFF" : "#D9000000"
                        }

                        MouseArea {
                            id: hourItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hourList.currentIndex = index
                                root.selectedHour = index
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: parent.height
                    color: "#0A000000"
                }

                ListView {
                    id: minuteList
                    width: parent.width / 2
                    height: parent.height
                    clip: true
                    model: 60
                    currentIndex: root.selectedMinute
                    highlightMoveDuration: 200
                    preferredHighlightBegin: height / 2 - 16
                    preferredHighlightEnd: height / 2 + 16
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    snapMode: ListView.SnapToItem

                    delegate: Item {
                        width: minuteList.width
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 6
                            color: minuteList.currentIndex === index ? "#0A006BFF"
                                 : minItemMouse.containsMouse ? "#0A000000"
                                 : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.pad(index)
                            font.pixelSize: 14
                            font.family: "Alibaba PuHuiTi 3.0"
                            font.weight: minuteList.currentIndex === index ? Font.DemiBold : Font.Normal
                            color: minuteList.currentIndex === index ? "#006BFF" : "#D9000000"
                        }

                        MouseArea {
                            id: minItemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                minuteList.currentIndex = index
                                root.selectedMinute = index
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: confirmBtn
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                height: 32
                radius: 6
                color: confirmMouse.pressed ? "#005CE6"
                     : confirmMouse.containsMouse ? "#1A7AFF"
                     : "#006BFF"

                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "确定"
                    font.pixelSize: 13
                    font.family: "Alibaba PuHuiTi 3.0"
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: confirmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedHour = hourList.currentIndex
                        root.selectedMinute = minuteList.currentIndex
                        root.timeSelected(root.selectedHour, root.selectedMinute)
                        popup.close()
                    }
                }
            }
        }
    }
}
