import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.3
import QtGraphicalEffects 1.0

Item {
    id: root

    property var templates: []
    property var userTemplates: []
    property bool loading: false
    property string gatewayHttpBaseUrl: ""
    property string searchText: ""
    property string selectedCategory: "精选"
    property var activeTemplate: ({})
    property bool previewOpen: false
    property bool uploadBusy: false
    property string pendingTemplateFileUrl: ""
    property string pendingTemplateFileName: ""
    property string pendingCoverFileUrl: ""
    property string pendingCoverFileName: ""
    readonly property string userTemplateCategory: qsTr("用户上传模板")
    readonly property bool uploadReady: uploadNameInput.text.trim().length > 0
                                        && pendingTemplateFileUrl.length > 0
                                        && pendingCoverFileUrl.length > 0
    property var categories: [
        "精选", "国际国内期刊论文类", "行业情报类", "新药研发类",
        "药品注册申报类", "医药监管申报合规类", "药品准入与HTA类",
        "政务类", "医工交叉期刊类", "设备科工作模板类", "用户上传模板"
    ]

    signal refreshRequested()
    signal addTemplateRequested()
    signal uploadTemplateRequested(string name, string description,
                                   string templateFileUrl, string coverFileUrl)
    signal useTemplateRequested(var template)
    signal messageRequested(string message)

    function normalizedCategory(value) {
        return String(value || "").replace(/\s/g, "")
    }

    function templateTitle(template) {
        return String((template && (template.name || template.title)) || qsTr("未命名模板"))
    }

    function templateDetail(template) {
        return String((template && (template.detail || template.description || template.desc)) || "")
    }

    function cardImageUrl(template) {
        if (template && template.isUserTemplate)
            return String(template.coverUrl || template.previewUrl || "")
        var id = parseInt(String((template && template.id) || ""), 10)
        return isNaN(id) ? "" : "qrc:/images/template/" + id + ".png"
    }

    function absolutePreviewUrl(template) {
        var raw = String((template && (template.previewUrl || template.thumbnail || template.cover)) || "")
        if (!raw || /^(https?:|file:|qrc:|data:)/i.test(raw))
            return raw
        var base = String(root.gatewayHttpBaseUrl || "").replace(/\/$/, "")
        return base + (raw.charAt(0) === "/" ? raw : "/" + raw)
    }

    function filteredTemplates() {
        var userCategorySelected = root.selectedCategory === root.userTemplateCategory
        var rows = userCategorySelected ? (root.userTemplates || []) : (root.templates || [])
        var query = root.searchText.trim().toLowerCase()
        var result = []
        for (var i = 0; i < rows.length; i++) {
            var item = rows[i] || {}
            if (!userCategorySelected && root.selectedCategory !== "精选"
                    && root.normalizedCategory(item.category) !== root.normalizedCategory(root.selectedCategory))
                continue
            var searchable = (root.templateTitle(item) + " " + root.templateDetail(item)).toLowerCase()
            if (!query || searchable.indexOf(query) >= 0)
                result.push(item)
        }
        return result
    }

    function fileNameFromUrl(value) {
        var raw = String(value || "").replace(/\\/g, "/")
        var name = raw.substring(raw.lastIndexOf("/") + 1)
        try { return decodeURIComponent(name) } catch (error) { return name }
    }

    function fileExtension(value) {
        var name = fileNameFromUrl(value)
        var dot = name.lastIndexOf(".")
        return dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
    }

    function setTemplateFile(value) {
        var url = String(value || "")
        if (!/^(doc|docx|md|html|htm)$/.test(fileExtension(url))) {
            messageRequested(qsTr("模板附件仅支持 Word、MD、HTML 格式"))
            return
        }
        pendingTemplateFileUrl = url
        pendingTemplateFileName = fileNameFromUrl(url)
    }

    function setCoverFile(value) {
        var url = String(value || "")
        if (!/^(jpg|jpeg|png)$/.test(fileExtension(url))) {
            messageRequested(qsTr("模板封面仅支持 JPG、PNG 格式"))
            return
        }
        pendingCoverFileUrl = url
        pendingCoverFileName = fileNameFromUrl(url)
    }

    function openUploadDialog() {
        uploadNameInput.text = ""
        uploadDescriptionInput.text = ""
        pendingTemplateFileUrl = ""
        pendingTemplateFileName = ""
        pendingCoverFileUrl = ""
        pendingCoverFileName = ""
        uploadBusy = false
        uploadDialog.open()
        Qt.callLater(function() { uploadNameInput.forceActiveFocus() })
    }

    function finishUpload(errorMessage) {
        uploadBusy = false
        if (errorMessage) {
            messageRequested(errorMessage)
            return
        }
        selectedCategory = userTemplateCategory
        uploadDialog.close()
    }

    function openTemplate(template) {
        activeTemplate = template || ({})
        previewOpen = true
        templateUseDialog.open()
    }

    function closePreview() {
        if (!previewOpen)
            return
        previewOpen = false
        activeTemplate = ({})
        templateUseDialog.close()
    }

    onVisibleChanged: {
        if (!visible) {
            if (previewOpen)
                closePreview()
            uploadDialog.close()
        }
        else if (visible && !loading && (!templates || templates.length === 0))
            refreshRequested()
    }

    Component.onCompleted: {
        if (visible && !loading && (!templates || templates.length === 0))
            refreshRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: "#FFFFFF"

        Column {
            anchors.fill: parent
            anchors.leftMargin: Math.max(28, Math.min(60, parent.width * 0.05))
            anchors.rightMargin: Math.max(28, Math.min(60, parent.width * 0.05))
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            spacing: 16

            Item {
                width: parent.width
                height: 54

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Label {
                        text: qsTr("模板库")
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: "#D9000000"
                    }
                    Label {
                        text: qsTr("探索真实工作案例，找到模板，一键开始")
                        font.pixelSize: 13
                        color: "#80000000"
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: Math.min(250, Math.max(180, root.width * 0.22))
                        height: 38
                        radius: 8
                        border.width: 1
                        border.color: templateSearch.activeFocus ? "#006BFF" : "#1F000000"
                        color: "#FFFFFF"
                        Image {
                            width: 16; height: 16
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/images/search.png"
                            opacity: 0.6
                        }
                        TextField {
                            id: templateSearch
                            anchors.fill: parent
                            leftPadding: 38
                            rightPadding: 12
                            topPadding: 0
                            bottomPadding: 0
                            font.pixelSize: 14
                            font.family: "Alibaba PuHuiTi 3.0"
                            font.weight: Font.Normal
                            color: "#A6000000"
                            placeholderText: qsTr("搜索模板库...")
                            placeholderTextColor: "#66000000"
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            background: Item {}
                            cursorDelegate: Rectangle {
                                width: 1
                                color: "#006BFF"
                            }
                            onTextChanged: root.searchText = text
                        }
                    }
                    CustomButton {
                        id: headerUploadButton
                        backgroundColor: "#0F006BFF"
                        hoverBackgroundColor: "#1A006BFF"
                        pressedBackgroundColor: "#26006BFF"
                        iconSource: "qrc:/images/uploadTemplate.png"
                        iconSize: 16
                        text: qsTr("上传")
                        fontSize: 14
                        textColor: "#006BFF"
                        hoverTextColor: "#006BFF"
                        pressedTextColor: "#006BFF"
                        buttonWidth: 72
                        buttonHeight: 38
                        onClicked: root.openUploadDialog()

                        ToolTip {
                            id: templateUploadTip
                            visible: headerUploadButton.containsMouse
                            text: qsTr("支持 word，MD，html格式")
                            delay: 400
                            background: Rectangle {
                                color: "#A6000000"
                                radius: 4
                            }
                            contentItem: Text {
                                text: templateUploadTip.text
                                font.pixelSize: 14
                                font.family: "Alibaba PuHuiTi 3.0"
                                color: "#FFFFFF"
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: root.categories
                    delegate: Rectangle {
                        width: categoryLabel.implicitWidth + 20
                        height: 30
                        radius: 8
                        color: root.selectedCategory === modelData ? "#EAF2FF"
                              : categoryMouse.containsMouse ? "#F0F1F3" : "#F6F7F8"
                        Label {
                            id: categoryLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 13
                            color: root.selectedCategory === modelData ? "#006BFF" : "#99000000"
                        }
                        MouseArea {
                            id: categoryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedCategory = modelData
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - y

                GridView {
                    id: templateGrid
                    anchors.fill: parent
                    clip: true
                    model: root.filteredTemplates()
                    readonly property int columnCount: width >= 960 ? 3 : (width >= 620 ? 2 : 1)
                    cellWidth: width / columnCount
                    cellHeight: 330
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Item {
                        id: cardCell
                        required property var modelData
                        width: templateGrid.cellWidth
                        height: templateGrid.cellHeight

                        Rectangle {
                            id: templateCard
                            readonly property bool hovered: cardMouse.containsMouse
                                                             || useTemplateMouse.containsMouse
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 8
                            height: 314
                            radius: 12
                            color: "#FFFFFF"
                            clip: true
                            layer.enabled: hovered
                            layer.effect: DropShadow {
                                transparentBorder: true
                                radius: 12
                                samples: 25
                                verticalOffset: 4
                                color: "#26000000"
                            }

                            Item {
                                id: coverArea
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 214

                                Item {
                                    id: coverSource
                                    anchors.fill: parent
                                    visible: false

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#F5F6F8"
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: root.cardImageUrl(cardCell.modelData)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }
                                }

                                Item {
                                    id: coverMask
                                    anchors.fill: parent
                                    visible: false

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        height: templateCard.radius * 2
                                        radius: templateCard.radius
                                        color: "#FFFFFF"
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: parent.height - templateCard.radius
                                        color: "#FFFFFF"
                                    }
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: coverSource
                                    maskSource: coverMask
                                    cached: true
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                z: 1
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openTemplate(cardCell.modelData)
                            }

                            Item {
                                id: cardTextPanel
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: templateCard.hovered ? 132 : 100
                                z: 2

                                Behavior on height {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: templateCard.radius
                                    color: "#FFFFFF"
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: templateCard.radius
                                    color: "#FFFFFF"
                                }

                                Column {
                                    z: 1
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.top: parent.top
                                    anchors.topMargin: 10
                                    spacing: 4

                                    Label {
                                        width: parent.width
                                        text: root.templateTitle(cardCell.modelData)
                                        font.pixelSize: 17
                                        font.weight: Font.DemiBold
                                        color: "#D9000000"
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        width: parent.width
                                        text: root.templateDetail(cardCell.modelData)
                                        font.pixelSize: 13
                                        lineHeight: 1.25
                                        color: "#73000000"
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Item {
                                        width: 1
                                        height: templateCard.hovered ? 4 : 0
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: templateCard.hovered ? 34 : 0
                                        radius: 6
                                        visible: height > 0
                                        color: useTemplateMouse.pressed ? "#0056CC" : "#006BFF"

                                        Behavior on height {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            text: qsTr("使用")
                                            font.pixelSize: 14
                                            color: "#FFFFFF"
                                        }
                                        MouseArea {
                                            id: useTemplateMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openTemplate(cardCell.modelData)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                z: 3
                                radius: templateCard.radius
                                color: "transparent"
                                border.width: 1
                                border.color: "#EBEDF0"
                            }
                        }
                    }
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: root.loading && templateGrid.count === 0
                    visible: running
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: !root.loading && templateGrid.count === 0
                             && (root.selectedCategory !== root.userTemplateCategory
                                 || root.searchText.length > 0)
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 54; height: 54
                        source: "qrc:/images/doc/document-text.svg"
                        opacity: 0.55
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.searchText ? qsTr("未找到匹配模板") : qsTr("暂无模板")
                        font.pixelSize: 15
                        color: "#73000000"
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: !root.loading && templateGrid.count === 0
                             && root.selectedCategory === root.userTemplateCategory
                             && root.searchText.length === 0

                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 150
                        height: 112
                        source: "qrc:/images/templateEmpty.png"
                        fillMode: Image.PreserveAspectFit
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("上传你的第一个自定义模板吧")
                        font.pixelSize: 15
                        color: "#73000000"
                    }
                    CustomButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        backgroundColor: "#006BFF"
                        hoverBackgroundColor: "#1677FF"
                        pressedBackgroundColor: "#0056CC"
                        iconSource: "qrc:/images/upload-white.png"
                        iconSize: 16
                        text: qsTr("上传")
                        fontSize: 14
                        textColor: "#FFFFFF"
                        buttonWidth: 76
                        buttonHeight: 36
                        onClicked: root.openUploadDialog()
                    }
                }
            }
        }
    }

    Popup {
        id: templateUseDialog
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(900, parent.width - 48)
        height: Math.min(720, parent.height - 48)
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        Overlay.modal: Rectangle { color: "#66000000" }

        background: Rectangle {
            color: "#FFFFFF"
            radius: 16
        }

        onClosed: {
            root.previewOpen = false
            root.activeTemplate = ({})
        }
        onOpened: previewFlick.contentY = 0

        contentItem: Item {
            Rectangle {
                id: dialogHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 88
                color: "transparent"

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.right: dialogCloseButton.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Label {
                        width: parent.width
                        text: root.templateTitle(root.activeTemplate)
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                        color: "#D9000000"
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: root.templateDetail(root.activeTemplate)
                        font.pixelSize: 13
                        color: "#73000000"
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: dialogCloseButton
                    width: 34; height: 34; radius: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    color: dialogCloseMouse.containsMouse ? "#F0F1F3" : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 22
                        color: "#A6000000"
                    }
                    MouseArea {
                        id: dialogCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closePreview()
                    }
                }
            }

            Rectangle {
                id: dialogPreview
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.top: dialogHeader.bottom
                anchors.bottom: dialogFooter.top
                radius: 8
                color: "#F5F7F9"
                clip: true

                Flickable {
                    id: previewFlick
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: Math.max(height, largeTemplatePreview.height + 40)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Image {
                        id: largeTemplatePreview
                        x: 20
                        y: 20
                        width: Math.max(1, previewFlick.width - 40)
                        height: sourceSize.width > 0
                                ? width * sourceSize.height / sourceSize.width : 0
                        source: root.absolutePreviewUrl(root.activeTemplate)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                    }
                }
                BusyIndicator {
                    anchors.centerIn: parent
                    running: largeTemplatePreview.status === Image.Loading
                    visible: running
                }
                Label {
                    anchors.centerIn: parent
                    visible: largeTemplatePreview.status === Image.Error
                    text: qsTr("模板预览加载失败")
                    font.pixelSize: 14
                    color: "#99000000"
                }
            }

            Item {
                id: dialogFooter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 74

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 82; height: 36; radius: 6
                        color: cancelDialogMouse.containsMouse ? "#F3F4F6" : "#FFFFFF"
                        border.width: 1
                        border.color: "#1A000000"
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("取消")
                            font.pixelSize: 14
                            color: "#A6000000"
                        }
                        MouseArea {
                            id: cancelDialogMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePreview()
                        }
                    }

                    Rectangle {
                        width: 96; height: 36; radius: 6
                        color: confirmTemplateMouse.pressed ? "#0056CC" : "#006BFF"
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("使用该模板")
                            font.pixelSize: 14
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            id: confirmTemplateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var selected = root.activeTemplate
                                root.closePreview()
                                root.useTemplateRequested(selected)
                            }
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: uploadDialog
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(566, parent.width - 32)
        height: Math.min(664, parent.height - 32)
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        Overlay.modal: Rectangle { color: "#66000000" }

        background: Rectangle {
            color: "#FFFFFF"
            radius: 12
        }

        contentItem: Item {
            Rectangle {
                id: uploadHeader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 58
                color: "transparent"

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("上传自定义模板")
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    color: "#D9000000"
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: uploadCloseMouse.containsMouse ? "#F1F2F4" : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 21
                        color: "#A6000000"
                    }
                    MouseArea {
                        id: uploadCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.uploadBusy
                        onClicked: uploadDialog.close()
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: "#EBEDF0"
                }
            }

            Flickable {
                id: uploadFormFlick
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: uploadHeader.bottom
                anchors.bottom: uploadFooter.top
                contentWidth: width
                contentHeight: uploadForm.height + 36
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: uploadForm
                    x: 24
                    y: 18
                    width: uploadFormFlick.width - 48
                    spacing: 14

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板名称")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        TextField {
                            id: uploadNameInput
                            width: parent.width
                            height: 36
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 0
                            bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            font.pixelSize: 14
                            color: "#D9000000"
                            placeholderText: qsTr("如：XX医院设备验收报告模板")
                            placeholderTextColor: "#52000000"
                            selectByMouse: true
                            background: Rectangle {
                                radius: 8
                                color: "#FFFFFF"
                                border.width: 1
                                border.color: uploadNameInput.activeFocus ? "#006BFF" : "#1F000000"
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板简介")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        TextArea {
                            id: uploadDescriptionInput
                            width: parent.width
                            height: 68
                            leftPadding: 12
                            rightPadding: 12
                            topPadding: 8
                            bottomPadding: 8
                            font.pixelSize: 14
                            color: "#D9000000"
                            placeholderText: qsTr("简要描述模板用途和适用场景，如：用于大型影像设备验收检测，包含外观检查、功能测试、性能指标等栏目")
                            placeholderTextColor: "#52000000"
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            background: Rectangle {
                                radius: 8
                                color: "#FFFFFF"
                                border.width: 1
                                border.color: uploadDescriptionInput.activeFocus ? "#006BFF" : "#1F000000"
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板附件")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Rectangle {
                            width: parent.width
                            height: root.pendingTemplateFileUrl ? 36 : 118
                            radius: 8
                            color: root.pendingTemplateFileUrl ? "#F0F1F3" : "#F7F9FA"
                            border.width: root.pendingTemplateFileUrl ? 0 : 1
                            border.color: "#DDE1E7"

                            Row {
                                visible: root.pendingTemplateFileUrl.length > 0
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: templateFileClear.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Image {
                                    width: 18
                                    height: 18
                                    source: "qrc:/images/doc/document-word.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                Label {
                                    width: parent.width - 26
                                    text: root.pendingTemplateFileName
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                    elide: Text.ElideMiddle
                                }
                            }

                            Label {
                                id: templateFileClear
                                visible: root.pendingTemplateFileUrl.length > 0
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                font.pixelSize: 17
                                color: "#73000000"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingTemplateFileUrl = ""
                                        root.pendingTemplateFileName = ""
                                    }
                                }
                            }

                            Column {
                                visible: root.pendingTemplateFileUrl.length === 0
                                anchors.centerIn: parent
                                spacing: 6
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Label {
                                        text: qsTr("选择文件")
                                        font.pixelSize: 15
                                        color: "#006BFF"
                                    }
                                    Label {
                                        text: qsTr("或 拖拽文件至此")
                                        font.pixelSize: 15
                                        color: "#A6000000"
                                    }
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("支持 word，MD，html格式")
                                    font.pixelSize: 14
                                    color: "#66000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: root.pendingTemplateFileUrl.length === 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: templateFileDialog.open()
                            }
                            DropArea {
                                anchors.fill: parent
                                enabled: root.pendingTemplateFileUrl.length === 0
                                onDropped: function(drop) {
                                    if (drop.urls && drop.urls.length > 0)
                                        root.setTemplateFile(drop.urls[0])
                                    drop.acceptProposedAction()
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板封面")
                            font.pixelSize: 14
                            color: "#D9000000"
                        }
                        Rectangle {
                            width: parent.width
                            height: root.pendingCoverFileUrl ? 36 : 118
                            radius: 8
                            color: root.pendingCoverFileUrl ? "#F0F1F3" : "#F7F9FA"
                            border.width: root.pendingCoverFileUrl ? 0 : 1
                            border.color: "#DDE1E7"

                            Row {
                                visible: root.pendingCoverFileUrl.length > 0
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: coverFileClear.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                Image {
                                    width: 18
                                    height: 18
                                    source: "qrc:/images/doc/document-text.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                Label {
                                    width: parent.width - 26
                                    text: root.pendingCoverFileName
                                    font.pixelSize: 14
                                    color: "#D9000000"
                                    elide: Text.ElideMiddle
                                }
                            }

                            Label {
                                id: coverFileClear
                                visible: root.pendingCoverFileUrl.length > 0
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "×"
                                font.pixelSize: 17
                                color: "#73000000"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.pendingCoverFileUrl = ""
                                        root.pendingCoverFileName = ""
                                    }
                                }
                            }

                            Column {
                                visible: root.pendingCoverFileUrl.length === 0
                                anchors.centerIn: parent
                                spacing: 6
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Label {
                                        text: qsTr("选择文件")
                                        font.pixelSize: 15
                                        color: "#006BFF"
                                    }
                                    Label {
                                        text: qsTr("或 拖拽文件至此")
                                        font.pixelSize: 15
                                        color: "#A6000000"
                                    }
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("支持jpg，png，建议 400x300")
                                    font.pixelSize: 14
                                    color: "#66000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: root.pendingCoverFileUrl.length === 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: coverFileDialog.open()
                            }
                            DropArea {
                                anchors.fill: parent
                                enabled: root.pendingCoverFileUrl.length === 0
                                onDropped: function(drop) {
                                    if (drop.urls && drop.urls.length > 0)
                                        root.setCoverFile(drop.urls[0])
                                    drop.acceptProposedAction()
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: uploadFooter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 76

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    CustomButton {
                        backgroundColor: "#FFFFFF"
                        hoverBackgroundColor: "#F5F6F8"
                        pressedBackgroundColor: "#EBEDF0"
                        borderWidth: 1
                        borderColor: "#DDE1E7"
                        text: qsTr("取消")
                        fontSize: 14
                        textColor: "#73000000"
                        hoverTextColor: "#73000000"
                        pressedTextColor: "#73000000"
                        buttonWidth: 92
                        buttonHeight: 38
                        enabled: !root.uploadBusy
                        onClicked: uploadDialog.close()
                    }
                    CustomButton {
                        backgroundColor: "#006BFF"
                        hoverBackgroundColor: "#1677FF"
                        pressedBackgroundColor: "#0056CC"
                        disabledBackgroundColor: "#A9CBFF"
                        text: root.uploadBusy ? qsTr("上传中...") : qsTr("上传")
                        fontSize: 14
                        textColor: "#FFFFFF"
                        disabledTextColor: "#FFFFFF"
                        buttonWidth: 92
                        buttonHeight: 38
                        enabled: root.uploadReady && !root.uploadBusy
                        onClicked: {
                            root.uploadBusy = true
                            root.uploadTemplateRequested(
                                uploadNameInput.text.trim(),
                                uploadDescriptionInput.text.trim(),
                                root.pendingTemplateFileUrl,
                                root.pendingCoverFileUrl)
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: templateFileDialog
        title: qsTr("选择模板附件")
        nameFilters: [qsTr("支持的模板 (*.doc *.docx *.md *.html *.htm)")]
        selectMultiple: false
        onAccepted: root.setTemplateFile(fileUrl)
    }

    FileDialog {
        id: coverFileDialog
        title: qsTr("选择模板封面")
        nameFilters: [qsTr("支持的图片 (*.jpg *.jpeg *.png)")]
        selectMultiple: false
        onAccepted: root.setCoverFile(fileUrl)
    }
}
