import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine

// Qt 6.8: keep one mapped popup Window (dynamic Windows stay blank on
// Windows) and host multiple WebEngineView tabs inside it, like a browser.
WebEngineView {
    id: viewer
    property string viewerUrl: ""
    signal viewerLoadFailed(string message)
    signal viewerLoaded()
    signal saveAsUnavailable()
    property var popupViews: []
    property int currentPopupTab: -1

    function popupHostWindow() {
        try {
            if (viewer.Window && viewer.Window.window)
                return viewer.Window.window
        } catch (err) {
        }
        var node = viewer.parent
        while (node) {
            if (node.requestActivate && node.visibility !== undefined)
                return node
            node = node.parent
        }
        return null
    }

    function placePopupWindow() {
        var firstShow = !popupWindow.visible
        if (firstShow) {
            var host = popupHostWindow()
            if (host && host.width > 0 && host.height > 0) {
                popupWindow.x = host.x + Math.max(24, Math.round((host.width - popupWindow.width) / 2))
                popupWindow.y = host.y + Math.max(24, Math.round((host.height - popupWindow.height) / 2))
            }
        }
        popupWindow.visible = true
        popupWindow.show()
        popupWindow.raise()
        popupWindow.requestActivate()
    }

    function requestedUrlOf(request) {
        try {
            if (request && request.requestedUrl)
                return request.requestedUrl
        } catch (err) {
        }
        return ""
    }

    function applyRequestToView(request, webView) {
        var dest = requestedUrlOf(request)
        try {
            request.openIn(webView)
        } catch (err) {
            console.log("[ViewerWeb] openIn failed", err)
        }
        var destText = String(dest || "")
        if (destText && destText !== "about:blank")
            webView.url = dest
        Qt.callLater(function() {
            var current = String(webView.url || "")
            if (destText && destText !== "about:blank"
                    && (!current || current === "about:blank"))
                webView.url = dest
        })
    }

    function tabTitleOf(webView, fallback) {
        var title = ""
        try { title = String(webView.title || "") } catch (err) {}
        if (title)
            return title
        var href = String(webView.url || "")
        if (href && href !== "about:blank") {
            var parts = href.split("/")
            return parts[parts.length - 1] || href
        }
        return fallback || qsTr("新标签页")
    }

    function selectPopupTab(index) {
        if (index < 0 || index >= popupViews.length)
            return
        currentPopupTab = index
        for (var i = 0; i < popupViews.length; i++) {
            if (popupViews[i])
                popupViews[i].visible = (i === index)
        }
    }

    function addPopupTab(request) {
        var view = null
        if (popupViews.indexOf(firstTabView) < 0)
            view = firstTabView
        else
            view = extraTabComponent.createObject(tabHost)
        if (!view)
            return null
        view.anchors.fill = tabHost
        popupViews.push(view)
        popupTabs.append({ "title": qsTr("加载中...") })
        selectPopupTab(popupViews.length - 1)
        applyRequestToView(request, view)
        return view
    }

    function closePopupTab(index) {
        if (index < 0 || index >= popupViews.length)
            return
        var view = popupViews[index]
        popupViews.splice(index, 1)
        popupTabs.remove(index)
        if (view) {
            try { view.url = "about:blank" } catch (err) {}
            if (view !== firstTabView)
                view.destroy()
            else
                view.visible = false
        }
        if (popupViews.length === 0) {
            currentPopupTab = -1
            popupWindow.visible = false
            return
        }
        selectPopupTab(Math.min(index, popupViews.length - 1))
    }

    function openNewView(request) {
        placePopupWindow()
        if (!addPopupTab(request))
            request.openIn(viewer)
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
        if (failed && !aborted)
            viewerLoadFailed(info.errorString || "")
        else if (succeeded)
            viewerLoaded()
    }

    ListModel {
        id: popupTabs
    }

    Component {
        id: extraTabComponent
        WebEngineView {
            id: tabView
            visible: false
            profile: viewer.profile
            backgroundColor: "#FFFFFF"
            settings.javascriptEnabled: true
            settings.localStorageEnabled: true
            settings.javascriptCanOpenWindows: true
            settings.errorPageEnabled: true
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

            onTitleChanged: {
                var index = viewer.popupViews.indexOf(tabView)
                if (index >= 0 && index < popupTabs.count)
                    popupTabs.setProperty(index, "title", viewer.tabTitleOf(tabView))
            }
            onUrlChanged: {
                var index = viewer.popupViews.indexOf(tabView)
                if (index >= 0 && index < popupTabs.count && !tabView.title)
                    popupTabs.setProperty(index, "title", viewer.tabTitleOf(tabView))
            }
            onNewWindowRequested: function(request) {
                viewer.openNewView(request)
            }
            onFullScreenRequested: function(request) {
                request.accept()
            }
            onWindowCloseRequested: {
                var index = viewer.popupViews.indexOf(tabView)
                if (index >= 0)
                    viewer.closePopupTab(index)
            }
            onLoadingChanged: function(info) {
                console.log("[ViewerWeb tab] loading", tabView.url,
                            "status", info ? info.status : -1,
                            "error", info && info.errorString ? info.errorString : "")
            }
        }
    }

    Window {
        id: popupWindow
        width: 1100
        height: 760
        minimumWidth: 480
        minimumHeight: 320
        visible: false
        flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowSystemMenuHint
               | Qt.WindowMinMaxButtonsHint | Qt.WindowCloseButtonHint
        title: currentPopupTab >= 0 && currentPopupTab < popupTabs.count
               ? (popupTabs.get(currentPopupTab).title || qsTr("HTML 预览"))
               : qsTr("HTML 预览")
        color: "#F3F4F6"

        onClosing: function(close) {
            close.accepted = false
            while (popupViews.length > 0)
                closePopupTab(0)
        }

        Rectangle {
            id: tabBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 38
            color: "#E5E7EB"

            Flickable {
                id: tabFlick
                anchors.fill: parent
                anchors.rightMargin: 8
                contentWidth: tabRow.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: tabRow
                    height: parent.height
                    spacing: 0

                    Repeater {
                        model: popupTabs
                        Rectangle {
                            id: tabChip
                            required property int index
                            required property string title
                            width: Math.min(220, Math.max(120, tabTitle.implicitWidth + 44))
                            height: tabBar.height
                            color: index === currentPopupTab ? "#FFFFFF" : "transparent"
                            border.width: 0

                            Rectangle {
                                visible: index === currentPopupTab
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 2
                                color: "#006BFF"
                            }

                            Text {
                                id: tabTitle
                                anchors.left: parent.left
                                anchors.right: tabClose.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 4
                                text: tabChip.title || qsTr("新标签页")
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                color: "#111827"
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.rightMargin: 28
                                onClicked: selectPopupTab(tabChip.index)
                            }

                            Text {
                                id: tabClose
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                font.pixelSize: 16
                                color: tabCloseArea.containsMouse ? "#B91C1C" : "#6B7280"

                                MouseArea {
                                    id: tabCloseArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    onClicked: closePopupTab(tabChip.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: tabHost
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom

            WebEngineView {
                id: firstTabView
                anchors.fill: parent
                visible: false
                profile: viewer.profile
                backgroundColor: "#FFFFFF"
                settings.javascriptEnabled: true
                settings.localStorageEnabled: true
                settings.javascriptCanOpenWindows: true
                settings.errorPageEnabled: true
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

                onTitleChanged: {
                    var index = viewer.popupViews.indexOf(firstTabView)
                    if (index >= 0 && index < popupTabs.count)
                        popupTabs.setProperty(index, "title", viewer.tabTitleOf(firstTabView))
                }
                onUrlChanged: {
                    var index = viewer.popupViews.indexOf(firstTabView)
                    if (index >= 0 && index < popupTabs.count && !firstTabView.title)
                        popupTabs.setProperty(index, "title", viewer.tabTitleOf(firstTabView))
                }
                onNewWindowRequested: function(request) {
                    viewer.openNewView(request)
                }
                onFullScreenRequested: function(request) {
                    request.accept()
                }
                onWindowCloseRequested: {
                    var index = viewer.popupViews.indexOf(firstTabView)
                    if (index >= 0)
                        viewer.closePopupTab(index)
                }
            }
        }
    }
}
