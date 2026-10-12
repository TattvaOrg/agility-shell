import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: editWindow

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-desktop-edit-mode"
    WlrLayershell.keyboardFocus: CanvasService.editModeActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: CanvasService.editModeActive

    // ─── Subtle Alignment Grid Dots Background ───
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: CanvasService.snapToGrid ? 0.35 : 0.15

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#40FFFFFF"

            var step = CanvasService.gridSize
            for (var x = step; x < width; x += step) {
                for (var y = step; y < height; y += step) {
                    ctx.fillRect(x - 1, y - 1, 2, 2)
                }
            }
        }
    }

    // ─── Top Floating Edit Mode HUD Controller ───
    GlassCard {
        id: hudCard
        anchors.top: parent.top
        anchors.topMargin: 52
        anchors.horizontalCenter: parent.horizontalCenter
        width: 580
        height: 52
        radius: 26

        Row {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            anchors.verticalCenter: parent.verticalCenter

            GlassIcon {
                source: "grid-four"
                size: 20
                color: Theme.colAccent
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Desktop Canvas Edit Mode"
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }

                Text {
                    text: "Drag applets to reposition • Corner handle to resize"
                    color: Theme.colTextSec
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                    opacity: 0.8
                }
            }

            Item {
                width: Math.max(0, parent.width - childrenRect.width)
                height: 1
            }

            // Snap-to-Grid Toggle Pill
            GlassPill {
                text: CanvasService.snapToGrid ? "Snap: 20px" : "Free Move"
                iconSource: "magnet"
                pillHeight: 30
                active: CanvasService.snapToGrid
                activeColor: Theme.colAccent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    CanvasService.snapToGrid = !CanvasService.snapToGrid
                    gridCanvas.requestPaint()
                }
            }

            // Widget Catalog Selector Button
            GlassPill {
                text: "Widgets"
                iconSource: "squares-four"
                pillHeight: 30
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    widgetsDrawer.visible = !widgetsDrawer.visible
                }
            }

            // Done / Save Button
            GlassButton {
                text: "Done"
                primary: true
                height: 32
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    widgetsDrawer.visible = false
                    CanvasService.exitEditMode()
                }
            }
        }
    }

    // ─── Widgets Visibility Drawer Popover ───
    GlassCard {
        id: widgetsDrawer
        anchors.top: hudCard.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        width: 480
        height: 320
        radius: 18
        visible: false

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                text: "Toggle Desktop Applets"
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            GridView {
                id: widgetGrid
                width: parent.width
                height: parent.height - 35
                cellWidth: 220
                cellHeight: 38
                clip: true
                model: CanvasService.widgetCatalog

                delegate: GlassCard {
                    width: 210
                    height: 32
                    radius: 10
                    isTile: true

                    property bool isVis: Theme.isWidgetVisible(modelData.id)

                    rimColor: isVis ? Theme.colAccent : Theme.borderColor
                    dropletColorTop: isVis ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.2) : (Theme.isGlass ? "#321C2A38" : Theme.colBgTile)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter

                        GlassIcon {
                            source: modelData.icon
                            size: 14
                            color: isVis ? Theme.colAccent : Theme.colTextSec
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: modelData.name
                            color: isVis ? Theme.colText : Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            font.weight: isVis ? Font.DemiBold : Font.Normal
                            width: parent.width - 50
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: isVis ? Theme.colAccent : "transparent"
                            border.color: isVis ? Theme.colAccent : Theme.colTextSec
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter

                            GlassIcon {
                                source: "check"
                                size: 10
                                color: "#FFFFFF"
                                visible: isVis
                                anchors.centerIn: parent
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            CanvasService.toggleWidgetVisibility(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ─── Interactive Draggable Overlays for Active Widgets ───
    Item {
        id: draggableLayers
        anchors.fill: parent

        Repeater {
            model: CanvasService.widgetCatalog

            Item {
                id: overlayItem
                property string widgetKey: modelData.id
                property bool isVisibleOnDesktop: Theme.isWidgetVisible(widgetKey)

                visible: isVisibleOnDesktop

                // Load initial coordinates from Theme.allSettings
                property var widgetConfig: (Theme.allSettings && Theme.allSettings[widgetKey]) ? Theme.allSettings[widgetKey] : {}
                property real currentScale: widgetConfig.scale || 1.0

                width: Math.max(160, Math.round((widgetConfig.width || 240) * currentScale))
                height: Math.max(80, Math.round((widgetConfig.height || 140) * currentScale))
                x: widgetConfig.x !== undefined ? widgetConfig.x : 100
                y: widgetConfig.y !== undefined ? widgetConfig.y : 100

                // ─── Outlined Drag Box Card ───
                Rectangle {
                    id: outlineBox
                    anchors.fill: parent
                    radius: 16
                    color: dragMouseArea.drag.active ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.12)
                    border.color: dragMouseArea.drag.active ? Qt.lighter(Theme.colAccent, 1.3) : Theme.colAccent
                    border.width: 2

                    // Top Badge: Icon + Name
                    GlassCard {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6
                        height: 24
                        radius: 12
                        isTile: true

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 5
                            anchors.verticalCenter: parent.verticalCenter

                            GlassIcon {
                                source: modelData.icon
                                size: 12
                                color: Theme.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData.name
                                color: Theme.colText
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Top-right Quick Controls: Scale (-) & (+) and Hide (x)
                    Row {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        spacing: 4

                        // Scale Down
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: "#30000000"
                            border.color: "#30FFFFFF"
                            border.width: 1

                            Text {
                                text: "-"
                                color: "#FFFFFF"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    overlayItem.currentScale = Math.max(0.6, overlayItem.currentScale - 0.1)
                                    CanvasService.savePlacement(overlayItem.widgetKey, overlayItem.x, overlayItem.y, overlayItem.currentScale)
                                    Theme.reloadSettings()
                                }
                            }
                        }

                        // Scale Up
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: "#30000000"
                            border.color: "#30FFFFFF"
                            border.width: 1

                            Text {
                                text: "+"
                                color: "#FFFFFF"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    overlayItem.currentScale = Math.min(2.2, overlayItem.currentScale + 0.1)
                                    CanvasService.savePlacement(overlayItem.widgetKey, overlayItem.x, overlayItem.y, overlayItem.currentScale)
                                    Theme.reloadSettings()
                                }
                            }
                        }

                        // Hide Widget
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: "#40FF5555"
                            border.color: "#80FF5555"
                            border.width: 1

                            Text {
                                text: "×"
                                color: "#FFFFFF"
                                font.pixelSize: 13
                                anchors.centerIn: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    CanvasService.toggleWidgetVisibility(overlayItem.widgetKey)
                                }
                            }
                        }
                    }

                    // Center Coordinates Badge
                    Text {
                        anchors.centerIn: parent
                        text: "X: " + Math.round(overlayItem.x) + "  Y: " + Math.round(overlayItem.y) + " (" + Math.round(overlayItem.currentScale * 100) + "%)"
                        color: Theme.colAccent
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        opacity: dragMouseArea.drag.active ? 1.0 : 0.65
                    }

                    // Bottom-right Resize Grip
                    Rectangle {
                        width: 16
                        height: 16
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 4
                        radius: 4
                        color: Theme.colAccent
                        opacity: 0.8
                    }

                    // Drag MouseArea for repositioning
                    MouseArea {
                        id: dragMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor
                        drag.target: overlayItem
                        drag.axis: Drag.XAndYAxis
                        drag.minimumX: 10
                        drag.maximumX: editWindow.width - overlayItem.width - 10
                        drag.minimumY: 10
                        drag.maximumY: editWindow.height - overlayItem.height - 10

                        onReleased: {
                            // Snap to grid
                            var snappedX = CanvasService.snap(overlayItem.x)
                            var snappedY = CanvasService.snap(overlayItem.y)
                            overlayItem.x = snappedX
                            overlayItem.y = snappedY

                            // Save placement reactively
                            CanvasService.savePlacement(overlayItem.widgetKey, snappedX, snappedY, overlayItem.currentScale)
                            Theme.reloadSettings()
                        }
                    }
                }
            }
        }
    }
}
