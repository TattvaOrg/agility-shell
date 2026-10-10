import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: 32

    signal clicked()

    GlassPill {
        anchors.fill: parent
        interactive: true
        onClicked: {
            root.clicked()
            BarDataService.lockSession()
        }

        GlassIcon {
            anchors.centerIn: parent
            source: "power"
            size: 15
            color: "#EF4444"
        }
    }
}
