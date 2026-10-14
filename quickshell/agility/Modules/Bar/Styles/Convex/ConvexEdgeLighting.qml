import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
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
    readonly property real dynamicScale: 1.0 + (beatEnergy * 0.2)

    // Color derivation
    readonly property color baseColor: {
        if (SettingsService.edgeLightingColorMode === "album_art") {
            return Theme.accent;
        }
        return SettingsService.edgeLightingCustomColor;
    }

    // Geometry
    readonly property real screenW: Math.round(root.width)
    readonly property real screenH: Math.round(root.height)
    readonly property real bezel: root.bezelSize * root.fsTransitionProg
    readonly property real topBezel: 0
    readonly property real inX: bezel - root.expandOffset
    readonly property real inY: topBezel - root.expandOffset
    readonly property real inW: screenW - 2 * bezel + 2 * root.expandOffset
    readonly property real inH: screenH - topBezel - bezel + 2 * root.expandOffset
    readonly property real strokeThickness: Math.round(SettingsService.edgeLightingThickness * dynamicScale)

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: shouldGlow ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }
    }

    // Rotation progress along perimeter
    property real travelAngle: 0
    NumberAnimation on travelAngle {
        from: 0
        to: 360
        duration: Math.max(1000, Math.round(5000 / Math.max(0.1, SettingsService.edgeLightingSpeed)))
        loops: Animation.Infinite
        running: root.shouldGlow
    }

    // Sweeping conical light beam container
    Item {
        id: beamSource
        anchors.fill: parent
        visible: false

        Item {
            anchors.centerIn: parent
            width: Math.max(root.screenW, root.screenH) * 1.5
            height: width

            ConicalGradient {
                anchors.fill: parent
                angle: root.travelAngle
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: Math.max(0.01, 1.0 - (SettingsService.edgeLightingLength / 100.0))
                        color: "transparent"
                    }
                    GradientStop {
                        position: Math.max(0.01, 1.0 - (SettingsService.edgeLightingLength / 100.0 * 0.35))
                        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.5)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Math.min(1, root.baseColor.r * 1.3), Math.min(1, root.baseColor.g * 1.3), Math.min(1, root.baseColor.b * 1.3), 1.0)
                    }
                }
            }
        }
    }

    // Border mask following screen bezel
    Item {
        id: bezelStrokeMask
        anchors.fill: parent
        visible: false

        Rectangle {
            x: root.inX
            y: root.inY
            width: root.inW
            height: root.inH
            radius: root.innerRadius
            color: "transparent"
            border.color: "white"
            border.width: root.strokeThickness
        }
    }

    // Masked traveling beam
    Item {
        id: maskedBeam
        anchors.fill: parent
        visible: false

        OpacityMask {
            anchors.fill: parent
            source: beamSource
            maskSource: bezelStrokeMask
        }
    }

    // Soft Ambient Glow Bloom Spill
    MultiEffect {
        anchors.fill: parent
        source: maskedBeam
        blurEnabled: true
        blur: Math.min(1.0, (SettingsService.edgeLightingGlow * root.dynamicScale) / 32.0)
        blurMax: Math.round(SettingsService.edgeLightingGlow * 2 * root.dynamicScale)
        brightness: 0.15 + (root.beatEnergy * 0.25)
        contrast: 0.1
        opacity: 0.85
    }

    // Sharp Core Neon Beam
    MultiEffect {
        anchors.fill: parent
        source: maskedBeam
        blurEnabled: true
        blur: 0.15
        blurMax: 8
        brightness: 0.2
        opacity: 1.0
    }
}
