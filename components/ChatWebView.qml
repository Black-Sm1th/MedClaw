import QtQuick 2.15
import QtWebEngine 1.10

Item {
    id: root

    property var model: null
    property bool webReady: false

    signal linkActivated(string link)

    function js(value) {
        return JSON.stringify(value === undefined ? null : value)
    }

    function syncMessages() {
        syncTimer.stop()
        if (!webReady || !model || !model.messages)
            return
        webView.runJavaScript("window.MedClawChat.setMessages("
                              + JSON.stringify(model.messages()) + ");")
    }

    function scheduleSyncMessages() {
        if (!webReady || !model || !model.messages)
            return
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

    Component.onCompleted: scheduleSyncMessages()
    onModelChanged: scheduleSyncMessages()

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
            root.scheduleSyncMessages()
        }

        function onIsStreamingChanged() {
            root.scheduleSyncMessages()
        }

        function onStreamFlushed(row, delta) {
            root.appendStreamDelta(row, delta)
        }

        function onMessagePayloadChanged() {
            root.scrollToBottom()
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
                root.scheduleSyncMessages()
            }
        }

        onNavigationRequested: function(request) {
            if (request.url.toString() !== "qrc:/web/chat_view.html") {
                request.action = WebEngineNavigationRequest.IgnoreRequest
                root.linkActivated(request.url.toString())
            }
        }
    }
}
