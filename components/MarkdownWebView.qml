import QtQuick 2.15
import QtWebEngine 1.10

Item {
    id: root

    property string sourceText: ""
    property bool streaming: false
    property bool isUser: false
    property bool isIntermediate: false
    property int maxMarkdownChars: 500000
    property int markdownDelayMs: 80
    property color foreground: isUser ? "#E5000000" : (isIntermediate ? "#8C000000" : "#D9000000")
    property string fontFamily: "Arial, \"Alibaba PuHuiTi 3.0\", \"Noto Sans CJK SC\", \"Microsoft YaHei\", \"Noto Color Emoji\", sans-serif"
    property int fontPixelSize: 16

    signal linkActivated(string link)

    implicitWidth: webView.width
    implicitHeight: Math.max(24, renderedHeight)

    property bool webReady: false
    property int renderedHeight: 24
    property string pendingText: ""

    function colorToCss(c) {
        return "rgba("
               + Math.round(c.r * 255) + ","
               + Math.round(c.g * 255) + ","
               + Math.round(c.b * 255) + ","
               + c.a + ")"
    }

    function jsString(s) {
        return JSON.stringify(s || "")
    }

    function renderStyle() {
        return JSON.stringify({
            color: colorToCss(foreground),
            fontFamily: fontFamily,
            fontSize: fontPixelSize,
            italic: isIntermediate
        })
    }

    function pushText(text, finalRender) {
        pendingText = text || ""
        if (!webReady)
            return

        var markdown = finalRender && pendingText.length <= maxMarkdownChars
        webView.runJavaScript("window.MedClawMarkdown.setContent("
                              + jsString(pendingText) + ","
                              + (markdown ? "true" : "false") + ","
                              + renderStyle() + ");")
        measureTimer.restart()
    }

    function append(delta) {
        if (!delta || delta.length === 0)
            return
        pendingText += delta
        if (!webReady)
            return

        webView.runJavaScript("window.MedClawMarkdown.appendPlain("
                              + jsString(delta) + ","
                              + renderStyle() + ");")
        measureTimer.restart()
    }

    function scheduleFullRender() {
        renderTimer.stop()
        if (streaming)
            pushText(sourceText, false)
        else
            renderTimer.restart()
    }

    onSourceTextChanged: {
        if (!streaming)
            scheduleFullRender()
    }
    onStreamingChanged: scheduleFullRender()
    onForegroundChanged: pushText(pendingText.length > 0 ? pendingText : sourceText, !streaming)
    onFontFamilyChanged: pushText(pendingText.length > 0 ? pendingText : sourceText, !streaming)
    onFontPixelSizeChanged: pushText(pendingText.length > 0 ? pendingText : sourceText, !streaming)
    onIsIntermediateChanged: pushText(pendingText.length > 0 ? pendingText : sourceText, !streaming)
    Component.onCompleted: scheduleFullRender()

    Timer {
        id: renderTimer
        interval: root.markdownDelayMs
        repeat: false
        onTriggered: root.pushText(root.sourceText, true)
    }

    Timer {
        id: measureTimer
        interval: 40
        repeat: false
        onTriggered: {
            if (!root.webReady)
                return
            webView.runJavaScript(
                "Math.ceil(document.documentElement.scrollHeight || document.body.scrollHeight || 24);",
                function(height) {
                    var h = Number(height)
                    if (h > 0)
                        root.renderedHeight = h
                }
            )
        }
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: "qrc:/web/markdown_renderer.html"
        backgroundColor: "transparent"

        onLoadingChanged: function(loadRequest) {
            if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
                root.webReady = true
                root.pushText(root.sourceText, !root.streaming)
            }
        }

        onNavigationRequested: function(request) {
            if (request.url.toString() !== "qrc:/web/markdown_renderer.html") {
                request.action = WebEngineNavigationRequest.IgnoreRequest
                root.linkActivated(request.url.toString())
            }
        }
    }
}
