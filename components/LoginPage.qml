import QtQuick 2.15
import QtQuick.Controls 2.15
import MedClaw.Theme 1.0

Item {
    id: loginPage
    signal errorRequested(string message)
    property bool governmentEdition: false
    property bool imagingEdition: false
    // 影像版不再要「领域卡片 + 登录」那一屏（设计稿 5626-73454 已废弃），
    // 直接进手机号表单（设计稿 5627-83678）
    property bool showPhoneForm: imagingEdition
    property int resendSeconds: 0
    property bool initializing: false
    property int startupEllipsisCount: 0
    // 深色 + 影像版：标题用 Aether.Imaging，领域卡片用设计稿（5626-73454）的深色组图。
    readonly property bool darkImaging: Theme.dark && imagingEdition
    readonly property real contentWidth: Math.min(709, Math.max(280, width - 48))
    readonly property real shortcutAreaWidth: darkImaging ? Math.min(1120, Math.max(280, width - 48))
                                                          : Math.min(904, Math.max(280, width - 48))
    readonly property real formWidth: Math.min(400, Math.max(240, width - 48))
    readonly property bool useEnterpriseCredentials: authController.enterpriseCredentialLoginEnabled
    readonly property string welcomeTitle: governmentEdition
                                         ? qsTr("你好，欢迎来到 政务智能体")
                                         : (imagingEdition ? qsTr("你好，欢迎来到 汇小智 Aether.Imaging")
                                                           : qsTr("你好，欢迎来到 汇小智 Aether study"))
    readonly property var shortcutImages: darkImaging
                                          ? ["loginShortcut-dark-1.png", "loginShortcut-dark-2.png",
                                             "loginShortcut-dark-3.png", "loginShortcut-dark-4.png",
                                             "loginShortcut-dark-5.png"]
                                          : imagingEdition
                                            ? ["loginShortcut1.png", "loginShortcut5.png"]
                                            : governmentEdition
                                              ? ["loginShortcut1.png", "loginShortcut3-sp.png", "loginShortcut6-sp.png"]
                                              : ["loginShortcut1.png", "loginShortcut2.png", "loginShortcut3.png",
                                                 "loginShortcut4.png", "loginShortcut5.png", "loginShortcut6.png"]

    function sendCode() { authController.sendSmsCode(phoneInput.text) }
    function submitLogin() {
        if (loginPage.useEnterpriseCredentials) {
            if (authController.networkSelectionEnabled
                    && !authController.setNetworkEnvironment(authController.apiEnvironment))
                return
            if (authController.internalApiHostInputEnabled
                    && !authController.setInternalApiHost(internalIpInput.text)) {
                internalIpInput.forceActiveFocus()
                return
            }
            authController.loginWithCredentials(usernameInput.text, passwordInput.text)
        } else {
            authController.loginWithPhone(phoneInput.text, codeInput.text)
        }
    }

    // 背景用窗口底色（深色 #14171A）：设计稿登录页的底色就是窗口底色，
    // 之前用 Theme.surface（#242627）会整页偏亮。
    Rectangle { anchors.fill: parent; color: Theme.windowBg }
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
        Column {
            width: parent.width
            spacing: 16
            Row {
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Image {
                    width: 36
                    height: 36
                    source: "qrc:/images/star.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: loginPage.welcomeTitle
                    color: Theme.textPrimary
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 40
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("开启你的智能探索之旅")
                color: Theme.textSecondary
                font.family: "Alibaba PuHuiTi 3.0"
                font.pixelSize: 28
                wrapMode: Text.Wrap
            }
        }
        Item { width: 1; height: showPhoneForm ? 80 : 68 }
        Item {
            id: shortcutCarousel
            width: parent.width
            readonly property real shortcutSpacing: loginPage.darkImaging
                                                    ? 32
                                                    : Math.min(32, Math.max(8, width * 0.055))
            readonly property real shortcutWidth: loginPage.darkImaging
                                                  ? 202
                                                  : Math.min(202,
                                                             Math.max(1, (width - shortcutSpacing * 4) / 5))
            readonly property real cycleWidth: loginPage.shortcutImages.length
                                                  * (shortcutWidth + shortcutSpacing)
            height: shortcutWidth * 175 / 202
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !loginPage.showPhoneForm

            Flickable {
                id: shortcutFlickable
                anchors.fill: parent
                clip: true
                interactive: false
                contentWidth: shortcutStrip.width
                contentHeight: height

                Row {
                    id: shortcutStrip
                    height: parent.height
                    spacing: shortcutCarousel.shortcutSpacing

                        Repeater {
                            model: loginPage.shortcutImages.length * 2
                            Image {
                                width: shortcutCarousel.shortcutWidth
                                height: shortcutCarousel.height
                                source: "qrc:/images/login/" + loginPage.shortcutImages[index % loginPage.shortcutImages.length]
                                // 深色卡片是 2 倍图（404x350），按 202x175 显示保持清晰
                                sourceSize: loginPage.darkImaging ? Qt.size(404, 350) : Qt.size(0, 0)
                                fillMode: Image.PreserveAspectFit
                            }
                        }
                }

                SequentialAnimation on contentX {
                    running: loginPage.visible
                             && !loginPage.showPhoneForm
                             && !loginPage.initializing
                    loops: Animation.Infinite
                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        from: 0
                        to: shortcutCarousel.cycleWidth
                        duration: 14000
                        easing.type: Easing.Linear
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                width: Math.min(48, parent.width * 0.08)
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.windowBg }
                    GradientStop { position: 1.0; color: "#00FFFFFF" }
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: Math.min(48, parent.width * 0.08)
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#00FFFFFF" }
                    GradientStop { position: 1.0; color: Theme.windowBg }
                }
            }
        }
        Item { width: 1; height: 68; visible: !loginPage.showPhoneForm }
        Column {
            width: parent.width; spacing: 24; visible: loginPage.showPhoneForm && !loginPage.useEnterpriseCredentials; height: visible ? implicitHeight : 0
            Rectangle {
                width: loginPage.formWidth; height: 56; radius: 7; color: Theme.surfaceMuted
                anchors.horizontalCenter: parent.horizontalCenter
                Label {
                    text: "+86"
                    anchors.left: parent.left
                    anchors.leftMargin: loginPage.darkImaging ? 17 : 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textMutedSolid
                    font.pixelSize: 16
                }
                // 设计稿（5627-83678）：+86 与手机号之间有一条 1px 分隔线
                Rectangle {
                    visible: loginPage.darkImaging
                    width: 1
                    height: 20
                    color: Theme.divider
                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.verticalCenter: parent.verticalCenter
                }
                SingleLineTextInput {
                    id: phoneInput
                    anchors.left: parent.left
                    anchors.leftMargin: loginPage.darkImaging ? 70 : 50
                    anchors.right: parent.right
                    inputWidth: parent.width - (loginPage.darkImaging ? 70 : 50)
                    inputHeight: parent.height
                    backgroundColor: "transparent"
                    borderWidth: 0
                    inputRadius: 0
                    fontSize: 16
                    textColor: Theme.textSolid
                    placeholderColor: Theme.textFaint
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
                    backgroundColor: Theme.surfaceMuted
                    borderWidth: 0
                    inputRadius: 7
                    fontSize: 16
                    textColor: Theme.textSolid
                    placeholderColor: Theme.textFaint
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
                            color: parent.enabled ? Theme.accent : Theme.textFaint
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
        Column {
            width: parent.width; spacing: 16; visible: loginPage.showPhoneForm && loginPage.useEnterpriseCredentials; height: visible ? implicitHeight : 0
            Row {
                width: loginPage.formWidth
                height: 48
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter
                visible: authController.networkSelectionEnabled
                Repeater {
                    model: [
                        { label: "公网", value: "prod" },
                        { label: "内网", value: "internal" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (loginPage.formWidth - 12) / 2
                        height: 48
                        radius: 7
                        color: authController.apiEnvironment === modelData.value
                               ? Theme.accentSoftBg : Theme.surfaceMuted
                        border.width: authController.apiEnvironment === modelData.value ? 1 : 0
                        border.color: Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: authController.apiEnvironment === modelData.value
                                   ? Theme.accent : Theme.textSecondary
                            font.family: "Alibaba PuHuiTi 3.0"
                            font.pixelSize: 16
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !authController.busy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                authController.setNetworkEnvironment(modelData.value)
                            }
                        }
                    }
                }
            }
            SingleLineTextInput {
                id: usernameInput
                anchors.horizontalCenter: parent.horizontalCenter
                inputWidth: loginPage.formWidth
                inputHeight: 56
                backgroundColor: Theme.surfaceMuted
                borderWidth: 0
                inputRadius: 7
                fontSize: 16
                textColor: Theme.textSolid
                placeholderColor: Theme.textFaint
                placeholderText: "请输入账号"
                onTextChanged: authController.clearError()
            }
            SingleLineTextInput {
                id: passwordInput
                anchors.horizontalCenter: parent.horizontalCenter
                inputWidth: loginPage.formWidth
                inputHeight: 56
                backgroundColor: Theme.surfaceMuted
                borderWidth: 0
                inputRadius: 7
                fontSize: 16
                textColor: Theme.textSolid
                placeholderColor: Theme.textFaint
                placeholderText: "请输入密码"
                echoMode: TextInput.Password
                onAccepted: loginPage.submitLogin()
                onTextChanged: authController.clearError()
            }
            SingleLineTextInput {
                id: internalIpInput
                anchors.horizontalCenter: parent.horizontalCenter
                inputWidth: loginPage.formWidth
                inputHeight: 56
                backgroundColor: Theme.surfaceMuted
                borderWidth: 0
                inputRadius: 7
                fontSize: 16
                textColor: Theme.textSolid
                placeholderColor: Theme.textFaint
                placeholderText: "请输入内网IP地址"
                text: authController.internalApiHost
                maximumLength: 15
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                visible: authController.internalApiHostInputEnabled
                onTextChanged: authController.clearError()
                onEditingFinished: {
                    if (!authController.setInternalApiHost(text))
                        text = authController.internalApiHost
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
            backgroundColor: Theme.accent
            hoverBackgroundColor: Theme.accentHover
            pressedBackgroundColor: Theme.accentPressed
            disabledBackgroundColor: Theme.accentSoftBg
            textColor: Theme.textInverse
            disabledTextColor: Theme.surface
            onClicked: {
                if (!loginPage.showPhoneForm) {
                    loginPage.showPhoneForm = true
                    if (loginPage.useEnterpriseCredentials)
                        usernameInput.forceActiveFocus()
                    else
                        phoneInput.forceActiveFocus()
                } else {
                    loginPage.submitLogin()
                }
            }
        }
    }

    Column {
        width: loginPage.contentWidth
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        visible: loginPage.initializing

        Column {
            width: parent.width
            spacing: 16
            Row {
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Image {
                    width: 36
                    height: 36
                    source: "qrc:/images/star.png"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: loginPage.welcomeTitle
                    color: Theme.textPrimary
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.pixelSize: 40
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("开启你的智能探索之旅")
                color: Theme.textSecondary
                font.family: "Alibaba PuHuiTi 3.0"
                font.pixelSize: 28
                wrapMode: Text.Wrap
            }
        }
        AnimatedImage {
            width: Math.min(480, loginPage.contentWidth)
            height: width * 0.75
            anchors.horizontalCenter: parent.horizontalCenter
            source: "qrc:/images/waiting.gif"
            fillMode: Image.PreserveAspectFit
            // 深色影像版用设计稿（5581-37634）的深色插画；waiting.gif 是白底的，深色下是一大块白
            visible: !loginPage.darkImaging
            playing: loginPage.initializing && !loginPage.darkImaging
        }
        // 深色影像版：设计稿（5581-37660）的 5 秒微动效 GIF；静帧先顶上，
        // 动图加载好（frameCount>0）再叠上去，避免空白/闪烁。同一槽位，别拆成两个条目。
        Item {
            visible: loginPage.darkImaging
            width: Math.min(450, loginPage.contentWidth)
            height: width * 338 / 450
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                anchors.fill: parent
                source: "qrc:/images/imaging/splash-dark.png"
                sourceSize: Qt.size(900, 676)
                fillMode: Image.PreserveAspectFit
            }
            AnimatedImage {
                anchors.fill: parent
                source: "qrc:/images/imaging/splash-dark.gif"
                fillMode: Image.PreserveAspectFit
                visible: frameCount > 0
                playing: loginPage.initializing
            }
        }
        Label {
            width: parent.width
            text: qsTr("启动中") + Array(startupEllipsisCount + 1).join(".")
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textSecondary
            font.family: "Alibaba PuHuiTi 3.0"
            font.pixelSize: 18
        }
    }

    Label { text: "隐私政策   服务条款"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 40; color: Theme.textTertiary; font.pixelSize: 16; visible: !loginPage.initializing}
    Timer {
        interval: 450
        repeat: true
        running: loginPage.visible && loginPage.initializing
        onTriggered: loginPage.startupEllipsisCount = (loginPage.startupEllipsisCount + 1) % 4
    }
    Timer { interval: 1000; repeat: true; running: loginPage.resendSeconds > 0; onTriggered: loginPage.resendSeconds-- }
    Connections {
        target: authController
        function onSmsCodeSent() { loginPage.resendSeconds = 60; codeInput.forceActiveFocus() }
        function onErrorMessageChanged() {
            if (authController.errorMessage.length > 0)
                loginPage.errorRequested(authController.errorMessage)
        }
    }
    onVisibleChanged: {
        if (visible && !initializing) {
            // 影像版直接停在表单页，其它版本仍从「欢迎 + 领域卡片」开始
            showPhoneForm = imagingEdition
            resendSeconds = 0
            phoneInput.clear()
            codeInput.clear()
            usernameInput.clear()
            passwordInput.clear()
            authController.clearError()
        }
    }
}
