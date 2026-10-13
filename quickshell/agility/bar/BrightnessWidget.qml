import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    GlassPill {
        anchors.fill: parent
        interactive: true

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "brightness"
                size: 15
                color: Theme.colAccentWarning
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(BarDataService.brightness * 100) + "%"
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onWheel: function(wheel) {
                var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                BarDataService.setBrightness(BarDataService.brightness + delta)
            }
        }
    }
}
