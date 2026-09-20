import QtQuick 2.15
import QtQuick.Controls 2.15
import MedClaw.Viewer 1.0

Item {
    id: root
    clip: true

    property string filePath: ""
    property string mode: "view"
    property string editorSource: ""
    property string pendingMode: ""
    property bool saving: false
    property bool closeAfterSave: false
    property bool pdfMode: false
    readonly property bool busy: pdfMode || editorSource.length > 0
    readonly property string editorUrl: editorSource
    readonly property string lastError: pdfMode ? pdfView.lastError : viewerHost.lastError

    signal documentSaved(string filePath)
    signal saveFinished(string filePath, bool saved)
    signal sessionClosed(string filePath, bool saved)
    signal editorLoaded(string editorMode)

    function isPdfPath(path) {
        var name = String(path || "").replace(/\\/g, "/").split("/").pop().toLowerCase()
        return name.length >= 4 && name.substring(name.length - 4) === ".pdf"
    }

    function open(path, requestedMode) {
        var targetPath = String(path || filePath)
        var targetMode = requestedMode === "edit" ? "edit" : "view"
        if (!targetPath)
            return false

        filePath = targetPath
        saving = false
        pendingMode = ""
        closeAfterSave = false

        if (isPdfPath(targetPath)) {
            viewerHost.closeDocument()
            editorSource = ""
            pdfMode = true
            mode = "view"
            console.log("[LocalOffice] open pdf", targetPath)
            if (!pdfView.open(targetPath))
                return false
            return true
        }

        pdfMode = false
        pdfView.close()
        mode = targetMode
        editorSource = viewerHost.openDocument(filePath, mode === "view", "zh-CN")
        console.log("[LocalOffice] open", targetPath, "mode", mode,
                    "url", editorSource, "error", viewerHost.lastError)
        if (!editorSource) {
            saving = false
            pendingMode = ""
            return false
        }
        return true
    }

    function finishClose(saved) {
        var closedPath = filePath
        closeFallbackTimer.stop()
        editorSource = ""
        pdfMode = false
        pdfView.close()
        viewerHost.closeDocument()
        saving = false
        pendingMode = ""
        closeAfterSave = false
        sessionClosed(closedPath, saved === true)
    }

    function closeEditor() {
        if (pdfMode) {
            finishClose(false)
            return
        }
        const currentUrl = String(viewerWebView.url || "")
        const editorAlive = currentUrl.indexOf("/index.html") >= 0
                         || currentUrl.indexOf("/markdown/") >= 0
                         || currentUrl.indexOf("/api/html/") >= 0
        if (mode === "edit" && editorAlive && busy) {
            closeAfterSave = true
            saving = true
            if (!viewerWebView.requestSave()) {
                finishClose(false)
                return
            }
            closeFallbackTimer.restart()
            return
        }
        finishClose(false)
    }

    function saveEditor() {
        if (pdfMode || !busy || mode !== "edit" || saving)
            return false
        saving = true
        if (!viewerWebView.requestSave()) {
            saving = false
            saveFinished(filePath, false)
            return false
        }
        saveFallbackTimer.restart()
        return true
    }

    function saveAndSwitchMode(requestedMode) {
        if (!busy || mode !== "edit" || saving)
            return false
        pendingMode = requestedMode === "edit" ? "edit" : "view"
        if (!saveEditor()) {
            pendingMode = ""
            return false
        }
        return true
    }

    function switchMode(requestedMode) {
        var targetMode = requestedMode === "edit" ? "edit" : "view"
        if (pdfMode) {
            mode = "view"
            return
        }
        if (targetMode === mode)
            return
        if (mode === "edit" && targetMode === "view") {
            saveAndSwitchMode(targetMode)
            return
        }
        open(filePath, targetMode)
    }

    function cancel() {
        finishClose(false)
    }

    ViewerHost {
        id: viewerHost

        onDocumentSaved: function(path) {
            saveFallbackTimer.stop()
            closeFallbackTimer.stop()
            root.saving = false
            root.documentSaved(path)
            root.saveFinished(path, true)

            if (root.closeAfterSave) {
                root.finishClose(true)
            } else if (root.pendingMode.length > 0) {
                var nextMode = root.pendingMode
                root.pendingMode = ""
                Qt.callLater(function() { root.open(root.filePath, nextMode) })
            }
        }
    }

    PdfView {
        id: pdfView
        anchors.fill: parent
        visible: root.pdfMode
        onLoaded: root.editorLoaded("view")
        onLoadFailed: function(message) {
            root.saving = false
            root.saveFinished(root.filePath, false)
        }
    }

    ViewerWebView {
        id: viewerWebView
        anchors.fill: parent
        visible: !root.pdfMode
        viewerUrl: root.pdfMode ? "" : root.editorSource

        onViewerLoaded: root.editorLoaded(root.mode)
        onViewerLoadFailed: function(message) {
            root.saving = false
            root.saveFinished(root.filePath, false)
        }
    }

    Timer {
        id: saveFallbackTimer
        interval: 15000
        repeat: false
        onTriggered: {
            root.saving = false
            root.pendingMode = ""
            root.saveFinished(root.filePath, false)
        }
    }

    Timer {
        id: closeFallbackTimer
        interval: 15000
        repeat: false
        onTriggered: root.finishClose(false)
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: !root.pdfMode && root.editorSource.length === 0 && root.lastError.length === 0
        visible: running
        palette.dark: "#006BFF"
        palette.mid: "#006BFF"
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        visible: !root.pdfMode && root.lastError.length > 0 && root.editorSource.length === 0
        text: root.lastError
        color: "#b91c1c"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}

