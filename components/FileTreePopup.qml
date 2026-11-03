import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine
import QtQuick.Dialogs

// 文件树弹层：快捷键唤出，把一个文件夹拖进来即可浏览。
//
// 目录枚举由宿主（fileTreeProvider）完成，页面按需分块请求，所以
//   1) 不受 WebEngine 里 webkitGetAsEntry 拿不到 OS 拖拽路径的限制；
//   2) 大目录是边读边显示，而不是枚举完再一次性塞进来。
Item {
    id: root

    signal fileSelected(string path)

    property alias popupVisible: overlay.visible
    // 默认从资源里加载；测试时可用 file:// 覆盖
    property string pageUrl: "qrc:/web/file-tree.html"
    readonly property string shortcutText: "Ctrl+Shift+E"
    readonly property alias viewer: treeLoader.item

    // 页面还没加载完时先记下来，加载完成后再送过去
    property var pendingPaths: []
    property bool pageReady: false

    function open() {
        overlay.visible = true
        overlay.forceActiveFocus()
    }

    function close() {
        overlay.visible = false
        // 关掉即卸载 WebEngine，避免常驻一个渲染进程
        treeLoader.active = false
        pageReady = false
    }

    function toggle() {
        if (overlay.visible)
            close()
        else
            open()
    }

    /** 打开一个或多个本地路径：单个目录 → 作为根浏览；文件/多项 → 合成一个虚拟根 */
    function openPaths(localPaths) {
        var list = []
        for (var i = 0; i < localPaths.length; i++) {
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

    function openPath(localPath) {
        openPaths([localPath])
    }

    function pushPaths() {
        if (!treeLoader.item || !pendingPaths || pendingPaths.length === 0)
            return
        // 由宿主判断是文件还是目录（页面拿不到文件系统信息）
        var described = fileTreeProvider.describeAll(pendingPaths)
        treeLoader.item.runJavaScript(
                    "window.__fileTree && window.__fileTree.setHostPaths("
                    + JSON.stringify(described) + ")")
    }

    function jsQuote(text) {
        return JSON.stringify(String(text))
    }

    Component.onCompleted: {
        // 诊断：确认宿主侧的目录服务已注入（缺失时这里是 undefined）
        console.log("[TreePopup] fileTreeProvider=" + typeof fileTreeProvider)
    }

    anchors.fill: parent
    // 注意：不要写 visible: overlay.visible —— Item.visible 是"有效可见性"，
    // 父项不可见时子项读出来恒为 false，会形成循环绑定把赋值吞掉。
    z: 20000

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
        onAccepted: root.openPath(selectedFolder.toString())
    }

    Item {
        id: overlay
        anchors.fill: parent
        visible: false
        focus: visible

        Keys.onEscapePressed: root.close()
        onVisibleChanged: {
            if (visible)
                treeLoader.active = true
        }

        Rectangle {
            anchors.fill: parent
            color: "#40000000"
            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Rectangle {
            id: sheet
            width: Math.min(parent.width * 0.86, 1180)
            height: Math.min(parent.height * 0.86, 820)
            anchors.centerIn: parent
            radius: 12
            color: "#FFFFFF"
            clip: true

            // 拦截点击，避免穿透到遮罩把自己的弹层关掉
            MouseArea { anchors.fill: parent }

            Loader {
                id: treeLoader
                anchors.fill: parent
                active: false
                sourceComponent: WebEngineView {
                    anchors.fill: parent
                    backgroundColor: "transparent"
                    url: root.pageUrl

                    onLoadingChanged: function(info) {
                        if (info.status === WebEngineView.LoadSucceededStatus) {
                            root.pageReady = true
                            if (root.pendingPaths && root.pendingPaths.length > 0)
                                root.pushPaths()
                        }
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
                        if (payload.type === "close") {
                            root.close()
                        } else if (payload.type === "openFile") {
                            root.fileSelected(String(payload.path || ""))
                        } else if (payload.type === "listDir") {
                            // 页面要某一层的第 offset 段；宿主读完直接回调
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
                            thumbnailer.request(String(payload.id || ""),
                                                String(payload.path || ""))
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
                    if (!drop.hasUrls || drop.urls.length === 0)
                        return
                    var locals = []
                    for (var i = 0; i < drop.urls.length; i++) {
                        var local = drop.urls[i].toLocalFile()
                        if (local && local.length > 0)
                            locals.push(local)
                    }
                    root.openPaths(locals)
                }
            }
        }
    }
}
