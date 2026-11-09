import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine
import QtQuick.Dialogs

/**
 * 「输入文件」树：只含树本身，不带弹层外壳。
 *
 * 给工作区浮层（WorkspaceOverlay）复用。页面通过 setEmbedMode 去掉自带的
 * 头部按钮、预览区和底栏；目录枚举、缩略图仍然走宿主（fileTreeProvider /
 * Thumbnailer），和 Ctrl+Shift+E 的独立弹层用的是同一套。
 */
Item {
    id: root

    /// 双击/回车打开某个文件
    signal fileSelected(string path)
    /// 页面加载完成、嵌入模式已生效（宿主可以在这之后喂路径）
    signal fileTreeReady()
    /// 勾选集合变化（路径数组）
    signal selectionChanged(var paths)
    /// 拖入了一批路径：由宿主决定是替换还是追加
    signal dropPaths(var paths)

    property string pageUrl: "qrc:/web/file-tree.html"
    /// 页面还没加载完时先记下来，加载完成后再送过去
    property var pendingPaths: []
    property bool pageReady: false
    /// 树字号/行高缩放（宿主用 −/+ 按钮调，1.0 是默认）
    property real zoomScale: 1.0

    onZoomScaleChanged: applyZoom()

    function applyZoom() {
        if (!treeLoader.item)
            return
        treeLoader.item.runJavaScript(
                    "window.__fileTree && window.__fileTree.setZoom("
                    + Number(zoomScale) + ")")
    }

    readonly property alias viewer: treeLoader.item

    /// QML 的 url 值没有 toLocalFile()（Qt 6 里调用会抛 TypeError，
    /// 拖放回调直接中断，表现就是"拖进来没反应"）。这里自己转成本地路径。
    function localPathFromUrl(value) {
        var path = String(value || "")
        if (path.indexOf("file://") === 0)
            path = decodeURIComponent(path.replace(/^file:\/\/{2,3}/, ""))
        if (Qt.platform.os === "windows") {
            if (path.length >= 3 && path.charAt(0) === "/" && path.charAt(2) === ":")
                path = path.substring(1)
            path = path.replace(/\//g, "\\")
        } else if (Qt.platform.os === "linux" || Qt.platform.os === "osx") {
            if (path.charAt(0) !== "/")
                path = "/" + path
        }
        return path
    }

    function openPaths(localPaths) {
        var list = []
        for (var i = 0; i < localPaths.length; ++i) {
            var item = String(localPaths[i] || "")
            if (item.length > 0)
                list.push(item)
        }
        if (list.length === 0)
            return
        pendingPaths = list
        if (pageReady)
            pushPaths()
    }

    /// 产物树：直接给「文件夹 → 文件」的分组，页面按文件夹形式渲染
    property var pendingArtifacts: []

    function openArtifacts(groups) {
        pendingArtifacts = groups || []
        if (pageReady)
            pushArtifacts()
        else
            pendingPaths = []
    }

    function pushArtifacts() {
        if (!treeLoader.item)
            return
        treeLoader.item.runJavaScript(
                    "window.__fileTree && window.__fileTree.setArtifactNodes("
                    + JSON.stringify(pendingArtifacts || []) + ")")
    }

    function pushPaths() {
        if (!treeLoader.item || !pendingPaths || pendingPaths.length === 0)
            return
        var described = fileTreeProvider.describeAll(pendingPaths)
        treeLoader.item.runJavaScript(
                    "window.__fileTree && window.__fileTree.setHostPaths("
                    + JSON.stringify(described) + ")")
    }

    // 注意：这里不要写 anchors.fill: parent —— 组件自身再锚一次会覆盖调用方设置的
    // anchors.top/bottom，导致它铺满父项、把标题栏盖住。
    Connections {
        target: thumbnailer
        function onReady(requestId, path, dataUrl, width, height) {
            var view = treeLoader.item
            if (view)
                view.runJavaScript("window.__fileTree && window.__fileTree.onThumbResult("
                                   + JSON.stringify(String(requestId)) + ","
                                   + JSON.stringify(String(dataUrl)) + ","
                                   + Number(width) + "," + Number(height) + ",\"\")")
        }
        function onFailed(requestId, path, reason) {
            var view = treeLoader.item
            if (view)
                view.runJavaScript("window.__fileTree && window.__fileTree.onThumbResult("
                                   + JSON.stringify(String(requestId)) + ",\"\",0,0,"
                                   + JSON.stringify(String(reason)) + ")")
        }
    }

    FolderDialog {
        id: folderDialog
        title: "选择要浏览的文件夹"
        onAccepted: root.openPaths([selectedFolder.toString()])
    }

    Loader {
        id: treeLoader
        anchors.fill: parent
        // 只在面板露出来时才创建 WebEngine（并排模式关掉就卸掉）
        active: root.visible
        sourceComponent: WebEngineView {
            anchors.fill: parent
            backgroundColor: "transparent"
            url: root.pageUrl

            onLoadingChanged: function(info) {
                if (info.status !== WebEngineView.LoadSucceededStatus)
                    return
                root.pageReady = true
                // 去掉页面自带的头部/预览/底栏
                runJavaScript("window.__fileTree && window.__fileTree.setEmbedMode(true)")
                root.applyZoom()
                if (root.pendingPaths && root.pendingPaths.length > 0)
                    root.pushPaths()
                else if (root.pendingArtifacts && root.pendingArtifacts.length > 0)
                    root.pushArtifacts()
                root.fileTreeReady()
            }

            onJavaScriptConsoleMessage: function(level, message) {
                var prefix = "MEDCLAW_TREE:"
                if (message.indexOf(prefix) !== 0)
                    return
                var payload
                try {
                    payload = JSON.parse(message.substring(prefix.length))
                } catch (error) {
                    return
                }
                if (payload.type === "openFile") {
                    root.fileSelected(String(payload.path || ""))
                } else if (payload.type === "selection") {
                    root.selectionChanged(payload.paths || [])
                } else if (payload.type === "listDir") {
                    var result = fileTreeProvider.list(String(payload.path || ""),
                                                       Number(payload.offset) || 0,
                                                       Number(payload.limit) || 300)
                    var js = "window.__fileTree && window.__fileTree.onDirChunk("
                            + (Number(payload.id) || 0) + ","
                            + JSON.stringify(result) + ")"
                    var view = treeLoader.item
                    if (view)
                        view.runJavaScript(js)
                } else if (payload.type === "thumb") {
                    thumbnailer.request(String(payload.id || ""), String(payload.path || ""))
                } else if (payload.type === "pickFolder") {
                    folderDialog.open()
                } else if (payload.type === "readFile") {
                    var text = fileTreeProvider.readText(String(payload.path || ""),
                                                         Number(payload.maxBytes) || 524288)
                    var view2 = treeLoader.item
                    if (view2)
                        view2.runJavaScript("window.__fileTree && window.__fileTree.onFileRead("
                                            + (Number(payload.id) || 0) + ","
                                            + JSON.stringify(text) + ")")
                } else if (payload.type === "resetCache") {
                    fileTreeProvider.reset()
                }
            }
        }
    }

    // 原生接管拖拽：只有这里能拿到文件夹的真实绝对路径
    DropArea {
        anchors.fill: parent
        z: 10
        onEntered: function(drag) {
            if (drag.hasUrls)
                drag.accepted = true
            console.log("[FileTreeDrop] entered urls=" + (drag.urls ? drag.urls.length : -1))
            var view = treeLoader.item
            if (view)
                view.runJavaScript("document.body.classList.add('dragging')")
        }
        onExited: {
            var view = treeLoader.item
            if (view)
                view.runJavaScript("document.body.classList.remove('dragging')")
        }
        onDropped: function(drop) {
            var view = treeLoader.item
            if (view)
                view.runJavaScript("document.body.classList.remove('dragging')")
            console.log("[FileTreeDrop] dropped hasUrls=" + drop.hasUrls
                        + " count=" + (drop.urls ? drop.urls.length : -1))
            if (!drop.hasUrls || drop.urls.length === 0)
                return
            var locals = []
            for (var i = 0; i < drop.urls.length; ++i) {
                var local = root.localPathFromUrl(drop.urls[i])
                if (local && local.length > 0)
                    locals.push(local)
            }
            if (locals.length === 0)
                return
            drop.acceptProposedAction()
            // 交给宿主：可能需要弹框问"追加还是替换"
            root.dropPaths(locals)
        }
    }
}
