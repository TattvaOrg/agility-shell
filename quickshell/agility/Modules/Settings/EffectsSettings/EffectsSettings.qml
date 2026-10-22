import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    AppGroup {
        title: "Animations"
        icon: "sparkles"

        SettingSpinBox {
            label: "Global Animation Speed"
            description: "Control UI transition and fade speed"
            from: 0
            to: 2
            stepSize: 0.1
            value: HyprlandService.enableAnimations ? HyprlandService.animationSpeedFactor : 0
            suffix: "x"
            decimals: 1
            allowOff: true
            offText: "Off"
            onMoved: (val) => {
                if (val <= 0.001) {
                    HyprlandService.enableAnimations = false;
                } else {
                    if (!HyprlandService.enableAnimations)
                        HyprlandService.enableAnimations = true;

                    HyprlandService.animationSpeedFactor = Number(val.toFixed(1));
                }
            }
        }

    }

    AppGroup {
        title: "Sound Effects"
        icon: "volume"

        SettingToggle {
            label: "System Sound Effects"
            description: "Play audio feedback for startup, popups, battery plug/unplug, notifications, and shell events"
            checked: SettingsService.soundEffectsEnabled
            onCheckedChanged: {
                SettingsService.soundEffectsEnabled = checked;
                if (checked) {
                    SoundService.play("confirm");
                }
            }
        }

        Divider {
            Layout.fillWidth: true
            visible: true
        }

        SettingRowTemplate {
            label: "Audition Sound Theme"
            description: "Play a preview sound effect to verify audio feedback"

            Button {
                id: testSoundBtn
                text: "▶ Play Test Sound"
                enabled: SettingsService.soundEffectsEnabled
                opacity: enabled ? 1.0 : 0.5
                font.family: Constants.fontFamily
                font.pixelSize: Math.round(11 * SettingsService.fontScale)
                font.weight: Font.DemiBold
                implicitHeight: 32
                implicitWidth: 140
                contentItem: ThemedText {
                    text: testSoundBtn.text
                    font.family: Constants.fontFamily
                    font.pixelSize: Math.round(11 * SettingsService.fontScale)
                    font.weight: Font.DemiBold
                    color: testSoundBtn.enabled ? (testSoundBtn.hovered ? Theme.bg : Theme.accent) : Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: testSoundBtn.enabled && testSoundBtn.hovered ? Theme.accent : Theme.bg
                    border.color: testSoundBtn.enabled ? Theme.accent : Theme.borderSecondary
                    border.width: 1
                    radius: Constants.sizeXs

                    Behavior on color {
                        ColorAnimation {
                            duration: Constants.animFast
                        }
                    }
                }
                onClicked: {
                    SoundService.play("confirm", 0);
                }
            }
        }
    }

    AppGroup {
        title: "Compositor Effects"
        icon: "hyprland"

        SettingSpinBox {
            label: "Global Opacity"
            description: "Transparency of windows and shell"
            from: 50
            to: 100
            stepSize: 5
            value: HyprlandService.hyprActiveOpacity
            defaultValue: 100
            suffix: "%"
            onMoved: (val) => {
                let intVal = Math.round(val);
                HyprlandService.hyprActiveOpacity = intVal;
                HyprlandService.hyprInactiveOpacity = intVal;
                HyprlandService.applyHyprlandSettings();
                Theme.bgOpacity = intVal / 100;
                Theme.saveScheme();
            }
        }

        SettingToggle {
            id: blurToggle

            label: "Enable Window & Panel Blur"
            onCheckedChanged: {
                if (checked !== HyprlandService.hyprBlur)
                    HyprlandService.hyprBlur = checked;

            }

            Binding on checked {
                value: HyprlandService.hyprBlur
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: HyprlandService.hyprBlur
            opacity: enabled ? 1 : 0.5

            SettingSpinBox {
                label: "Blur Size"
                from: 1
                to: 15
                stepSize: 1
                value: HyprlandService.hyprBlurSize
                defaultValue: 6
                onMoved: (val) => {
                    HyprlandService.hyprBlurSize = Math.round(val);
                }
            }

            SettingSpinBox {
                label: "Blur Passes"
                from: 1
                to: 10
                stepSize: 1
                value: HyprlandService.hyprBlurPasses
                defaultValue: 4
                onMoved: (val) => {
                    HyprlandService.hyprBlurPasses = Math.round(val);
                }
            }

        }

        SettingToggle {
            id: shadowToggle

            label: "Enable Window & Shell Shadows"
            onCheckedChanged: {
                if (checked !== HyprlandService.hyprShadow)
                    HyprlandService.hyprShadow = checked;

            }

            Binding on checked {
                value: HyprlandService.hyprShadow
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: HyprlandService.hyprShadow
            opacity: enabled ? 1 : 0.5

            SettingSpinBox {
                label: "Shadow Range"
                from: 1
                to: 60
                stepSize: 1
                value: HyprlandService.hyprShadowRange
                defaultValue: 20
                suffix: "px"
                onMoved: (val) => {
                    HyprlandService.hyprShadowRange = Math.round(val);
                }
            }

            SettingSpinBox {
                label: "Shadow Render Power"
                from: 1
                to: 4
                stepSize: 1
                value: HyprlandService.hyprShadowRenderPower
                defaultValue: 2
                onMoved: (val) => {
                    HyprlandService.hyprShadowRenderPower = Math.round(val);
                }
            }

        }

    }

    AppGroup {
        title: "Ambient Edge Lighting"
        icon: "sun"

        SettingToggle {
            label: "Enable Ambient Edge Lighting"
            description: "Glowing perimeter beam along screen bezel (Convex bar)"
            onCheckedChanged: {
                if (checked !== SettingsService.edgeLightingEnabled)
                    SettingsService.edgeLightingEnabled = checked;
            }

            Binding on checked {
                value: SettingsService.edgeLightingEnabled
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: SettingsService.edgeLightingEnabled
            opacity: enabled ? 1 : 0.5

            SettingToggle {
                label: "Activate Only When Audio Plays"
                description: "Lights up on music or system audio; glows idle when off"
                onCheckedChanged: {
                    if (checked !== SettingsService.edgeLightingAudioOnly)
                        SettingsService.edgeLightingAudioOnly = checked;
                }

                Binding on checked {
                    value: SettingsService.edgeLightingAudioOnly
                }
            }

            SettingToggle {
                label: "Dynamic Album Art Colors"
                description: "Extract color from playing music; disable to use custom color"
                onCheckedChanged: {
                    let mode = checked ? "album_art" : "custom";
                    if (mode !== SettingsService.edgeLightingColorMode)
                        SettingsService.edgeLightingColorMode = mode;
                }

                Binding on checked {
                    value: SettingsService.edgeLightingColorMode === "album_art"
                }
            }

            SettingSegmented {
                label: "Glow Direction"
                description: "Rotation direction of the light path along the screen bezel"
                model: [{
                    "text": "Clockwise",
                    "value": "clockwise"
                }, {
                    "text": "Counter-Clockwise",
                    "value": "counter_clockwise"
                }]
                currentValue: SettingsService.edgeLightingDirection
                onActivated: (value) => {
                    SettingsService.edgeLightingDirection = value;
                }
            }

            SettingSpinBox {
                label: "Glow Width"
                description: "Thickness of the glowing light band inside the bezel channel"
                from: 4
                to: 32
                stepSize: 2
                value: SettingsService.edgeLightingThickness
                defaultValue: 12
                suffix: "px"
                onMoved: (val) => {
                    SettingsService.edgeLightingThickness = Math.round(val);
                }
            }

            SettingSpinBox {
                label: "Rotation Speed"
                description: "Speed of traveling light beam around the screen"
                from: 0.2
                to: 3.0
                stepSize: 0.2
                value: SettingsService.edgeLightingSpeed
                defaultValue: 1.0
                decimals: 1
                suffix: "x"
                onMoved: (val) => {
                    SettingsService.edgeLightingSpeed = Number(val.toFixed(1));
                }
            }

            SettingSpinBox {
                label: "Beam Length"
                description: "Length of the glowing comet arc along perimeter"
                from: 10
                to: 100
                stepSize: 5
                value: SettingsService.edgeLightingLength
                defaultValue: 30
                suffix: "%"
                onMoved: (val) => {
                    SettingsService.edgeLightingLength = Math.round(val);
                }
            }

            SettingSpinBox {
                label: "Glow Spread & Bloom"
                description: "Atmospheric radiance and diffusion radius of the rim glow"
                from: 2
                to: 36
                stepSize: 2
                value: SettingsService.edgeLightingGlow
                defaultValue: 16
                suffix: "px"
                onMoved: (val) => {
                    SettingsService.edgeLightingGlow = Math.round(val);
                }
            }
        }
    }

}
