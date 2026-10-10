import QtQuick
import ".."

Item {
    id: root

    property string text: ""
    property string iconSource: ""
    property string badgeText: ""
    property bool active: false
    property bool interactive: true
    property real pillHeight: 32
    property real pillRadius: pillHeight / 2
    property color activeColor: Theme.colAccent
    property color textColor: active ? activeColor : Theme.colText
    property color iconColor: active ? activeColor : Theme.colTextSec

    signal clicked()

    implicitWidth: Math.max(pillHeight, rowLayout.implicitWidth + 24)
    implicitHeight: pillHeight

    scale: interactive && mouseArea.pressed ? 0.96 : (interactive && mouseArea.containsMouse ? 1.03 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Drop shadow
    Rectangle {
        anchors.fill: pillBody
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: root.pillRadius
        color: "#20000000"
        visible: Theme.isGlass
        z: 0
    }

    // Pill body
    Rectangle {
        id: pillBody
        anchors.fill: parent
        radius: root.pillRadius
        antialiasing: true
        z: 1

        color: {
            if (root.active) return Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.22)
            if (mouseArea.containsMouse) return Theme.isGlass ? "#4D28384D" : Theme.colPillBg
            return Theme.isGlass ? "#2D203045" : Theme.colPillBg
        }

        border.color: {
            if (root.active) return root.activeColor
            if (mouseArea.containsMouse) return Theme.isGlass ? "#40FFFFFF" : Theme.borderColor
            return Theme.isGlass ? "#1FFFFFFF" : Theme.borderColor
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Curved top specular sheen
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 1
            width: Math.max(0, parent.width - 6)
            height: Math.min(parent.height * 0.45, 12)
            radius: root.pillRadius
            antialiasing: true
            visible: Theme.isGlass

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.active ? "#33FFFFFF" : "#22FFFFFF" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Layout contents
        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 6

            GlassIcon {
                id: pillIcon
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconSource
                size: root.pillHeight * 0.5
                color: root.iconColor
                visible: root.iconSource !== ""
            }

            Text {
                id: labelText
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                font.family: Theme.fontMain
                font.pixelSize: Math.round(root.pillHeight * 0.4)
                font.weight: root.active ? Font.DemiBold : Font.Normal
                visible: root.text !== ""
            }

            // Badge pill
            Rectangle {
                id: badgeRect
                anchors.verticalCenter: parent.verticalCenter
                visible: root.badgeText !== ""
                height: Math.round(root.pillHeight * 0.55)
                width: Math.max(height, badgeLabel.implicitWidth + 8)
                radius: height / 2
                color: root.activeColor

                Text {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: root.badgeText
                    color: "#FFFFFF"
                    font.family: Theme.fontMono
                    font.pixelSize: Math.round(parent.height * 0.7)
                    font.bold: true
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: root.interactive
            cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.clicked()
            z: 2
        }
    }
}
