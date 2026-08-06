import QtQuick 2.15
import QtWebEngine 1.10

Rectangle {
    id: root

    property color borderColor: "#E6E7EB"
    property color focusedBorderColor: "#006BFF"
    property color backgroundColor: "#FFFFFF"
    property color textColor: "#A6000000"
    property color placeholderColor: "#40000000"
    property int fontSize: 14
    property string placeholderText: qsTr("请输入...")
    property int borderWidth: 1
    property int inputRadius: 8
    property string text: ""
    property bool readOnly: false
    property real textContentHeight: 52
    property bool webReady: false
    property bool syncingFromWeb: false
    property var pendingFiles: []
    property bool fileTipVisible: false
    property string fileTipText: ""
    property real fileTipX: 0
    property real fileTipY: 0
    property real fileTipWidth: 0
    property real fileTipHeight: 0

    signal submitRequested(string message)

    color: backgroundColor
    border.color: activeFocus && !readOnly ? focusedBorderColor : borderColor
    border.width: borderWidth
    radius: inputRadius
    clip: true

    function js(value) {
        return JSON.stringify(value === undefined ? null : value)
    }

    function callEditor(method, args) {
        if (!webReady)
            return
        var parts = []
        for (var i = 0; i < args.length; i++)
            parts.push(js(args[i]))
        webView.runJavaScript("window.MedClawComposer." + method + "(" + parts.join(",") + ");")
    }

    function insertFile(displayName, path, isFolder) {
        var entry = { name: String(displayName || path), path: String(path || ""), folder: !!isFolder }
        if (!webReady) {
            var queued = pendingFiles.slice(0)
            queued.push(entry)
            pendingFiles = queued
            return
        }
        callEditor("insertFile", [entry.name, entry.path, entry.folder])
    }

    function focusEditor() {
        webView.forceActiveFocus()
        callEditor("focus", [])
    }

    function submit() {
        callEditor("submit", [])
    }

    onActiveFocusChanged: {
        if (activeFocus && !readOnly)
            focusEditor()
    }

    onTextChanged: {
        if (!syncingFromWeb)
            callEditor("setPlainText", [text])
    }

    onReadOnlyChanged: callEditor("setReadOnly", [readOnly])
    onPlaceholderTextChanged: callEditor("setPlaceholder", [placeholderText])

    WebEngineView {
        id: webView
        anchors.fill: parent
        anchors.margins: root.borderWidth
        url: "qrc:/web/prompt_composer.html"
        backgroundColor: "transparent"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status !== WebEngineLoadRequest.LoadSucceededStatus)
                return
            root.webReady = true
            root.callEditor("configure", [root.text, root.placeholderText, root.readOnly])
            for (var i = 0; i < root.pendingFiles.length; i++) {
                var file = root.pendingFiles[i]
                root.callEditor("insertFile", [file.name, file.path, file.folder])
            }
            root.pendingFiles = []
        }

        onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceId) {
            var prefix = "MEDCLAW_COMPOSER:"
            if (message.indexOf(prefix) !== 0)
                return
            var payload
            try {
                payload = JSON.parse(message.substring(prefix.length))
            } catch (error) {
                return
            }
            if (payload.type === "state") {
                root.syncingFromWeb = true
                root.text = payload.text || ""
                root.syncingFromWeb = false
                root.textContentHeight = Math.max(52, Number(payload.height) || 52)
            } else if (payload.type === "submit") {
                root.submitRequested(payload.text || "")
            } else if (payload.type === "fileHover") {
                root.fileTipText = payload.path || ""
                root.fileTipX = Number(payload.x) || 0
                root.fileTipY = Number(payload.y) || 0
                root.fileTipWidth = Number(payload.width) || 0
                root.fileTipHeight = Number(payload.height) || 0
                root.fileTipVisible = root.fileTipText.length > 0
            } else if (payload.type === "fileHoverEnd") {
                root.fileTipVisible = false
            }
        }
    }

    FilePathToolTip {
        visible: root.fileTipVisible
        text: root.fileTipText
        targetX: root.fileTipX
        targetY: root.fileTipY
        targetWidth: root.fileTipWidth
        targetHeight: root.fileTipHeight
    }
}
