import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes
import qs.Core
import qs.Core.Services

Item {
    id: root

    property int iconSize: Math.round((Constants.size2Xl + 4) * (SettingsService.barWidgetHeight / 28.0))
    property color iconColor: Theme.accent
    readonly property int scaledIconSize: Math.max(16, Math.round(iconSize * SettingsService.fontScale))
    property bool enableIntroAnim: true
    property bool enableIntervalAnim: true

    // Material 3 Expressive Shapes (24x24 viewBox coordinates)
    readonly property string m3DashboardPath: "M 3 5 C 3 3.9 3.9 3 5 3 L 9 3 C 10.1 3 11 3.9 11 5 L 11 11 C 11 12.1 10.1 13 9 13 L 5 13 C 3.9 13 3 12.1 3 11 Z M 3 17 C 3 15.9 3.9 15 5 15 L 9 15 C 10.1 15 11 15.9 11 17 L 11 19 C 11 20.1 10.1 21 9 21 L 5 21 C 3.9 21 3 20.1 3 19 Z M 13 5 C 13 3.9 13.9 3 15 3 L 19 3 C 20.1 3 21 3.9 21 5 L 21 19 C 21 20.1 20.1 21 19 21 L 15 21 C 13.9 21 13 20.1 13 19 Z"
    readonly property string sparklePath: "M 12 2 C 12 7.52 7.52 12 2 12 C 7.52 12 12 16.48 12 22 C 12 16.48 16.48 12 22 12 C 16.48 12 12 7.52 12 2 Z"
    readonly property string flowerPath: "M 12 2.5 C 14.5 2.5 16.5 4.5 16.5 7 C 19 7 21 9 21 11.5 C 21 14 19 16 16.5 16 C 16.5 18.5 14.5 20.5 12 20.5 C 9.5 20.5 7.5 18.5 7.5 16 C 5 16 3 14 3 11.5 C 3 9 5 7 7.5 7 C 7.5 4.5 9.5 2.5 12 2.5 Z"
    readonly property string scallopPath: "M 12 2 C 13.5 2 14.7 3 15.3 4.2 C 16.6 4.1 17.8 4.9 18.2 6.1 C 19.3 6.8 19.9 8.1 19.7 9.4 C 20.8 10.2 21.4 11.5 21.2 12.8 C 21.9 14 21.8 15.5 20.9 16.6 C 21 17.9 20.2 19.2 19 19.8 C 18.1 20.8 16.7 21.2 15.4 20.8 C 14.6 21.8 13.3 22.3 12 22 C 10.7 22.3 9.4 21.8 8.6 20.8 C 7.3 21.2 5.9 20.8 5 19.8 C 3.8 19.2 3 17.9 3.1 16.6 C 2.2 15.5 2.1 14 2.8 12.8 C 2.6 11.5 3.2 10.2 4.3 9.4 C 4.1 8.1 4.7 6.8 5.8 6.1 C 6.2 4.9 7.4 4.1 8.7 4.2 C 9.3 3 10.5 2 12 2 Z"
    readonly property string hexagonPath: "M 12 3 C 12.8 3 13.6 3.4 14.1 4.2 L 19.5 10.8 C 20.1 11.5 20.1 12.5 19.5 13.2 L 14.1 19.8 C 13.6 20.6 12.8 21 12 21 C 11.2 21 10.4 20.6 9.9 19.8 L 4.5 13.2 C 3.9 12.5 3.9 11.5 4.5 10.8 L 9.9 4.2 C 10.4 3.4 11.2 3 12 3 Z"
    readonly property string archPath: "M 6 12 C 6 8.69 8.69 6 12 6 C 15.31 6 18 8.69 18 12 L 18 18 C 18 19.1 17.1 20 16 20 L 8 20 C 6.9 20 6 19.1 6 18 Z"
    readonly property string gemPath: "M 8.5 3 L 15.5 3 C 16.3 3 17.1 3.3 17.7 3.9 L 20.1 6.3 C 20.7 6.9 21 7.7 21 8.5 L 21 15.5 C 21 16.3 20.7 17.1 20.1 17.7 L 17.7 20.1 C 17.1 20.7 16.3 21 15.5 21 L 8.5 21 C 7.7 21 6.9 20.7 6.3 20.1 L 3.9 17.7 C 3.3 17.1 3 16.3 3 15.5 L 3 8.5 C 3 7.7 3.3 6.9 3.9 6.3 L 6.3 3.9 C 6.9 3.3 7.7 3 8.5 3 Z"

    function getShapePath(name) {
        switch (name) {
        case "sparkle":
            return sparklePath;
        case "flower":
            return flowerPath;
        case "scallop":
            return scallopPath;
        case "hexagon":
            return hexagonPath;
        case "arch":
            return archPath;
        case "gem":
            return gemPath;
        case "dashboard":
        default:
            return m3DashboardPath;
        }
    }

    property int cycleIndex: 0
    property string currentShapeKey: {
        let list = SettingsService.barIconCycleShapes || ["dashboard"];
        if (cycleIndex >= 0 && cycleIndex < list.length)
            return list[cycleIndex];
        return SettingsService.barIconShape || "dashboard";
    }

    readonly property string activeSvgPath: {
        if (SettingsService.barIconMode === "custom" && SettingsService.barIconCustomSvg && SettingsService.barIconCustomSvg.trim() !== "") {
            return SettingsService.barIconCustomSvg.trim();
        }
        if (SettingsService.barIconMode === "single") {
            return getShapePath(SettingsService.barIconShape);
        }
        return getShapePath(currentShapeKey);
    }

    function advanceToNextShape() {
        if (morphAnim.running)
            return ;
        morphAnim.restart();
    }

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
                        path: root.activeSvgPath
                    }
                }
            }
        }

        // Automatic Shape Cycling Timer
        Timer {
            id: cycleTimer
            interval: Math.max(3, SettingsService.barIconCycleInterval) * 1000
            repeat: true
            running: SettingsService.barIconMode === "cycle" && (SettingsService.barIconCycleShapes || []).length > 1
            onTriggered: {
                root.advanceToNextShape();
            }
        }

        // Morphing Shape Transition Animation
        SequentialAnimation {
            id: morphAnim

            ParallelAnimation {
                NumberAnimation {
                    target: dashboardShape
                    property: "scale"
                    to: 0.15
                    duration: 180
                    easing.type: Easing.InBack
                }
                NumberAnimation {
                    target: dashboardShape
                    property: "rotation"
                    to: -60
                    duration: 180
                    easing.type: Easing.InQuad
                }
            }

            ScriptAction {
                script: {
                    let shapes = SettingsService.barIconCycleShapes || ["dashboard"];
                    if (shapes.length > 0) {
                        root.cycleIndex = (root.cycleIndex + 1) % shapes.length;
                    }
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: dashboardShape
                    property: "scale"
                    to: 1.0
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.25
                }
                NumberAnimation {
                    target: dashboardShape
                    property: "rotation"
                    to: 0
                    duration: 340
                    easing.type: Easing.OutBack
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

        // Idle gentle micro-animation (only when not cycling or during quiet interval)
        SequentialAnimation {
            id: intervalAnim

            running: HyprlandService.enableAnimations && root.enableIntervalAnim && !introAnim.running && !morphAnim.running && (SettingsService.barIconMode !== "cycle" || (SettingsService.barIconCycleShapes || []).length <= 1)
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
