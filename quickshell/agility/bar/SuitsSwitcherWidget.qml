import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 20

    GlassPill {
        anchors.fill: parent
        interactive: true
        onClicked: BarDataService.nextSuite()

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "✦"
                color: Theme.colAccent
                font.pixelSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BarDataService.activeSuiteName
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onWheel: function(wheel) {
                BarDataService.nextSuite()
            }
        }
    }
}
