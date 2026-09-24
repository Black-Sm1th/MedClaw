import QtQuick 2.15
import QtQuick.Window 2.15
import QtWebEngine

Window {
    width: 1400
    height: 1000
    visible: true
    opacity: 0
    WebEngineView {
        anchors.fill: parent
        url: "about:blank"
    }
    Timer {
        interval: 90000
        running: true
        onTriggered: Qt.quit()
    }
}
