import QtQuick 2.15
import Qt5Compat.GraphicalEffects
import MedClaw.Theme 1.0

Item {
    id: root

    property alias source: bgImage.source
    property color hoveredColor: Theme.surfaceHover
    property color pressedColor: Theme.surfacePressed
    property int radius: 4
    property int padding: 4
    property int btnWidth: bgImage.implicitWidth
    property int btnHeight: bgImage.implicitHeight
    // 黑色线框图标在深色下需要转浅：colorize=true 时用 colorizeColor 覆盖图标颜色。
    // 彩色图标（红删除、白上传等）请显式 colorize: false。
    property bool colorize: true
    property color colorizeColor: Theme.iconColor
    signal clicked()

    implicitWidth: btnWidth + padding * 2
    implicitHeight: btnHeight + padding * 2

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: mouseArea.pressed ? root.pressedColor
             : mouseArea.containsMouse ? root.hoveredColor
             : "transparent"

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Image {
        id: bgImage
        width: btnWidth
        height: btnHeight
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
        layer.enabled: root.colorize
        layer.effect: ColorOverlay {
            color: root.colorizeColor
            cached: true
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
