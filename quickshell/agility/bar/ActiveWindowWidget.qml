import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: Math.min(280, Math.max(120, contentRow.implicitWidth + 20))
    visible: BarDataService.activeWindowTitle !== ""

    GlassCard {
        anchors.fill: parent
        radius: 16
        isTile: true

        Row {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: BarDataService.activeWindowAppId || "terminal"
                size: 16
                color: Theme.colAccent
            }

            GlassMarquee {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                height: 20
                text: BarDataService.activeWindowTitle || "Desktop"
                color: Theme.colText
                fontSize: 12
            }
        }
    }
}
