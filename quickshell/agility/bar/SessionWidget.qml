import QtQuick
import ".."
import "../components"
import "../popouts" as Popouts

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
            Popouts.PopoutService.toggle("session")
        }

        GlassIcon {
            anchors.centerIn: parent
            source: "power"
            size: 15
            color: "#EF4444"
        }
    }
}
