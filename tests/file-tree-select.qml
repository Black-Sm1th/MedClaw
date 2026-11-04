import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine

Window {
    id: win
    width: 900
    height: 600
    visible: true

    property int step: 0

    WebEngineView {
        id: view
        anchors.fill: parent
        url: "file:///C:/Users/guanboyu/Documents/MedClaw/web/file-tree.html"

        onLoadingChanged: function(info) {
            if (info.status === WebEngineView.LoadSucceededStatus) {
                runJavaScript("window.__fileTree.setEmbedMode(true)")
                runJavaScript('window.__fileTree.loadDemo({name:"root",children:[{name:"a.png"},{name:"b.png"},{name:"c.png"}]})')
                win.step = 1
            }
        }

        onJavaScriptConsoleMessage: function(level, message) {
            if (message.indexOf("MEDCLAW_TREE:") === 0)
                console.log("PAGE " + message.substring(13))
        }
    }

    onStepChanged: {
        if (step === 1) {
            // 真实 DOM 点击第一个 .check
            view.runJavaScript(
                '(function(){var c=document.querySelectorAll(".check");'
                + 'c[0].click();c[2].click();'
                + 'return document.querySelectorAll(".check.checked").length})()')
            .then(function(n) {
                console.log("CHECKED count=" + n)
                win.step = 2
            })
        } else if (step === 2) {
            view.runJavaScript(
                '(function(){var c=document.querySelectorAll(".check");'
                + 'c[0].click();'
                + 'return document.querySelectorAll(".check.checked").length})()')
            .then(function(n) {
                console.log("AFTER_UNCHECK count=" + n)
                Qt.quit()
            })
        }
    }
}
