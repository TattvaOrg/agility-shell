import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import qs.Core
import qs.Core.Services

Item {
    id: root

    property int iconSize: Constants.size3Xl
    property color iconColor: Theme.accent
    readonly property int scaledIconSize: Math.round(iconSize * SettingsService.fontScale)
    property bool enableIntroAnim: true
    property bool enableIntervalAnim: true

    // Official Google Material Theme 'space_dashboard' (2x2 asymmetric rounded tiles)
    readonly property string m3DashboardPath: "M 3 5 C 3 3.9 3.9 3 5 3 L 9 3 C 10.1 3 11 3.9 11 5 L 11 11 C 11 12.1 10.1 13 9 13 L 5 13 C 3.9 13 3 12.1 3 11 Z M 3 17 C 3 15.9 3.9 15 5 15 L 9 15 C 10.1 15 11 15.9 11 17 L 11 19 C 11 20.1 10.1 21 9 21 L 5 21 C 3.9 21 3 20.1 3 19 Z M 13 5 C 13 3.9 13.9 3 15 3 L 19 3 C 20.1 3 21 3.9 21 5 L 21 19 C 21 20.1 20.1 21 19 21 L 15 21 C 13.9 21 13 20.1 13 19 Z"

    width: scaledIconSize
    height: scaledIconSize
    implicitWidth: scaledIconSize
    implicitHeight: scaledIconSize
    layer.enabled: HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")

    Item {
        id: iconContainer

        width: 24
        height: 24
        scale: root.scaledIconSize / 24
        anchors.centerIn: parent
        enabled: false

        Item {
            id: dashboardShape

            width: 24
            height: 24
            anchors.centerIn: parent
            transformOrigin: Item.Center

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.iconColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: root.m3DashboardPath
                    }
                }
            }
        }

        // Intro animation
        SequentialAnimation {
            id: introAnim

            running: HyprlandService.enableAnimations && root.enableIntroAnim

            PropertyAction {
                target: dashboardShape
                property: "scale"
                value: 0
            }

            PauseAnimation {
                duration: 50
            }

            NumberAnimation {
                target: dashboardShape
                property: "scale"
                to: 1
                duration: Constants.animExpressive + 100
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        // Idle gentle micro-animation
        SequentialAnimation {
            id: intervalAnim

            running: HyprlandService.enableAnimations && root.enableIntervalAnim && !introAnim.running
            loops: Animation.Infinite

            PauseAnimation {
                duration: 5000
            }

            SequentialAnimation {
                NumberAnimation {
                    target: dashboardShape
                    property: "scale"
                    to: 1.08
                    duration: 250
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: dashboardShape
                    property: "scale"
                    to: 1.0
                    duration: 350
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    layer.effect: DropShadow {
        id: shadowEffect

        transparentBorder: true
        color: Qt.rgba(root.iconColor.r, root.iconColor.g, root.iconColor.b, 0.4)
        radius: Constants.sizeXs
        samples: 15
        spread: 0.1
    }
}
