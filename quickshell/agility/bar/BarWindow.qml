import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    // Sizing & Modes
    property int barHeight: 38
    property bool isFloating: true
    property int horizontalMargin: isFloating ? 12 : 0
    property int topMargin: isFloating ? 8 : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-status-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: isFloating ? (barHeight + topMargin * 2) : barHeight

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: isFloating ? (barHeight + topMargin * 2) : barHeight
    color: "transparent"

    // Container panel
    GlassCard {
        id: barContainer
        anchors.fill: parent
        anchors.topMargin: root.topMargin
        anchors.bottomMargin: root.topMargin
        anchors.leftMargin: root.horizontalMargin
        anchors.rightMargin: root.horizontalMargin
        radius: root.isFloating ? 16 : 0

        // ─── Left Zone ───
        Row {
            id: leftZone
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            WorkspacesWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            ActiveWindowWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            MediaWidget {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ─── Center Zone ───
        Row {
            id: centerZone
            anchors.centerIn: parent
            spacing: 8

            SuitsSwitcherWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            ClockWidget {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ─── Right Zone ───
        Row {
            id: rightZone
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            SystemTrayWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            SysMonWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            VolumeWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            BrightnessWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            NetworkWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            BluetoothWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            BatteryWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            CaffeineWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            NightLightWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            NotificationBellWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            QuickSettingsToggleWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            SessionWidget {
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
