import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import MedClaw.Theme 1.0

Item {
    id: root

    property var templates: []
    property var userTemplates: []
    property bool loading: false
    property string gatewayHttpBaseUrl: ""
    property string searchText: ""
    property bool governmentEdition: false
    property bool imagingEdition: false
    property string selectedCategory: imagingEdition ? "医工交叉期刊类"
                                                      : governmentEdition ? "政务类" : "精选"
    property var activeTemplate: ({})
    property bool previewOpen: false
    property bool uploadBusy: false
    property var pendingDeleteTemplate: ({})
    property string pendingTemplateFileUrl: ""
    property string pendingTemplateFileName: ""
    property string pendingCoverFileUrl: ""
    property string pendingCoverFileName: ""
    readonly property string userTemplateCategory: qsTr("用户上传模板")
    readonly property bool uploadReady: uploadNameInput.text.trim().length > 0
                                        && pendingTemplateFileUrl.length > 0
                                        && pendingCoverFileUrl.length > 0
    property var categories: imagingEdition
        ? ["医工交叉期刊类", "设备科工作模板类", "用户上传模板"]
        : governmentEdition
          ? ["政务类", "用户上传模板"]
          : [
            "精选", "国际国内期刊论文类", "行业情报类", "新药研发类",
            "药品注册申报类", "医药监管申报合规类", "药品准入与HTA类",
            "政务类", "医工交叉期刊类", "设备科工作模板类", "用户上传模板"
        ]

    signal refreshRequested()
    signal addTemplateRequested()
    signal uploadTemplateRequested(string name, string description,
                                   string templateFileUrl, string coverFileUrl)
    signal useTemplateRequested(var template)
    signal deleteTemplateRequested(var template)
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

    function templateIntroduction(template) {
        var intro = String(template && (template.introduction || template.intro) || "")
        var trigger = String(template && (template.triggerScene || template.trigger_scene) || "")
        if (intro && trigger && intro !== trigger)
            return intro + "\n" + trigger
        return intro || trigger || root.templateDetail(template)
    }

    function templateStructure(template) {
        return String((template && (template.structureFramework
                                    || template.structure_framework
                                    || template.structure || template.framework)) || "")
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

    function requestDeleteTemplate(template) {
        pendingDeleteTemplate = template || ({})
        deleteConfirmDialog.open()
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

    onSelectedCategoryChanged: {
        if (categories.indexOf(selectedCategory) < 0)
            selectedCategory = imagingEdition ? categories[0]
                                               : governmentEdition ? categories[0] : "精选"
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface

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
                        color: Theme.textPrimary
                    }
                    Label {
                        text: qsTr("探索真实工作案例，找到模板，一键开始")
                        font.pixelSize: 12
                        color: Theme.textSecondary
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
                        border.color: templateSearch.activeFocus ? Theme.accent : Theme.dividerTopbar
                        color: Theme.surface
                        Image {
                            width: 16; height: 16
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            source: "qrc:/images/search.png"
                            opacity: 0.6
                            layer.enabled: true
                            layer.effect: ColorOverlay { color: Theme.iconColor; cached: true }
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
                            color: Theme.textSecondary
                            placeholderText: qsTr("搜索模板库...")
                            placeholderTextColor: Theme.textDim
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            background: Item {}
                            cursorDelegate: Rectangle {
                                width: 1
                                color: Theme.accent
                            }
                            onTextChanged: root.searchText = text
                        }
                    }
                    CustomButton {
                        id: headerUploadButton
                        backgroundColor: Theme.accentTintBg
                        hoverBackgroundColor: Theme.accentTintBg
                        pressedBackgroundColor: Theme.accentTintBg
                        iconSource: "qrc:/images/uploadTemplate.png"
                        iconSize: 16
                        text: qsTr("上传")
                        fontSize: 14
                        textColor: Theme.accent
                        hoverTextColor: Theme.accent
                        pressedTextColor: Theme.accent
                        buttonWidth: 72
                        buttonHeight: 38
                        onClicked: root.openUploadDialog()

                        ToolTip {
                            id: templateUploadTip
                            visible: headerUploadButton.containsMouse
                            text: qsTr("支持 word，MD，html格式")
                            delay: 400
                            background: Rectangle {
                                color: Theme.textSecondary
                                radius: 4
                            }
                            contentItem: Text {
                                text: templateUploadTip.text
                                font.pixelSize: 14
                                font.family: "Alibaba PuHuiTi 3.0"
                                color: Theme.surface
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
                        color: root.selectedCategory === modelData ? Theme.accentSoftBg
                              : categoryMouse.containsMouse ? Theme.surfaceAlt : Theme.surfaceMuted
                        Label {
                            id: categoryLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 14
                            color: root.selectedCategory === modelData ? Theme.accent : Theme.textDim
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
                                                             || deleteTemplateMouse.containsMouse
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 8
                            height: 314
                            radius: 12
                            color: Theme.surface
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
                                        color: Theme.surfaceMuted
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
                                        color: Theme.surface
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: parent.height - templateCard.radius
                                        color: Theme.surface
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
                                height: templateCard.hovered
                                        ? (cardCell.modelData.isUserTemplate ? 174 : 132)
                                        : 100
                                z: 2

                                Behavior on height {
                                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: templateCard.radius
                                    color: Theme.surface
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: templateCard.radius
                                    color: Theme.surface
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
                                        font.pixelSize: 20
                                        font.weight: Font.DemiBold
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        width: parent.width
                                        text: root.templateDetail(cardCell.modelData)
                                        font.pixelSize: 14
                                        lineHeight: 1.25
                                        color: Theme.textTertiary
                                        wrapMode: Text.Wrap
                                        maximumLineCount: 1
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
                                        color: useTemplateMouse.pressed ? Theme.accentPressed : Theme.accent

                                        Behavior on height {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            text: qsTr("使用")
                                            font.pixelSize: 14
                                            color: Theme.textInverse
                                        }
                                        MouseArea {
                                            id: useTemplateMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openTemplate(cardCell.modelData)
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: templateCard.hovered && cardCell.modelData.isUserTemplate ? 34 : 0
                                        radius: 6
                                        visible: height > 0
                                        color: deleteTemplateMouse.pressed ? Theme.danger
                                              : deleteTemplateMouse.containsMouse ? Theme.danger : Theme.danger
                                        border.width: 1
                                        border.color: Theme.danger

                                        Behavior on height {
                                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            text: qsTr("删除")
                                            font.pixelSize: 14
                                            color: Theme.textInverse
                                        }
                                        MouseArea {
                                            id: deleteTemplateMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.requestDeleteTemplate(cardCell.modelData)
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
                                border.color: Theme.surfaceSelectedAlt
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
                        color: Theme.textTertiary
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
                        color: Theme.textTertiary
                    }
                    CustomButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        backgroundColor: Theme.accent
                        hoverBackgroundColor: Theme.accentHover
                        pressedBackgroundColor: Theme.accentPressed
                        iconSource: "qrc:/images/upload-white.png"
                        iconSize: 16
                        text: qsTr("上传")
                        fontSize: 14
                        textColor: Theme.textInverse
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
        width: Math.min(980, parent.width - 32)
        height: Math.min(680, parent.height - 32)
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        Overlay.modal: Rectangle { color: Theme.scrimMedium }

        background: Rectangle {
            color: Theme.surface
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
                anchors.left: dialogPreview.right
                anchors.leftMargin: 1
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: "transparent"

                Image {
                    id: dialogTemplateIcon
                    source: "qrc:/images/template.png"
                    width: 24
                    height: 24
                    fillMode: Image.PreserveAspectFit
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: dialogCloseButton.verticalCenter
                    layer.enabled: true
                    layer.effect: ColorOverlay { color: Theme.iconColor; cached: true }
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.top: dialogTemplateIcon.bottom
                    anchors.topMargin: 20
                    spacing: 8
                    Label {
                        width: parent.width
                        text: root.templateTitle(root.activeTemplate)
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        wrapMode: Text.Wrap
                    }
                    Label {
                        width: parent.width
                        text: qsTr("介绍 / 触发场景：") + root.templateIntroduction(root.activeTemplate)
                        font.pixelSize: 14
                        color: Theme.textTertiary
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        lineHeight: 1.3
                    }
                    Label {
                        width: parent.width
                        visible: root.templateStructure(root.activeTemplate).length > 0
                        text: qsTr("结构框架：") + root.templateStructure(root.activeTemplate)
                        font.pixelSize: 14
                        color: Theme.textTertiary
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        lineHeight: 1.3
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.surfaceSelectedAlt
                }

                Rectangle {
                    id: dialogCloseButton
                    width: 34; height: 34; radius: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.top: parent.top
                    anchors.topMargin: 24
                    color: dialogCloseMouse.containsMouse ? Theme.surfaceAlt : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 24
                        color: Theme.textSecondary
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
                width: parent.width * 0.66
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 8
                color: Theme.surfaceMuted
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
                        x: 0
                        y: 12
                        width: Math.max(1, previewFlick.width)
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
                    color: Theme.textDim
                }
            }

            Item {
                id: dialogFooter
                anchors.left: dialogHeader.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 74

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: 82; height: 36; radius: 6
                        color: cancelDialogMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                        border.width: 1
                        border.color: Theme.divider
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("取消")
                            font.pixelSize: 14
                            color: Theme.textSecondary
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
                        color: confirmTemplateMouse.pressed ? Theme.accentPressed : Theme.accent
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("使用该模板")
                            font.pixelSize: 14
                            color: Theme.textInverse
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
        id: deleteConfirmDialog
        parent: Overlay.overlay
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: Math.min(380, parent.width - 40)
        height: 188
        padding: 0
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        onClosed: root.pendingDeleteTemplate = ({})
        Overlay.modal: Rectangle { color: Theme.scrimMedium }
        background: Rectangle { color: Theme.surface; radius: 12 }
        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14
            Label {
                text: qsTr("删除模板")
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
            Label {
                width: parent.width
                text: qsTr("确定删除“%1”吗？删除后无法恢复。\n模板文件和封面也会一并删除。")
                      .arg(root.templateTitle(root.pendingDeleteTemplate))
                wrapMode: Text.Wrap
                font.pixelSize: 14
                color: Theme.textTertiary
            }
            Item {
                width: parent.width
                height: 34
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    Rectangle {
                        width: 78; height: 34; radius: 6
                        color: cancelDeleteMouse.containsMouse ? Theme.surfaceAlt : Theme.surface
                        border.width: 1; border.color: Theme.divider
                        Label { anchors.centerIn: parent; text: qsTr("取消"); font.pixelSize: 14; color: Theme.textSecondary }
                        MouseArea { id: cancelDeleteMouse; anchors.fill: parent; hoverEnabled: true; onClicked: deleteConfirmDialog.close();cursorShape: Qt.PointingHandCursor }
                    }
                    Rectangle {
                        width: 78; height: 34; radius: 6
                        color: confirmDeleteMouse.containsMouse ? Theme.danger : Theme.danger
                        Label { anchors.centerIn: parent; text: qsTr("删除"); font.pixelSize: 14; color: Theme.textInverse }
                        MouseArea {
                            id: confirmDeleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var selected = root.pendingDeleteTemplate
                                deleteConfirmDialog.close()
                                root.deleteTemplateRequested(selected)
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

        Overlay.modal: Rectangle { color: Theme.scrimMedium }

        background: Rectangle {
            color: Theme.surface
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
                    color: Theme.textPrimary
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: uploadCloseMouse.containsMouse ? Theme.surfaceAlt : "transparent"
                    Label {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 21
                        color: Theme.textSecondary
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
                    color: Theme.surfaceSelectedAlt
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
                            color: Theme.textPrimary
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
                            color: Theme.textPrimary
                            placeholderText: qsTr("如：XX医院设备验收报告模板")
                            placeholderTextColor: Theme.textFaint
                            selectByMouse: true
                            background: Rectangle {
                                radius: 8
                                color: Theme.surface
                                border.width: 1
                                border.color: uploadNameInput.activeFocus ? Theme.accent : Theme.dividerTopbar
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板简介")
                            font.pixelSize: 14
                            color: Theme.textPrimary
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
                            color: Theme.textPrimary
                            placeholderText: qsTr("简要描述模板用途和适用场景，如：用于大型影像设备验收检测，包含外观检查、功能测试、性能指标等栏目")
                            placeholderTextColor: Theme.textFaint
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            background: Rectangle {
                                radius: 8
                                color: Theme.surface
                                border.width: 1
                                border.color: uploadDescriptionInput.activeFocus ? Theme.accent : Theme.dividerTopbar
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7
                        Label {
                            text: qsTr("模板附件")
                            font.pixelSize: 14
                            color: Theme.textPrimary
                        }
                        Rectangle {
                            width: parent.width
                            height: root.pendingTemplateFileUrl ? 36 : 118
                            radius: 8
                            color: root.pendingTemplateFileUrl ? Theme.surfaceAlt : Theme.sidebarBg
                            border.width: root.pendingTemplateFileUrl ? 0 : 1
                            border.color: Theme.borderLight

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
                                    color: Theme.textPrimary
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
                                color: Theme.textTertiary
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
                                        color: Theme.accent
                                    }
                                    Label {
                                        text: qsTr("或 拖拽文件至此")
                                        font.pixelSize: 15
                                        color: Theme.textSecondary
                                    }
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("支持 word，MD，html格式")
                                    font.pixelSize: 14
                                    color: Theme.textDim
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
                            color: Theme.textPrimary
                        }
                        Rectangle {
                            width: parent.width
                            height: root.pendingCoverFileUrl ? 36 : 118
                            radius: 8
                            color: root.pendingCoverFileUrl ? Theme.surfaceAlt : Theme.sidebarBg
                            border.width: root.pendingCoverFileUrl ? 0 : 1
                            border.color: Theme.borderLight

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
                                    color: Theme.textPrimary
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
                                color: Theme.textTertiary
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
                                        color: Theme.accent
                                    }
                                    Label {
                                        text: qsTr("或 拖拽文件至此")
                                        font.pixelSize: 15
                                        color: Theme.textSecondary
                                    }
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: qsTr("支持jpg，png，建议 400x300")
                                    font.pixelSize: 14
                                    color: Theme.textDim
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
                        backgroundColor: Theme.surface
                        hoverBackgroundColor: Theme.surfaceMuted
                        pressedBackgroundColor: Theme.surfaceSelectedAlt
                        borderWidth: 1
                        borderColor: Theme.borderLight
                        text: qsTr("取消")
                        fontSize: 14
                        textColor: Theme.textTertiary
                        hoverTextColor: Theme.textTertiary
                        pressedTextColor: Theme.textTertiary
                        buttonWidth: 92
                        buttonHeight: 38
                        enabled: !root.uploadBusy
                        onClicked: uploadDialog.close()
                    }
                    CustomButton {
                        backgroundColor: Theme.accent
                        hoverBackgroundColor: Theme.accentHover
                        pressedBackgroundColor: Theme.accentPressed
                        disabledBackgroundColor: Theme.accentSoftBg
                        text: root.uploadBusy ? qsTr("上传中...") : qsTr("上传")
                        fontSize: 14
                        textColor: Theme.textInverse
                        disabledTextColor: Theme.surface
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
        fileMode: FileDialog.OpenFile
        onAccepted: root.setTemplateFile(selectedFile)
    }

    FileDialog {
        id: coverFileDialog
        title: qsTr("选择模板封面")
        nameFilters: [qsTr("支持的图片 (*.jpg *.jpeg *.png)")]
        fileMode: FileDialog.OpenFile
        onAccepted: root.setCoverFile(selectedFile)
    }
}
