import QtQuick 2.15
import QtWebEngine 1.10

// Reusable QML wrapper. It only needs a URL returned by ViewerHost, so it can
// be copied to another Qt Quick project without application-specific types.
WebEngineView {
    id: viewer
    property string viewerUrl: ""
    signal viewerLoadFailed(string message)
    signal viewerLoaded()
    signal saveAsUnavailable()

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
    settings.javascriptCanOpenWindows: false
    settings.errorPageEnabled: true
    settings.fullScreenSupportEnabled: true

    userScripts: [
        WebEngineScript {
            injectionPoint: WebEngineScript.DocumentCreation
            worldId: WebEngineScript.MainWorld
            runOnSubframes: true
            sourceCode: "(function(){if(typeof Object.hasOwn!=='function'){Object.hasOwn=function(o,p){return Object.prototype.hasOwnProperty.call(Object(o),p);};}if(typeof Array.prototype.at!=='function'){Object.defineProperty(Array.prototype,'at',{configurable:true,writable:true,value:function(i){var l=this.length>>>0,n=Math.trunc(i)||0,p=n<0?l+n:n;return p<0||p>=l?undefined:this[p];}});}if(typeof String.prototype.at!=='function'){Object.defineProperty(String.prototype,'at',{configurable:true,writable:true,value:function(i){var s=String(this),n=Math.trunc(i)||0,p=n<0?s.length+n:n;return p<0||p>=s.length?undefined:s.charAt(p);}});}if(typeof Array.prototype.findLast!=='function'){Object.defineProperty(Array.prototype,'findLast',{configurable:true,writable:true,value:function(fn,arg){for(var i=this.length-1;i>=0;i--){if(fn.call(arg,this[i],i,this))return this[i];}}});}if(typeof Array.prototype.findLastIndex!=='function'){Object.defineProperty(Array.prototype,'findLastIndex',{configurable:true,writable:true,value:function(fn,arg){for(var i=this.length-1;i>=0;i--){if(fn.call(arg,this[i],i,this))return i;}return -1;}});}})();"
        }
    ]

    onLoadingChanged: function(request) {
        if (request.status === WebEngineView.LoadFailedStatus)
            viewerLoadFailed(request.errorString)
        else if (request.status === WebEngineView.LoadSucceededStatus)
            viewerLoaded()
    }
}
