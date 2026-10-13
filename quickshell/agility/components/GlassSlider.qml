import QtQuick
import ".."

Item {
    id: root

    property real value: 0.5
    property real minimumValue: 0.0
    property real maximumValue: 1.0
    property real stepSize: 0.01
    property bool interactive: true
    property real trackHeight: 8
    property real thumbSize: 18
    property color accentColor: Theme.colAccent
    property color trackColor: Theme.isGlass ? "#281D2938" : Theme.colPillBg

    signal valueChangedByUser(real newValue)

    implicitWidth: 160
    implicitHeight: Math.max(thumbSize, trackHeight) + 8

    // Normalized progress 0.0 -> 1.0
    readonly property real progress: {
        var range = maximumValue - minimumValue
        if (range <= 0.0) return 0.0
        return Math.max(0.0, Math.min(1.0, (value - minimumValue) / range))
    }

    function setValueFromPosition(mouseX) {
        var availWidth = root.width - root.thumbSize
        var clampedX = Math.max(0, Math.min(availWidth, mouseX - root.thumbSize / 2))
        var ratio = clampedX / (availWidth > 0 ? availWidth : 1)
        var rawVal = root.minimumValue + ratio * (root.maximumValue - root.minimumValue)
        var steps = Math.round(rawVal / root.stepSize)
        var finalVal = Math.max(root.minimumValue, Math.min(root.maximumValue, steps * root.stepSize))
        root.value = finalVal
        root.valueChangedByUser(finalVal)
    }

    // Background track groove
    Rectangle {
        id: trackGroove
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.trackHeight
        radius: root.trackHeight / 2
        color: root.trackColor
        border.color: Theme.isGlass ? "#1AFFFFFF" : Theme.borderColor
        border.width: 1
        clip: true

        // Filled active progress
        Rectangle {
            id: filledTrack
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, root.thumbSize / 2 + root.progress * (root.width - root.thumbSize))
            radius: root.trackHeight / 2

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.darker(root.accentColor, 1.15) }
                GradientStop { position: 1.0; color: root.accentColor }
            }

            Behavior on width {
                enabled: !mouseArea.drag.active
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }

    // Draggable thumb pill
    Rectangle {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        x: root.progress * (root.width - root.thumbSize)
        width: root.thumbSize
        height: root.thumbSize
        radius: root.thumbSize / 2
        antialiasing: true
        z: 2

        color: mouseArea.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.95)
        border.color: mouseArea.containsMouse ? root.accentColor : "#40FFFFFF"
        border.width: 1.5

        scale: mouseArea.pressed ? 1.15 : (mouseArea.containsMouse ? 1.08 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on x {
            enabled: !mouseArea.drag.active
            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        // Thumb specular dome
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 1
            width: parent.width - 4
            height: parent.height * 0.4
            radius: parent.radius
            color: "#60FFFFFF"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: function(mouse) {
            root.setValueFromPosition(mouse.x)
        }

        onPositionChanged: function(mouse) {
            if (pressed) {
                root.setValueFromPosition(mouse.x)
            }
        }

        onWheel: function(wheel) {
            var delta = (wheel.angleDelta.y > 0 ? 1 : -1) * root.stepSize * 2
            var newVal = Math.max(root.minimumValue, Math.min(root.maximumValue, root.value + delta))
            root.value = newVal
            root.valueChangedByUser(newVal)
        }
    }
}
