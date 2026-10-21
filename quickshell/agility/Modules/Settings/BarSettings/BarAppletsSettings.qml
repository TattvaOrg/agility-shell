import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: barAppletsRoot

    // ACTIVE WINDOW TITLE & ICON PILL
    AppGroup {
        title: "Active Window Pill"
        icon: "window"

        SettingToggle {
            label: "Enable Active Window Pill"
            description: "Display the focused application's icon and truncated window title in a compact pill"
            checked: SettingsService.appletActiveWindow
            onCheckedChanged: {
                SettingsService.appletActiveWindow = checked;
            }
        }

        Divider {
            visible: SettingsService.appletActiveWindow
        }

        SettingSegmented {
            visible: SettingsService.appletActiveWindow
            label: "Primary Click Action"
            description: "Choose what happens when clicking the window pill (Right-click always opens App Switcher)"
            model: [{
                "text": "Maximize / Restore",
                "value": "maximize"
            }, {
                "text": "App Switcher",
                "value": "switcher"
            }]
            currentValue: SettingsService.appletActiveWindowAction
            onActivated: (value) => {
                SettingsService.appletActiveWindowAction = value;
            }
        }
    }

    // DYNAMIC AUDIO VISUALIZER & MEDIA PILL
    AppGroup {
        title: "Dynamic Media & Visualizer"
        icon: "music"

        SettingToggle {
            label: "Enable Dynamic Media Pill"
            description: "Display playing song and artist inside a dynamic capsule with hover playback controls"
            checked: SettingsService.appletDynamicMedia
            onCheckedChanged: {
                SettingsService.appletDynamicMedia = checked;
            }
        }

        Divider {
            visible: SettingsService.appletDynamicMedia
        }

        SettingToggle {
            visible: SettingsService.appletDynamicMedia
            label: "Live Cava Audio Visualizer"
            description: "Show 4-bar bouncing visualizer bars synchronized with audio output"
            checked: SettingsService.appletMediaVisualizer
            onCheckedChanged: {
                SettingsService.appletMediaVisualizer = checked;
            }
        }
    }

    // WEATHER PILL & 3-DAY FORECAST
    AppGroup {
        title: "Weather Pill & Forecast"
        icon: "sun"

        SettingToggle {
            label: "Enable Weather Pill"
            description: "Display live weather condition icon and temperature beside the clock that expands into a 3-day card"
            checked: SettingsService.appletWeather
            onCheckedChanged: {
                SettingsService.appletWeather = checked;
            }
        }

        Divider {
            visible: SettingsService.appletWeather
        }

        SettingSegmented {
            visible: SettingsService.appletWeather
            label: "Temperature Unit"
            description: "Choose between Celsius (°C) and Fahrenheit (°F)"
            model: [{
                "text": "Celsius (°C)",
                "value": "C"
            }, {
                "text": "Fahrenheit (°F)",
                "value": "F"
            }]
            currentValue: SettingsService.appletWeatherUnit
            onActivated: (value) => {
                SettingsService.appletWeatherUnit = value;
            }
        }
    }

    // BATTERY HEALTH & CHARGE ESTIMATOR
    AppGroup {
        title: "Battery Health & Estimator"
        icon: "charger"

        SettingToggle {
            label: "Enable Battery Pill"
            description: "Display battery capsule with pulse charging animation and level indicator"
            checked: SettingsService.appletBattery
            onCheckedChanged: {
                SettingsService.appletBattery = checked;
            }
        }

        Divider {
            visible: SettingsService.appletBattery
        }

        SettingToggle {
            visible: SettingsService.appletBattery
            label: "Show Discharge / Charge Time"
            description: "Display estimated remaining hours and minutes (e.g. ⚡ 85% • 3h 15m)"
            checked: SettingsService.appletBatteryShowTime
            onCheckedChanged: {
                SettingsService.appletBatteryShowTime = checked;
            }
        }
    }

    // NETWORK & STATUS INDICATORS
    AppGroup {
        title: "Network & Status Indicators"
        icon: "wifi"

        SettingToggle {
            label: "Network Traffic Monitor"
            description: "Display real-time upload and download speeds on the bar"
            checked: SettingsService.appletNetwork
            onCheckedChanged: {
                SettingsService.appletNetwork = checked;
            }
        }

        Divider {
        }

        SettingToggle {
            label: "Do Not Disturb (DND) Pill"
            description: "Quick 1-click toggle on the bar to suppress notification popups and banners"
            checked: SettingsService.appletDnd
            onCheckedChanged: {
                SettingsService.appletDnd = checked;
            }
        }
    }

    // BAR TRANSLUCENCY & GLASSMORPHISM
    AppGroup {
        title: "Bar Translucency & Glassmorphism"
        icon: "sparkles"

        SettingSegmented {
            label: "Background Mode"
            description: "Choose between Solid, Frosted Glass, Translucent Gradient, or Wallpaper-adaptive tint"
            model: [{
                "text": "Solid",
                "value": "solid"
            }, {
                "text": "Frosted Glass",
                "value": "blur"
            }, {
                "text": "Gradient",
                "value": "gradient"
            }, {
                "text": "Adaptive Tint",
                "value": "adaptive"
            }]
            currentValue: SettingsService.barGlassMode
            onActivated: (value) => {
                SettingsService.barGlassMode = value;
            }
        }

        Divider {
            visible: SettingsService.barGlassMode === "solid"
        }

        SettingSegmented {
            visible: SettingsService.barGlassMode === "solid"
            label: "Solid Tone"
            description: "Choose between deep black or pure white solid bar background"
            model: [{
                "text": "Black",
                "value": "black"
            }, {
                "text": "White",
                "value": "white"
            }]
            currentValue: SettingsService.barSolidTone
            onActivated: (value) => {
                SettingsService.barSolidTone = value;
            }
        }

        Divider {
            visible: SettingsService.barGlassMode !== "solid"
        }

        ThemedSlider {
            visible: SettingsService.barGlassMode !== "solid"
            label: "Bar Opacity"
            from: 20
            to: 100
            stepSize: 1
            value: SettingsService.barGlassOpacity
            suffix: "%"
            decimals: 0
            onMoved: (val) => {
                SettingsService.barGlassOpacity = Math.round(val);
            }
        }
    }
}
