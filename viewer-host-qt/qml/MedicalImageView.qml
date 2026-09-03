import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine 1.10
import MedClaw.Viewer 1.0

// Qt5.15 WebEngine wrapper for the copied Cornerstone3D bundle. Local files
// never use file://; ViewerHost exposes a short-lived, session-scoped HTTP URL.
Item {
    id: root

    property string filePath: ""
    property string mode: "view"
    property string viewerSource: ""
    readonly property bool busy: viewerSource.length > 0
    readonly property bool saving: false
    readonly property string lastError: viewerHost.lastError

    signal documentSaved(string filePath)
    signal saveFinished(string filePath, bool saved)
    signal sessionClosed(string filePath, bool saved)
    signal editorLoaded(string editorMode)
    signal viewerLoadFailed(string message)
    signal viewerLoaded()

    function open(path, requestedMode) {
        var target = String(path || filePath)
        if (!target)
            return false
        viewerHost.closeDocument()
        filePath = target
        mode = "view"
        viewerSource = viewerHost.openMedicalImage(target)
        if (!viewerSource)
            return false
        return true
    }

    function closeEditor() {
        if (!busy)
            return
        var closedPath = filePath
        viewerSource = ""
        viewerHost.closeDocument()
        sessionClosed(closedPath, false)
    }

    function cancel() {
        closeEditor()
    }

    function setLayout(layout) {
        if (!busy)
            return false
        var value = JSON.stringify(String(layout || "single"))
        viewer.runJavaScript("window.__medclawSetLayout && window.__medclawSetLayout(" + value + ");")
        return true
    }

    ViewerHost {
        id: viewerHost
    }

    ViewerWebView {
        id: viewer
        anchors.fill: parent
        viewerUrl: root.viewerSource

        onViewerLoaded: {
            root.viewerLoaded()
            root.editorLoaded("view")
            // The page also auto-starts the bridge. Calling it here makes the
            // handoff deterministic when Qt reports LoadSucceeded late.
            Qt.callLater(function() {
                viewer.runJavaScript("window.__medclawLoad && window.__medclawLoad();")
            })
        }
        onViewerLoadFailed: {
            root.viewerLoadFailed(message)
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.viewerSource.length === 0 && root.lastError.length === 0
        visible: running
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 520)
        visible: root.lastError.length > 0 && root.viewerSource.length === 0
        text: root.lastError
        color: "#b91c1c"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
