import QtQuick
import ".."
import "../components"
import "../launcher" as Launcher

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    signal clicked()

    GlassPill {
        anchors.fill: parent
        interactive: true
        active: Launcher.LauncherService.isOpen
        activeColor: Theme.colAccent

        onClicked: {
            root.clicked()
            Launcher.LauncherService.toggle()
        }

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "magnifying-glass"
                size: 15
                color: Launcher.LauncherService.isOpen ? Theme.colAccent : Theme.colText
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Dash"
                color: Launcher.LauncherService.isOpen ? Theme.colAccent : Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }
    }
}
