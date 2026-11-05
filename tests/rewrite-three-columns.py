import io

p = 'main.qml'
src = io.open(p, encoding='utf-8').read()
lines = src.split('\n')

# ---------- 1) 在 artifactSidebar 之前插入「输入文件」中栏 ----------
anchor = '''                Rectangle {
                    id: artifactSidebar
                    visible: newTaskRec.artifactPanelVisible'''
assert src.count(anchor) == 1

middle = '''                // ── 中间栏：输入文件（文件夹树，带连接线）─────────────────
                Rectangle {
                    id: splitFilesPanel

                    visible: newTaskRec.splitMode
                    width: newTaskRec.splitFilesWidth
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: artifactSidebar.left
                    color: "#FFFFFF"

                    Rectangle {
                        width: 1
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: "#14000000"
                    }

                    Item {
                        id: splitFilesHeader

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 52

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("输入文件")
                            color: "#D9000000"
                            font.family: "Alibaba PuHuiTi 3.0"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: "#0F000000"
                        }
                    }

                    InputFileTree {
                        id: splitTree
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: splitFilesHeader.bottom
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 4
                        anchors.bottomMargin: 76

                        onFileSelected: function(path) {
                            newTaskRec.openArtifactPath(path)
                        }
                        onSelectionChanged: function(paths) {
                            newTaskRec.splitSelection = paths
                        }
                        onFileTreeReady: openPaths(newTaskRec.splitRoots)
                    }

                    Connections {
                        target: newTaskRec
                        function onSplitRootsChanged() {
                            if (newTaskRec.splitMode)
                                splitTree.openPaths(newTaskRec.splitRoots)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: newTaskRec.splitRoots.length === 0
                        text: qsTr("把一个文件夹拖到对话里，或按 Ctrl+Shift+W 选择")
                        color: "#40000000"
                        font.family: "Alibaba PuHuiTi 3.0"
                        font.pixelSize: 13
                    }

                    // 选择操作条
                    Rectangle {
                        id: splitActionBar

                        visible: newTaskRec.splitSelection.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 16
                        width: Math.min(parent.width - 24, splitActionRow.implicitWidth + 24)
                        height: 48
                        radius: 8
                        color: "#FFFFFF"
                        border.width: 1
                        border.color: "#E6E7EB"

                        Row {
                            id: splitActionRow

                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("已选 %1 个").arg(newTaskRec.splitSelection.length)
                                color: "#D9000000"
                                font.family: "Alibaba PuHuiTi 3.0"
                                font.pixelSize: 14
                            }

                            Rectangle {
                                width: splitOpenLabel.implicitWidth + 28
                                height: 32
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: splitOpenMouse.containsMouse ? "#F4F6F9" : "#FFFFFF"
                                border.width: 1
                                border.color: "#E6E7EB"

                                Text {
                                    id: splitOpenLabel
                                    anchors.centerIn: parent
                                    text: qsTr("在阅片台打开")
                                    color: "#D9000000"
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: splitOpenMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: newTaskRec.openSplitSelectionInViewer()
                                }
                            }

                            Rectangle {
                                width: splitReferenceLabel.implicitWidth + 28
                                height: 32
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: splitReferenceMouse.containsMouse ? "#0058D6" : "#006BFF"

                                Text {
                                    id: splitReferenceLabel
                                    anchors.centerIn: parent
                                    text: qsTr("在对话框中引用")
                                    color: "#FFFFFF"
                                    font.family: "Alibaba PuHuiTi 3.0"
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: splitReferenceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: newTaskRec.referenceSplitSelection()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: artifactSidebar
                    visible: newTaskRec.artifactPanelVisible'''

src = src.replace(anchor, middle, 1)

# ---------- 2) 把右侧栏里的旧 splitPanel 换成「产物」面板 ----------
lines = src.split('\n')
start = None
for i, l in enumerate(lines):
    if l.strip() == '// ── 并排模式（Figma 5068-48030）──':
        start = i
        break
assert start is not None
# 结束：doc: 'Item {' officeDocumentPanel 之前
end = None
for i in range(start, len(lines)):
    if 'id: officeDocumentPanel' in lines[i]:
        end = i - 1     # 指向 'Item {' 行
        break
assert end is not None
while lines[end].strip() != 'Item {':
    end -= 1

