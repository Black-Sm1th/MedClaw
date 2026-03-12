import QtQuick 2.9
import QtQuick.Controls 2.2

Rectangle {
    id: multiLineTextInput
    
    // 可配置属性
    property int inputWidth: 300
    property int inputHeight: 120
    property color borderColor: "transparent"
    property color focusedBorderColor: "#006BFF"
    property color backgroundColor: "#F5F5F5"
    property color textColor: "#D9000000"
    property color placeholderColor: "#40000000"
    property int fontSize: 16
    property string placeholderText: qsTr("请输入...")
    property int borderWidth: 1
    property int inputRadius: 8
    
    // 文本属性
    property alias text: textArea.text
    property alias readOnly: textArea.readOnly
    
    // 设置尺寸
    width: inputWidth
    height: inputHeight
    
    // 背景样式
    color: backgroundColor
    border.color: textArea.activeFocus && !readOnly ? focusedBorderColor : borderColor
    border.width: borderWidth
    radius: inputRadius
    
    // 简单的滚动视图
    ScrollView {
        anchors.fill: parent
        anchors.margins: borderWidth + 4
        clip: true
        
        TextArea {
            id: textArea
            clip: true
            font.pixelSize: fontSize
            font.family: "Alibaba PuHuiTi 3.0"
            color: textColor
            selectByMouse: true
            wrapMode: TextArea.Wrap
            
            placeholderText: multiLineTextInput.placeholderText
            placeholderTextColor: placeholderColor
            
            background: Rectangle {
                color: "transparent"
            }
        }
    }
    
    // 边框颜色动画
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }
} 
