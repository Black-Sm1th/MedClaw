import QtQuick 2.15

Item {
    id: root

    property alias source: bgImage.source
    property color hoveredColor: "#0A000000"
    property color pressedColor: "#14000000"
    property int radius: 4
    property int padding: 4
    property int btnWidth: bgImage.implicitWidth
    property int btnHeight: bgImage.implicitHeight
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
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
