import QtQuick
import QtQuick.Layouts
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

        Divider {
        }

        SettingToggle {
            label: "Open on Hover"
            description: "Automatically open menus and popups when hovering over bar widgets without needing to click"
            checked: SettingsService.barOpenOnHover
            onCheckedChanged: {
                SettingsService.barOpenOnHover = checked;
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

        Divider {
        }

        ThemedSlider {
            label: "Bar Thickness"
            from: 26
            to: 52
            stepSize: 1
            value: SettingsService.pillBarThickness
            suffix: "px"
            decimals: 0
            onMoved: (val) => {
                SettingsService.pillBarThickness = Math.round(val);
            }
        }

    }

    // BAR ICON (MATERIAL SHAPES & ANIMATIONS)
    AppGroup {
        title: "Bar Icon"
        icon: "sparkles"

        SettingSegmented {
            label: "Icon Mode"
            description: "Choose whether the bar icon stays on a single shape, cycles through Material shapes, or uses a custom SVG"
            model: [{
                "text": "Cycle Shapes",
                "value": "cycle"
            }, {
                "text": "Single Shape",
                "value": "single"
            }, {
                "text": "Custom SVG",
                "value": "custom"
            }]
            currentValue: SettingsService.barIconMode
            onActivated: (value) => {
                SettingsService.barIconMode = value;
            }
        }

        Divider {
            visible: SettingsService.barIconMode === "single"
        }

        SettingSegmented {
            visible: SettingsService.barIconMode === "single"
            label: "Active Shape"
            description: "Select which Material shape to display"
            model: [{
                "text": "Dashboard",
                "value": "dashboard"
            }, {
                "text": "Sparkle",
                "value": "sparkle"
            }, {
                "text": "Flower",
                "value": "flower"
            }, {
                "text": "Scallop",
                "value": "scallop"
            }, {
                "text": "Hexagon",
                "value": "hexagon"
            }, {
                "text": "Arch",
                "value": "arch"
            }]
            currentValue: SettingsService.barIconShape
            onActivated: (value) => {
                SettingsService.barIconShape = value;
            }
        }

        Divider {
            visible: SettingsService.barIconMode === "cycle"
        }

        ThemedSlider {
            visible: SettingsService.barIconMode === "cycle"
            label: "Cycle Interval"
            from: 3
            to: 60
            stepSize: 1
            value: SettingsService.barIconCycleInterval
            suffix: "s"
            decimals: 0
            onMoved: (val) => {
                SettingsService.barIconCycleInterval = Math.round(val);
            }
        }

        Divider {
            visible: SettingsService.barIconMode === "cycle"
        }

        ColumnLayout {
            visible: SettingsService.barIconMode === "cycle"
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                text: "Included Shapes in Rotation"
                customSize: Constants.sizeSm
                font.bold: true
            }

            ThemedText {
                text: "Select one or multiple Material 3 shapes to include in the automatic morph cycle"
                color: Theme.muted
                customSize: Constants.sizeXs + 2
            }

            Flow {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                Repeater {
                    model: [
                        { id: "dashboard", label: "Dashboard" },
                        { id: "sparkle", label: "Sparkle" },
                        { id: "flower", label: "Flower" },
                        { id: "scallop", label: "Scallop" },
                        { id: "hexagon", label: "Hexagon" },
                        { id: "arch", label: "Arch" },
                        { id: "gem", label: "Gem" }
                    ]

                    Rectangle {
                        readonly property bool isSelected: (SettingsService.barIconCycleShapes || []).indexOf(modelData.id) !== -1
                        implicitWidth: chipText.implicitWidth + Constants.sizeMd * 2
                        implicitHeight: 32
                        radius: 16
                        color: isSelected ? Theme.accent : Theme.bgSecondary
                        border.width: 1
                        border.color: isSelected ? Theme.accent : Theme.border

                        ThemedText {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: isSelected ? Theme.bg : Theme.fg
                            font.bold: isSelected
                            customSize: Constants.sizeSm
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let list = (SettingsService.barIconCycleShapes || []).slice();
                                let idx = list.indexOf(modelData.id);
                                if (idx !== -1) {
                                    if (list.length > 1) {
                                        list.splice(idx, 1);
                                    }
                                } else {
                                    list.push(modelData.id);
                                }
                                SettingsService.barIconCycleShapes = list;
                            }
                        }
                    }
                }
            }
        }

        Divider {
            visible: SettingsService.barIconMode === "custom"
        }

        ColumnLayout {
            visible: SettingsService.barIconMode === "custom"
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                text: "Custom SVG Path Data"
                customSize: Constants.sizeSm
                font.bold: true
            }

            ThemedText {
                text: "Paste an SVG path 'd' string (scaled to 24x24 viewBox)"
                color: Theme.muted
                customSize: Constants.sizeXs + 2
            }

            ThemedTextField {
                Layout.fillWidth: true
                placeholderText: "M 12 2 C 12 ... Z"
                text: SettingsService.barIconCustomSvg
                onEditingFinished: {
                    SettingsService.barIconCustomSvg = text.trim();
                }
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
