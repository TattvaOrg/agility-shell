import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import qs.Core
import qs.Core.Services

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property color activeColor: "#34C759" // macOS system green switch

    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 22

    opacity: root.enabled ? 1.0 : 0.45

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 11

        // Apple System Green (#34C759) or activeColor when ON, subtle dark/light neutral when OFF
        color: root.checked ? root.activeColor : (Theme.isDark ? "#39393D" : "#E9E9EB")
        border.width: 1
        border.color: root.checked ? "#30B34F" : (Theme.isDark ? "#48484A" : "#D1D1D6")

        Behavior on color {
            ColorAnimation { duration: 160 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 160 }
        }

        // macOS Switch "On" Vertical Tick Indicator (| at x: 8.5, y: 7)
        Rectangle {
            x: 8.5
            y: 7
            width: 1.2
            height: 8
            radius: 0.6
            color: "#FFFFFF"
            opacity: root.checked ? 0.85 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
        }

        // Pure white macOS capsule knob (24 x 18 with 9px radius, resting at x: 2 or x: 16)
        Rectangle {
            id: knob
            x: root.checked ? (track.width - width - 2) : 2
            y: 2
            width: mouseArea.pressed ? 27 : 24
            height: 18
            radius: 9
            color: "#FFFFFF"
            border.width: 0.5
            border.color: "#00000014"

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                color: "#00000030"
                radius: 3
                samples: 9
                verticalOffset: 1.2
            }

            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
