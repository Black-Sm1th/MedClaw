import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Item {
    id: root

    property int selectedYear: new Date().getFullYear()
    property int selectedMonth: new Date().getMonth() + 1
    property int selectedDay: new Date().getDate()
    property string displayText: selectedYear + "/" + selectedMonth + "/" + selectedDay
    property color borderColor: "#E6E7EB"
    property color textColor: "#D9000000"
    property color placeholderColor: "#80000000"
    property string placeholder: "年/月/日"
    property int fontSize: 14

    signal dateSelected(int year, int month, int day)

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

    property int viewYear: selectedYear
    property int viewMonth: selectedMonth

    function daysInMonth(year, month) {
        return new Date(year, month, 0).getDate()
    }

    function firstDayOfWeek(year, month) {
        var d = new Date(year, month - 1, 1).getDay()
        return d === 0 ? 7 : d
    }

    function buildDayModel() {
        var list = []
        var total = daysInMonth(viewYear, viewMonth)
        var offset = firstDayOfWeek(viewYear, viewMonth) - 1
        for (var i = 0; i < offset; i++) list.push(-1)
        for (var d = 1; d <= total; d++) list.push(d)
        return list
    }

    Popup {
        id: popup
        x: 0
        width: 280
        padding: 12

        function calcY() {
            var globalPos = root.mapToItem(null, 0, 0)
            var windowH = root.Window.height || 800
            var popupH = popup.implicitHeight > 0 ? popup.implicitHeight : 320
            if (globalPos.y + root.height + 4 + popupH > windowH)
                return -popupH - 4
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

        contentItem: Column {
            spacing: 8

            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: prevYearMouse.containsMouse ? "#0A000000" : "transparent"
                        Text { anchors.centerIn: parent; text: "«"; font.pixelSize: 14; color: "#80000000" }
                        MouseArea {
                            id: prevYearMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.viewYear--; dayGrid.model = buildDayModel() }
                        }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: prevMonthMouse.containsMouse ? "#0A000000" : "transparent"
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 16; color: "#80000000" }
                        MouseArea {
                            id: prevMonthMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.viewMonth === 1) { root.viewMonth = 12; root.viewYear-- }
                                else root.viewMonth--
                                dayGrid.model = buildDayModel()
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.viewYear + " 年 " + root.viewMonth + " 月"
                    font.pixelSize: 14
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.weight: Font.DemiBold
                    color: "#D9000000"
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: nextMonthMouse.containsMouse ? "#0A000000" : "transparent"
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: 16; color: "#80000000" }
                        MouseArea {
                            id: nextMonthMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.viewMonth === 12) { root.viewMonth = 1; root.viewYear++ }
                                else root.viewMonth++
                                dayGrid.model = buildDayModel()
                            }
                        }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 6
                        color: nextYearMouse.containsMouse ? "#0A000000" : "transparent"
                        Text { anchors.centerIn: parent; text: "»"; font.pixelSize: 14; color: "#80000000" }
                        MouseArea {
                            id: nextYearMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.viewYear++; dayGrid.model = buildDayModel() }
                        }
                    }
                }
            }

            Grid {
                columns: 7
                spacing: 0
                width: parent.width

                Repeater {
                    model: ["一", "二", "三", "四", "五", "六", "日"]
                    delegate: Item {
                        width: parent.width / 7
                        height: 28
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 12
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: "#80000000"
                        }
                    }
                }
            }

            Grid {
                id: dayGridContainer
                columns: 7
                spacing: 0
                width: parent.width

                Repeater {
                    id: dayGrid
                    model: buildDayModel()

                    delegate: Item {
                        width: dayGridContainer.width / 7
                        height: 32

                        property bool isToday: modelData > 0
                            && root.viewYear === selectedYear
                            && root.viewMonth === selectedMonth
                            && modelData === selectedDay

                        Rectangle {
                            width: 28; height: 28
                            radius: 14
                            anchors.centerIn: parent
                            color: isToday ? "#006BFF"
                                 : dayMouse.containsMouse && modelData > 0 ? "#0A000000"
                                 : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                font.pixelSize: 13
                                font.family: "Alibaba PuHuiTi 3.0"
                                color: isToday ? "#FFFFFF" : "#D9000000"
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: modelData > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (modelData > 0) {
                                    root.selectedYear = root.viewYear
                                    root.selectedMonth = root.viewMonth
                                    root.selectedDay = modelData
                                    root.dateSelected(root.selectedYear, root.selectedMonth, root.selectedDay)
                                    popup.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
