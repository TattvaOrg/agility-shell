import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:agility-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        bottom: true
    }

    implicitWidth: 320
    implicitHeight: 120
    color: "transparent"

    visible: OsdService.isShowing

    // ─── Floating Liquid Glass Capsule ───
    GlassCard {
        id: osdCard
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: OsdService.isShowing ? 48 : 20
        width: 280
        height: 58
        radius: 29

        opacity: OsdService.isShowing ? 1.0 : 0.0
        scale: OsdService.isShowing ? 1.0 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.18 }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 14
            anchors.verticalCenter: parent.verticalCenter

            // Icon container with tinted circular background
            Rectangle {
                width: 36
                height: 36
                radius: 18
                anchors.verticalCenter: parent.verticalCenter
                color: OsdService.isMuted ? "#33FF5555" : (Theme.isGlass ? "#25FFFFFF" : Theme.colPillBg)
                border.color: OsdService.isMuted ? "#88FF5555" : (Theme.isGlass ? "#33FFFFFF" : Theme.borderColor)
                border.width: 1

                GlassIcon {
                    source: OsdService.icon
                    size: 18
                    color: OsdService.isMuted ? "#FF5555" : Theme.colAccent
                    anchors.centerIn: parent
                }
            }

            // Information & Gauge area
            Column {
                width: parent.width - 50
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                // Top label & percentage
                Row {
                    width: parent.width
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Text {
                        text: OsdService.label
                        color: Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: Math.max(0, parent.width - childrenRect.width)
                        height: 1
                    }

                    Text {
                        text: OsdService.valueText
                        color: OsdService.isMuted ? "#FF5555" : Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Gauge Bar or Badge
                Item {
                    width: parent.width
                    height: 8
                    visible: OsdService.showGauge

                    // Gauge background track
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Theme.isGlass ? "#22FFFFFF" : Theme.colPillBg
                        border.color: Theme.isGlass ? "#1AFFFFFF" : Theme.borderColor
                        border.width: 1
                    }

                    // Gauge fill bar
                    Rectangle {
                        id: fillBar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: 4
                        width: Math.max(0, Math.min(parent.width, Math.round(parent.width * Math.min(1.0, OsdService.gaugeLevel))))

                        color: OsdService.isMuted ? "#FF5555" : Theme.colAccent

                        Behavior on width {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // Pill text badge (for non-gauge items like Keyboard layout or Power profile)
                Item {
                    width: parent.width
                    height: 14
                    visible: !OsdService.showGauge

                    Text {
                        text: OsdService.valueText
                        color: Theme.colAccent
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.left: parent.left
                    }
                }
            }
        }
    }
}
