pragma Singleton
import QtQuick
import "../bar" as Bar

Item {
    id: root

    // ─── OSD Display State ───
    property bool isShowing: false
    visible: isShowing
    property string osdType: "volume" // "volume", "brightness", "keyboard", "power"
    property string icon: "speaker-high"
    property string label: "Volume"
    property string valueText: "65%"
    property real gaugeLevel: 0.65
    property bool showGauge: true
    property bool isMuted: false

    // Cold-boot suppression to prevent OSD popup on initial startup
    property bool isReady: false

    Timer {
        id: startupTimer
        interval: 2200
        running: true
        repeat: false
        onTriggered: {
            root.isReady = true
        }
    }

    // ─── Auto-Dismiss Timer (1500ms) ───
    Timer {
        id: dismissTimer
        interval: 1500
        repeat: false
        onTriggered: {
            root.isShowing = false
        }
    }

    function showOsd(type, iconName, labelName, text, level, gauge, muted) {
        root.osdType = type
        root.icon = iconName
        root.label = labelName
        root.valueText = text
        root.gaugeLevel = Math.max(0.0, level)
        root.showGauge = gauge
        root.isMuted = !!muted
        root.isShowing = true

        dismissTimer.restart()
    }

    // ─── Trigger Functions ───
    function triggerVolume(vol, muted) {
        var v = (vol !== undefined) ? vol : Bar.BarDataService.volume
        var m = (muted !== undefined) ? muted : Bar.BarDataService.volumeMuted
        var percent = Math.round(v * 100)
        var iconName = m ? "speaker-slash" : (v <= 0.01 ? "speaker-simple-none" : (v < 0.5 ? "speaker-low" : "speaker-high"))
        var labelStr = m ? "Muted" : (percent > 100 ? "Boosted Volume" : "Volume")
        var valStr = m ? "Mute" : (percent + "%")

        showOsd("volume", iconName, labelStr, valStr, v, true, m)
    }

    function triggerBrightness(b) {
        var val = (b !== undefined) ? b : Bar.BarDataService.brightness
        var percent = Math.round(val * 100)
        var iconName = "sun"

        showOsd("brightness", iconName, "Brightness", percent + "%", val, true, false)
    }

    function triggerKeyboard(layout) {
        var name = (layout !== undefined && layout !== "") ? layout : Bar.BarDataService.keyboardLayout
        showOsd("keyboard", "keyboard", "Keyboard Layout", name.toUpperCase(), 1.0, false, false)
    }

    function triggerPower(profile) {
        var p = (profile !== undefined && profile !== "") ? profile : Bar.BarDataService.powerProfile
        var iconName = (p === "performance") ? "rocket" : (p === "power-saver" ? "leaf" : "speedometer")
        var formatted = p.charAt(0).toUpperCase() + p.slice(1).replace("-", " ")

        showOsd("power", iconName, "Power Profile", formatted, 1.0, false, false)
    }

    function trigger(type, val, text) {
        if (type === "volume") triggerVolume(val)
        else if (type === "brightness") triggerBrightness(val)
        else if (type === "keyboard") triggerKeyboard(text)
        else if (type === "power") triggerPower(text)
    }

    // ─── Reactive Listeners to BarDataService ───
    Connections {
        target: Bar.BarDataService

        function onVolumeChanged() {
            if (root.isReady) {
                root.triggerVolume(Bar.BarDataService.volume, Bar.BarDataService.volumeMuted)
            }
        }

        function onVolumeMutedChanged() {
            if (root.isReady) {
                root.triggerVolume(Bar.BarDataService.volume, Bar.BarDataService.volumeMuted)
            }
        }

        function onBrightnessChanged() {
            if (root.isReady) {
                root.triggerBrightness(Bar.BarDataService.brightness)
            }
        }

        function onKeyboardLayoutChanged() {
            if (root.isReady) {
                root.triggerKeyboard(Bar.BarDataService.keyboardLayout)
            }
        }

        function onPowerProfileChanged() {
            if (root.isReady) {
                root.triggerPower(Bar.BarDataService.powerProfile)
            }
        }
    }
}
