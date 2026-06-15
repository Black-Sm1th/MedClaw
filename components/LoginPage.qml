import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.0

/**
 * LoginPage —— 登录页（覆盖整个窗口）
 *
 * 只需填写「用户名」+「Token」。服务器地址（含端口）在创建用户时已分配，
 * 沿用 config.json 中的 serverUrl，登录无需填写端口。
 *
 * 用法：作为 ApplicationWindow 的顶层子项，visible 绑定 !wsClient.loggedIn，
 *      并将 appWindow 设为根 window（用于拖动 / 最小化 / 关闭）。
 */
Rectangle {
    id: loginRoot

    /// 根 ApplicationWindow，用于无边框窗口的拖动、最小化、关闭
    property var appWindow: null

    /// 登录中（已发起连接，等待握手结果）
    property bool busy: false
    /// 错误提示文案
    property string errorText: ""

    color: "#F4F6FB"

    // ── 背景装饰渐变 ──
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#EEF3FF" }
            GradientStop { position: 1.0; color: "#F7F8FB" }
        }
    }
    Rectangle {
        width: 520; height: 520; radius: 260
        color: "#1A3C7EFF"
        anchors.right: parent.right; anchors.rightMargin: -160
        anchors.top: parent.top; anchors.topMargin: -180
    }
    Rectangle {
        width: 420; height: 420; radius: 210
        color: "#14572499"
        anchors.left: parent.left; anchors.leftMargin: -150
        anchors.bottom: parent.bottom; anchors.bottomMargin: -160
    }

    // 拦截穿透到下层主界面的点击
    MouseArea { anchors.fill: parent }

    // ── 顶部可拖动条 + 窗口控制按钮 ──
    Item {
        id: titleBar
        height: 48
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        MouseArea {
            anchors.fill: parent
            property point dragPos
            onPressed: dragPos = Qt.point(mouseX, mouseY)
            onPositionChanged: {
                if (pressed && loginRoot.appWindow) {
                    loginRoot.appWindow.x += mouseX - dragPos.x
                    loginRoot.appWindow.y += mouseY - dragPos.y
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            ImageButton {
                source: "qrc:/images/minus.png"
                onClicked: if (loginRoot.appWindow) loginRoot.appWindow.showMinimized()
            }
            ImageButton {
                source: "qrc:/images/close.png"
                onClicked: Qt.quit()
            }
        }
    }

    // ── 登录卡片 ──
    Rectangle {
        id: card
        width: 420
        height: cardCol.implicitHeight + 64
        radius: 16
        color: "#FFFFFF"
        anchors.centerIn: parent
        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 0
            verticalOffset: 8
            radius: 28
            samples: 33
            color: "#22000000"
        }

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 32
            anchors.rightMargin: 32
            anchors.topMargin: 32
            spacing: 16

            // Logo + 标题
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Image {
                    source: "qrc:/images/largeIcon.png"
                    width: 56
                    height: 56
                    fillMode: Image.PreserveAspectFit
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("登录 MedClaw")
                    font.pixelSize: 22
                    font.family: "Alibaba PuHuiTi 3.0"
                    font.bold: true
                    color: "#1A1A1A"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: qsTr("输入用户名与 Token 进入你的工作区")
                    font.pixelSize: 13
                    color: "#8A8F99"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // 已保存账号（可点击快速填充）
            Flow {
                width: parent.width
                spacing: 8
                visible: wsClient.accounts.length > 0

                Repeater {
                    model: wsClient.accounts
                    delegate: Rectangle {
                        height: 28
                        width: chipText.implicitWidth + 24
                        radius: 14
                        color: chipArea.containsMouse ? "#E8F0FF" : "#F2F4F8"
                        border.color: "#E6E7EB"
                        border.width: 1
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.username
                            font.pixelSize: 12
                            color: "#3C7EFF"
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                usernameInput.text = modelData.username
                                var tk = wsClient.tokenForUsername(modelData.username)
                                if (tk && tk.length > 0)
                                    tokenInput.text = tk
                                loginRoot.errorText = ""
                            }
                        }
                    }
                }
            }

            // 用户名
            Column {
                width: parent.width
                spacing: 6
                Text {
                    text: qsTr("用户名")
                    font.pixelSize: 13
                    color: "#5A6068"
                }
                SingleLineTextInput {
                    id: usernameInput
                    inputWidth: parent.width
                    inputHeight: 42
                    fontSize: 14
                    placeholderText: qsTr("请输入用户名")
                    onTextChanged: loginRoot.errorText = ""
                    onAccepted: tokenInput.forceActiveFocus()
                }
            }

            // Token
            Column {
                width: parent.width
                spacing: 6
                Row {
                    width: parent.width
                    Text {
                        text: qsTr("Token")
                        font.pixelSize: 13
                        color: "#5A6068"
                    }
                    Item { width: parent.width - 100; height: 1 }
                    Text {
                        text: tokenInput.echoMode === TextInput.Password ? qsTr("显示") : qsTr("隐藏")
                        font.pixelSize: 12
                        color: "#3C7EFF"
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tokenInput.echoMode =
                                tokenInput.echoMode === TextInput.Password
                                    ? TextInput.Normal : TextInput.Password
                        }
                    }
                }
                SingleLineTextInput {
                    id: tokenInput
                    inputWidth: parent.width
                    inputHeight: 42
                    fontSize: 14
                    echoMode: TextInput.Password
                    placeholderText: qsTr("请输入 Token")
                    onTextChanged: loginRoot.errorText = ""
                    onAccepted: loginRoot.doLogin()
                }
            }

            // 记住账号
            Row {
                spacing: 8
                Rectangle {
                    id: rememberBox
                    property bool checked: true
                    width: 18; height: 18; radius: 4
                    border.width: 1.5
                    border.color: checked ? "#3C7EFF" : "#C2C7D0"
                    color: checked ? "#3C7EFF" : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "\u2713"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        visible: rememberBox.checked
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rememberBox.checked = !rememberBox.checked
                    }
                }
                Text {
                    text: qsTr("记住账号（下次自动登录）")
                    font.pixelSize: 13
                    color: "#5A6068"
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rememberBox.checked = !rememberBox.checked
                    }
                }
            }

            // 错误提示
            Text {
                width: parent.width
                text: loginRoot.errorText
                visible: loginRoot.errorText.length > 0
                color: "#FF4D4F"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            // 登录按钮
            CustomButton {
                width: parent.width
                height: 44
                backgroundColor: "#3C7EFF"
                textColor: "#FFFFFF"
                borderWidth: 0
                fontSize: 16
                enabled: !loginRoot.busy
                text: loginRoot.busy ? qsTr("登录中...") : qsTr("登 录")
                onClicked: loginRoot.doLogin()
            }
        }
    }

    // ── 登录动作 ──
    function doLogin() {
        if (busy)
            return
        var u = usernameInput.text.trim()
        var t = tokenInput.text.trim()
        if (u.length === 0 || t.length === 0) {
            errorText = qsTr("请输入用户名和 Token")
            return
        }
        errorText = ""
        busy = true
        wsClient.login(u, t, rememberBox.checked)
    }

    // ── 进入时预填记住的账号 ──
    Component.onCompleted: {
        var u = wsClient.rememberedUsername
        if (u && u.length > 0) {
            usernameInput.text = u
            var tk = wsClient.tokenForUsername(u)
            if (tk && tk.length > 0)
                tokenInput.text = tk
        }
    }

    Connections {
        target: wsClient
        function onLoginFailed(reason) {
            loginRoot.busy = false
            loginRoot.errorText = reason && reason.length > 0
                ? reason : qsTr("登录失败，请检查用户名和 Token")
        }
        function onLoginSucceeded() {
            loginRoot.busy = false
            loginRoot.errorText = ""
        }
    }
}
