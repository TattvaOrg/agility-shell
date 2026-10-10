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
                source: BarDataService.wifiConnected ? "wifi" : "wifi-high-duotone.svg"
                size: 15
                color: BarDataService.wifiConnected ? Theme.colAccent : Theme.colTextSec
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BarDataService.wifiConnected ? BarDataService.wifiSsid : "Disconnected"
                color: BarDataService.wifiConnected ? Theme.colText : Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
