import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: Math.max(0, rowLayout.implicitWidth)
    visible: BarDataService.trayItems.length > 0

    GlassCard {
        anchors.fill: parent
        radius: 16
        isTile: true

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: BarDataService.trayItems

                Rectangle {
                    width: 24
                    height: 24
                    radius: 6
                    color: trayMouse.containsMouse ? "#33FFFFFF" : "transparent"

                    GlassIcon {
                        anchors.centerIn: parent
                        source: modelData.icon_name || "settings"
                        size: 16
                    }

                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                // Context menu trigger
                            } else {
                                // Activate trigger
                            }
                        }
                    }
                }
            }
        }
    }
}
