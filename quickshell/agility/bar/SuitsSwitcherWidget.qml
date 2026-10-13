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

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "sparkles"
                iconSize: 13
                iconColor: Theme.colAccent
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
