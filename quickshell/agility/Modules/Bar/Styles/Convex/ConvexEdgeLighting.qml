import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.Core
import qs.Core.Services
import qs.Core.Utils

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

    // Sub-bass beat detection from Cava spectrum (bars 0..3)
    readonly property real rawBeatEnergy: {
        let data = CavaService.cavaData;
        if (!data || data.length < 4)
            return 0.0;
        let sum = data[0] + data[1] + data[2] + data[3];
        return Math.min(1.0, sum / 320.0);
    }

    // Smoothed beat with snappy punch (40ms attack) and velvety decay (280ms)
    property real smoothedBeat: 0.0

    Binding on smoothedBeat {
        value: root.isAudioActive ? root.rawBeatEnergy : 0.0
    }

    Behavior on smoothedBeat {
        NumberAnimation {
            duration: root.rawBeatEnergy > root.smoothedBeat ? 40 : 280
            easing.type: root.rawBeatEnergy > root.smoothedBeat ? Easing.OutQuad : Easing.OutCubic
        }
    }

    // Ethereal idle breathing cycle for calm ambient mood when audio is idle/paused
    property real idlePhase: 0.0
    NumberAnimation {
        target: root
        property: "idlePhase"
        from: 0.0
        to: 6.2831853
        duration: 5200
        loops: Animation.Infinite
        running: root.shouldGlow
    }
    readonly property real idleGlow: Math.sin(idlePhase) * 0.08

    // Primary & Complementary palette derivation (Lumn dual-tone style)
    readonly property color primaryColor: {
        if (SettingsService.edgeLightingColorMode === "album_art") {
            return Theme.accent;
        }
        return SettingsService.edgeLightingCustomColor;
    }

    readonly property color secondaryColor: {
        if (SettingsService.edgeLightingColorMode === "album_art") {
            return Theme.accentComplementary;
        }
        let c = primaryColor;
        let r = c.r, g = c.g, b = c.b;
        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let h = 0, s = 0, l = (max + min) / 2;
        if (max !== min) {
            let d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === r) h = (g - b) / d + (g < b ? 6 : 0);
            else if (max === g) h = (b - r) / d + 2;
            else h = (r - g) / d + 4;
            h /= 6;
        }
        if (s < 0.08) {
            return Qt.rgba(0.92, 0.45, 0.72, 1.0);
        }
        let compH = (h + 0.42) % 1.0;
        return Qt.hsla(compH, Math.max(0.65, s), Math.min(0.70, Math.max(0.40, l)), 1.0);
    }

    // Geometry matching the Convex display frame
    readonly property real screenW: Math.round(root.width)
    readonly property real screenH: Math.round(root.height)
    readonly property real coreThickness: Math.max(2, Math.round(SettingsService.edgeLightingThickness * (1.0 + (root.smoothedBeat * 0.25)) * root.fsTransitionProg))
    readonly property real primaryRatio: Math.max(0.30, Math.min(0.85, SettingsService.edgeLightingLength / 100.0))
    readonly property real dynamicGlowSpread: Math.round((SettingsService.edgeLightingGlow + (root.smoothedBeat * 16)) * root.fsTransitionProg)

    // Gentle ambient drift rotation
    readonly property bool isClockwise: SettingsService.edgeLightingDirection !== "counter_clockwise"
    property real driftAngle: isClockwise ? 0 : 360

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
        id: driftAnim
        target: root
        property: "driftAngle"
        from: root.isClockwise ? 0 : 360
        to: root.isClockwise ? 360 : 0
        duration: Math.max(6000, Math.round(30000 / Math.max(0.1, SettingsService.edgeLightingSpeed)))
        loops: Animation.Infinite
        running: root.shouldGlow
    }

    Connections {
        target: SettingsService
        function onEdgeLightingDirectionChanged() {
            driftAnim.restart();
        }
        function onEdgeLightingSpeedChanged() {
            driftAnim.restart();
        }
    }

    // Dual-tone conical gradient source (seamless wrap at 0/360)
    Item {
        id: gradientSource
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Item {
            anchors.centerIn: parent
            width: Math.max(root.screenW, root.screenH) * 1.5
            height: width

            GE.ConicalGradient {
                anchors.fill: parent
                angle: root.driftAngle
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: root.primaryColor
                    }
                    GradientStop {
                        position: Math.max(0.05, root.primaryRatio * 0.70)
                        color: root.primaryColor
                    }
                    GradientStop {
                        position: Math.min(0.92, root.primaryRatio + ((1.0 - root.primaryRatio) * 0.35))
                        color: root.secondaryColor
                    }
                    GradientStop {
                        position: Math.min(0.96, 1.0 - ((1.0 - root.primaryRatio) * 0.20))
                        color: root.secondaryColor
                    }
                    GradientStop {
                        position: 1.0
                        color: root.primaryColor
                    }
                }
            }
        }
    }

    // Full-perimeter rim contour stroke matching exact Convex bezel inner curves
    Item {
        id: rimShapeContainer
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Shape {
            id: rimShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: Math.round(root.coreThickness)
                strokeColor: "white"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: {
                        let W = Math.round(root.width);
                        let H = Math.round(root.height);
                        let b = Math.max(1, Math.round(root.bezelSize * root.fsTransitionProg));
                        let r = Math.max(1, root.innerRadius);
                        let off = root.expandOffset;
                        let topBezel = 0;
                        let inX = b - off;
                        let inY = topBezel - off;
                        let inW = W - 2 * b + 2 * off;
                        let inH = H - topBezel - b + 2 * off;
                        if (W <= 0 || H <= 0 || inW <= 0 || inH <= 0)
                            return "";

                        let k = r * 0.552285;
                        return `M ${inX} ${inY + r} ` +
                               `L ${inX} ${inY + inH - r} ` +
                               `C ${inX} ${inY + inH - r + k}, ${inX + r - k} ${inY + inH}, ${inX + r} ${inY + inH} ` +
                               `L ${inX + inW - r} ${inY + inH} ` +
                               `C ${inX + inW - r + k} ${inY + inH}, ${inX + inW} ${inY + inH - r + k}, ${inX + inW} ${inY + inH - r} ` +
                               `L ${inX + inW} ${inY + r} ` +
                               `C ${inX + inW} ${inY + r - k}, ${inX + inW - r + k} ${inY}, ${inX + inW - r} ${inY} ` +
                               `L ${inX + r} ${inY} ` +
                               `C ${inX + r - k} ${inY}, ${inX} ${inY + r - k}, ${inX} ${inY + r} Z`;
                    }
                }
            }
        }
    }

    // Masked dual-tone continuous rim
    Item {
        id: maskedRim
        anchors.fill: parent
        visible: false
        layer.enabled: true

        GE.OpacityMask {
            anchors.fill: parent
            source: gradientSource
            maskSource: rimShapeContainer
        }
    }

    // Pass 1: Atmospheric Inward Bloom Diffusion (Lumn Ambient Radiance)
    // Fixed blurMax (48) prevents runtime shader re-compilation/re-allocation
    MultiEffect {
        anchors.fill: parent
        source: maskedRim
        visible: SettingsService.edgeLightingGlow > 0
        blurEnabled: true
        blurMax: 48
        blur: Math.min(1.0, root.dynamicGlowSpread / 48.0)
        brightness: 0.18 + (root.smoothedBeat * 0.38) + root.idleGlow
        contrast: 0.14 + (root.smoothedBeat * 0.10)
        saturation: 0.12 + (root.smoothedBeat * 0.20)
        opacity: 0.80 + (root.smoothedBeat * 0.20)
    }

    // Pass 2: Concentrated Core Aura (Luminous Band along Bezel Rim)
    // Fixed blurMax (16) provides steady high-FPS bloom without stutter
    MultiEffect {
        anchors.fill: parent
        source: maskedRim
        blurEnabled: true
        blurMax: 16
        blur: Math.min(1.0, (8.0 + (root.smoothedBeat * 6.0)) / 16.0)
        brightness: 0.24 + (root.smoothedBeat * 0.28)
        contrast: 0.10
        saturation: 0.15
        opacity: 0.90 + (root.smoothedBeat * 0.10)
    }

    // Pass 3: Precision Luminous Edge (Crisp Definition along Bezel Seam)
    MultiEffect {
        anchors.fill: parent
        source: maskedRim
        blurEnabled: true
        blurMax: 4
        blur: 0.20
        brightness: 0.18 + (root.smoothedBeat * 0.18)
        opacity: 0.96
    }
}
