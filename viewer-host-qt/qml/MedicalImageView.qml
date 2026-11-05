import QtQuick 2.15
import QtQuick.Controls 2.15
import QtWebEngine
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
    /// 顶部序列缩略图条被点击：宿主据此切换标签
    signal seriesPicked(string path)

    function open(path, requestedMode) {
        var target = String(path || filePath)
        if (!target)
            return false
        viewerHost.closeDocument()
        filePath = target
        mode = "view"
        viewerSource = viewerHost.openMedicalImage(target)
        console.log("[MedicalView] open path=" + target
                    + " ok=" + (viewerSource.length > 0)
                    + " err=" + viewerHost.lastError)
        if (!viewerSource)
            return false
        return true
    }

    function addFile(path) {
        var target = String(path || "")
        if (!target)
            return false
        if (!viewerSource)
            return open(target, "view")
        var url = viewerHost.addMedicalImage(target)
        if (!url)
            return false
        if (viewerSource === url)
            return false
        filePath = target
        viewerSource = url
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

    /// 喂给查看器内部顶部缩略图条的数据（页面加载完再真正下发）
    property var pendingSeriesStrip: null

    function applySeriesStrip() {
        if (!busy || !pendingSeriesStrip)
            return false
        var payload = JSON.stringify(pendingSeriesStrip.items || [])
        var active = JSON.stringify(String(pendingSeriesStrip.active || ""))
        viewer.runJavaScript(
                    "window.__medclawSetSeriesStrip && window.__medclawSetSeriesStrip("
                    + payload + "," + active + ");")
        return true
    }

    /// 把「已打开的影像」列表喂给查看器内部的顶部缩略图条。
    /// 页面可能还没加载完，先存起来，onViewerLoaded 里会补发一次。
    function setSeriesStrip(items, activePath) {
        pendingSeriesStrip = { items: items || [], active: String(activePath || "") }
        return applySeriesStrip()
    }

    function setLayout(layout) {
        if (!busy)
            return false
        var value = JSON.stringify(String(layout || "single"))
        viewer.runJavaScript("window.__medclawSetLayout && window.__medclawSetLayout(" + value + ");")
        return true
    }

    // ---------------------------------------------------------------------
    // Agent control channel (POST /api/viewer -> ViewerHost.controlRequest)
    // ---------------------------------------------------------------------
    function handleControl(requestId, action, args) {
        var a = args || {}
        var name = String(action || "").toLowerCase()
        if (name === "status") {
            replyStatus(requestId)
            return
        }
        if (name === "layout") {
            var layout = String(a.layout || a.value || "single")
            var ok = root.setLayout(layout)
            viewerHost.replyControl(requestId, ok, { "layout": layout })
            return
        }
        if (name === "open" || name === "add") {
            var path = String(a.path || a.file || "")
            if (!path) {
                viewerHost.replyControl(requestId, false, { "error": "path is required" })
                return
            }
            var changed = (name === "open") ? root.open(path, "view") : root.addFile(path)
            viewerHost.replyControl(requestId, !!changed, { "path": path })
            return
        }
        if (name === "close") {
            root.closeEditor()
            viewerHost.replyControl(requestId, true, {})
            return
        }
        if (name === "screenshot") {
            captureScreenshot(requestId)
            return
        }
        var script = scriptFor(name, a)
        if (!script) {
            viewerHost.replyControl(requestId, false, { "error": "unknown action: " + name })
            return
        }
        runJsAndReply(requestId, script)
    }

    function replyStatus(requestId) {
        var base = {
            "filePath": root.filePath,
            "busy": root.busy,
            "port": viewerHost.port,
            "viewerSource": root.viewerSource,
            "layout": "",
            "masks": []
        }
        var script = "(function(){" +
            "var layoutEl=document.querySelector('[data-medclaw-layout]');" +
            "var layout=layoutEl?String(layoutEl.getAttribute('data-medclaw-layout')||''):'';" +
            "var masks=Array.prototype.slice.call(document.querySelectorAll('[data-mask-id]')).map(function(card){" +
            "  var id=card.getAttribute('data-mask-id');" +
            "  var vis=card.querySelector('[data-mask-action=\"visible\"]');" +
            "  var op=card.querySelector('[data-mask-action=\"opacity\"]');" +
            "  return {id:id,visible:vis?!!vis.checked:null,opacity:op?Number(op.value):null};});" +
            "var series=document.getElementById('seriesName');" +
            "return {layout:layout,masks:masks,series:series?String(series.textContent||''):''};})()"
        viewer.runJavaScript(script, function(result) {
            var payload = {}
            for (var k in base)
                payload[k] = base[k]
            if (result && typeof result === "object") {
                for (var r in result)
                    payload[r] = result[r]
            }
            viewerHost.replyControl(requestId, true, payload)
        })
    }

    function runJsAndReply(requestId, script) {
        viewer.runJavaScript(script, function(result) {
            var payload = {}
            if (result && typeof result === "object") {
                for (var k in result)
                    payload[k] = result[k]
            } else if (result !== undefined) {
                payload["value"] = String(result)
            }
            var ok = (payload.ok !== false)
            viewerHost.replyControl(requestId, ok, payload)
        })
    }

    function captureScreenshot(requestId) {
        if (!root.busy) {
            viewerHost.replyControl(requestId, false, { "error": "viewer is not open" })
            return
        }
        var path = viewerHost.newScreenshotPath()
        viewer.grabToImage(function(result) {
            var saved = !!(result && result.saveToFile(path))
            viewerHost.replyControl(requestId, saved, {
                "path": saved ? path : "",
                "error": saved ? "" : "grabToImage failed"
            })
        })
    }

    // The Cornerstone3D bundle exposes layout/fit/overlay only. Window presets,
    // slice navigation and mask controls are driven through the same DOM
    // controls the UI itself uses; keep every selector here so a viewer
    // rebuild only requires updating this function.
    function scriptFor(name, a) {
        var payload = JSON.stringify(a || {})
        if (name === "fit") {
            return "(function(){var ok=typeof window.__medclawFitViewport==='function';" +
                   "if(ok)window.__medclawFitViewport();return {ok:ok};})()"
        }
        if (name === "window") {
            return "(function(a){" +
                "var map={soft:'软组织',lung:'肺窗',bone:'骨窗',brain:'脑窗',abdomen:'腹部',auto:'自动窗'};" +
                "var want=map[String(a.preset||'').toLowerCase()]||String(a.preset||'');" +
                "var nodes=Array.prototype.slice.call(document.querySelectorAll('button,[data-tool],.tool,.preset'));" +
                "var hits=nodes.filter(function(n){return (n.textContent||'').indexOf(want)>=0;});" +
                "hits.sort(function(x,y){return (x.textContent||'').length-(y.textContent||'').length;});" +
                "if(!hits.length)return {ok:false,error:'preset not found: '+want};" +
                "hits[0].click();return {ok:true,preset:want};})(" + payload + ")"
        }
        if (name === "slice") {
            return "(function(a){" +
                "var rows=Array.prototype.slice.call(document.querySelectorAll('[data-slice-index]'));" +
                "if(!rows.length)return {ok:false,error:'viewer has no slice list'};" +
                "var cur=document.querySelector('[data-slice-index].on');" +
                "var idx=cur?parseInt(cur.getAttribute('data-slice-index'),10):0;" +
                "var target=(a.index!==undefined&&a.index!==null)?parseInt(a.index,10):idx+parseInt(a.delta||0,10);" +
                "if(isNaN(target))return {ok:false,error:'bad slice index'};" +
                "var el=rows.filter(function(r){return parseInt(r.getAttribute('data-slice-index'),10)===target;})[0];" +
                "if(!el)return {ok:false,error:'slice out of range: '+target,current:idx};" +
                "el.click();return {ok:true,index:target,current:idx};})(" + payload + ")"
        }
        if (name === "mask") {
            return "(function(a){" +
                "var scope=a.id?document.querySelector('[data-mask-id=\"'+a.id+'\"]'):document;" +
                "if(!scope)return {ok:false,error:'mask not found: '+a.id};" +
                "if(a.visible!==undefined&&a.visible!==null){" +
                "  var vis=scope.querySelector('[data-mask-action=\"visible\"]');" +
                "  if(!vis)return {ok:false,error:'visibility control not found'};" +
                "  if(!!vis.checked!==!!a.visible)vis.click();" +
                "  return {ok:true,id:a.id,visible:!!a.visible};}" +
                "if(a.opacity!==undefined&&a.opacity!==null){" +
                "  var op=scope.querySelector('[data-mask-action=\"opacity\"]');" +
                "  if(!op)return {ok:false,error:'opacity control not found'};" +
                "  op.value=String(a.opacity);op.dispatchEvent(new Event('input',{bubbles:true}));" +
                "  return {ok:true,id:a.id,opacity:Number(a.opacity)};}" +
                "if(a.color){" +
                "  var pick=scope.querySelector('[data-mask-action=\"pick-color\"]');" +
                "  if(pick)pick.click();" +
                "  var chip=document.querySelector('[data-mask-action=\"apply-color\"][data-color=\"'+a.color+'\"]');" +
                "  if(!chip)return {ok:false,error:'color not available: '+a.color};" +
                "  chip.click();return {ok:true,id:a.id,color:a.color};}" +
                "return {ok:false,error:'mask needs visible|opacity|color'};})(" + payload + ")"
        }
        if (name === "focus") {
            return "(function(a){" +
                "var want=String(a.viewport||a.name||'axial').toLowerCase();" +
                "var el=document.getElementById('container-'+want);" +
                "if(!el)return {ok:false,error:'viewport not found: '+want};" +
                "el.click();return {ok:true,viewport:want};})(" + payload + ")"
        }
        return ""
    }

    Connections {
        target: viewerHost
        function onControlRequest(requestId, action, args) {
            root.handleControl(requestId, action, args)
        }
    }

    ViewerHost {
        id: viewerHost
    }

    ViewerWebView {
        id: viewer
        anchors.fill: parent
        viewerUrl: root.viewerSource

        onMedviewPicked: function(path) { root.seriesPicked(path) }

        onViewerLoaded: {
            root.viewerLoaded()
            root.editorLoaded("view")
            // The page also auto-starts the bridge. Calling it here makes the
            // handoff deterministic when Qt reports LoadSucceeded late.
            Qt.callLater(function() {
                viewer.runJavaScript("window.__medclawLoad && window.__medclawLoad();")
            })
            // 页面每次加载都会重置 DOM，缩略图条要在加载后重新下发
            Qt.callLater(root.applySeriesStrip)
            Qt.callLater(fitViewport)
            fitTimer.interval = 250
            fitTimer.restart()
            fitTimer2.interval = 800
            fitTimer2.restart()
        }

        function fitViewport() {
            if (!root.busy)
                return
            viewer.runJavaScript(
                "window.__medclawFitViewport && window.__medclawFitViewport();")
        }

        function scheduleFit() {
            if (!root.busy)
                return
            resizeFitTimer.interval = 120
            resizeFitTimer.restart()
        }

        function resumeInteraction() {
            if (!root.busy)
                return
            viewer.runJavaScript(
                "window.__medclawResumeInteraction && window.__medclawResumeInteraction();")
        }

        onWidthChanged: scheduleFit()
        onHeightChanged: scheduleFit()
        onVisibleChanged: {
            if (visible)
                Qt.callLater(resumeInteraction)
        }

        Timer {
            id: fitTimer
            repeat: false
            onTriggered: viewer.fitViewport()
        }
        Timer {
            id: fitTimer2
            repeat: false
            onTriggered: viewer.fitViewport()
        }
        Timer {
            id: resizeFitTimer
            repeat: false
            onTriggered: viewer.fitViewport()
        }
        onViewerLoadFailed: {
            root.viewerLoadFailed(message)
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: root.viewerSource.length === 0 && root.lastError.length === 0
        visible: running
        palette.dark: "#006BFF"
        palette.mid: "#006BFF"
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
