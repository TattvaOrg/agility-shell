import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.DesktopCanvas.Widgets

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    focusable: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: SettingsService.settingsLoaded && SettingsService.systemTheme === "material"

    opacity: visible ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: MaterialTheme.animDurationNormal
            easing.type: Easing.OutCubic
        }
    }

    // Top Bar Margin based on preset
    readonly property int topBarMargin: SettingsService.desktopPreset === "bottom_waffle" ? 24 : 64
    readonly property int bottomBarMargin: SettingsService.desktopPreset === "bottom_waffle" ? 72 : 24

    // Left Column Widgets (Clock & Media)
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 36
        anchors.top: parent.top
        anchors.topMargin: root.topBarMargin
        spacing: 20

        MaterialClockWidget {
            id: clockWidget
            visible: SettingsService.widgetClockEnabled
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }

        MaterialMediaWidget {
            id: mediaWidget
            visible: SettingsService.widgetMediaEnabled
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }
    }

    // Right Column Widgets (System Resources & Quick Note)
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 36
        anchors.top: parent.top
        anchors.topMargin: root.topBarMargin
        spacing: 20

        MaterialSystemResourcesWidget {
            id: resourcesWidget
            visible: SettingsService.widgetResourcesEnabled
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }

        MaterialNoteWidget {
            id: noteWidget
            visible: SettingsService.widgetNoteEnabled
            opacity: visible ? 1.0 : 0.0
            scale: visible ? 1.0 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250 } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        }
    }
}
