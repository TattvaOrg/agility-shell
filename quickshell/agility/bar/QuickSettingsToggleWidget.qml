import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    signal clicked()

    GlassPill {
        anchors.fill: parent
        interactive: true
        onClicked: root.clicked()

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "settings"
                size: 15
                color: Theme.colAccent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Controls"
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
