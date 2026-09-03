import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property bool running: false
    property bool hovered: false
    readonly property bool moreHovered: moreMouse.containsMouse
    readonly property bool showingMore: hovered || moreHovered
    signal moreClicked(real sceneX, real sceneY)

    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        width: 6
        height: 6
        radius: 3
        anchors.centerIn: parent
        color: "#006BFF"
        visible: !root.running && !root.showingMore
    }

    Canvas {
        id: spinner
        width: 20
        height: 20
        anchors.centerIn: parent
        visible: root.running && !root.showingMore
        onVisibleChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#006BFF"
            ctx.lineWidth = 3
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, 7,
                    -Math.PI * 0.25, Math.PI * 1.25, false)
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

    Rectangle {
        anchors.fill: parent
        radius: 6
        visible: root.showingMore
        color: moreMouse.containsMouse ? "#10000000" : "transparent"

        Image {
            anchors.centerIn: parent
            width: 16
            height: 16
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
                root.moreClicked(point.x, point.y)
            }
        }
    }
}
