import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property var tabs: []
    property int currentIndex: 0
    property color activeColor: "#006BFF"
    property color lineColor: "#14000000"
    property color textColor: "#D9000000"
    property color inactiveTextColor: "#A6000000"
    property int fontSize: 16
    property int tabHeight: 40
    property int indicatorHeight: 2
    property real lineWidth: -1

    signal tabClicked(int index)

    implicitHeight: tabHeight
    implicitWidth: tabRow.implicitWidth

    Row {
        id: tabRow
        height: root.tabHeight
        spacing: 0

        Repeater {
            id: tabRepeater
            model: root.tabs

            delegate: Item {
                id: tabItem
                width: tabContent.implicitWidth + 48
                height: root.tabHeight

                property bool isActive: index === root.currentIndex

                Row {
                    id: tabContent
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: modelData.text !== undefined ? modelData.text : modelData
                        font.pixelSize: root.fontSize
                        font.family: "Alibaba PuHuiTi 3.0"
                        font.weight: tabItem.isActive ? Font.DemiBold : Font.Normal
                        color: tabItem.isActive ? root.textColor : root.inactiveTextColor
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }
                    }

                    Rectangle {
                        visible: modelData.badge !== undefined && modelData.badge > 0
                        width: badgeText.implicitWidth + 12
                        height: 20
                        radius: 10
                        color: tabItem.isActive ? "#0F006BFF" : "#0A000000"
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        Text {
                            id: badgeText
                            text: modelData.badge !== undefined ? modelData.badge : ""
                            font.pixelSize: 12
                            font.family: "Alibaba PuHuiTi 3.0"
                            color: tabItem.isActive ? root.activeColor : root.inactiveTextColor
                            anchors.centerIn: parent

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentIndex = index
                        root.tabClicked(index)
                    }
                }
            }
        }
    }

    Rectangle {
        id: bottomLine
        width: root.lineWidth < 0 ? parent.width : root.lineWidth
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 1
        color: root.lineColor
    }

    Rectangle {
        id: indicator
        height: root.indicatorHeight
        radius: 1
        color: root.activeColor
        anchors.bottom: parent.bottom

        property var targetItem: tabRepeater.count > root.currentIndex
                                 ? tabRepeater.itemAt(root.currentIndex) : null

        x: targetItem ? targetItem.x : 0
        width: targetItem ? targetItem.width : 0

        Behavior on x {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
