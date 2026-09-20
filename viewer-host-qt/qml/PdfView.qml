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
    property real zoomFactor: 1
    readonly property bool ready: pdfDocument.status === PdfDocument.Ready
    readonly property int pageCount: pdfDocument.pageCount
    readonly property int currentPage: Math.max(0, pageList.currentIndex)
    readonly property bool hasOutline: bookmarkCount > 0
    readonly property int pageGutter: 16

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
            fitWidth()
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
        zoomFactor = 1
        outlineVisible = true
    }

    function fitWidth() {
        zoomFactor = 1
        pageList.forceLayout()
    }

    function pageFitScale(pageIndex, availableWidth) {
        var size = pdfDocument.pagePointSize(Math.max(0, pageIndex))
        var pageWidth = Math.max(1, size.width)
        return Math.max(0.1, (Math.max(1, availableWidth) - pageGutter) / pageWidth)
    }

    function goToPage(page) {
        var index = Math.max(0, Math.min(pdfDocument.pageCount - 1, page))
        pageList.currentIndex = index
        pageList.positionViewAtIndex(index, ListView.Beginning)
    }

    function goToLocation(page, location, zoom) {
        if (zoom > 0 && pdfDocument.pageCount > 0) {
            var size = pdfDocument.pagePointSize(Math.max(0, page))
            var fit = pageFitScale(page, pageHolder.width)
            if (fit > 0)
                zoomFactor = Math.max(0.25, Math.min(8, zoom / fit))
        }
        goToPage(page)
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
                root.zoomFactor = 1
                root.loaded()
                Qt.callLater(root.fitWidth)
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
                enabled: root.currentPage > 0
                onClicked: root.goToPage(root.currentPage - 1)
            }
            Label {
                text: root.ready
                      ? qsTr("%1 / %2").arg(root.currentPage + 1).arg(Math.max(1, pdfDocument.pageCount))
                      : "—"
                color: "#A6000000"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            ToolButton {
                text: qsTr("下一页")
                enabled: root.ready && root.currentPage + 1 < pdfDocument.pageCount
                onClicked: root.goToPage(root.currentPage + 1)
            }
            ToolButton {
                text: qsTr("缩小")
                enabled: root.ready
                onClicked: root.zoomFactor = Math.max(0.25, root.zoomFactor / 1.2)
            }
            Label {
                text: root.ready ? Math.round(root.zoomFactor * 100) + "%" : ""
                color: "#A6000000"
                font.pixelSize: 13
                Layout.alignment: Qt.AlignVCenter
            }
            ToolButton {
                text: qsTr("放大")
                enabled: root.ready
                onClicked: root.zoomFactor = Math.min(8, root.zoomFactor * 1.2)
            }
            ToolButton {
                text: qsTr("适宽")
                enabled: root.ready
                onClicked: root.fitWidth()
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
                onAccepted: {
                    searchModel.currentResult += 1
                    root.goToPage(searchModel.currentPage)
                }
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
                    root.goToLocation(page, location || Qt.point(-1, -1), zoom > 0 ? zoom : 0)
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
            currentIndex: root.currentPage
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
                    border.width: thumbItem.index === root.currentPage ? 2 : 1
                    border.color: thumbItem.index === root.currentPage ? "#006BFF" : "#D0D5DD"
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
                    color: thumbItem.index === root.currentPage ? "#006BFF" : "#A6000000"
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToPage(thumbItem.index)
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

        PdfSearchModel {
            id: searchModel
            document: pdfDocument
            searchString: searchField.text
            currentPage: root.currentPage
        }

        ListView {
            id: pageList
            anchors.fill: parent
            clip: true
            visible: root.ready
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: root.zoomFactor > 1.01 ? Flickable.HorizontalAndVerticalFlick
                                                       : Flickable.VerticalFlick
            spacing: 8
            model: root.ready ? pdfDocument.pageCount : 0
            cacheBuffer: 800
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 6
            }
            ScrollBar.horizontal: ScrollBar {
                policy: root.zoomFactor > 1.01 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                height: 6
            }
            onWidthChanged: if (root.ready) Qt.callLater(pageList.forceLayout)
            onContentYChanged: {
                if (!root.ready || count <= 0)
                    return
                var y = contentY + Math.min(40, height / 4)
                var item = itemAt(contentX + width / 2, y)
                if (item && item.pageIndex !== undefined)
                    currentIndex = item.pageIndex
            }

            delegate: Item {
                id: pageItem
                required property int index
                readonly property int pageIndex: index
                readonly property size pageSize: pdfDocument.pagePointSize(index)
                readonly property real fitScale: root.pageFitScale(index, pageList.width)
                readonly property real pageScale: fitScale * root.zoomFactor
                readonly property real paintedWidth: Math.max(1, pageSize.width * pageScale)
                readonly property real paintedHeight: Math.max(1, pageSize.height * pageScale)
                width: Math.max(pageList.width, paintedWidth + root.pageGutter)
                height: paintedHeight + 8

                Rectangle {
                    id: paper
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    width: pageItem.paintedWidth
                    height: pageItem.paintedHeight
                    color: "#FFFFFF"
                    border.color: "#D0D5DD"
                    border.width: 1

                    PdfPageImage {
                        anchors.fill: parent
                        document: pdfDocument
                        currentFrame: pageItem.index
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: paper.width * Screen.devicePixelRatio
                        sourceSize.height: 0
                    }
                }
            }
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
