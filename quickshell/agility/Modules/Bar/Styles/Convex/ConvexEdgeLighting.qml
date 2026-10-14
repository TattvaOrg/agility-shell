import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Core
import qs.Core.Services

Item {
    id: root

    property int barHeight: Constants.size4Xl
    property int bezelSize: Constants.sizeXs
    property int innerRadius: Constants.size4Xl
    property real fsTransitionProg: 1
    property real expandOffset: 0

    // Audio reactivity
    readonly property bool isAudioActive: MprisService.isPlaying || AudioService.isSinkInputActive
    readonly property bool shouldGlow: SettingsService.edgeLightingEnabled && (!SettingsService.edgeLightingAudioOnly || isAudioActive) && fsTransitionProg > 0.01

    // Bass / Beat energy from Cava
    readonly property real beatEnergy: {
        let data = CavaService.cavaData;
        if (!data || data.length < 4)
            return 0;
        let sum = data[0] + data[1] + data[2] + data[3];
        return Math.min(1.0, sum / 320.0);
    }
    readonly property real dynamicScale: 1.0 + (beatEnergy * 0.25)

    // Color derivation
    readonly property color baseColor: {
        if (SettingsService.edgeLightingColorMode === "album_art") {
            return Theme.accent;
        }
        return SettingsService.edgeLightingCustomColor;
    }

    // Geometry & Channel Thickness
    readonly property real screenW: Math.round(root.width)
    readonly property real screenH: Math.round(root.height)
    readonly property real channelThickness: Math.round(Math.max(root.bezelSize, SettingsService.edgeLightingThickness) * dynamicScale)

    // Rotation Direction & Speed
    readonly property bool isClockwise: SettingsService.edgeLightingDirection !== "counter_clockwise"
    property real travelAngle: isClockwise ? 0 : 360

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: shouldGlow ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: rotationAnim

        target: root
        property: "travelAngle"
        from: root.isClockwise ? 0 : 360
        to: root.isClockwise ? 360 : 0
        duration: Math.max(800, Math.round(5000 / Math.max(0.1, SettingsService.edgeLightingSpeed)))
        loops: Animation.Infinite
        running: root.shouldGlow
    }

    Connections {
        target: SettingsService
        function onEdgeLightingDirectionChanged() {
            rotationAnim.restart();
        }
        function onEdgeLightingSpeedChanged() {
            rotationAnim.restart();
        }
    }

    // Rotating conical light beam
    Item {
        id: beamSource

        anchors.fill: parent
        visible: false

        Item {
            anchors.centerIn: parent
            width: Math.max(root.screenW, root.screenH) * 1.6
            height: width

            GE.ConicalGradient {
                anchors.fill: parent
                angle: root.travelAngle
                gradient: Gradient {
                    readonly property real arcLength: Math.max(0.10, Math.min(1.0, SettingsService.edgeLightingLength / 100.0))

                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: Math.max(0.001, 1.0 - arcLength)
                        color: "transparent"
                    }
                    GradientStop {
                        position: Math.max(0.002, 1.0 - (arcLength * 0.70))
                        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.15)
                    }
                    GradientStop {
                        position: Math.max(0.003, 1.0 - (arcLength * 0.35))
                        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.50)
                    }
                    GradientStop {
                        position: Math.max(0.004, 1.0 - (arcLength * 0.10))
                        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.85)
                    }
                    GradientStop {
                        position: Math.max(0.005, 1.0 - (arcLength * 0.02))
                        color: Qt.rgba(Math.min(1, root.baseColor.r * 1.25), Math.min(1, root.baseColor.g * 1.25), Math.min(1, root.baseColor.b * 1.25), 1.0)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.0)
                    }
                }
            }
        }
    }

    // Broad channel mask matching the exact Convex outline
    Item {
        id: bezelChannelMask

        anchors.fill: parent
        visible: false

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: "white"
                fillRule: ShapePath.OddEvenFill

                PathSvg {
                    path: {
                        let W = root.screenW;
                        let H = root.screenH;
                        let b = Math.max(1, Math.round(root.channelThickness));
                        let r = Math.max(1, root.innerRadius);
                        let off = root.expandOffset;
                        let inX = b - off;
                        let inY = b - off;
                        let inW = W - 2 * b + 2 * off;
                        let inH = H - 2 * b + 2 * off;
                        if (W <= 0 || H <= 0 || inW <= 0 || inH <= 0)
                            return "";

                        let k = r * 0.552285;
                        let outer = `M 0 0 L ${W} 0 L ${W} ${H} L 0 ${H} Z `;
                        let inner = `M ${inX} ${inY + r} ` +
                                    `L ${inX} ${inY + inH - r} ` +
                                    `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} ` +
                                    `L ${inX + inW - r} ${inY + inH} ` +
                                    `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} ` +
                                    `L ${inX + inW} ${inY + r} ` +
                                    `C ${inX + inW} ${inY + r - k}, ${inX + inW - r + k} ${inY}, ${inX + inW - r} ${inY} ` +
                                    `L ${inX + r} ${inY} ` +
                                    `C ${inX + r - k} ${inY}, ${inX} ${inY + r - k}, ${inX} ${inY + r} Z`;
                        return outer + inner;
                    }
                }
            }
        }
    }

    // Masked traveling beam
    Item {
        id: maskedBeam

        anchors.fill: parent
        visible: false

        GE.OpacityMask {
            anchors.fill: parent
            source: beamSource
            maskSource: bezelChannelMask
        }
    }

    // Primary Luminous Channel Pass (Broad Soft Core Glow)
    MultiEffect {
        anchors.fill: parent
        source: maskedBeam
        blurEnabled: true
        blur: 0.20
        blurMax: 8
        brightness: 0.15 + (root.beatEnergy * 0.30)
        contrast: 0.12
        opacity: 0.92
    }

    // Secondary Ambient Diffusion Bloom (Atmospheric Rim Radiance)
    MultiEffect {
        anchors.fill: parent
        source: maskedBeam
        blurEnabled: true
        blur: Math.min(1.0, (SettingsService.edgeLightingGlow * root.dynamicScale) / 28.0)
        blurMax: Math.round(SettingsService.edgeLightingGlow * 2.2 * root.dynamicScale)
        brightness: 0.20 + (root.beatEnergy * 0.40)
        opacity: 0.80
    }
}
