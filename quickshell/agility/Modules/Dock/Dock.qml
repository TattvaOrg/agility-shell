import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockPanel
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: SettingsService.dockAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
            color: "transparent"
            focusable: false
            visible: SettingsService.settingsLoaded && SettingsService.dockEnabled && !DisplayProfileService.gameModeActive

            readonly property bool isBottom: SettingsService.dockPosition === "bottom" || SettingsService.dockPosition === ""
            readonly property bool isLeft: SettingsService.dockPosition === "left"
            readonly property bool isRight: SettingsService.dockPosition === "right"

            anchors {
                bottom: dockPanel.isBottom
                left: dockPanel.isLeft
                right: dockPanel.isRight
            }

            implicitWidth: dockPanel.isBottom ? dockStrip.width + 40 : (dockStrip.width + 20)
            implicitHeight: dockPanel.isBottom ? (dockStrip.height + 24) : (dockStrip.height + 40)

            property bool isHovered: dockMouseArea.containsMouse || edgeTriggerArea.containsMouse
            property real hideOffset: (SettingsService.dockAutoHide && !dockPanel.isHovered) ? (dockPanel.isBottom ? 70 : (dockPanel.isLeft ? -70 : 70)) : 0

            Behavior on hideOffset {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            // Screen edge trigger zone for auto-hide
            MouseArea {
                id: edgeTriggerArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                z: 0
            }

            // Floating Capsule Container
            Rectangle {
                id: dockStrip
                anchors.centerIn: parent
                z: 1

                transform: Translate {
                    y: dockPanel.isBottom ? dockPanel.hideOffset : 0
                    x: !dockPanel.isBottom ? dockPanel.hideOffset : 0
                }

                width: dockPanel.isBottom ? (dockContentRow.implicitWidth + 24) : (SettingsService.dockIconSize + 24)
                height: dockPanel.isBottom ? (SettingsService.dockIconSize + 22) : (dockContentCol.implicitHeight + 24)
                radius: dockPanel.isBottom ? (height / 2) : (width / 2)

                color: Theme.isDark ? Qt.rgba(0.06, 0.07, 0.10, 0.88) : Qt.rgba(0.96, 0.96, 0.98, 0.90)
                border.width: 1
                border.color: Theme.border

                // Ambient Drop Shadow
                ThemedShadow {
                    anchors.fill: parent
                    radius: parent.radius
                    elevation: 16
                    opacity: 0.5
                }

                // Mouse interaction area for magnification
                MouseArea {
                    id: dockMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                // Horizontal Layout (Bottom Dock)
                Row {
                    id: dockContentRow
                    visible: dockPanel.isBottom
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: dockAppList

                        Item {
                            id: itemWrapper
                            width: iconBox.width
                            height: iconBox.height

                            // Magnification math
                            property real cursorDist: {
                                if (!dockMouseArea.containsMouse || !SettingsService.dockMagnification) return 999;
                                let itemGlobalCenter = itemWrapper.x + (itemWrapper.width / 2);
                                return Math.abs(dockMouseArea.mouseX - 12 - itemGlobalCenter);
                            }
                            property real magScale: {
                                if (cursorDist > 90) return 1.0;
                                let ratio = Math.cos((cursorDist / 90) * (Math.PI / 2));
                                return 1.0 + (0.35 * ratio);
                            }

                            Behavior on magScale {
                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                            }

                            Rectangle {
                                id: iconBox
                                width: Math.round(SettingsService.dockIconSize * itemWrapper.magScale)
                                height: Math.round(SettingsService.dockIconSize * itemWrapper.magScale)
                                radius: width / 2
                                color: itemHover.hovered ? Theme.bgSecondary : "transparent"
                                anchors.bottom: parent.bottom

                                HoverHandler { id: itemHover }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: modelData.icon
                                    iconSize: Math.round((SettingsService.dockIconSize - 16) * itemWrapper.magScale)
                                    iconColor: itemHover.hovered ? Theme.accent : Theme.fg
                                    flat: true
                                }

                                // Running Dot Indicator
                                Rectangle {
                                    visible: modelData.isRunning
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.accent
                                }

                                // Tooltip popup
                                Rectangle {
                                    visible: itemHover.hovered
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 8
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: tooltipText.implicitWidth + 14
                                    height: 22
                                    radius: 6
                                    color: Theme.isDark ? "#12151D" : "#FFFFFF"
                                    border.width: 1
                                    border.color: Theme.border
                                    z: 99

                                    ThemedText {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        customSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SoundService.play("click");
                                        root.triggerAction(modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // Vertical Layout (Left/Right Dock)
                Column {
                    id: dockContentCol
                    visible: !dockPanel.isBottom
                    anchors.centerIn: parent
                    spacing: 8

                    Repeater {
                        model: dockAppList

                        Item {
                            id: colItemWrapper
                            width: colIconBox.width
                            height: colIconBox.height

                            property real cursorDist: {
                                if (!dockMouseArea.containsMouse || !SettingsService.dockMagnification) return 999;
                                let itemGlobalCenter = colItemWrapper.y + (colItemWrapper.height / 2);
                                return Math.abs(dockMouseArea.mouseY - 12 - itemGlobalCenter);
                            }
                            property real magScale: {
                                if (cursorDist > 90) return 1.0;
                                let ratio = Math.cos((cursorDist / 90) * (Math.PI / 2));
                                return 1.0 + (0.35 * ratio);
                            }

                            Behavior on magScale {
                                NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                            }

                            Rectangle {
                                id: colIconBox
                                width: Math.round(SettingsService.dockIconSize * colItemWrapper.magScale)
                                height: Math.round(SettingsService.dockIconSize * colItemWrapper.magScale)
                                radius: width / 2
                                color: colItemHover.hovered ? Theme.bgSecondary : "transparent"
                                anchors.centerIn: parent

                                HoverHandler { id: colItemHover }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: modelData.icon
                                    iconSize: Math.round((SettingsService.dockIconSize - 16) * colItemWrapper.magScale)
                                    iconColor: colItemHover.hovered ? Theme.accent : Theme.fg
                                    flat: true
                                }

                                Rectangle {
                                    visible: modelData.isRunning
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: dockPanel.isLeft ? parent.left : undefined
                                    anchors.left: dockPanel.isRight ? parent.right : undefined
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: Theme.accent
                                }

                                Rectangle {
                                    visible: colItemHover.hovered
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: dockPanel.isLeft ? parent.right : undefined
                                    anchors.right: dockPanel.isRight ? parent.left : undefined
                                    anchors.margins: 8
                                    width: colTooltipText.implicitWidth + 14
                                    height: 22
                                    radius: 6
                                    color: Theme.isDark ? "#12151D" : "#FFFFFF"
                                    border.width: 1
                                    border.color: Theme.border
                                    z: 99

                                    ThemedText {
                                        id: colTooltipText
                                        anchors.centerIn: parent
                                        text: modelData.name
                                        customSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SoundService.play("click");
                                        root.triggerAction(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Process executor for launching commands
    Process {
        id: execProc
    }

    function triggerAction(item) {
        if (!item) return;
        if (item.actionType === "toggle") {
            AppState.toggleWidget(item.target);
        } else if (item.actionType === "exec") {
            execProc.command = ["agl", "launch-exec", item.target];
            execProc.startDetached();
        } else if (item.actionType === "overview") {
            AppState.toggleWidget("missioncontrol");
        }
    }

    // Default Dock App Registry
    readonly property var dockAppList: [
        { id: "launcher",   name: "Applications",   icon: "apps",          actionType: "toggle",   target: "launcher",       isRunning: AppState.isWidgetOpen("launcher") },
        { id: "omni",       name: "Omni Command Bar", icon: "search",      actionType: "toggle",   target: "omni",           isRunning: AppState.isWidgetOpen("omni") },
        { id: "overview",   name: "Mission Control", icon: "window",       actionType: "overview", target: "missioncontrol", isRunning: AppState.isWidgetOpen("missioncontrol") },
        { id: "terminal",   name: "Terminal",       icon: "code",          actionType: "exec",     target: "x-terminal-emulator", isRunning: false },
        { id: "files",      name: "File Manager",   icon: "box",           actionType: "exec",     target: "xdg-open ~",     isRunning: false },
        { id: "browser",    name: "Web Browser",    icon: "rocket",        actionType: "exec",     target: "xdg-open https://", isRunning: false },
        { id: "music",      name: "Music Player",   icon: "music",         actionType: "toggle",   target: "music",          isRunning: MprisService.isPlaying },
        { id: "widgets",    name: "Desktop Widgets", icon: "widgets",      actionType: "toggle",   target: "desktopwidgets", isRunning: SettingsService.desktopWidgetsEnabled },
        { id: "settings",   name: "Settings",       icon: "settings-icon", actionType: "toggle",   target: "minflair_settings", isRunning: AppState.isWidgetOpen("minflair_settings") },
        { id: "trash",      name: "Trash",          icon: "trash",         actionType: "exec",     target: "xdg-open trash:///", isRunning: false }
    ]
}