artifacts_panel = '''                    // ── 右侧栏：产物（普通列表，文件夹不连连接线）──
                    Item {
                        id: splitPanel

                        visible: newTaskRec.splitMode
                        anchors.fill: parent

                        Item {
                            id: splitArtifactsHeader

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 52

                            Text {
                                id: splitArtifactsTitle
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: newTaskRec.splitArtifactRows.length > 0
                                      ? qsTr("产物 (%1)").arg(newTaskRec.splitArtifactFileCount)
                                      : qsTr("产物")
                                color: "#D9000000"
                                font.family: "Alibaba PuHuiTi 3.0"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                            }

                            Rectangle {
                                id: splitCloseButton

                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32
                                height: 32
                                radius: 8
                                color: splitCloseMouse.containsMouse ? "#0A000000" : "transparent"

                                Canvas {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.strokeStyle = "#D9000000"
                                        ctx.lineWidth = 1.4
                                        ctx.lineCap = "round"
                                        ctx.beginPath()
                                        ctx.moveTo(3.5, 3.5)
                                        ctx.lineTo(12.5, 12.5)
                                        ctx.moveTo(12.5, 3.5)
                                        ctx.lineTo(3.5, 12.5)
                                        ctx.stroke()
                                    }
                                }

                                MouseArea {
                                    id: splitCloseMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: newTaskRec.exitSplit()
                                }

                                ToolTip.visible: splitCloseMouse.containsMouse
                                ToolTip.text: qsTr("退出并排视图")
                            }
                        }

                        // 筛选胶囊：只有真的存在该类产物时才出现
                        Row {
                            id: artifactFilters

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.top: splitArtifactsHeader.bottom
                            spacing: 8

                            Repeater {
                                model: newTaskRec.splitArtifactFilterChips

                                delegate: Rectangle {
                                    id: artifactFilterChip

                                    required property var modelData

                                    readonly property bool active:
                                        newTaskRec.splitArtifactFilter === modelData.key

                                    width: 74
                                    height: 29
                                    radius: 8
                                    color: active ? "#006BFF"
                                                  : (chipMouse.containsMouse ? "#EFF2F6" : "#F7F9FA")

                                    Text {
                                        anchors.centerIn: parent
                                        text: artifactFilterChip.modelData.label
                                        color: artifactFilterChip.active ? "#FFFFFF" : "#D9000000"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        id: chipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newTaskRec.splitArtifactFilter
                                                   = artifactFilterChip.modelData.key
                                    }
                                }
                            }
                        }

                        ListView {
                            id: splitArtifactList

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: artifactFilters.bottom
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            clip: true
                            spacing: 2
                            model: newTaskRec.splitArtifactRows
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                id: artifactRowItem

                                required property var modelData

                                readonly property bool isDir: modelData.isDir === true

                                width: splitArtifactList.width
                                height: 32
                                radius: 8
                                color: artifactRowMouse.containsMouse ? "#F4F6F9" : "transparent"

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8 + (artifactRowItem.modelData.depth || 0) * 16
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Canvas {
                                        visible: artifactRowItem.isDir
                                        width: 16
                                        height: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        rotation: artifactRowItem.modelData.collapsed ? -90 : 0

                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.strokeStyle = "#73000000"
                                            ctx.lineWidth = 1.2
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            ctx.beginPath()
                                            ctx.moveTo(5, 6.5)
                                            ctx.lineTo(8, 9.5)
                                            ctx.lineTo(11, 6.5)
                                            ctx.stroke()
                                        }
                                    }

                                    Image {
                                        width: 20
                                        height: 20
                                        anchors.verticalCenter: parent.verticalCenter
                                        source: artifactRowItem.isDir
                                                ? "qrc:/images/folder.png"
                                                : newTaskRec.artifactIcon(artifactRowItem.modelData)
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        width: parent.width - 42
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: artifactRowItem.modelData.name
                                        color: "#D9000000"
                                        font.family: "Alibaba PuHuiTi 3.0"
                                        font.pixelSize: 14
                                        elide: Text.ElideMiddle
                                    }
                                }

                                MouseArea {
                                    id: artifactRowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (artifactRowItem.isDir)
                                            newTaskRec.toggleArtifactFolder(artifactRowItem.modelData.path)
                                        else
                                            newTaskRec.openArtifactPath(artifactRowItem.modelData.path)
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: splitArtifactList.count === 0
                                text: qsTr("还没有产物")
                                color: "#40000000"
                                font.family: "Alibaba PuHuiTi 3.0"
                                font.pixelSize: 13
                            }
                        }
                    }

'''

out = lines[:start] + artifacts_panel.split('\n') + lines[end:]
io.open(p, 'w', encoding='utf-8', newline='').write('\n'.join(out))
print('three-column layout written')
