import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine

// Qt 6.8: WebEngineScript cannot be declared as a QML child element
// ("Element is not creatable"). Chromium in 6.8 already provides
// Object.hasOwn / Array.at / CSS inset, so the Qt 5 injection scripts
// are not required.
WebEngineView {
    id: viewer
    property string viewerUrl: ""
    signal viewerLoadFailed(string message)
    signal viewerLoaded()
    signal saveAsUnavailable()
    property var popupWindows: []

    function popupHostWindow() {
        try {
            return viewer.Window.window
        } catch (err) {
            return null
        }
    }

    function placePopupWindow(popup, host) {
        if (!popup)
            return
        if (host && host.width > 0 && host.height > 0) {
            popup.x = host.x + Math.max(24, Math.round((host.width - popup.width) / 2))
            popup.y = host.y + Math.max(24, Math.round((host.height - popup.height) / 2))
        }
        popup.visible = true
        popup.show()
        popup.raise()
        popup.requestActivate()
    }

    function openNewView(request) {
        var host = popupHostWindow()
        var popup = popupWindowComponent.createObject(host)
        if (!popup) {
            request.openIn(viewer)
            return
        }
        popupWindows.push(popup)
        popup.destroyed.connect(function() {
            var index = popupWindows.indexOf(popup)
            if (index >= 0)
                popupWindows.splice(index, 1)
        })
        placePopupWindow(popup, host)
        request.openIn(popup.webView)
        Qt.callLater(function() { placePopupWindow(popup, host) })
    }

    function requestSave() {
        if (viewer.url.toString() === "about:blank")
            return false
        viewer.runJavaScript(
            "window.dispatchEvent(new KeyboardEvent('keydown',{key:'s',code:'KeyS',ctrlKey:true,bubbles:true,cancelable:true}));")
        return true
    }

    function requestSaveAs() {
        viewer.runJavaScript(
            "(function(){var fn=window.__officeViewerRequestSaveAs;return typeof fn==='function'&&fn()===true;})()",
            function(handled) {
                if (handled !== true)
                    viewer.saveAsUnavailable()
            })
    }

    url: viewerUrl.length > 0 ? viewerUrl : "about:blank"
    backgroundColor: "#FFFFFF"

    settings.javascriptEnabled: true
    settings.localStorageEnabled: true
    settings.javascriptCanOpenWindows: true
    settings.errorPageEnabled: false
    settings.fullScreenSupportEnabled: true
    settings.webGLEnabled: true
    settings.accelerated2dCanvasEnabled: true
    settings.localContentCanAccessRemoteUrls: true
    settings.localContentCanAccessFileUrls: true
    settings.allowRunningInsecureContent: true
    settings.javascriptCanAccessClipboard: true
    settings.pdfViewerEnabled: true
    settings.focusOnNavigationEnabled: true
    settings.allowWindowActivationFromJavaScript: true
    settings.unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes

    onNewWindowRequested: function(request) {
        viewer.openNewView(request)
    }

    onFullScreenRequested: function(request) {
        request.accept()
    }

    onJavaScriptConsoleMessage: function(level, message, lineNumber, sourceId) {
        console.log("[ViewerWeb]", level, sourceId, lineNumber, message)
    }

    onLoadingChanged: function(info) {
        console.log("[ViewerWeb] loading", viewer.url, "status", info ? info.status : -1,
                    "error", info && info.errorString ? info.errorString : "")
        var status = info ? info.status : -1
        var failed = status === 3
        var succeeded = status === 2
        if (typeof WebEngineLoadingInfo !== "undefined") {
            failed = status === WebEngineLoadingInfo.LoadFailedStatus
            succeeded = status === WebEngineLoadingInfo.LoadSucceededStatus
        } else if (typeof WebEngineView !== "undefined") {
            if (WebEngineView.LoadFailedStatus !== undefined)
                failed = status === WebEngineView.LoadFailedStatus
            if (WebEngineView.LoadSucceededStatus !== undefined)
                succeeded = status === WebEngineView.LoadSucceededStatus
        }
        var aborted = status === 1
                || String((info && info.errorString) || "").indexOf("ERR_ABORTED") >= 0
        var pdfPlugin = String(viewer.url).indexOf("/api/document") >= 0
        if (failed && !(aborted && pdfPlugin))
            viewerLoadFailed(info.errorString || "")
        else if (succeeded || (aborted && pdfPlugin))
            viewerLoaded()
    }

    Component {
        id: popupWindowComponent

        Window {
            id: popupWindow
            width: 1100
            height: 760
            minimumWidth: 480
            minimumHeight: 320
            visible: true
            flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
                   | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
            title: popupView.title || qsTr("HTML 预览")
            color: "#FFFFFF"
            property alias webView: popupView

            onClosing: destroy()

            WebEngineView {
                id: popupView
                anchors.fill: parent
                backgroundColor: "#FFFFFF"
                settings.javascriptEnabled: true
                settings.localStorageEnabled: true
                settings.javascriptCanOpenWindows: true
                settings.errorPageEnabled: false
                settings.fullScreenSupportEnabled: true
                settings.webGLEnabled: true
                settings.accelerated2dCanvasEnabled: true
                settings.localContentCanAccessRemoteUrls: true
                settings.localContentCanAccessFileUrls: true
                settings.allowRunningInsecureContent: true
                settings.javascriptCanAccessClipboard: true
                settings.focusOnNavigationEnabled: true
                settings.allowWindowActivationFromJavaScript: true
                settings.unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes

                onNewWindowRequested: function(request) {
                    viewer.openNewView(request)
                }

                onFullScreenRequested: function(request) {
                    request.accept()
                }

                onWindowCloseRequested: popupWindow.close()
            }
        }
    }
}
