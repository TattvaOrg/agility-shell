import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: barSettingsRoot

    AppGroup {
        title: "Bar Style"
        icon: "bar"

        SettingSegmented {
            label: "Style"
            description: "Choose between Convex, Island, or Floating Pill"
            model: [{
                "text": "Convex",
                "value": "convex"
            }, {
                "text": "Island",
                "value": "island"
            }, {
                "text": "Floating Pill",
                "value": "pill"
            }]
            currentValue: SettingsService.barStyle
            onActivated: (value) => {
                SettingsService.barStyle = value;
            }
        }

        Divider {
            visible: SettingsService.barIslandMode || SettingsService.barPillMode
        }

        SettingToggle {
            visible: SettingsService.barIslandMode || SettingsService.barPillMode
            label: "Auto-hide Bar"
            description: "Smoothly slide the bar out of view when a window is open, reveal when hovered or screen is empty"
            checked: SettingsService.barAutoHide
            onCheckedChanged: {
                SettingsService.barAutoHide = checked;
            }
        }

    }

    // ISLAND MODE WIDGETS
    AppGroup {
        title: "Island Bar Widgets"
        icon: "widgets"
        visible: SettingsService.barIslandMode

        SettingSegmented {
            label: "Right Circular Island"
            description: "Choose what to display in the right circular island (Music cover or Control Center)"
            model: [{
                "text": "Auto (Music or Tune)",
                "value": "auto"
            }, {
                "text": "Always Music",
                "value": "music"
            }, {
                "text": "Always Control Center",
                "value": "control_center"
            }]
            currentValue: SettingsService.islandRightMode
            onActivated: (value) => {
                SettingsService.islandRightMode = value;
            }
        }

    }

    // PILL MODE SETTINGS
    AppGroup {
        title: "Pill Bar Customization"
        icon: "tune"
        visible: SettingsService.barPillMode

        SettingSegmented {
            label: "Popup Style"
            description: "Choose how options and menus open (Sided, Top, or Center)"
            model: [{
                "text": "Sided",
                "value": "sided"
            }, {
                "text": "Top",
                "value": "top"
            }, {
                "text": "Center",
                "value": "center"
            }]
            currentValue: SettingsService.pillPopupStyle
            onActivated: (value) => {
                SettingsService.pillPopupStyle = value;
            }
        }

        Divider {
        }

        SettingSegmented {
            label: "Widget Layout"
            description: "Choose how widgets are arranged across the bar"
            model: [{
                "text": "Distributed",
                "value": "distributed"
            }, {
                "text": "Centered",
                "value": "centered"
            }]
            currentValue: SettingsService.pillWidgetLayout
            onActivated: (value) => {
                SettingsService.pillWidgetLayout = value;
            }
        }

        Divider {
        }

        ThemedSlider {
            label: "Bar Width"
            from: 30
            to: 100
            stepSize: 1
            value: SettingsService.pillBarWidthPercent
            suffix: "%"
            decimals: 0
            onMoved: (val) => {
                SettingsService.pillBarWidthPercent = Math.round(val);
            }
        }

    }

    AppGroup {
        title: "Clock Format"
        icon: "clock"

        SettingToggle {
            label: "24-Hour Time"
            description: "Use 24-hour time format instead of 12-hour AM/PM"
            checked: SettingsService.clock24h
            onCheckedChanged: {
                SettingsService.clock24h = checked;
            }
        }

        SettingToggle {
            label: "Show Seconds"
            description: "Display seconds on the main clock"
            checked: SettingsService.clockSeconds
            onCheckedChanged: {
                SettingsService.clockSeconds = checked;
            }
        }

        SettingToggle {
            label: "Show Date"
            description: "Display the current date next to the clock"
            checked: SettingsService.clockShowDate
            onCheckedChanged: {
                SettingsService.clockShowDate = checked;
            }
        }

    }

}
