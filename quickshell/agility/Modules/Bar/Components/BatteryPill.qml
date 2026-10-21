import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    readonly property bool isCharging: SystemInfoService.batteryStatus === "Charging"
    readonly property int level: SystemInfoService.batteryLevel
    readonly property bool hasBattery: SystemInfoService.hasBattery
    readonly property bool isVisible: SettingsService.appletBattery && hasBattery
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    function getBatteryIcon() {
        if (root.isCharging)
            return "battery-charging-duotone";
        if (root.level >= 80)
            return "battery-full-duotone";
        if (root.level >= 50)
            return "battery-high-duotone";
        if (root.level >= 20)
            return "battery-medium-duotone";
        return "battery-low-duotone";
    }

    implicitHeight: SettingsService.barWidgetHeight
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    implicitWidth: isVisible ? (contentRow.implicitWidth + Constants.sizeSm * 2) : 0
    width: implicitWidth
    opacity: isVisible ? 1 : 0
    visible: isVisible || opacity > 0.001
    clip: true

    radius: height / 2
    color: isHovered ? Theme.barBgSecondary : (isCharging ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : "transparent")
    border.color: isCharging ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : (isHovered ? Theme.barBorder : "transparent")
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

    // Charging Pulse Glow Animation
    SequentialAnimation on opacity {
        running: root.isCharging && root.isVisible
        loops: Animation.Infinite

        NumberAnimation {
            from: 1.0
            to: 0.65
            duration: 1000
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 0.65
            to: 1.0
            duration: 1000
            easing.type: Easing.InOutSine
        }
    }

    Timer {
        id: hoverTimer

        interval: 160
        repeat: false
        onTriggered: {
            if (SettingsService.barOpenOnHover && root.isHovered && !AppState.isWidgetOpen("controlCenter")) {
                AppState.openWidget("controlCenter");
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (SettingsService.barOpenOnHover)
                hoverTimer.restart();
        }
        onExited: {
            hoverTimer.stop();
        }
        onClicked: {
            hoverTimer.stop();
            AppState.toggleWidget("controlCenter");
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Constants.size2Xs

        SvgIcon {
            icon: root.getBatteryIcon()
            iconSize: 14
            flat: true
            iconColor: {
                if (root.isCharging)
                    return Theme.isLightBar ? Theme.barFg : Theme.accent;
                if (root.level <= 15)
                    return Theme.error;
                if (root.level <= 30)
                    return Theme.warning;
                return root.isHovered ? Theme.barFg : Theme.barMuted;
            }
            Layout.alignment: Qt.AlignVCenter

            Behavior on iconColor {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }

        ThemedText {
            text: {
                let txt = root.level + "%";
                if (SettingsService.appletBatteryShowTime && SystemInfoService.batteryEstimation !== "") {
                    let est = SystemInfoService.batteryEstimation.trim();
                    if (est !== "" && est !== "Unknown" && est !== "Estimating...") {
                        txt += " • " + est;
                    }
                }
                return txt;
            }
            customSize: 11
            font.weight: Font.Medium
            color: root.isHovered ? Theme.barFg : Theme.barMuted
            Layout.alignment: Qt.AlignVCenter

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }
    }
}
