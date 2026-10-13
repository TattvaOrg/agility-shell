import QtQuick
import ".."
import "../components"

Item {
    id: root

    property var itemData: null
    property real baseSize: 48
    property real magnificationScale: 1.0
    property bool isHovered: false

    implicitWidth: baseSize
    implicitHeight: baseSize + 12

    readonly property bool isRunning: itemData ? DockDataService.isRunning(itemData.appId) : false
    readonly property bool isFocused: itemData ? DockDataService.isFocused(itemData.appId) : false
    readonly property bool isPinned: itemData ? DockDataService.isPinned(itemData.appId) : true

    // Launch bounce animation
    property real bounceY: 0.0
    SequentialAnimation {
        id: bounceAnim
        loops: 3
        NumberAnimation { target: root; property: "bounceY"; from: 0; to: -14; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bounceY"; from: -14; to: 0; duration: 220; easing.type: Easing.OutBounce }
    }

    Item {
        id: iconContainer
        width: root.baseSize
        height: root.baseSize
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.bounceY

        scale: root.magnificationScale
        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
        }

        // Icon backing card
        GlassCard {
            id: iconCard
            anchors.fill: parent
            radius: 14
            isTile: true

            GlassIcon {
                anchors.centerIn: parent
                source: (root.itemData && root.itemData.icon) ? root.itemData.icon : "terminal"
                size: root.baseSize * 0.65
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    contextMenu.opened = !contextMenu.opened
                } else {
                    bounceAnim.restart()
                    if (root.itemData) {
                        DockDataService.launchApp(root.itemData.exec, root.itemData.appId)
                    }
                }
            }
        }
    }

    // Running / focus indicator dot/pill under icon
    Rectangle {
        id: indicator
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 2
        visible: root.isRunning

        width: root.isFocused ? 14 : 4
        height: 4
        radius: 2
        color: root.isFocused ? Theme.colAccent : Theme.colTextSec

        Behavior on width {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    // Right-click context popover menu
    GlassMenu {
        id: contextMenu
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        menuWidth: 150

        items: [
            { "id": "new_window", "text": "New Window", "icon": "plus" },
            { "id": "toggle_pin", "text": root.isPinned ? "Unpin from Dock" : "Pin to Dock", "icon": "push-pin" },
            { "id": "close", "text": "Close", "icon": "x", "danger": true }
        ]

        onItemTriggered: function(actionId) {
            if (!root.itemData) return
            if (actionId === "new_window") {
                DockDataService.launchApp(root.itemData.exec, root.itemData.appId)
            } else if (actionId === "toggle_pin") {
                DockDataService.togglePin(root.itemData.appId, root.itemData.name, root.itemData.exec, root.itemData.icon)
            } else if (actionId === "close") {
                DockDataService.closeApp(root.itemData.appId)
            }
        }
    }
}
