pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components" as Components

Item {
    id: root

    // Workspaces state
    property int activeWorkspaceIdx: 0
    property string activeWorkspaceName: "1"
    property var workspacesList: [
        {"idx": 0, "name": "1", "is_active": true, "window_count": 1},
        {"idx": 1, "name": "2", "is_active": false, "window_count": 0},
        {"idx": 2, "name": "3", "is_active": false, "window_count": 0}
    ]
    property string activeWindowTitle: ""
    property string activeWindowAppId: ""
    property string keyboardLayout: "US"

    // Hardware & Telemetry
    property real cpuUsage: 5.0
    property real memoryUsage: 25.0
    property real batteryPercent: 85.0
    property bool batteryCharging: false

    // Audio & Volume
    property real volume: 0.65
    property bool volumeMuted: false
    property real micVolume: 0.80
    property bool micMuted: false

    // Brightness
    property real brightness: 0.80

    // Connectivity
    property bool wifiConnected: true
    property string wifiSsid: "Agility-WiFi"
    property int wifiSignal: 85
    property bool bluetoothConnected: false
    property int bluetoothDeviceCount: 0

    // Media
    property string mediaPlaybackStatus: "Stopped" // "Playing", "Paused", "Stopped"
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool mediaPlaying: mediaPlaybackStatus === "Playing"
    property string mediaArtUrl: ""
    property real mediaPositionRatio: 0.0
    property string mediaPositionFormatted: "00:00"
    property string mediaLengthFormatted: "00:00"

    // Power & Toggles
    property bool caffeineActive: false
    property string powerProfile: "balanced"
    property bool nightLightActive: false
    property int nightLightTemp: 4000

    // Notifications
    property int unreadNotifications: 0
    property bool dndEnabled: false

    // Desktop Suite
    property string activeSuiteName: "Default"
    property string activeSuiteId: "default"

    // System Tray
    property var trayItems: []

    // ─── Actions Dispatching to agilityd D-Bus ───
    function switchWorkspace(idx) {
        root.activeWorkspaceIdx = idx
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Workspaces org.agility.Daemon.Workspaces SwitchWorkspace u " + idx + " 2>/dev/null || true")
    }

    function setVolume(val) {
        var clamped = Math.max(0.0, Math.min(1.5, val))
        root.volume = clamped
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Audio org.agility.Daemon.Audio SetVolume d " + clamped.toFixed(2) + " 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ " + clamped.toFixed(2) + " 2>/dev/null || true")
    }

    function toggleVolumeMute() {
        root.volumeMuted = !root.volumeMuted
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Audio org.agility.Daemon.Audio SetMuted b " + (root.volumeMuted ? "true" : "false") + " 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || true")
    }

    function setBrightness(val) {
        var clamped = Math.max(0.05, Math.min(1.0, val))
        root.brightness = clamped
        runCmd("brightnessctl set " + Math.round(clamped * 100) + "% 2>/dev/null || true")
    }

    function toggleMediaPlayPause() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Media org.agility.Daemon.Media PlayPause 2>/dev/null || playerctl play-pause 2>/dev/null || true")
    }

    function mediaNext() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Media org.agility.Daemon.Media Next 2>/dev/null || playerctl next 2>/dev/null || true")
    }

    function mediaPrevious() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Media org.agility.Daemon.Media Previous 2>/dev/null || playerctl previous 2>/dev/null || true")
    }

    function mediaToggleShuffle() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Media org.agility.Daemon.Media Shuffle 2>/dev/null || playerctl shuffle toggle 2>/dev/null || true")
    }

    function mediaCycleLoop() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Media org.agility.Daemon.Media Loop 2>/dev/null || playerctl loop Track 2>/dev/null || true")
    }

    function seekMediaRatio(ratio) {
        var clamped = Math.max(0.0, Math.min(1.0, ratio))
        root.mediaPositionRatio = clamped
        runCmd("playerctl position $(echo \"$clamped * $(playerctl metadata mpris:length 2>/dev/null || echo 0) / 1000000\" | bc 2>/dev/null) 2>/dev/null || true")
    }

    function toggleCaffeine() {
        root.caffeineActive = !root.caffeineActive
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Power org.agility.Daemon.Power ToggleCaffeine 2>/dev/null || true")
    }

    function toggleNightLight() {
        root.nightLightActive = !root.nightLightActive
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Power org.agility.Daemon.Power ToggleNightLight 2>/dev/null || true")
    }

    function cyclePowerProfile() {
        var next = root.powerProfile === "power-saver" ? "balanced" : (root.powerProfile === "balanced" ? "performance" : "power-saver")
        root.powerProfile = next
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Power org.agility.Daemon.Power SetPowerProfile s \"" + next + "\" 2>/dev/null || powerprofilesctl set " + next + " 2>/dev/null || true")
    }

    function nextSuite() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Suits org.agility.Daemon.Suits NextSuite 2>/dev/null || true")
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Notifications org.agility.Daemon.Notifications ToggleDnd 2>/dev/null || true")
    }

    function lockSession() {
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Lock org.agility.Daemon.Lock LockSession 2>/dev/null || loginctl lock-session 2>/dev/null || true")
    }

    // ─── Asynchronous Poller Querying agilityd ───
    Process {
        id: pollProc
        command: ["agl", "bar-data"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    if (d.workspaces) root.workspacesList = d.workspaces
                    if (d.active_ws_idx !== undefined) root.activeWorkspaceIdx = d.active_ws_idx
                    if (d.win_title !== undefined) root.activeWindowTitle = d.win_title
                    if (d.win_app !== undefined) root.activeWindowAppId = d.win_app
                    if (d.cpu !== undefined) root.cpuUsage = d.cpu
                    if (d.mem !== undefined) root.memoryUsage = d.mem

                    if (d.bat !== undefined) {
                        var prevBat = root.batteryPercent
                        root.batteryPercent = d.bat
                        if (d.bat <= 10 && prevBat > 10) {
                            Components.SoundService.play("battery-low")
                        } else if (d.bat <= 20 && prevBat > 20) {
                            Components.SoundService.play("battery-warning")
                        }
                    }
                    if (d.bat_chg !== undefined) {
                        var prevChg = root.batteryCharging
                        root.batteryCharging = d.bat_chg
                        if (d.bat_chg && !prevChg) {
                            Components.SoundService.play("battery-charge")
                        }
                    }

                    if (d.vol !== undefined) root.volume = d.vol
                    if (d.muted !== undefined) root.volumeMuted = d.muted
                    if (d.wifi !== undefined) root.wifiConnected = d.wifi
                    if (d.wifi_ssid !== undefined) root.wifiSsid = d.wifi_ssid
                    if (d.wifi_sig !== undefined) root.wifiSignal = d.wifi_sig
                    if (d.bt !== undefined) root.bluetoothConnected = d.bt
                    if (d.bt_count !== undefined) root.bluetoothDeviceCount = d.bt_count
                    if (d.media_status !== undefined) root.mediaPlaybackStatus = d.media_status
                    if (d.media_title !== undefined) root.mediaTitle = d.media_title
                    if (d.media_artist !== undefined) root.mediaArtist = d.media_artist
                    if (d.caffeine !== undefined) root.caffeineActive = d.caffeine
                    if (d.night_light !== undefined) root.nightLightActive = d.night_light
                    if (d.power_profile !== undefined) root.powerProfile = d.power_profile
                    if (d.suite_name !== undefined) root.activeSuiteName = d.suite_name
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            if (!pollProc.running) {
                pollProc.running = true
            }
        }
    }

    Component.onCompleted: {
        pollProc.running = true
    }

    Process {
        id: execProc
        running: false
    }

    function runCmd(cmd) {
        execProc.command = ["sh", "-c", cmd]
        execProc.running = true
    }
}
