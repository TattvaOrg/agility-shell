import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: dockSettingsRoot

    ColumnLayout {
        width: parent.width
        spacing: Constants.sizeLg

        // ─────────────────────────────────────────────
        // 1. FLOATING DOCK CONFIGURATION
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "FLOATING DOCK"

            SettingToggle {
                labelText: "Enable Dynamic Dock"
                descriptionText: "Show a floating macOS / iPadOS-style app dock with smooth magnification"
                iconName: "apps"
                checked: SettingsService.dockEnabled
                onToggled: function(val) {
                    SettingsService.dockEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingSegmented {
                labelText: "Dock Screen Edge Position"
                descriptionText: "Pin the dock along the bottom, left, or right display boundary"
                iconName: "layout"
                options: ["Bottom", "Left", "Right"]
                currentIndex: {
                    if (SettingsService.dockPosition === "left") return 1;
                    if (SettingsService.dockPosition === "right") return 2;
                    return 0;
                }
                onIndexSelected: function(idx) {
                    let pos = "bottom";
                    if (idx === 1) pos = "left";
                    if (idx === 2) pos = "right";
                    SettingsService.dockPosition = pos;
                    SettingsService.saveSettings();
                }
            }

            SettingToggle {
                labelText: "Auto-Hide Dock"
                descriptionText: "Hide dock when idle and smoothly reveal when hovering screen edge"
                iconName: "eye"
                checked: SettingsService.dockAutoHide
                onToggled: function(val) {
                    SettingsService.dockAutoHide = val;
                    SettingsService.saveSettings();
                }
            }

            SettingToggle {
                labelText: "Dynamic Magnification Zoom"
                descriptionText: "Magnify hovered app icon and neighboring icons using parabolic physics"
                iconName: "sparkles"
                checked: SettingsService.dockMagnification
                onToggled: function(val) {
                    SettingsService.dockMagnification = val;
                    SettingsService.saveSettings();
                }
            }

            SettingSegmented {
                labelText: "Base Icon Size"
                descriptionText: "Standard size for application icons resting in the dock"
                iconName: "settings"
                options: ["36px", "44px", "48px", "56px"]
                currentIndex: {
                    if (SettingsService.dockIconSize === 36) return 0;
                    if (SettingsService.dockIconSize === 44) return 1;
                    if (SettingsService.dockIconSize === 56) return 3;
                    return 2; // 48px
                }
                onIndexSelected: function(idx) {
                    let sizes = [36, 44, 48, 56];
                    SettingsService.dockIconSize = sizes[idx];
                    SettingsService.saveSettings();
                }
            }
        }

        // ─────────────────────────────────────────────
        // 2. RAYCAST / SPOTLIGHT OMNI-LAUNCHER
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "OMNI SPOTLIGHT LAUNCHER"

            SettingToggle {
                labelText: "Enable Omni-Launcher (Mod + K)"
                descriptionText: "Raycast-style unified omni bar for math, apps, window switching, and web"
                iconName: "search"
                checked: SettingsService.omniLauncherEnabled
                onToggled: function(val) {
                    SettingsService.omniLauncherEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingRowTemplate {
                labelText: "Open Omni-Launcher"
                descriptionText: "Trigger the omni search modal now to test searches and actions"
                iconName: "command"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: omniBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: omniBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: omniBtnText
                        anchors.centerIn: parent
                        text: "Launch (Mod+K)"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.DemiBold
                        color: omniBtnHover.containsMouse ? Theme.bg : Theme.text
                    }

                    MouseArea {
                        id: omniBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("omni")
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 3. DYNAMIC ISLAND / LIVE ACTIVITIES HUB
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "DYNAMIC ISLAND & LIVE ACTIVITIES"

            SettingToggle {
                labelText: "Enable Dynamic Island Capsule"
                descriptionText: "Expanding floating capsule at top center for live music, timer, and toasts"
                iconName: "music"
                checked: SettingsService.dynamicIslandEnabled
                onToggled: function(val) {
                    SettingsService.dynamicIslandEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            // Overview Info Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: islandInfoCol.implicitHeight + 24
                radius: Constants.sizeLg
                color: Qt.rgba(0.1, 0.1, 0.15, 0.4)
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: islandInfoCol
                    anchors.fill: parent
                    anchors.margins: Constants.sizeMd
                    spacing: 8

                    Text {
                        text: "Included Live Activities:"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    Text {
                        text: "• Rotating vinyl & audio wave bars for active MPRIS music playback\n• Expandable mini-player on click with scrub bar and media controls\n• Live countdown timer and circular progress ring when Focus Timer is running\n• Animated toast capsule whenever text is copied to clipboard\n• Low battery (< 15%) flashing warning badge"
                        font.pixelSize: Constants.fontSizeSm
                        color: Theme.textSecondary
                        lineHeight: 1.3
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 4. MISSION CONTROL / VISUAL WORKSPACE OVERVIEW
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "MISSION CONTROL & WORKSPACE OVERVIEW"

            SettingToggle {
                labelText: "Enable Mission Control (Mod + Tab)"
                descriptionText: "Fullscreen visual overview of all workspaces and open windows"
                iconName: "window"
                checked: SettingsService.missionControlEnabled
                onToggled: function(val) {
                    SettingsService.missionControlEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingRowTemplate {
                labelText: "Open Mission Control"
                descriptionText: "View all occupied workspaces, filter windows, and switch between them"
                iconName: "layout"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: mcBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: mcBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: mcBtnText
                        anchors.centerIn: parent
                        text: "Launch (Mod+Tab)"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.DemiBold
                        color: mcBtnHover.containsMouse ? Theme.bg : Theme.text
                    }

                    MouseArea {
                        id: mcBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("missioncontrol")
                    }
                }
            }
        }
    }
}
