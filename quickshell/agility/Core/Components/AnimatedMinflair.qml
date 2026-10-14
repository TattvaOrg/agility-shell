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

    // Material 3 Expressive 4-pointed curved star ("auto_awesome" / Gemini sparkle)
    readonly property string m3StarPath: "M 12 2 C 12 7.52 7.52 12 2 12 C 7.52 12 12 16.48 12 22 C 12 16.48 16.48 12 22 12 C 16.48 12 12 7.52 12 2 Z"
    // Companion mini-sparkle
    readonly property string m3MiniStarPath: "M 19 2.5 C 19 4.4 17.4 6 15.5 6 C 17.4 6 19 7.6 19 9.5 C 19 7.6 20.6 6 22.5 6 C 20.6 6 19 4.4 19 2.5 Z"

    width: scaledIconSize
    height: scaledIconSize
    implicitWidth: scaledIconSize
    implicitHeight: scaledIconSize
    layer.enabled: HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")

    Item {
        id: starContainer

        width: 24
        height: 24
        scale: root.scaledIconSize / 24
        anchors.centerIn: parent
        enabled: false

        // Main M3 4-pointed sparkle
        Item {
            id: mainStarShape

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
                        path: root.m3StarPath
                    }
                }
            }
        }

        // Companion secondary mini-sparkle (top right)
        Item {
            id: companionStarShape

            width: 24
            height: 24
            anchors.centerIn: parent
            transformOrigin: Item.Center
            opacity: 0.85

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.iconColor
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: root.m3MiniStarPath
                    }
                }
            }
        }

        // Intro animation
        SequentialAnimation {
            id: introAnim

            running: HyprlandService.enableAnimations && root.enableIntroAnim

            PropertyAction {
                target: mainStarShape
                property: "scale"
                value: 0
            }

            PropertyAction {
                target: companionStarShape
                property: "scale"
                value: 0
            }

            PauseAnimation {
                duration: 50
            }

            ParallelAnimation {
                NumberAnimation {
                    target: mainStarShape
                    property: "scale"
                    to: 1
                    duration: Constants.animExpressive + 200
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.15
                }

                SequentialAnimation {
                    PauseAnimation {
                        duration: 120
                    }

                    NumberAnimation {
                        target: companionStarShape
                        property: "scale"
                        to: 1
                        duration: Constants.animExpressive
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }
                }
            }
        }

        // Idle micro-animation
        SequentialAnimation {
            id: intervalAnim

            running: HyprlandService.enableAnimations && root.enableIntervalAnim && !introAnim.running
            loops: Animation.Infinite

            PauseAnimation {
                duration: 4500
            }

            ParallelAnimation {
                SequentialAnimation {
                    NumberAnimation {
                        target: mainStarShape
                        property: "scale"
                        to: 1.08
                        duration: 350
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: mainStarShape
                        property: "scale"
                        to: 1.0
                        duration: 450
                        easing.type: Easing.InOutQuad
                    }
                }

                SequentialAnimation {
                    NumberAnimation {
                        target: companionStarShape
                        property: "opacity"
                        to: 1.0
                        duration: 300
                    }

                    NumberAnimation {
                        target: companionStarShape
                        property: "scale"
                        to: 1.18
                        duration: 350
                        easing.type: Easing.OutBack
                    }

                    NumberAnimation {
                        target: companionStarShape
                        property: "scale"
                        to: 1.0
                        duration: 400
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        target: companionStarShape
                        property: "opacity"
                        to: 0.85
                        duration: 300
                    }
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
