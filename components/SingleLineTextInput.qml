import QtQuick 2.9
import QtQuick.Controls 2.2

Rectangle {
    id: singleLineTextInput
    
    // 可配置属性
    property int inputWidth: 300
    property int inputHeight: 30
    property color borderColor: "#E6E7EB"
    property color focusedBorderColor: "#006BFF"
    property color backgroundColor: "#FFFFFF"
    property color textColor: "#A6000000"
    property color placeholderColor: "#40000000"
    property int fontSize: 14
    property string placeholderText: qsTr("请输入...")
    property int borderWidth: 1
    property int inputRadius: 8
    property string icon: ""
    property int iconSize: 16
    
    // 文本属性
    property alias text: textField.text
    property alias readOnly: textField.readOnly
    property alias echoMode: textField.echoMode
    property alias maximumLength: textField.maximumLength
    property alias validator: textField.validator
    property alias inputMethodHints: textField.inputMethodHints
    
    // 信号
    signal accepted()
    signal editingFinished()
    signal focusChanged(bool hasFocus)
    
    // 设置尺寸
    width: inputWidth
    height: inputHeight
    
    // 背景样式
    color: backgroundColor
    border.color: textField.activeFocus && !readOnly ? focusedBorderColor : borderColor
    border.width: borderWidth
    radius: inputRadius
    
    Image {
        id: iconImage
        source: singleLineTextInput.icon
        width: singleLineTextInput.iconSize
        height: singleLineTextInput.iconSize
        visible: singleLineTextInput.icon !== ""
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(singleLineTextInput.iconSize, singleLineTextInput.iconSize)
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
    }

    TextField {
        id: textField
        anchors.left: iconImage.visible ? iconImage.right : parent.left
        anchors.leftMargin: iconImage.visible ? 4 : 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        font.pixelSize: fontSize
        font.family: "Alibaba PuHuiTi 3.0"
        color: textColor
        selectByMouse: !readOnly
        padding: 4
        placeholderText: !readOnly ? singleLineTextInput.placeholderText : ""
        placeholderTextColor: placeholderColor
        
        background: Rectangle {
            color: "transparent"
        }
        
        onAccepted: singleLineTextInput.accepted()
        onEditingFinished: singleLineTextInput.editingFinished()
        onActiveFocusChanged: singleLineTextInput.focusChanged(activeFocus)
    }
    
    // 边框颜色动画
    Behavior on border.color {
        ColorAnimation { duration: 200 }
    }
    
    // 提供焦点控制方法
    function forceActiveFocus() {
        textField.forceActiveFocus()
    }
    
    function clear() {
        textField.clear()
    }
}
