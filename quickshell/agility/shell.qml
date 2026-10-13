import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "bar" as Bar
import "dock" as Dock
import "popouts" as Popouts
import "launcher" as Launcher
import "osd" as Osd
import "notifications" as Notifications
import "canvas" as Canvas
import "lockscreen" as Lockscreen
import "components" as Components

ShellRoot {
    IpcHandler {
        target: "suits"
        function reload() {
            Theme.reloadSettings()
        }
    }

    IpcHandler {
        target: "canvas"
        function toggleEdit() {
            Canvas.CanvasService.toggleEditMode()
        }
        function editMode() {
            Canvas.CanvasService.toggleEditMode()
        }
    }

    IpcHandler {
        target: "applets-edit"
        function toggle() {
            Canvas.CanvasService.toggleEditMode()
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            Launcher.LauncherService.toggle()
        }
        function open() {
            Launcher.LauncherService.open()
        }
        function close() {
            Launcher.LauncherService.close()
        }
    }

    IpcHandler {
        target: "dash"
        function toggle() {
            Launcher.LauncherService.toggle()
        }
        function open() {
            Launcher.LauncherService.open()
        }
        function close() {
            Launcher.LauncherService.close()
        }
    }

    IpcHandler {
        target: "osd"
        function volume(val: real) {
            Osd.OsdService.triggerVolume(val)
        }
        function brightness(val: real) {
            Osd.OsdService.triggerBrightness(val)
        }
        function keyboard(layout: string) {
            Osd.OsdService.triggerKeyboard(layout)
        }
        function power(profile: string) {
            Osd.OsdService.triggerPower(profile)
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle() {
            Notifications.NotificationService.toggleDrawer()
        }
        function open() {
            Notifications.NotificationService.openDrawer()
        }
        function close() {
            Notifications.NotificationService.closeDrawer()
        }
        function clear() {
            Notifications.NotificationService.clearAllHistory()
        }
    }

    IpcHandler {
        target: "lock"
        function lock() {
            Lockscreen.LockService.lockSession()
        }
        function unlock() {
            Lockscreen.LockService.unlockSession()
        }
    }

    IpcHandler {
        target: "melt"
        function trigger(duration: real, cols: int) {
            Lockscreen.DoomMeltService.triggerMelt("", duration, cols, [])
        }
    }

    IpcHandler {
        target: "sounds"
        function play(sound: string) {
            Components.SoundService.play(sound)
        }
    }

    Component.onCompleted: {
        Components.SoundService.play("session-start")
    }

    // Top Multi-Monitor Status Bar
    Variants {
        model: Quickshell.screens
        Bar.BarWindow {
            property var modelData
            screenModel: modelData
        }
    }

    // Island Popout Applets & Control Center
    Variants {
        model: Quickshell.screens
        Popouts.PopoutWindow {
            property var modelData
            screenModel: modelData
        }
    }

    // Bottom Floating Application Dock
    Variants {
        model: Quickshell.screens
        Dock.DockWindow {
            property var modelData
            screenModel: modelData
        }
    }

    // Centered Modal Application Launcher Dash
    Variants {
        model: Quickshell.screens
        Launcher.LauncherWindow {
            property var modelData
            screenModel: modelData
        }
    }

    // Floating On-Screen Display (OSD) Overlays
    Variants {
        model: Quickshell.screens
        Osd.OsdWindow {
            property var modelData
            screenModel: modelData
        }
    }

    // Floating Notification Toasts Overlay
    Variants {
        model: Quickshell.screens
        Notifications.NotificationToasts {
            property var modelData
            screenModel: modelData
        }
    }

    // Slide-in Notification History Drawer
    Variants {
        model: Quickshell.screens
        Notifications.NotificationDrawer {
            property var modelData
            screenModel: modelData
        }
    }

    // Multi-Monitor Desktop Background Canvas (WlrLayer.Bottom)
    Variants {
        model: Quickshell.screens
        Canvas.DesktopCanvas {
            property var modelData
            screenModel: modelData
        }
    }

    // Interactive Desktop Applets Edit Mode (WlrLayer.Top)
    Variants {
        model: Quickshell.screens
        Canvas.DesktopEditMode {
            property var modelData
            screenModel: modelData
        }
    }

    // Exclusive Wayland Session Lock Screen (ext-session-lock-v1)
    Lockscreen.LockWindow {}

    // Multi-Monitor Doom Vertical Melt Screen Transition Overlay
    Variants {
        model: Quickshell.screens
        Lockscreen.DoomMeltOverlay {
            property var modelData
            screenModel: modelData
        }
    }
}
