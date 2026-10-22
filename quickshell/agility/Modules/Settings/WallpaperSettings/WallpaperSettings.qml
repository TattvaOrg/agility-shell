import "Components"
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
    id: wallpaperRoot

    Process {
        id: folderPickerProc

        command: ["sh", "-c", "zenity --file-selection --directory --title='Select Wallpapers Folder' 2>/dev/null || true"]
        onExited: function(exitCode) {
            let path = pickerOutput.text.trim();
            if (path && path !== "") {
                HyprlandService.wpCustomFolderPath = path;
                SettingsService.saveSettings();
                WallpaperManager.reloadWallpaperList();
            }
        }

        stdout: StdioCollector {
            id: pickerOutput
        }
    }

    AppGroup {
        title: "Wallpaper Source & Library"
        icon: "folder"

        SettingSegmented {
            label: "Wallpaper Source"
            description: "Choose whether to use system default wallpapers or a custom folder"
            model: [{
                "text": "Default",
                "value": "default"
            }, {
                "text": "Custom Folder",
                "value": "custom"
            }]
            currentValue: HyprlandService.wpSourceMode
            onActivated: (val) => {
                HyprlandService.wpSourceMode = val;
                SettingsService.saveSettings();
                WallpaperManager.reloadWallpaperList();
            }
        }

        ColumnLayout {
            spacing: Constants.sizeSm
            Layout.fillWidth: true
            visible: HyprlandService.wpSourceMode === "custom"

            RowLayout {
                spacing: Constants.sizeSm
                Layout.fillWidth: true

                ThemedTextField {
                    id: customFolderInput

                    Layout.fillWidth: true
                    label: "Folder Path"
                    placeholderText: "Path to wallpapers folder (e.g. ~/Pictures/Wallpapers)"
                    text: HyprlandService.wpCustomFolderPath
                    onEditingFinished: {
                        if (text.trim() !== HyprlandService.wpCustomFolderPath) {
                            HyprlandService.wpCustomFolderPath = text.trim();
                            SettingsService.saveSettings();
                            WallpaperManager.reloadWallpaperList();
                        }
                    }
                }

                SvgIconButton {
                    Layout.alignment: Qt.AlignBottom
                    icon: "folder"
                    textIcon: "Browse"
                    textIconSize: Constants.sizeSm
                    useCustomWidth: true
                    onClicked: {
                        folderPickerProc.running = false;
                        folderPickerProc.running = true;
                    }
                }
            }

            ThemedText {
                text: {
                    if (WallpaperManager.wallpaperListCount > 0)
                        return WallpaperManager.wallpaperListCount + " wallpapers loaded from active folder";
                    if (!HyprlandService.wpCustomFolderPath)
                        return "Please select or type a folder path";
                    return "No image files (.png, .jpg, .webp, .gif) found in this folder";
                }
                color: WallpaperManager.wallpaperListCount > 0 ? Theme.accent : Theme.muted
                customSize: Constants.sizeSm
            }
        }
    }

    AppGroup {
        title: "Screen Framing & Cropping"
        icon: "picture-spark"
        showDividers: false

        WallpaperCropPreview {
            Layout.fillWidth: true
        }

        SettingSegmented {
            label: "Scaling Mode"
            description: "How wallpapers adapt across different aspect ratios"
            model: [{
                "text": "Crop (Fill)",
                "value": "crop"
            }, {
                "text": "Fit",
                "value": "fit"
            }, {
                "text": "Stretch",
                "value": "stretch"
            }]
            currentValue: HyprlandService.wpResizeMode
            onActivated: (val) => {
                HyprlandService.wpResizeMode = val;
            }
        }

    }

    AppGroup {
        title: "Automation & Transitions"
        icon: "sparkles"

        SettingToggle {
            id: clicksToggle

            label: "Desktop Double-Click (clicks)"
            description: "Double-click anywhere on the empty desktop to switch wallpaper"
            onCheckedChanged: {
                if (checked !== HyprlandService.wpClicksEnabled) {
                    HyprlandService.wpClicksEnabled = checked;
                    SettingsService.saveSettings();
                }
            }

            Binding {
                target: clicksToggle
                property: "checked"
                value: HyprlandService.wpClicksEnabled
            }
        }

        SettingToggle {
            id: autoShuffleToggle

            label: "Auto-shuffle Wallpapers"
            onCheckedChanged: {
                if (checked !== HyprlandService.wpAutoShuffle)
                    HyprlandService.wpAutoShuffle = checked;

            }

            Binding {
                target: autoShuffleToggle
                property: "checked"
                value: HyprlandService.wpAutoShuffle
            }

        }

        SettingSpinBox {
            enabled: HyprlandService.wpAutoShuffle
            opacity: enabled ? 1 : 0.5
            label: "Shuffle Interval"
            from: 1
            to: 60
            stepSize: 1
            value: HyprlandService.wpShuffleInterval
            suffix: " min"
            decimals: 0
            onMoved: (val) => {
                HyprlandService.wpShuffleInterval = Math.round(val);
            }
        }

        ThemedSelect {
            label: "Transition Type"
            model: ["none", "grow", "outer", "center", "fade", "wipe", "wave", "random"]
            currentIndex: {
                if (!HyprlandService.wpEnableTransitions)
                    return 0;

                let idx = model.indexOf(HyprlandService.wpTransitionType);
                return idx !== -1 ? idx : 1;
            }
            onActivated: (index) => {
                let val = model[index];
                if (val === "none") {
                    HyprlandService.wpEnableTransitions = false;
                } else {
                    HyprlandService.wpEnableTransitions = true;
                    HyprlandService.wpTransitionType = val;
                }
            }
        }

        ThemedSelect {
            label: "Transition Position"
            model: ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"]
            currentIndex: {
                let idx = model.indexOf(HyprlandService.wpTransitionPos);
                return idx !== -1 ? idx : 4;
            }
            onActivated: (index) => {
                HyprlandService.wpTransitionPos = model[index];
            }
            enabled: HyprlandService.wpEnableTransitions && HyprlandService.wpTransitionType !== "random"
            opacity: enabled ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                }

            }

        }

        ColumnLayout {
            spacing: Constants.sizeLg
            Layout.fillWidth: true
            enabled: HyprlandService.wpEnableTransitions
            opacity: enabled ? 1 : 0.4

            SettingSegmented {
                label: "Transition Speed"
                model: [{
                    "text": "Slow",
                    "value": 60
                }, {
                    "text": "Normal",
                    "value": 120
                }, {
                    "text": "Fast",
                    "value": 180
                }, {
                    "text": "Ultra",
                    "value": 240
                }]
                currentValue: HyprlandService.wpTransitionStep
                onActivated: (val) => {
                    HyprlandService.wpTransitionStep = val;
                }
            }

            Divider {
            }

            SettingSegmented {
                label: "Transition Frame Rate"
                model: [{
                    "text": "30",
                    "value": 30
                }, {
                    "text": "60",
                    "value": 60
                }, {
                    "text": "120",
                    "value": 120
                }, {
                    "text": "144",
                    "value": 144
                }]
                currentValue: HyprlandService.wpTransitionFps
                onActivated: (val) => {
                    HyprlandService.wpTransitionFps = val;
                }
            }

            Divider {
                visible: HyprlandService.wpTransitionType === "wipe" || HyprlandService.wpTransitionType === "wave"
            }

            ThemedSlider {
                label: "Transition Angle"
                from: 0
                to: 360
                stepSize: 10
                value: HyprlandService.wpTransitionAngle
                suffix: "°"
                decimals: 0
                visible: HyprlandService.wpTransitionType === "wipe" || HyprlandService.wpTransitionType === "wave"
                onMoved: (val) => {
                    HyprlandService.wpTransitionAngle = Math.round(val);
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Constants.animFast
                }

            }

        }

    }

}
