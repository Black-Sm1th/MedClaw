import QtQuick 2.15
import QtWebEngine 1.10

Item {
    id: root

    property var model: null
    property bool webReady: false
    property bool forceFullSyncPending: false
    property bool fileTipVisible: false
    property string fileTipText: ""
    property real fileTipX: 0
    property real fileTipY: 0
    property real fileTipWidth: 0
    property real fileTipHeight: 0

    signal linkActivated(string link)
    signal artifactsRequested()
    signal artifactRequested(string path)

    function js(value) {
        return JSON.stringify(value === undefined ? null : value)
    }

    function syncMessages() {
        syncTimer.stop()
        if (!webReady || !model || !model.messages)
            return
        var forceFullSync = forceFullSyncPending
        forceFullSyncPending = false
        webView.runJavaScript("window.MedClawChat.setMessages("
                              + JSON.stringify(model.messages()) + ","
                              + (forceFullSync ? "true" : "false") + ");")
    }

    function scheduleSyncMessages(forceFullSync) {
        if (!webReady || !model || !model.messages)
            return
        if (forceFullSync === true)
            forceFullSyncPending = true
        syncTimer.restart()
    }

    function appendStreamDelta(row, delta) {
        if (!webReady || !delta || delta.length === 0)
            return
        webView.runJavaScript("window.MedClawChat.appendStreamDelta("
                              + Number(row) + ","
                              + js(delta) + ");")
    }

    function scrollToBottom() {
        if (!webReady)
            return
        webView.runJavaScript("window.MedClawChat.scrollToBottom();")
    }

    Component.onCompleted: scheduleSyncMessages(true)
    onModelChanged: scheduleSyncMessages(true)

    Timer {
        id: syncTimer
        interval: 40
        repeat: false
        onTriggered: root.syncMessages()
    }

    Connections {
        target: root.model

        function onCountChanged() {
            root.scheduleSyncMessages()
        }

        function onDataChanged() {
            root.scheduleSyncMessages()
        }

        function onModelReset() {
            root.scheduleSyncMessages(true)
        }

        function onIsStreamingChanged() {
            root.scheduleSyncMessages()
        }

        function onStreamFlushed(row, delta) {
            root.appendStreamDelta(row, delta)
        }

    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: "qrc:/web/chat_view.html"
        backgroundColor: "transparent"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
                root.webReady = true
                root.scheduleSyncMessages(true)
            }
        }

        onNavigationRequested: function(request) {
            if (request.url.toString() !== "qrc:/web/chat_view.html") {
                request.action = WebEngineNavigationRequest.IgnoreRequest
                root.linkActivated(request.url.toString())
            }
        }

        onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceId) {
            var prefix = "MEDCLAW_CHAT:"
            if (message.indexOf(prefix) !== 0)
                return
            var payload
            try {
                payload = JSON.parse(message.substring(prefix.length))
            } catch (error) {
                return
            }
            if (payload.type === "fileHover") {
                root.fileTipText = payload.path || ""
                root.fileTipX = Number(payload.x) || 0
                root.fileTipY = Number(payload.y) || 0
                root.fileTipWidth = Number(payload.width) || 0
                root.fileTipHeight = Number(payload.height) || 0
                root.fileTipVisible = root.fileTipText.length > 0
            } else if (payload.type === "fileHoverEnd") {
                root.fileTipVisible = false
            } else if (payload.type === "openArtifacts") {
                root.artifactsRequested()
            } else if (payload.type === "openArtifact") {
                root.artifactRequested(payload.path || "")
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
