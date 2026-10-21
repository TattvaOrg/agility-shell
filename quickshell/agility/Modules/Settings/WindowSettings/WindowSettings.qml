import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    AppGroup {
        title: "Display Scaling"
        icon: "monitor"

        SettingSegmented {
            label: "Hyprland Monitor Scale"
            description: "Global Wayland display scaling"
            model: [{
                "text": "100%",
                "value": 1
            }, {
                "text": "125%",
                "value": 1.25
            }, {
                "text": "150%",
                "value": 1.5
            }, {
                "text": "200%",
                "value": 2
            }]
            currentValue: SettingsService.hyprScale
            onActivated: (value) => {
                SettingsService.hyprScale = value;
                hyprScaleApplyProc.running = false;
                hyprScaleApplyProc.running = true;
            }

            Process {
                id: hyprScaleApplyProc

                command: ["sh", "-c", Quickshell.shellDir + "/Scripts/system/hypr_scale.sh " + SettingsService.hyprScale]
            }

        }

    }

    AppGroup {
        title: "Settings Window"
        icon: "window"

        SettingSegmented {
            label: "Window Presentation"
            description: "Choose how the Settings application opens on screen (Full Screen, Half Screen, or Centered Box)"
            model: [{
                "text": "Full Screen",
                "value": "full"
            }, {
                "text": "Half Screen",
                "value": "half"
            }, {
                "text": "Boxed",
                "value": "boxed"
            }]
            currentValue: SettingsService.settingsWindowMode
            onActivated: (value) => {
                SettingsService.settingsWindowMode = value;
                SettingsService.saveSettings();
            }
        }

        Divider {
            visible: SettingsService.settingsWindowMode === "boxed"
        }

        ThemedSlider {
            visible: SettingsService.settingsWindowMode === "boxed"
            label: "Box Width"
            from: 640
            to: 1400
            stepSize: 20
            value: SettingsService.settingsBoxedWidth
            suffix: "px"
            decimals: 0
            onMoved: (val) => {
                SettingsService.settingsBoxedWidth = Math.round(val);
                SettingsService.saveSettings();
            }
        }

        Divider {
            visible: SettingsService.settingsWindowMode === "boxed"
        }

        ThemedSlider {
            visible: SettingsService.settingsWindowMode === "boxed"
            label: "Box Height"
            from: 480
            to: 950
            stepSize: 20
            value: SettingsService.settingsBoxedHeight
            suffix: "px"
            decimals: 0
            onMoved: (val) => {
                SettingsService.settingsBoxedHeight = Math.round(val);
                SettingsService.saveSettings();
            }
        }
    }

    AppGroup {
        title: "Window Geometry & Tiling"
        icon: "window"

        SettingSpinBox {
            label: "Window Rounding"
            from: 0
            to: 40
            stepSize: 1
            value: HyprlandService.hyprRounding
            defaultValue: 32
            suffix: "px"
            onMoved: (val) => {
                HyprlandService.hyprRounding = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Gaps In"
            description: "Modifying this may break the Convex Style layout"
            from: 0
            to: 20
            stepSize: 1
            value: HyprlandService.hyprGapsIn
            defaultValue: 4
            suffix: "px"
            onMoved: (val) => {
                HyprlandService.hyprGapsIn = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Gaps Out"
            description: "Modifying this may break the Convex Style layout"
            from: 0
            to: 40
            stepSize: 1
            value: HyprlandService.hyprGapsOut
            defaultValue: Constants.sizeXs
            suffix: "px"
            onMoved: (val) => {
                HyprlandService.hyprGapsOut = Math.round(val);
            }
        }

        SettingSpinBox {
            label: "Border Size"
            from: 0
            to: 10
            stepSize: 1
            value: HyprlandService.hyprBorderSize
            defaultValue: 2
            suffix: "px"
            onMoved: (val) => {
                HyprlandService.hyprBorderSize = Math.round(val);
            }
        }

    }

}
