import QtQuick
import ".."

Item {
    id: root

    property var items: [] // Array of { id: string, text: string, icon: string, danger: bool }
    property bool opened: false
    property real menuWidth: 180
    property real itemHeight: 34

    signal itemTriggered(string itemId)
    signal dismissed()

    visible: opacity > 0.001
    opacity: opened ? 1.0 : 0.0
    scale: opened ? 1.0 : 0.94

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    implicitWidth: menuWidth
    implicitHeight: Math.max(30, columnLayout.implicitHeight + 16)

    // Glass backdrop container
    GlassCard {
        anchors.fill: parent
        radius: 16
        isTile: true

        Column {
            id: columnLayout
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Repeater {
                model: root.items

                Rectangle {
                    id: rowItem
                    width: parent.width
                    height: root.itemHeight
                    radius: 8
                    antialiasing: true

                    property bool hovered: rowMouse.containsMouse
                    property var dataItem: modelData

                    color: hovered ? (Theme.isGlass ? "#3DFFFFFF" : Theme.colPillBg) : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        GlassIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: dataItem.icon || ""
                            size: 16
                            color: dataItem.danger ? "#EF4444" : (rowItem.hovered ? Theme.colAccent : Theme.colTextSec)
                            visible: dataItem.icon !== undefined && dataItem.icon !== ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dataItem.text || ""
                            color: dataItem.danger ? "#EF4444" : Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 13
                            font.weight: rowItem.hovered ? Font.Medium : Font.Normal
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.opened = false
                            root.itemTriggered(dataItem.id || dataItem.text)
                        }
                    }
                }
            }
        }
    }
}
