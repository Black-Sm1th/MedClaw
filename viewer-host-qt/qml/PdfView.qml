import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Pdf

Item {
    id: root
    clip: true

    property url sourceUrl: ""
    property string lastError: ""
    property bool outlineVisible: true
    property int bookmarkCount: 0
    readonly property bool ready: pdfDocument.status === PdfDocument.Ready
    readonly property int pageCount: pdfDocument.pageCount
    readonly property int currentPage: pdfView.currentPage
    readonly property bool hasOutline: bookmarkCount > 0

    signal loaded()
    signal loadFailed(string message)

    function toFileUrl(path) {
        var p = String(path || "").replace(/\\/g, "/")
        if (!p)
            return ""
        if (p.indexOf("file:") === 0)
            return p
        if (p.charAt(1) === ":")
            return "file:///" + p
        if (p.charAt(0) === "/")
            return "file://" + p
        return "file:///" + p
    }

    function open(path) {
        lastError = ""
        var url = toFileUrl(path)
        if (!url)
            return false
        if (String(sourceUrl) === String(url) && ready) {
            fitWidthSoon()
            loaded()
            return true
        }
        sourceUrl = url
        return true
    }

    function close() {
        sourceUrl = ""
        lastError = ""
        searchField.text = ""
        bookmarkCount = 0
        outlineVisible = true
    }

    function fitWidthSoon() {
        Qt.callLater(function() {
            if (!root.ready || pdfView.width <= 0)
                return
            pdfView.scaleToWidth(pdfView.width, pdfView.height)
        })
    }

    PdfDocument {
        id: pdfDocument
        source: root.sourceUrl
        onPasswordRequired: passwordDialog.open()
        onStatusChanged: {
            if (!root.sourceUrl || status === PdfDocument.Null || status === PdfDocument.Loading)
                return
            if (status === PdfDocument.Ready) {
                root.lastError = ""
                root.refreshBookmarkCount()
                root.loaded()
                root.fitWidthSoon()
            } else if (status === PdfDocument.Error) {
                root.lastError = error || qsTr("无法打开 PDF")
                root.loadFailed(root.lastError)
            }
        }
    }

    PdfBookmarkModel {
        id: bookmarkModel
        document: pdfDocument
        onDocumentChanged: Qt.callLater(root.refreshBookmarkCount)
        onModelReset: Qt.callLater(root.refreshBookmarkCount)
        onRowsInserted: Qt.callLater(root.refreshBookmarkCount)
        onRowsRemoved: Qt.callLater(root.refreshBookmarkCount)
    }

    function refreshBookmarkCount() {
        try {
            bookmarkCount = bookmarkModel.rowCount()
        } catch (err) {
            bookmarkCount = 0
        }
    }

    Rectangle {
        id: toolBar
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        color: "#F7F9FA"
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#14000000"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 4

            ToolButton {
                text: root.hasOutline ? qsTr("目录") : qsTr("缩略图")
                checkable: true
                checked: root.outlineVisible
                onClicked: root.outlineVisible = checked
            }
            ToolButton {
                text: qsTr("上一页")
                enabled: pdfView.currentPage > 0
                onClicked: pdfView.goToPage(pdfView.currentPage - 1)
            }
            Label {
                text: root.ready
                      ? qsTr("%1 / %2").arg(pdfView.currentPage + 1).arg(Math.max(1, pdfDocument.pageCount))
                      : "—"
                color: "#A6000000"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            ToolButton {
                text: qsTr("下一页")
                enabled: root.ready && pdfView.currentPage + 1 < pdfDocument.pageCount
                onClicked: pdfView.goToPage(pdfView.currentPage + 1)
            }
            ToolButton {
                text: qsTr("缩小")
                enabled: root.ready
                onClicked: pdfView.renderScale = Math.max(0.25, pdfView.renderScale / 1.2)
            }
            Label {
                text: root.ready ? Math.round(pdfView.renderScale * 100) + "%" : ""
                color: "#A6000000"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            ToolButton {
                text: qsTr("放大")
                enabled: root.ready
                onClicked: pdfView.renderScale = Math.min(8, pdfView.renderScale * 1.2)
            }
            ToolButton {
                text: qsTr("适宽")
                enabled: root.ready
                onClicked: pdfView.scaleToWidth(pdfView.width, pdfView.height)
            }
            Item { Layout.fillWidth: true }
            TextField {
                id: searchField
                Layout.preferredWidth: 168
                Layout.maximumWidth: 200
                Layout.minimumWidth: 96
                Layout.preferredHeight: 28
                placeholderText: qsTr("搜索")
                enabled: root.ready
                onAccepted: pdfView.searchForward()
            }
        }
    }

    Rectangle {
        id: outlinePanel
        z: 1
        anchors.left: parent.left
        anchors.top: toolBar.bottom
        anchors.bottom: parent.bottom
        width: root.outlineVisible ? 220 : 0
        visible: width > 0
        clip: true
        color: "#FAFBFC"

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 1
            color: "#14000000"
        }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 36
            leftPadding: 12
            verticalAlignment: Text.AlignVCenter
            text: root.hasOutline ? qsTr("目录") : qsTr("缩略图")
            color: "#A6000000"
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        TreeView {
            id: outlineView
            anchors.fill: parent
            anchors.topMargin: 36
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: bookmarkModel
            visible: root.hasOutline
            selectionModel: ItemSelectionModel {}
            delegate: TreeViewDelegate {
                id: outlineDelegate
                implicitWidth: outlineView.width
                required property int index
                required property var model
                text: model.title || model.display || ""
                onClicked: {
                    var page = Number(model.page)
                    var zoom = Number(model.zoom)
                    var location = model.location
                    if (isNaN(page) || page < 0)
                        return
                    pdfView.goToLocation(page, location || Qt.point(-1, -1), zoom > 0 ? zoom : 0)
                    outlineView.toggleExpanded(row)
                }
            }
        }

        ListView {
            id: thumbnailView
            anchors.fill: parent
            anchors.topMargin: 36
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: root.ready && !root.hasOutline
            model: pdfDocument.pageModel
            spacing: 8
            topMargin: 8
            bottomMargin: 8
            currentIndex: pdfView.currentPage
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 120
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 4
            }
            delegate: Item {
                id: thumbItem
                required property int index
                width: thumbnailView.width
                readonly property size pageSize: pdfDocument.pagePointSize(index)
                readonly property real pageRatio: pageSize.width > 0
                                                  ? pageSize.height / pageSize.width : 1.414
                height: thumbFrame.height + 22

                Rectangle {
                    id: thumbFrame
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width - 20, 168)
                    height: Math.max(72, width * thumbItem.pageRatio)
                    color: "#FFFFFF"
                    border.width: thumbItem.index === pdfView.currentPage ? 2 : 1
                    border.color: thumbItem.index === pdfView.currentPage ? "#006BFF" : "#D0D5DD"
                    radius: 4
                    clip: true

                    PdfPageImage {
                        anchors.fill: parent
                        anchors.margins: 2
                        document: pdfDocument
                        currentFrame: thumbItem.index
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: width * Screen.devicePixelRatio
                        sourceSize.height: 0
                    }
                }

                Label {
                    anchors.top: thumbFrame.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pdfDocument.pageLabel(thumbItem.index) || String(thumbItem.index + 1)
                    color: thumbItem.index === pdfView.currentPage ? "#006BFF" : "#A6000000"
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pdfView.goToPage(thumbItem.index)
                }
            }
        }
    }

    Item {
        id: pageHolder
        clip: true
        anchors.left: outlinePanel.right
        anchors.right: parent.right
        anchors.top: toolBar.bottom
        anchors.bottom: parent.bottom

        PdfMultiPageView {
            id: pdfView
            anchors.fill: parent
            clip: true
            document: pdfDocument
            searchString: searchField.text
            visible: root.ready
        }
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: !!root.sourceUrl && pdfDocument.status === PdfDocument.Loading
        visible: running
        palette.dark: "#006BFF"
        palette.mid: "#006BFF"
        z: 3
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 520)
        visible: root.lastError.length > 0 && !root.ready
        text: root.lastError
        color: "#b91c1c"
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        z: 3
    }

    Dialog {
        id: passwordDialog
        modal: true
        title: qsTr("PDF 已加密")
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: Overlay.overlay
        onAccepted: {
            pdfDocument.password = passwordField.text
            passwordField.text = ""
        }
        onRejected: {
            passwordField.text = ""
            root.lastError = qsTr("需要密码才能打开该 PDF")
            root.loadFailed(root.lastError)
        }
        Column {
            spacing: 8
            Label { text: qsTr("请输入密码") }
            TextField {
                id: passwordField
                echoMode: TextInput.Password
                width: 240
            }
        }
    }
}
