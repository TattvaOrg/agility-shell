import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    // Dock styling & sizing
    property real iconSize: 48
    property real dockPadding: 8
    property real maxMagnification: 0.35
    property real sigma: 65.0 // Width of parabolic zoom influence

    // Autohide state
    property bool autohideEnabled: DockDataService.autohide
    property bool isRevealed: !autohideEnabled || dockMouseArea.containsMouse || triggerMouseArea.containsMouse

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: autohideEnabled ? 0 : (iconSize + dockPadding * 2 + 16)

    anchors {
        bottom: true
    }

    implicitWidth: Math.max(160, dockCard.implicitWidth + 24)
    implicitHeight: iconSize + dockPadding * 2 + 16
    color: "transparent"

    // Bottom edge trigger zone when autohide is active
    MouseArea {
        id: triggerMouseArea
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 10
        hoverEnabled: true
        visible: root.autohideEnabled
        z: 0
    }

    // Main Floating Glass Dock Container
    GlassCard {
        id: dockCard
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: root.isRevealed ? 8 : -(root.iconSize + root.dockPadding * 2 + 10)
        radius: 22

        implicitWidth: dockRow.implicitWidth + dockPadding * 2
        implicitHeight: root.iconSize + dockPadding * 2 + 6

        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                id: itemsRepeater
                model: DockDataService.allDockItems

                DockItem {
                    id: dItem
                    itemData: modelData
                    baseSize: root.iconSize

                    // Parabolic zoom scale calculation
                    magnificationScale: {
                        if (!dockMouseArea.containsMouse) return 1.0
                        var itemCenterX = dItem.x + dItem.width / 2
                        var mouseXInRow = dockMouseArea.mouseX - dockRow.x
                        var dist = Math.abs(mouseXInRow - itemCenterX)
                        var zoom = root.maxMagnification * Math.exp(-(dist * dist) / (2 * root.sigma * root.sigma))
                        return 1.0 + zoom
                    }
                }
            }
        }

        MouseArea {
            id: dockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            z: -1
        }
    }
}
