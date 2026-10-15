import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    readonly property string rawTitle: AppState.activeWindowTitle
    readonly property string rawClass: AppState.activeWindowClass
    readonly property bool hasWindow: SettingsService.appletActiveWindow && rawTitle !== ""
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    function resolveAppIcon(appId) {
        if (!appId)
            return "app-window-duotone";
        let lower = appId.toLowerCase();
        if (lower.includes("brave"))
            return "monitor-filled";
        if (lower.includes("firefox"))
            return "monitor";
        if (lower.includes("code") || lower.includes("nvim") || lower.includes("neovim"))
            return "code";
        if (lower.includes("terminal") || lower.includes("alacritty") || lower.includes("kitty") || lower.includes("foot"))
            return "terminal-window-duotone";
        if (lower.includes("spotify") || lower.includes("music") || lower.includes("cider"))
            return "music";
        if (lower.includes("files") || lower.includes("thunar") || lower.includes("nemo") || lower.includes("dolphin"))
            return "box";
        if (lower.includes("bubble"))
            return "sparkles";
        return "app-window-duotone";
    }

    function handlePrimaryClick() {
        if (SettingsService.appletActiveWindowAction === "switcher") {
            AppState.toggleWidget("launcher");
            return;
        }

        // Default: Maximize / Minimize toggle
        if (AppState.isNiri) {
            maximizeNiriProc.running = true;
        } else {
            Quickshell.exec(["hyprctl", "dispatch", "fullscreen", "1"]);
        }
    }

    Process {
        id: maximizeNiriProc
        command: ["niri", "msg", "action", "maximize-column"]
    }

    implicitHeight: SettingsService.barWidgetHeight
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    implicitWidth: hasWindow ? Math.min(220, contentRow.implicitWidth + Constants.sizeSm * 2) : 0
    width: implicitWidth
    opacity: hasWindow ? 1 : 0
    visible: hasWindow || opacity > 0.001
    clip: true

    radius: height / 2
    color: isHovered ? Theme.bgSecondary : "transparent"
    border.color: isHovered ? Theme.borderSecondary : "transparent"
    border.width: 1
    scale: isPressed ? 0.96 : (isHovered ? 1.02 : 1)

    Behavior on width {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Constants.animFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                AppState.toggleWidget("launcher");
            } else {
                root.handlePrimaryClick();
            }
        }

        onDoubleClicked: {
            AppState.toggleWidget("launcher");
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Constants.size2Xs

        SvgIcon {
            icon: root.resolveAppIcon(root.rawClass)
            iconSize: 14
            flat: true
            iconColor: root.isHovered ? Theme.accent : Theme.fg
            Layout.alignment: Qt.AlignVCenter

            Behavior on iconColor {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }

        ThemedText {
            text: {
                let t = root.rawTitle.trim();
                let c = root.rawClass.trim();
                if (c !== "" && !t.toLowerCase().startsWith(c.toLowerCase())) {
                    let shortClass = c.split('.').pop();
                    return "[" + shortClass + "] " + t;
                }
                return t;
            }
            customSize: 11
            font.weight: Font.Medium
            color: root.isHovered ? Theme.fg : Theme.muted
            elide: Text.ElideRight
            Layout.maximumWidth: 160
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }
    }
}
