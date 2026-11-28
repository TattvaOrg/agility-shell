import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Item {
    id: root

    property string label: ""
    property string description: ""
    property int labelSize: 13
    property bool isSubSetting: false
    default property alias content: controlContainer.data

    implicitHeight: Math.max(38, mainLayout.implicitHeight + 8)
    Layout.fillWidth: true

    RowLayout {
        id: mainLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Constants.sizeMd

        ColumnLayout {
            spacing: 2
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.fillWidth: true

            ThemedText {
                text: root.label
                customSize: root.labelSize
                font.weight: Font.Medium
                color: root.enabled ? Theme.fg : Theme.muted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            ThemedText {
                text: root.description
                customSize: 11
                color: Theme.muted
                visible: root.description !== ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Item {
            id: controlContainer

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }
}
