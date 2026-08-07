import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: loginPage
    property bool showPhoneForm: false
    property int resendSeconds: 0
    property bool initializing: false
    property string initializingText: ""
    readonly property real contentWidth: Math.min(577, Math.max(280, width - 48))
    readonly property real shortcutAreaWidth: Math.min(904, Math.max(280, width - 48))
    readonly property real formWidth: Math.min(400, Math.max(240, width - 48))

    function sendCode() { authController.sendSmsCode(phoneInput.text) }
    function submitLogin() { authController.loginWithPhone(phoneInput.text, codeInput.text) }

    Rectangle { anchors.fill: parent; color: "#FFFFFF" }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel.accepted = true
    }

    Column {
        width: loginPage.shortcutAreaWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -56
        spacing: 0
        visible: !loginPage.initializing
        Image {
            source: "qrc:/images/login/loginTitle.png"
            width: Math.min(577, parent.width)
            height: width * 110 / 577
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Item { width: 1; height: showPhoneForm ? 80 : 68 }
        Row {
            id: shortcutRow
            readonly property real shortcutWidth: Math.min(202,
                                                            Math.max(1, (width - spacing * 3) / 4))
            width: parent.width
            height: shortcutWidth * 175 / 202
            spacing: Math.min(32, Math.max(8, width * 0.055))
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !loginPage.showPhoneForm
            Image { width: shortcutRow.shortcutWidth; height: shortcutRow.height; source: "qrc:/images/login/loginShortcut1.png"; fillMode: Image.PreserveAspectFit }
            Image { width: shortcutRow.shortcutWidth; height: shortcutRow.height; source: "qrc:/images/login/loginShortcut2.png"; fillMode: Image.PreserveAspectFit }
            Image { width: shortcutRow.shortcutWidth; height: shortcutRow.height; source: "qrc:/images/login/loginShortcut3.png"; fillMode: Image.PreserveAspectFit }
            Image { width: shortcutRow.shortcutWidth; height: shortcutRow.height; source: "qrc:/images/login/loginShortcut4.png"; fillMode: Image.PreserveAspectFit }
        }
        Item { width: 1; height: 68; visible: !loginPage.showPhoneForm }
        Column {
            width: parent.width; spacing: 24; visible: loginPage.showPhoneForm; height: visible ? implicitHeight : 0
            Rectangle {
                width: loginPage.formWidth; height: 56; radius: 7; color: "#F7F8FA"
                anchors.horizontalCenter: parent.horizontalCenter
                Label {
                    text: "+86"
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#595959"
                    font.pixelSize: 16
                }
                SingleLineTextInput {
                    id: phoneInput
                    anchors.left: parent.left
                    anchors.leftMargin: 50
                    anchors.right: parent.right
                    inputWidth: parent.width - 50
                    inputHeight: parent.height
                    backgroundColor: "transparent"
                    borderWidth: 0
                    inputRadius: 0
                    fontSize: 16
                    textColor: "#262626"
                    placeholderColor: "#BFBFBF"
                    placeholderText: "请输入手机号"
                    inputMethodHints: Qt.ImhDigitsOnly
                    maximumLength: 11
                    onTextChanged: authController.clearError()
                }
            }
            Row {
                width: loginPage.formWidth; height: 56; spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter
                SingleLineTextInput {
                    id: codeInput
                    inputWidth: parent.width - 84 - 12
                    inputHeight: parent.height
                    backgroundColor: "#F7F8FA"
                    borderWidth: 0
                    inputRadius: 7
                    fontSize: 16
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
                    width: 84
                    height: parent.height
                    Button {
                        id: sendCodeButton
                        anchors.fill: parent
                        enabled: !authController.busy && loginPage.resendSeconds === 0
                        hoverEnabled: true
                        text: loginPage.resendSeconds > 0 ? loginPage.resendSeconds + "s后重发" : "获取验证码"
                        font.family: "Alibaba PuHuiTi 3.0"
                        font.pixelSize: 16
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
        Item { width: 1; height: 24; visible: loginPage.showPhoneForm}
        CustomButton {
            buttonWidth: loginPage.showPhoneForm ? loginPage.formWidth : Math.min(240, loginPage.contentWidth)
            buttonHeight: 62
            buttonRadius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            enabled: !authController.busy
            text: authController.busy ? (loginPage.showPhoneForm ? "登录中" : "请稍候") : "登录"
            fontSize: 20
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
        Label { visible: authController.errorMessage.length > 0; width: parent.width; topPadding: 14; text: authController.errorMessage; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; color: "#E54D42"; font.pixelSize: 16 }
    }

    Column {
        width: loginPage.contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -56
        spacing: 32
        visible: loginPage.initializing

        Image {
            source: "qrc:/images/login/loginTitle.png"
            width: parent.width
            height: width * 110 / 577
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }
        BusyIndicator {
            width: 48
            height: 48
            running: loginPage.initializing
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Label {
            width: parent.width
            text: loginPage.initializingText || qsTr("正在初始化当前用户的知识库...")
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#A6000000"
            font.pixelSize: 16
        }
    }

    Label { text: "隐私政策   服务条款"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40; color: "#73000000"; font.pixelSize: 16 }
    Timer { interval: 1000; repeat: true; running: loginPage.resendSeconds > 0; onTriggered: loginPage.resendSeconds-- }
    Connections { target: authController; function onSmsCodeSent() { loginPage.resendSeconds = 60; codeInput.forceActiveFocus() } }
    onVisibleChanged: {
        if (visible && !initializing) {
            showPhoneForm = false
            resendSeconds = 0
            phoneInput.clear()
            codeInput.clear()
            authController.clearError()
        }
    }
}
