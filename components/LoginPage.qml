import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: loginPage
    property bool showPhoneForm: false
    property int resendSeconds: 0

    function sendCode() { authController.sendSmsCode(phoneInput.text) }
    function submitLogin() { authController.loginWithPhone(phoneInput.text, codeInput.text) }

    Rectangle { anchors.fill: parent; color: "#FFFFFF" }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel.accepted = true
    }

    Column {
        width: 254
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -8
        spacing: 0
        Image { source: "qrc:/images/loginTitle.png";height:!showPhoneForm ? 209 : 128 ;width: !showPhoneForm ? 840 : 514;  fillMode: Image.PreserveAspectFit; anchors.horizontalCenter: parent.horizontalCenter }
        Item { width: 1; height: showPhoneForm ? 40 : 38 }

        Column {
            width: parent.width; spacing: 14; visible: loginPage.showPhoneForm; height: visible ? implicitHeight : 0
            Rectangle {
                width: parent.width; height: 36; radius: 6; color: "#F7F8FA"
                Label {
                    text: "+86"
                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#595959"
                    font.pixelSize: 12
                }
                SingleLineTextInput {
                    id: phoneInput
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: parent.right
                    inputWidth: parent.width - 42
                    inputHeight: parent.height
                    backgroundColor: "transparent"
                    borderWidth: 0
                    inputRadius: 0
                    fontSize: 12
                    textColor: "#262626"
                    placeholderColor: "#BFBFBF"
                    placeholderText: "请输入手机号"
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 11
                    onTextChanged: authController.clearError()
                }
            }
            Row {
                width: parent.width; height: 36; spacing: 10
                SingleLineTextInput {
                    id: codeInput
                    inputWidth: 190
                    inputHeight: parent.height
                    backgroundColor: "#F7F8FA"
                    borderWidth: 0
                    inputRadius: 6
                    fontSize: 12
                    textColor: "#262626"
                    placeholderColor: "#BFBFBF"
                    placeholderText: "请输入验证码"
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 6
                    onAccepted: loginPage.submitLogin()
                    onTextChanged: authController.clearError()
                }
                Item {
                    id: sendCodeSlot
                    width: 54
                    height: parent.height
                    Button {
                        id: sendCodeButton
                        anchors.fill: parent
                        enabled: !authController.busy && loginPage.resendSeconds === 0
                        hoverEnabled: true
                        text: loginPage.resendSeconds > 0 ? loginPage.resendSeconds + "s" : "获取验证码"
                        font.family: "Alibaba PuHuiTi 3.0"
                        font.pixelSize: 12
                        padding: 0
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#006BFF" : "#A6A6A6"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font: parent.font
                        }
                        background: Rectangle {
                            radius: 4
                            color: "transparent"
                        }
                        onClicked: loginPage.sendCode()
                    }
                    MouseArea {
                        id: sendCodeHover
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        cursorShape: containsMouse && sendCodeButton.enabled
                                     ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
        Item { width: 1; height: loginPage.showPhoneForm ? 14 : 0 }
        CustomButton {
            buttonWidth: parent.width
            buttonHeight: 40
            buttonRadius: 6
            enabled: !authController.busy
            text: authController.busy ? (loginPage.showPhoneForm ? "登录中" : "请稍候") : "登录"
            fontSize: 14
            backgroundColor: "#006BFF"
            hoverBackgroundColor: "#1677FF"
            pressedBackgroundColor: "#0057D9"
            disabledBackgroundColor: "#80AFFF"
            textColor: "#FFFFFF"
            disabledTextColor: "#FFFFFF"
            onClicked: {
                if (!loginPage.showPhoneForm) {
                    loginPage.showPhoneForm = true
                    phoneInput.forceActiveFocus()
                } else {
                    loginPage.submitLogin()
                }
            }
        }
        Label { visible: authController.errorMessage.length > 0; width: parent.width; topPadding: 12; text: authController.errorMessage; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; color: "#E54D42"; font.pixelSize: 12 }
    }

    Label { text: "隐私政策   服务条款"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 26; color: "#A6A6A6"; font.pixelSize: 12 }
    Timer { interval: 1000; repeat: true; running: loginPage.resendSeconds > 0; onTriggered: loginPage.resendSeconds-- }
    Connections { target: authController; function onSmsCodeSent() { loginPage.resendSeconds = 60; codeInput.forceActiveFocus() } }
    onVisibleChanged: {
        if (visible) {
            showPhoneForm = false
            resendSeconds = 0
            phoneInput.clear()
            codeInput.clear()
            authController.clearError()
        }
    }
}
