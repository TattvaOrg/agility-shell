import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    signal clicked()

    GlassPill {
        anchors.fill: parent
        interactive: true
        active: BarDataService.unreadNotifications > 0
        badgeText: BarDataService.unreadNotifications > 0 ? BarDataService.unreadNotifications.toString() : ""
        onClicked: root.clicked()

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: BarDataService.dndEnabled ? "bell-slash" : "bell"
                size: 15
                color: BarDataService.dndEnabled ? Theme.colAccentWarning : Theme.colAccent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BarDataService.dndEnabled ? "DND" : (BarDataService.unreadNotifications > 0 ? BarDataService.unreadNotifications.toString() : "")
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
                visible: text !== ""
            }
        }
    }
}
