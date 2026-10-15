import QtQuick
import Qt5Compat.GraphicalEffects as GE
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

    // Audio reactivity - real-time spectrum analysis from CavaService
    readonly property real rawBeatEnergy: {
        let data = CavaService.cavaData;
        if (!data || data.length < 8)
            return 0.0;
        let sum = 0;
        let count = Math.min(12, data.length);
        for (let i = 0; i < count; i++) {
            sum += data[i];
        }
        return Math.min(1.0, sum / 200.0);
    }

    readonly property bool isAudioActive: rawBeatEnergy > 0.02 || MprisService.isPlaying
    readonly property bool shouldGlow: SettingsService.edgeLightingEnabled && (!SettingsService.edgeLightingAudioOnly || isAudioActive) && fsTransitionProg > 0.01

    // Smoothed beat with snappy punch (40ms attack) and velvety decay (280ms)
    readonly property real targetBeat: root.isAudioActive ? root.rawBeatEnergy : 0.0
    property real smoothedBeat: targetBeat

    Behavior on smoothedBeat {
        NumberAnimation {
            duration: root.targetBeat > root.smoothedBeat ? 40 : 280
            easing.type: root.targetBeat > root.smoothedBeat ? Easing.OutQuad : Easing.OutCubic
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
        let c;
        if (SettingsService.edgeLightingColorMode === "album_art") {
            c = Theme.accent;
        } else {
            c = SettingsService.edgeLightingCustomColor;
        }
        let r = c.r, g = c.g, b = c.b;
        if (Math.max(r, g, b) < 0.15) {
            return Qt.rgba(0.65, 0.45, 0.95, 1.0);
        }
        return Qt.rgba(r, g, b, 1.0);
    }

    readonly property color secondaryColor: {
        if (SettingsService.edgeLightingColorMode === "album_art") {
            let comp = Theme.accentComplementary;
            if (Math.max(comp.r, comp.g, comp.b) > 0.15) {
                return Qt.rgba(comp.r, comp.g, comp.b, 1.0);
            }
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

    // Dynamic continuous wave drift
    readonly property bool isClockwise: SettingsService.edgeLightingDirection !== "counter_clockwise"
    property real wavePhase: 0.0

    NumberAnimation {
        id: waveAnim
        target: root
        property: "wavePhase"
        from: 0.0
        to: 1.0
        duration: Math.max(4000, Math.round(18000 / Math.max(0.1, SettingsService.edgeLightingSpeed)))
        loops: Animation.Infinite
        running: root.shouldGlow
    }

    Connections {
        target: SettingsService
        function onEdgeLightingDirectionChanged() {
            waveAnim.restart();
        }
        function onEdgeLightingSpeedChanged() {
            waveAnim.restart();
        }
    }

    // Dynamic dual-tone color sampling based on traveling wave phase
    function getWaveColor(offset) {
        let dir = root.isClockwise ? 1 : -1;
        let p = (root.wavePhase * dir + offset) % 1.0;
        if (p < 0.0) p += 1.0;

        let blend = (Math.cos(p * 2.0 * Math.PI) + 1.0) * 0.5;
        return Qt.rgba(
            primaryColor.r * blend + secondaryColor.r * (1.0 - blend),
            primaryColor.g * blend + secondaryColor.g * (1.0 - blend),
            primaryColor.b * blend + secondaryColor.b * (1.0 - blend),
            1.0
        );
    }

    readonly property color topColor: getWaveColor(0.0)
    readonly property color rightColor: getWaveColor(0.25)
    readonly property color bottomColor: getWaveColor(0.50)
    readonly property color leftColor: getWaveColor(0.75)

    // Dynamic Inward Glow Depth (scales smoothly with bass energy & idle breathing)
    readonly property real baseGlow: Math.max(12, SettingsService.edgeLightingGlow)
    readonly property real bloomDepth: Math.max(20, Math.round((baseGlow * 2.5) + (smoothedBeat * 28) + (idleGlow * 8)))
    readonly property real coreDepth: Math.max(8, Math.round(bloomDepth * 0.42))

    readonly property real bloomOpacity: Math.min(1.0, Math.max(0.0, (0.75 + (smoothedBeat * 0.22) + idleGlow) * root.fsTransitionProg))
    readonly property real coreOpacity: Math.min(1.0, Math.max(0.0, (0.88 + (smoothedBeat * 0.12)) * root.fsTransitionProg))

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: shouldGlow ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // ===== PASS 1: ATMOSPHERIC BLOOM (Deep ambient wash into display) =====
    // Top Edge Bloom
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.bloomDepth
        opacity: root.bloomOpacity
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.topColor }
            GradientStop { position: 0.25; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.45) }
            GradientStop { position: 0.60; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Bottom Edge Bloom
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.bloomDepth
        opacity: root.bloomOpacity
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.40; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.15) }
            GradientStop { position: 0.75; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.45) }
            GradientStop { position: 1.0; color: root.bottomColor }
        }
    }

    // Left Edge Bloom
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.bloomDepth
        opacity: root.bloomOpacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.leftColor }
            GradientStop { position: 0.25; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.45) }
            GradientStop { position: 0.60; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Right Edge Bloom
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.bloomDepth
        opacity: root.bloomOpacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.40; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.15) }
            GradientStop { position: 0.75; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.45) }
            GradientStop { position: 1.0; color: root.rightColor }
        }
    }

    // 4 Corner Radial Blooms
    GE.RadialGradient {
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.bloomDepth * 1.6
        height: width
        opacity: root.bloomOpacity * 0.85
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.leftColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.35) }
            GradientStop { position: 0.70; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.bloomDepth * 1.6
        height: width
        opacity: root.bloomOpacity * 0.85
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.topColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.35) }
            GradientStop { position: 0.70; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.bloomDepth * 1.6
        height: width
        opacity: root.bloomOpacity * 0.85
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.bottomColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.35) }
            GradientStop { position: 0.70; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.bloomDepth * 1.6
        height: width
        opacity: root.bloomOpacity * 0.85
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.rightColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.35) }
            GradientStop { position: 0.70; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // ===== PASS 2: RADIANT CORE (Intense inner edge radiance) =====
    // Top Core
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.coreDepth
        opacity: root.coreOpacity
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.topColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.65) }
            GradientStop { position: 0.75; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.20) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Bottom Core
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.coreDepth
        opacity: root.coreOpacity
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.25; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.20) }
            GradientStop { position: 0.65; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.65) }
            GradientStop { position: 1.0; color: root.bottomColor }
        }
    }

    // Left Core
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.coreDepth
        opacity: root.coreOpacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.leftColor }
            GradientStop { position: 0.35; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.65) }
            GradientStop { position: 0.75; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.20) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Right Core
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.coreDepth
        opacity: root.coreOpacity
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.25; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.20) }
            GradientStop { position: 0.65; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.65) }
            GradientStop { position: 1.0; color: root.rightColor }
        }
    }

    // 4 Corner Radial Cores
    GE.RadialGradient {
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.coreDepth * 1.5
        height: width
        opacity: root.coreOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.leftColor }
            GradientStop { position: 0.40; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.60) }
            GradientStop { position: 0.80; color: Qt.rgba(root.leftColor.r, root.leftColor.g, root.leftColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.coreDepth * 1.5
        height: width
        opacity: root.coreOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.topColor }
            GradientStop { position: 0.40; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.60) }
            GradientStop { position: 0.80; color: Qt.rgba(root.topColor.r, root.topColor.g, root.topColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.coreDepth * 1.5
        height: width
        opacity: root.coreOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.bottomColor }
            GradientStop { position: 0.40; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.60) }
            GradientStop { position: 0.80; color: Qt.rgba(root.bottomColor.r, root.bottomColor.g, root.bottomColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    GE.RadialGradient {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.coreDepth * 1.5
        height: width
        opacity: root.coreOpacity
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.rightColor }
            GradientStop { position: 0.40; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.60) }
            GradientStop { position: 0.80; color: Qt.rgba(root.rightColor.r, root.rightColor.g, root.rightColor.b, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
