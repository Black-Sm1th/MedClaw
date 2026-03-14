import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Item {
    id: root

    property var model: []
    property int currentIndex: 0
    property string currentText: model.length > 0 ? model[currentIndex] : ""
    property color textColor: "#D9000000"
    property color hoverColor: "#0A000000"
    property color pressedColor: "#14000000"
    property color popupBorderColor: "#14000000"
    property color popupBackgroundColor: "#FFFFFF"
    property color selectedItemColor: "#0A006BFF"
    property int fontSize: 14
    property int dropdownRadius: 8
    property int itemHeight: 36
    property color borderColor: "transparent"
    property int borderWidth: 0
    property int alignment: Qt.AlignHCenter
    property string icon: ""
    property int iconSize: 16

    signal selected(int index, string text)

    implicitWidth: 144
    implicitHeight: 40

    Rectangle {
        id: button
        anchors.fill: parent
        radius: dropdownRadius
        color: mouseArea.pressed ? root.pressedColor
             : mouseArea.containsMouse ? root.hoverColor
             : "transparent"
        border.color: root.borderColor
        border.width: root.borderWidth

        Behavior on color {
            ColorAnimation { duration: 100 }
        }

        Item {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: displayText.height

            Row {
                id: displayRow
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: root.alignment === Qt.AlignLeft ? parent.left : undefined
                anchors.horizontalCenter: root.alignment === Qt.AlignHCenter ? parent.horizontalCenter : undefined
                anchors.horizontalCenterOffset: root.alignment === Qt.AlignHCenter ? -chevron.width / 2 - 2 : 0

                Image {
                    id: displayIcon
                    source: root.icon
                    width: root.iconSize
                    height: root.iconSize
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.icon !== ""
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(root.iconSize, root.iconSize)
                }

                Text {
                    id: displayText
                    text: root.currentText
                    font.pixelSize: root.fontSize
                    font.family: "Alibaba PuHuiTi 3.0"
                    color: root.textColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Canvas {
                id: chevron
                width: 16
                height: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                rotation: popup.visible ? 180 : 0

                Behavior on rotation {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

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
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (popup.visible) {
                    popup.close()
                } else {
                    popup.open()
                }
            }
        }
    }

    function calcMaxItemWidth() {
        var maxW = 0
        for (var i = 0; i < model.length; i++) {
            textMetrics.text = model[i]
            if (textMetrics.width > maxW)
                maxW = textMetrics.width
        }
        popup.maxItemWidth = maxW + 24
    }

    onModelChanged: calcMaxItemWidth()
    Component.onCompleted: calcMaxItemWidth()

    Popup {
        id: popup
        x: 0
        width: Math.max(root.width, maxItemWidth + 16)
        padding: 4

        property real maxItemWidth: 0

        function calcY() {
            var globalPos = root.mapToItem(null, 0, 0)
            var windowH = root.Window.height || 800
            var popupH = root.model.length * root.itemHeight + 12
            if (globalPos.y + root.height + 4 + popupH > windowH)
                return -popupH - 4
            return root.height + 4
        }

        y: calcY()
        onAboutToShow: y = calcY()

        background: Rectangle {
            radius: root.dropdownRadius
            color: root.popupBackgroundColor
            border.color: root.popupBorderColor
            border.width: 1
        }

        contentItem: Column {
            spacing: 2

            Repeater {
                model: root.model

                delegate: Rectangle {
                    width: popup.width - 8
                    height: root.itemHeight
                    radius: 6
                    color: itemMouse.pressed ? root.pressedColor
                         : index === root.currentIndex ? root.selectedItemColor
                         : itemMouse.containsMouse ? root.hoverColor
                         : "transparent"

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8

                        Image {
                            source: root.icon
                            width: root.iconSize
                            height: root.iconSize
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.icon !== ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(root.iconSize, root.iconSize)
                        }

                        Text {
                            text: modelData
                            font.pixelSize: root.fontSize
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: root.textColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentIndex = index
                            root.selected(index, modelData)
                            popup.close()
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

    TextMetrics {
        id: textMetrics
        font.pixelSize: root.fontSize
        font.family: "Alibaba PuHuiTi 3.0"
    }
}
