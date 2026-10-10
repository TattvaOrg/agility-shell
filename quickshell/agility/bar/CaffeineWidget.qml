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
        active: BarDataService.caffeineActive
        onClicked: BarDataService.toggleCaffeine()

        GlassIcon {
            anchors.centerIn: parent
            source: "caffeine"
            size: 15
            color: BarDataService.caffeineActive ? Theme.colAccent : Theme.colTextSec
        }
    }
}
