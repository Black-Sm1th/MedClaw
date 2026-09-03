import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine 1.10

// Reusable QML wrapper. It only needs a URL returned by ViewerHost, so it can
// be copied to another Qt Quick project without application-specific types.
WebEngineView {
    id: viewer
    property string viewerUrl: ""
    readonly property string compatibilityScript: "(function(){if(typeof Object.hasOwn!=='function'){Object.hasOwn=function(o,p){return Object.prototype.hasOwnProperty.call(Object(o),p);};}if(typeof Array.prototype.at!=='function'){Object.defineProperty(Array.prototype,'at',{configurable:true,writable:true,value:function(i){var l=this.length>>>0,n=Math.trunc(i)||0,p=n<0?l+n:n;return p<0||p>=l?undefined:this[p];}});}if(typeof String.prototype.at!=='function'){Object.defineProperty(String.prototype,'at',{configurable:true,writable:true,value:function(i){var s=String(this),n=Math.trunc(i)||0,p=n<0?s.length+n:n;return p<0||p>=s.length?undefined:s.charAt(p);}});}if(typeof Array.prototype.findLast!=='function'){Object.defineProperty(Array.prototype,'findLast',{configurable:true,writable:true,value:function(fn,arg){for(var i=this.length-1;i>=0;i--){if(fn.call(arg,this[i],i,this))return this[i];}}});}if(typeof Array.prototype.findLastIndex!=='function'){Object.defineProperty(Array.prototype,'findLastIndex',{configurable:true,writable:true,value:function(fn,arg){for(var i=this.length-1;i>=0;i--){if(fn.call(arg,this[i],i,this))return i;}return -1;}});}})();"
    readonly property string webgl2CompatScript: "(function(){if(window.__medclawWebGlPatched)return;window.__medclawWebGlPatched=true;var original=HTMLCanvasElement.prototype.getContext;var attempts=[{alpha:true,depth:true,stencil:false,antialias:false,premultipliedAlpha:true,preserveDrawingBuffer:false,failIfMajorPerformanceCaveat:false,powerPreference:'default'},{alpha:true,depth:true,antialias:false,failIfMajorPerformanceCaveat:false,powerPreference:'low-power'},{alpha:true,depth:true,antialias:false,failIfMajorPerformanceCaveat:false,powerPreference:'high-performance'},{failIfMajorPerformanceCaveat:false,antialias:false},{}];function merge(a,b){var o={};if(a)for(var k in a)o[k]=a[k];if(b)for(var k2 in b)o[k2]=b[k2];return o;}HTMLCanvasElement.prototype.getContext=function(type,attrs){var t=String(type||'').toLowerCase();if(t!=='webgl2')return original.call(this,type,attrs);var tries=[attrs||{}];for(var i=0;i<attempts.length;i++){tries.push(merge(attempts[i],attrs));tries.push(attempts[i]);}for(var j=0;j<tries.length;j++){try{var gl=original.call(this,'webgl2',tries[j]);if(gl){window.__medclawWebGl={webgl2:true};return gl;}}catch(e){}}return original.call(this,type,attrs);};})();"
    readonly property string popupCompatScript: "(function(){if(window.__medclawOpenPatched)return;window.__medclawOpenPatched=true;var orig=window.open;window.open=function(url,name,specs){var opened=null;try{opened=orig.call(window,url,name,specs);}catch(e){}if(opened)return opened;var href=url==null?'':String(url);if(href&&href!=='about:blank'){window.location.assign(href);return window;}return window;};document.addEventListener('click',function(ev){if(ev.defaultPrevented)return;var node=ev.target;while(node&&node.nodeName!=='A')node=node.parentNode;if(!node||!node.getAttribute)return;var target=(node.getAttribute('target')||'').toLowerCase();if(target!=='_blank'&&target!=='_new')return;var href=node.href||node.getAttribute('href')||'';if(!href||href.charAt(0)==='#')return;if(ev.button!==0||ev.ctrlKey||ev.metaKey||ev.shiftKey||ev.altKey)return;ev.preventDefault();var popup=null;try{popup=window.open(href,'_blank');}catch(e){}if(!popup)window.location.assign(href);},true);})();"
    readonly property string cssCompatScript: "(function(){if(window.__medclawCssPatched)return;window.__medclawCssPatched=true;if(window.CSS&&CSS.supports&&CSS.supports('inset','0px'))return;function expand(css){return String(css).replace(/(^|[{;\\s])inset\\s*:\\s*([^;}{]+)/gi,function(m,pre,val){var imp=/!important/i.test(val)?' !important':'';var raw=String(val).replace(/!important/ig,'').trim();var p=raw.split(/\\s+/).filter(Boolean);if(!p.length)return m;var t=p[0],r=t,b=t,l=t;if(p.length===2){r=l=p[1];}else if(p.length===3){r=l=p[1];b=p[2];}else if(p.length>=4){r=p[1];b=p[2];l=p[3];}return pre+'top:'+t+imp+';right:'+r+imp+';bottom:'+b+imp+';left:'+l+imp;});}function patch(el){if(!el||el.__medclawInset)return;el.__medclawInset=true;var src=el.textContent||'';var next=expand(src);if(next!==src)el.textContent=next;}function run(){var nodes=document.querySelectorAll('style');for(var i=0;i<nodes.length;i++)patch(nodes[i]);}run();if(document.documentElement){try{new MutationObserver(function(ms){for(var i=0;i<ms.length;i++){var add=ms[i].addedNodes;for(var j=0;j<add.length;j++){var n=add[j];if(!n||n.nodeType!==1)continue;if(n.tagName==='STYLE')patch(n);if(n.querySelectorAll){var inner=n.querySelectorAll('style');for(var k=0;k<inner.length;k++)patch(inner[k]);}}}}).observe(document.documentElement,{childList:true,subtree:true});}catch(e){}}})();"
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
        // WebEngineView is a native child on Qt 5, so an overlay Item inside
        // the sidebar is covered. A real Window is required for window.open
        // / target=_blank. Parent it to the application window and show it
        // before openIn(); a parentless Window often never maps on Windows.
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
    settings.errorPageEnabled: true
    settings.fullScreenSupportEnabled: true
    settings.webGLEnabled: true
    settings.accelerated2dCanvasEnabled: true
    settings.localContentCanAccessRemoteUrls: true
    settings.localContentCanAccessFileUrls: true
    settings.pluginsEnabled: true
    settings.focusOnNavigationEnabled: true
    settings.allowWindowActivationFromJavaScript: true
    settings.unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes

    userScripts: [
        WebEngineScript {
            injectionPoint: WebEngineScript.DocumentCreation
            worldId: WebEngineScript.MainWorld
            runOnSubframes: true
            sourceCode: viewer.compatibilityScript
        },
        WebEngineScript {
            injectionPoint: WebEngineScript.DocumentCreation
            worldId: WebEngineScript.MainWorld
            runOnSubframes: true
            sourceCode: viewer.webgl2CompatScript
        },
        WebEngineScript {
            injectionPoint: WebEngineScript.DocumentCreation
            worldId: WebEngineScript.MainWorld
            runOnSubframes: true
            sourceCode: viewer.popupCompatScript
        },
        WebEngineScript {
            injectionPoint: WebEngineScript.DocumentReady
            worldId: WebEngineScript.MainWorld
            runOnSubframes: true
            sourceUrl: "qrc:/localviewer/html-compat.js"
        }
    ]

    onNewViewRequested: function(request) {
        viewer.openNewView(request)
    }

    onFullScreenRequested: function(request) {
        request.accept()
    }

    onLoadingChanged: function(request) {
        if (request.status === WebEngineView.LoadFailedStatus)
            viewerLoadFailed(request.errorString)
        else if (request.status === WebEngineView.LoadSucceededStatus)
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
                settings.errorPageEnabled: true
                settings.fullScreenSupportEnabled: true
                settings.webGLEnabled: true
                settings.accelerated2dCanvasEnabled: true
                settings.localContentCanAccessRemoteUrls: true
                settings.localContentCanAccessFileUrls: true
                settings.pluginsEnabled: true
                settings.focusOnNavigationEnabled: true
                settings.allowWindowActivationFromJavaScript: true
                settings.unknownUrlSchemePolicy: WebEngineSettings.AllowAllUnknownUrlSchemes

                userScripts: [
                    WebEngineScript {
                        injectionPoint: WebEngineScript.DocumentCreation
                        worldId: WebEngineScript.MainWorld
                        runOnSubframes: true
                        sourceCode: viewer.compatibilityScript
                    },
                    WebEngineScript {
                        injectionPoint: WebEngineScript.DocumentCreation
                        worldId: WebEngineScript.MainWorld
                        runOnSubframes: true
                        sourceCode: viewer.webgl2CompatScript
                    },
                    WebEngineScript {
                        injectionPoint: WebEngineScript.DocumentCreation
                        worldId: WebEngineScript.MainWorld
                        runOnSubframes: true
                        sourceCode: viewer.popupCompatScript
                    },
                    WebEngineScript {
                        injectionPoint: WebEngineScript.DocumentReady
                        worldId: WebEngineScript.MainWorld
                        runOnSubframes: true
                        sourceUrl: "qrc:/localviewer/html-compat.js"
                    }
                ]

                onNewViewRequested: function(request) {
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
