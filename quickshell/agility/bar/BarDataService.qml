pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import subprocess, json\n" +
            "def call_dbus(prop, iface, path):\n" +
            "    try:\n" +
            "        r = subprocess.run([\"busctl\", \"--user\", \"get-property\", \"org.agility.Daemon\", path, iface, prop], capture_output=True, text=True, timeout=0.4)\n" +
            "        if r.returncode == 0:\n" +
            "            parts = r.stdout.strip().split(maxsplit=1)\n" +
            "            return parts[1].strip(\"\\\"\\'\") if len(parts) > 1 else parts[0]\n" +
            "    except Exception: pass\n" +
            "    return None\n" +
            "\n" +
            "out = {}\n" +
            "w = call_dbus(\"workspaces\", \"org.agility.Daemon.Workspaces\", \"/org/agility/Daemon/Workspaces\")\n" +
            "if w: out[\"workspaces\"] = json.loads(w)\n" +
            "out[\"active_ws_idx\"] = int(call_dbus(\"active_workspace_idx\", \"org.agility.Daemon.Workspaces\", \"/org/agility/Daemon/Workspaces\") or 0)\n" +
            "out[\"win_title\"] = call_dbus(\"active_window_title\", \"org.agility.Daemon.Workspaces\", \"/org/agility/Daemon/Workspaces\") or \"\"\n" +
            "out[\"win_app\"] = call_dbus(\"active_window_app_id\", \"org.agility.Daemon.Workspaces\", \"/org/agility/Daemon/Workspaces\") or \"\"\n" +
            "out[\"cpu\"] = float(call_dbus(\"cpu_usage\", \"org.agility.Daemon.Hardware\", \"/org/agility/Daemon/Hardware\") or 5.0)\n" +
            "out[\"mem\"] = float(call_dbus(\"memory_usage\", \"org.agility.Daemon.Hardware\", \"/org/agility/Daemon/Hardware\") or 25.0)\n" +
            "out[\"bat\"] = float(call_dbus(\"battery_percent\", \"org.agility.Daemon.Hardware\", \"/org/agility/Daemon/Hardware\") or 100.0)\n" +
            "out[\"bat_chg\"] = (call_dbus(\"battery_charging\", \"org.agility.Daemon.Hardware\", \"/org/agility/Daemon/Hardware\") or \"false\") == \"true\"\n" +
            "out[\"vol\"] = float(call_dbus(\"volume\", \"org.agility.Daemon.Audio\", \"/org/agility/Daemon/Audio\") or 0.65)\n" +
            "out[\"muted\"] = (call_dbus(\"muted\", \"org.agility.Daemon.Audio\", \"/org/agility/Daemon/Audio\") or \"false\") == \"true\"\n" +
            "out[\"wifi\"] = (call_dbus(\"wifi_connected\", \"org.agility.Daemon.Connectivity\", \"/org/agility/Daemon/Connectivity\") or \"true\") == \"true\"\n" +
            "out[\"wifi_ssid\"] = call_dbus(\"wifi_ssid\", \"org.agility.Daemon.Connectivity\", \"/org/agility/Daemon/Connectivity\") or \"WiFi\"\n" +
            "out[\"wifi_sig\"] = int(call_dbus(\"wifi_signal\", \"org.agility.Daemon.Connectivity\", \"/org/agility/Daemon/Connectivity\") or 80)\n" +
            "out[\"bt\"] = (call_dbus(\"bluetooth_connected\", \"org.agility.Daemon.Connectivity\", \"/org/agility/Daemon/Connectivity\") or \"false\") == \"true\"\n" +
            "out[\"bt_count\"] = int(call_dbus(\"bluetooth_device_count\", \"org.agility.Daemon.Connectivity\", \"/org/agility/Daemon/Connectivity\") or 0)\n" +
            "out[\"media_status\"] = call_dbus(\"playback_status\", \"org.agility.Daemon.Media\", \"/org/agility/Daemon/Media\") or \"Stopped\"\n" +
            "out[\"media_title\"] = call_dbus(\"title\", \"org.agility.Daemon.Media\", \"/org/agility/Daemon/Media\") or \"\"\n" +
            "out[\"media_artist\"] = call_dbus(\"artist\", \"org.agility.Daemon.Media\", \"/org/agility/Daemon/Media\") or \"\"\n" +
            "out[\"caffeine\"] = (call_dbus(\"caffeine_active\", \"org.agility.Daemon.Power\", \"/org/agility/Daemon/Power\") or \"false\") == \"true\"\n" +
            "out[\"night_light\"] = (call_dbus(\"night_light_active\", \"org.agility.Daemon.Power\", \"/org/agility/Daemon/Power\") or \"false\") == \"true\"\n" +
            "out[\"power_profile\"] = call_dbus(\"power_profile\", \"org.agility.Daemon.Power\", \"/org/agility/Daemon/Power\") or \"balanced\"\n" +
            "out[\"suite_name\"] = call_dbus(\"active_suite_name\", \"org.agility.Daemon.Suits\", \"/org/agility/Daemon/Suits\") or \"Default\"\n" +
            "print(json.dumps(out))\n" +
            "'\n"
        ]
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
                    if (d.bat !== undefined) root.batteryPercent = d.bat
                    if (d.bat_chg !== undefined) root.batteryCharging = d.bat_chg
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
