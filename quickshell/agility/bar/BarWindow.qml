import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "styles/Island" as Island
import "styles/Convex" as Convex
import "styles/Gaming" as Gaming

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    // Sizing & Modes
    property int barHeight: Theme.isGamingBar ? 32 : (Theme.isConvexBar ? 40 : 38)
    property bool isFloating: Theme.isIslandBar ? true : (Theme.isConvexBar ? false : (Theme.isGamingBar ? false : true))
    property int horizontalMargin: isFloating ? 12 : 0
    property int topMargin: isFloating ? 6 : 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-status-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: Theme.isGamingBar ? 32 : (Theme.isConvexBar ? 46 : (barHeight + topMargin * 2))

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.isGamingBar ? 32 : (Theme.isConvexBar ? 46 : (barHeight + topMargin * 2))
    color: "transparent"

    // ─── Minflair Island Style Bar ───
    Island.IslandBar {
        anchors.fill: parent
        screenModel: root.screenModel
        barHeight: root.barHeight
        visible: Theme.isIslandBar
    }

    // ─── Minflair Convex Style Bar ───
    Convex.ConvexBar {
        anchors.fill: parent
        screenModel: root.screenModel
        barHeight: root.barHeight
        visible: Theme.isConvexBar
    }

    // ─── Minflair Gaming Style Bar ───
    Gaming.GamingBar {
        anchors.fill: parent
        screenModel: root.screenModel
        barHeight: root.barHeight
        visible: Theme.isGamingBar
    }

    // ─── Agility Classic Container Panel ───
    GlassCard {
        id: barContainer
        visible: Theme.isClassicBar
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

            LauncherWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

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
