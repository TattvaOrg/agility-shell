import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: 32

    GlassPill {
        anchors.fill: parent
        interactive: true
        active: BarDataService.nightLightActive
        onClicked: BarDataService.toggleNightLight()

        GlassIcon {
            anchors.centerIn: parent
            source: "moon"
            size: 15
            color: BarDataService.nightLightActive ? Theme.colAccentWarning : Theme.colTextSec
        }
    }
}
