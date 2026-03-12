import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.2
import "./components"
ApplicationWindow {
    id: window
    width: 1440
    height: 800
    visible: true
    title: qsTr("MedClaw")
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowMinimizeButtonHint
    font.family: "Alibaba PuHuiTi 3.0"
    font.pixelSize: 14
    property bool isNewTask: true
    Rectangle{
        id: leftContainer
        width: 280
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        color: "#F7F9FA"
        Column{
            height: parent.height
            width: parent.width
            leftPadding: 16
            rightPadding: 16
            Rectangle{
                id: leftTopPanel
                width: parent.width - 32
                height: 56
                color: "transparent"
                Image{
                    source: "qrc:/images/titleIcon.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                ImageButton{
                    source: "qrc:/images/sidebarMinimalistic.png"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                }
            }
            Rectangle{
                id: leftMidPanel
                width: parent.width - 32
                height: parent.height - 56 - 60
                color: "transparent"
            }
            Rectangle{
                id: leftBottomPanel
                width: parent.width - 32
                height: 60
                color: "transparent"
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: "#E6EAF2"
                }
            }
        }
    }
    Rectangle{
        id:rightContainer
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: leftContainer.right
        anchors.right: parent.right
        color: "#FFFFFF"
        Rectangle{
            id: rightTopPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 56
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: "#14000000"
            }

            MouseArea {
                anchors.fill: parent
                property point dragPos

                onPressed: {
                    dragPos = Qt.point(mouseX, mouseY)
                }
                onPositionChanged: {
                    if (pressed) {
                        var delta = Qt.point(mouseX - dragPos.x, mouseY - dragPos.y)
                        window.x += delta.x
                        window.y += delta.y
                    }
                }
            }

            Row{
                rightPadding: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                ImageButton{
                    id: minusBtn
                    source: "qrc:/images/minus.png"
                }
                ImageButton{
                    id: maxmizeBtn
                    source: "qrc:/images/add-square.png"
                }
                ImageButton{
                    id: closeBtn
                    source: "qrc:/images/close.png"
                    onClicked: {
                        Qt.quit()
                    }
                }
            }
        }
        Rectangle{
            id: rightMainPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: rightTopPanel.bottom
            anchors.bottom: parent.bottom
            Rectangle{
                id: newTaskRec
                anchors.fill: parent
                Column{
                    width: 840
                    spacing: 11
                    anchors.horizontalCenter: parent.horizontalCenter
                    Label{
                        text: "MedClaw"
                        font.family: "Alimama ShuHeiTi"
                        font.pixelSize: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Label{
                        text: "7×24 小时在线的专属智能伙伴"
                        font.pixelSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
