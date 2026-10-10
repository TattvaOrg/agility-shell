import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    readonly property bool isLow: BarDataService.batteryPercent <= 20.0
    readonly property bool isCritical: BarDataService.batteryPercent <= 10.0
    readonly property bool isCharging: BarDataService.batteryCharging

    readonly property color statusColor: {
        if (isCharging) return Theme.colAccentGreen
        if (isCritical) return "#EF4444"
        if (isLow) return Theme.colAccentWarning
        return Theme.colAccent
    }

    GlassPill {
        anchors.fill: parent
        interactive: false

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                GlassIcon {
                    anchors.centerIn: parent
                    source: root.isLow ? "battery-low" : "battery"
                    size: 15
                    color: root.statusColor

                    // Charging pulse animation
                    SequentialAnimation on opacity {
                        running: root.isCharging
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.45; duration: 800; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.45; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(BarDataService.batteryPercent) + "%"
                color: root.statusColor
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }
}
