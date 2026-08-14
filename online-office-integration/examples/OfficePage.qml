import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    // The host page sets this to an absolute local document path.
    property string selectedDocumentPath: ""

    Loader {
        id: officeLoader
        anchors.fill: parent
        source: "qrc:/onlineoffice/OnlineOfficeView.qml"

        onLoaded: {
            item.client = onlineOffice
            if (root.selectedDocumentPath.length > 0)
                item.open(root.selectedDocumentPath, "view")
        }
    }

    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8
        z: 10

        Button {
            text: qsTr("预览")
            onClicked: officeLoader.item.switchMode("view")
        }

        Button {
            text: qsTr("编辑")
            onClicked: officeLoader.item.switchMode("edit")
        }

        Button {
            text: qsTr("关闭")
            onClicked: officeLoader.item.closeEditor()
        }
    }
}
