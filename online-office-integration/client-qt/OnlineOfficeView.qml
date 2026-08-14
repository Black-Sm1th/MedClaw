import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine 1.10

Item {
    id: root

    property var client: null
    property string filePath: ""
    property string mode: "view"
    property bool autoOpen: false
    property string pendingPath: ""
    property string pendingMode: ""
    property string reportedLoadedUrl: ""
    property bool appReady: false
    readonly property string appReadyTitle: "MEDCLAW_OFFICE_APP_READY"
    readonly property bool loading: client ? client.busy && webView.url.toString() === "about:blank" : false
    readonly property string errorText: client ? client.lastError : ""

    signal documentSaved(string filePath)
    signal saveFinished(string filePath, bool saved)
    signal sessionClosed(string filePath, bool saved)
    signal editorLoaded(string editorMode)

    function reportEditorLoaded(forceReady) {
        var currentUrl = webView.url.toString()
        if (currentUrl === "about:blank" || currentUrl === reportedLoadedUrl)
            return
        if (!appReady && forceReady !== true)
            return
        reportedLoadedUrl = currentUrl
        editorLoadSettleTimer.stop()
        editorLoadFallbackTimer.stop()
        viewportResizeTimer.restart()
        root.editorLoaded(root.mode)
    }

    function refreshEditorViewport() {
        if (webView.url.toString() === "about:blank")
            return
        webView.runJavaScript(
            "(function(){"
            + "var root=document.getElementById('editor');"
            + "if(root){root.style.width='100%';root.style.height='100%';}"
            + "var frame=root&&root.querySelector('iframe');"
            + "if(frame){frame.style.width='100%';frame.style.height='100%';}"
            + "window.dispatchEvent(new Event('resize'));"
            + "try{if(frame&&frame.contentWindow)frame.contentWindow.dispatchEvent(new Event('resize'));}catch(e){}"
            + "})();")
    }

    function open(path, requestedMode) {
        if (!client)
            return
        var targetPath = String(path || filePath)
        var targetMode = requestedMode === "edit" ? "edit" : "view"
        if (!targetPath)
            return
        if (client.busy) {
            if (targetPath === filePath && targetMode === mode
                    && pendingPath.length === 0)
                return
            pendingPath = targetPath
            pendingMode = targetMode
            closeEditor()
            return
        }
        filePath = targetPath
        mode = targetMode
        client.openDocument(filePath, mode)
    }

    function closeEditor() {
        if (!client || !client.busy)
            return
        if (webView.url.toString() === "about:blank") {
            client.cancel()
            return
        }
        if (mode === "edit") {
            client.finishDocument()
            return
        }
        webView.url = "about:blank"
        closeTimer.restart()
    }

    function saveEditor() {
        if (!client || !client.busy || mode !== "edit"
                || webView.url.toString() === "about:blank")
            return
        client.saveDocument()
    }

    function saveAndSwitchMode(requestedMode) {
        if (!client || !client.busy || mode !== "edit"
                || webView.url.toString() === "about:blank")
            return false
        var normalized = requestedMode === "edit" ? "edit" : "view"
        pendingPath = filePath
        pendingMode = normalized
        client.saveDocument()
        return true
    }

    function switchMode(requestedMode) {
        var normalized = requestedMode === "edit" ? "edit" : "view"
        if (normalized === mode)
            return
        pendingPath = filePath
        pendingMode = normalized
        closeEditor()
    }

    Component.onCompleted: {
        if (autoOpen && filePath.length > 0)
            open(filePath, mode)
    }

    Timer {
        id: closeTimer
        interval: 250
        repeat: false
        onTriggered: if (root.client) root.client.finishDocument()
    }

    Timer {
        id: viewportResizeTimer
        interval: 80
        repeat: false
        onTriggered: root.refreshEditorViewport()
    }

    Timer {
        id: editorLoadSettleTimer
        interval: 120
        repeat: false
        onTriggered: root.reportEditorLoaded(false)
    }

    Timer {
        id: editorLoadFallbackTimer
        interval: 5000
        repeat: false
        onTriggered: root.reportEditorLoaded(true)
    }

    Connections {
        target: root.client

        function onEditorReady(url) {
            closeTimer.stop()
            root.reportedLoadedUrl = ""
            root.appReady = false
            webView.url = url
            editorLoadFallbackTimer.restart()
        }

        function onDocumentSaved(path) {
            root.documentSaved(path)
        }

        function onSaveFinished(path, saved) {
            root.saveFinished(path, saved)
            if (root.pendingPath.length > 0) {
                if (saved) {
                    // The edited file is already downloaded locally; only dispose
                    // the old edit session before opening the read-only session.
                    root.client.cancel()
                } else {
                    root.pendingPath = ""
                    root.pendingMode = ""
                }
            }
        }

        function onSessionFinished(path, saved) {
            closeTimer.stop()
            webView.url = "about:blank"
            root.sessionClosed(path, saved)
            if (root.pendingPath.length > 0) {
                var nextPath = root.pendingPath
                var nextMode = root.pendingMode || "view"
                root.pendingPath = ""
                root.pendingMode = ""
                root.open(nextPath, nextMode)
            }
        }
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: "about:blank"
        backgroundColor: "#ffffff"

        onWidthChanged: viewportResizeTimer.restart()
        onHeightChanged: viewportResizeTimer.restart()
        onTitleChanged: {
            if (title === root.appReadyTitle) {
                root.appReady = true
                editorLoadSettleTimer.restart()
            }
        }

        settings.javascriptEnabled: true
        settings.localStorageEnabled: true
        settings.javascriptCanOpenWindows: true
        settings.errorPageEnabled: true

        userScripts: [
            WebEngineScript {
                injectionPoint: WebEngineScript.DocumentCreation
                worldId: WebEngineScript.MainWorld
                runOnSubframes: true
                sourceCode: "if(typeof Object.hasOwn!=='function'){Object.defineProperty(Object,'hasOwn',{configurable:true,writable:true,value:function(o,p){if(o===null||o===undefined)throw new TypeError('null');return Object.prototype.hasOwnProperty.call(Object(o),p);}});}"
            }
        ]

    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.loading
        visible: running
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        visible: root.errorText.length > 0 && webView.url.toString() === "about:blank"
        text: root.errorText
        color: "#b91c1c"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
