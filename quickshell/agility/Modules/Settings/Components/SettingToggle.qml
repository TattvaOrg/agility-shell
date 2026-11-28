import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

SettingRowTemplate {
    id: root

    property alias checked: settingSwitch.checked

    signal toggled(bool checked)

    Switch {
        id: settingSwitch

        z: 10
        Layout.alignment: Qt.AlignVCenter
        opacity: root.enabled ? 1 : 0.45
        onToggled: root.toggled(checked)
        implicitWidth: 42
        implicitHeight: 22
        padding: 0
        leftPadding: 0
        rightPadding: 0
        topPadding: 0
        bottomPadding: 0

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        indicator: Rectangle {
            implicitWidth: 42
            implicitHeight: 22
            radius: 11

            // Apple System Green (#34C759) when ON, subtle dark/light neutral when OFF
            color: settingSwitch.checked ? "#34C759" : (Theme.isDark ? "#39393D" : "#E9E9EB")
            border.width: 1
            border.color: settingSwitch.checked ? "#30B34F" : (Theme.isDark ? "#48484A" : "#D1D1D6")

            // macOS Switch "On" Vertical Tick Indicator (| at x: 8.5, y: 7)
            Rectangle {
                x: 8.5
                y: 7
                width: 1.2
                height: 8
                radius: 0.6
                color: "#FFFFFF"
                opacity: settingSwitch.checked ? 0.85 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation { duration: 160 }
                }
            }

            // macOS Switch Pure White Capsule Knob (24 x 18 with 9px radius, resting at x: 2 or x: 16)
            Rectangle {
                id: knob

                x: settingSwitch.checked ? (parent.width - width - 2) : 2
                y: 2
                width: settingSwitch.pressed ? 27 : 24
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

            Behavior on color {
                ColorAnimation { duration: 160 }
            }

            Behavior on border.color {
                ColorAnimation { duration: 160 }
            }
        }
    }
}
