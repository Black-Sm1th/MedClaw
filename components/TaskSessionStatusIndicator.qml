import QtQuick 2.15

Item {
    id: root

    property bool running: false

    implicitWidth: 12
    implicitHeight: 12

    Rectangle {
        width: 6
        height: 6
        radius: 3
        anchors.centerIn: parent
        color: "#3387FF"
        visible: !root.running
    }

    Canvas {
        id: spinner
        anchors.fill: parent
        visible: root.running
        onVisibleChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#3387FF"
            ctx.lineWidth = 1.8
            ctx.lineCap = "round"
            ctx.beginPath()
            ctx.arc(width / 2, height / 2, 4.2,
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
}
