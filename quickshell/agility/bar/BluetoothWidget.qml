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
        active: BarDataService.bluetoothConnected

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "bluetooth"
                size: 15
                color: BarDataService.bluetoothConnected ? Theme.colAccent : Theme.colTextSec
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BarDataService.bluetoothConnected ? (BarDataService.bluetoothDeviceCount > 0 ? BarDataService.bluetoothDeviceCount.toString() : "On") : "Off"
                color: BarDataService.bluetoothConnected ? Theme.colText : Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
