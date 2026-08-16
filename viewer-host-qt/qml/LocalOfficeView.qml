import QtQuick 2.15
import QtQuick.Controls 2.15
import MedClaw.Viewer 1.0

Item {
    id: root

    property string filePath: ""
    property string mode: "view"
    property string editorSource: ""
    property string pendingMode: ""
    property bool saving: false
    property bool closeAfterSave: false
    readonly property bool busy: editorSource.length > 0
    readonly property string editorUrl: editorSource
    readonly property string lastError: viewerHost.lastError

    signal documentSaved(string filePath)
    signal saveFinished(string filePath, bool saved)
    signal sessionClosed(string filePath, bool saved)
    signal editorLoaded(string editorMode)

    function open(path, requestedMode) {
        var targetPath = String(path || filePath)
        var targetMode = requestedMode === "edit" ? "edit" : "view"
        if (!targetPath)
            return false

        viewerHost.closeDocument()
        filePath = targetPath
        mode = targetMode
        editorSource = viewerHost.openDocument(filePath, mode === "view", "zh-CN")
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
        viewerHost.closeDocument()
        saving = false
        pendingMode = ""
        closeAfterSave = false
        sessionClosed(closedPath, saved === true)
    }

    function closeEditor() {
        if (!busy)
            return
        if (mode === "edit") {
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
        if (!busy || mode !== "edit" || saving)
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

    ViewerWebView {
        id: viewerWebView
        anchors.fill: parent
        viewerUrl: root.editorSource

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
        running: root.editorSource.length === 0 && root.lastError.length === 0
        visible: running
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        visible: root.lastError.length > 0 && root.editorSource.length === 0
        text: root.lastError
        color: "#b91c1c"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}

