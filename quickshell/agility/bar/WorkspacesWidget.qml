import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowLayout.implicitWidth + 8

    GlassCard {
        anchors.fill: parent
        radius: 16
        isTile: true

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: BarDataService.workspacesList

                Rectangle {
                    id: wsPill
                    width: Math.max(26, wsText.implicitWidth + 12)
                    height: 24
                    radius: 12
                    antialiasing: true

                    property bool isActive: modelData.idx === BarDataService.activeWorkspaceIdx
                    property bool hasWindows: (modelData.window_count || 0) > 0
                    property bool hovered: mouseArea.containsMouse

                    color: {
                        if (isActive) return Theme.colAccent
                        if (hovered) return Theme.isGlass ? "#3DFFFFFF" : Theme.colPillBg
                        return "transparent"
                    }

                    border.color: isActive ? Qt.lighter(Theme.colAccent, 1.2) : (hovered ? "#33FFFFFF" : "transparent")
                    border.width: 1

                    scale: hovered && !isActive ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            id: wsText
                            text: (modelData.name && modelData.name !== "") ? modelData.name : (modelData.idx + 1).toString()
                            color: wsPill.isActive ? "#FFFFFF" : (wsPill.hasWindows ? Theme.colText : Theme.colTextSec)
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: wsPill.isActive ? Font.Bold : Font.Normal
                        }

                        // Window count indicator dot
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !wsPill.isActive && wsPill.hasWindows
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.colTextSec
                        }
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BarDataService.switchWorkspace(modelData.idx)
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onWheel: function(wheel) {
                var current = BarDataService.activeWorkspaceIdx
                var count = BarDataService.workspacesList.length
                if (count <= 1) return
                if (wheel.angleDelta.y > 0) {
                    var prev = (current - 1 + count) % count
                    BarDataService.switchWorkspace(prev)
                } else if (wheel.angleDelta.y < 0) {
                    var next = (current + 1) % count
                    BarDataService.switchWorkspace(next)
                }
            }
        }
    }
}
