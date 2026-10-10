import QtQuick
import ".."

Item {
    id: root

    property string text: ""
    property string iconSource: ""
    property bool primary: false
    property bool disabled: false
    property real radius: 12
    property color accentColor: Theme.colAccent
    property color textColor: primary ? "#FFFFFF" : Theme.colText
    property color iconColor: primary ? "#FFFFFF" : (mouseArea.containsMouse ? accentColor : Theme.colTextSec)

    signal clicked()

    implicitWidth: Math.max(36, contentRow.implicitWidth + 24)
    implicitHeight: 36

    opacity: disabled ? 0.45 : 1.0

    scale: !disabled && mouseArea.pressed ? 0.96 : (!disabled && mouseArea.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    // Outer elevation shadow
    Rectangle {
        anchors.fill: buttonBody
        anchors.topMargin: 2
        anchors.bottomMargin: -2
        radius: root.radius
        color: "#25000000"
        visible: Theme.isGlass
        z: 0
    }

    // Button body
    Rectangle {
        id: buttonBody
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        clip: true
        z: 1

        color: {
            if (root.primary) {
                return mouseArea.containsMouse ? Qt.lighter(root.accentColor, 1.1) : root.accentColor
            }
            if (mouseArea.containsMouse) {
                return Theme.isGlass ? "#4D28384D" : Theme.colPillBg
            }
            return Theme.isGlass ? "#281D2938" : Theme.colBgTile
        }

        border.color: {
            if (root.primary) return Qt.lighter(root.accentColor, 1.25)
            if (mouseArea.containsMouse) return Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
            return Theme.isGlass ? "#22FFFFFF" : Theme.borderColor
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Top specular meniscus highlight
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 1
            width: Math.max(0, parent.width - 4)
            height: Math.min(parent.height * 0.4, 14)
            radius: Math.max(1, root.radius - 2)
            antialiasing: true
            visible: Theme.isGlass

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.primary ? "#30FFFFFF" : "#22FFFFFF" }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Click ripple effect
        Rectangle {
            id: rippleRect
            width: Math.max(buttonBody.width, buttonBody.height) * 2.2
            height: width
            radius: width / 2
            x: mouseArea.mouseX - width / 2
            y: mouseArea.mouseY - height / 2
            color: root.primary ? "#FFFFFF" : root.accentColor
            opacity: 0.0

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: rippleRect; property: "opacity"; from: 0.28; to: 0.0; duration: 400; easing.type: Easing.OutQuad }
                NumberAnimation { target: rippleRect; property: "scale"; from: 0.1; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
            }
        }

        // Content
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: root.iconSource
                size: 18
                color: root.iconColor
                visible: root.iconSource !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                color: root.textColor
                font.family: Theme.fontMain
                font.pixelSize: 13
                font.weight: root.primary ? Font.DemiBold : Font.Medium
                visible: root.text !== ""
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: !root.disabled
            hoverEnabled: true
            cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                rippleAnim.restart()
                root.clicked()
            }
        }
    }
}
