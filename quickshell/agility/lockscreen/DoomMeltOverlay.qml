import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: meltWindow

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:agility-doom-melt"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: DoomMeltService.isMelting

    // ─── Staggered Vertical Melt Columns Repeater ───
    Item {
        id: columnsContainer
        anchors.fill: parent

        Repeater {
            id: columnsRepeater
            model: DoomMeltService.numColumns

            Item {
                id: columnStrip
                property int colIndex: index
                property real colWidth: Math.ceil(meltWindow.width / DoomMeltService.numColumns)

                x: Math.floor(index * (meltWindow.width / DoomMeltService.numColumns))
                y: 0
                width: colWidth
                height: meltWindow.height
                clip: true

                // Snapshot / Wallpaper slice
                Image {
                    id: snapshotSlice
                    x: -columnStrip.x
                    y: 0
                    width: meltWindow.width
                    height: meltWindow.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    source: {
                        if (DoomMeltService.snapshotPath !== "") {
                            return "file://" + DoomMeltService.snapshotPath
                        }
                        if (Theme.dbusTokens.active_wallpaper && Theme.dbusTokens.active_wallpaper !== "") {
                            return "file://" + Theme.dbusTokens.active_wallpaper
                        }
                        return ""
                    }
                }

                // Darkening acrylic overlay for the melting slice
                Rectangle {
                    anchors.fill: parent
                    color: Theme.colBg
                    opacity: 0.15
                }

                // Iconic Melt Drip Wave Top Ledge
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3
                    color: Theme.colAccent
                    opacity: 0.92
                }

                // Soft shadow under top drip edge
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 4
                    color: "#50000000"
                }

                // Column dropping gravity animation
                NumberAnimation {
                    id: dropAnim
                    target: columnStrip
                    property: "y"
                    from: 0
                    to: meltWindow.height + 40
                    duration: DoomMeltService.durationMs
                    easing.type: Easing.InQuad
                }

                Connections {
                    target: DoomMeltService
                    function onMeltStarted() {
                        columnStrip.y = 0
                        var delaySec = (DoomMeltService.columnDelays.length > colIndex) ? DoomMeltService.columnDelays[colIndex] : 0.0
                        dropAnim.stop()
                        animTimer.interval = Math.max(0, Math.round(delaySec * 1000))
                        animTimer.restart()
                    }
                    function onMeltFinished() {
                        animTimer.stop()
                        dropAnim.stop()
                        columnStrip.y = 0
                    }
                }

                Timer {
                    id: animTimer
                    repeat: false
                    onTriggered: {
                        dropAnim.restart()
                    }
                }
            }
        }
    }
}
