import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import MedClaw.Theme 1.0

ToolTip {
    id: root

    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0

    delay: 250
    timeout: -1
    padding: 0

    x: Math.max(8, Math.min(parent.width - implicitWidth - 8,
                            targetX + targetWidth / 2 - implicitWidth / 2))
    y: targetY >= implicitHeight + 8
       ? targetY - implicitHeight - 8
       : targetY + targetHeight + 8

    background: Rectangle {
        color: Theme.surface
        radius: 4
        border.width: 1
        border.color: Theme.dividerTopbar
        layer.enabled: true
        layer.effect: DropShadow {
            radius: 8
            samples: 17
            color: Theme.divider
            verticalOffset: 2
        }
    }

    contentItem: Text {
        leftPadding: 10
        rightPadding: 10
        topPadding: 7
        bottomPadding: 7
        text: root.text
        color: Theme.textPrimary
        font.family: "Alibaba PuHuiTi 3.0"
        font.pixelSize: 13
        wrapMode: Text.NoWrap
    }
}
