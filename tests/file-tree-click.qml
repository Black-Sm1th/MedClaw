import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine

Window {
    id: win
    width: 900
    height: 600
    visible: true

    WebEngineView {
        id: view
        anchors.fill: parent
        url: "file:///C:/Users/guanboyu/Documents/MedClaw/web/file-tree.html"

        onLoadingChanged: function(info) {
            if (info.status !== WebEngineView.LoadSucceededStatus)
                return
            runJavaScript("window.__fileTree.setEmbedMode(true)")
            runJavaScript('window.__fileTree.loadDemo({name:"root",children:['
                          + '{name:"dirA",children:[{name:"a1.png"},{name:"a2.png"}]},'
                          + '{name:"b.png"}]})')
            Qt.callLater(runStep1)
        }

        onJavaScriptConsoleMessage: function(level, message) {
            if (message.indexOf("MEDCLAW_TREE:") === 0)
                console.log("PAGE " + message.substring(13))
        }
    }

    function runStep1() {
        view.runJavaScript(
            '(function(){var rows=document.querySelectorAll(".node-row");'
            + 'var r=rows[1];r.querySelector(".node-name").click();'
            + 'return JSON.stringify({checked: document.querySelectorAll(".check.checked").length,'
            + 'blue: document.querySelectorAll(".node-row.selected").length,'
            + 'rows: document.querySelectorAll(".node-row").length})})()',
            function(res) { console.log("FOLDER_ROW_CLICK " + res); runStep2() })
    }

    function runStep2() {
        view.runJavaScript(
            '(function(){var rows=document.querySelectorAll(".node-row");'
            + 'for(var i=0;i<rows.length;i++){'
            + '  var n=rows[i].querySelector(".node-name");'
            + '  if(n && n.textContent==="b.png"){n.click();break}}'
            + 'return JSON.stringify({checked: document.querySelectorAll(".check.checked").length,'
            + 'blue: document.querySelectorAll(".node-row.selected").length})})()',
            function(res) { console.log("FILE_ROW_CLICK " + res); runStep3() })
    }

    function runStep3() {
        view.runJavaScript(
            '(function(){var rows=document.querySelectorAll(".node-row");'
            + 'for(var i=0;i<rows.length;i++){'
            + '  var n=rows[i].querySelector(".node-name");'
            + '  if(n && n.textContent==="b.png"){n.click();break}}'
            + 'return JSON.stringify({checked: document.querySelectorAll(".check.checked").length})})()',
            function(res) { console.log("FILE_ROW_CLICK2 " + res); Qt.quit() })
    }
}
