pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../bar" as Bar

Item {
    id: root

    // Active open popout: "" (none), "control_center", "wifi", "bluetooth", "audio_mixer", "session"
    property string activePopout: ""
    property var activeScreen: null

    function open(name) {
        root.activePopout = name
    }

    function close() {
        root.activePopout = ""
    }

    function toggle(name) {
        if (root.activePopout === name) {
            root.close()
        } else {
            root.open(name)
        }
    }

    function isOpen(name) {
        return root.activePopout === name
    }

    // ─── Screen Capture State & Controls ───
    property bool isRecording: false
    property int recordingDuration: 0

    function takeScreenshot(mode) {
        var m = mode || "fullscreen"
        var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/MediaCapture org.agility.Daemon.MediaCapture TakeScreenshot s \"" + m + "\" 2>/dev/null || " +
                  "mkdir -p ~/Pictures/Screenshots && grim ~/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png 2>/dev/null || true"
        runCmd(cmd)
    }

    function toggleScreenRecord() {
        if (root.isRecording) {
            runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/MediaCapture org.agility.Daemon.MediaCapture StopRecording 2>/dev/null || pkill -SIGINT wf-recorder 2>/dev/null || pkill -SIGINT wl-screenrec 2>/dev/null || true")
            root.isRecording = false
        } else {
            runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/MediaCapture org.agility.Daemon.MediaCapture StartRecording b true 2>/dev/null || " +
                   "mkdir -p ~/Videos/Recordings && wf-recorder -f ~/Videos/Recordings/recording_$(date +%Y%m%d_%H%M%S).mp4 >/dev/null 2>&1 &")
            root.isRecording = true
        }
    }

    // ─── Audio Microphone Controls ───
    function setMicVolume(val) {
        var clamped = Math.max(0.0, Math.min(1.0, val))
        Bar.BarDataService.micVolume = clamped
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Audio org.agility.Daemon.Audio SetMicVolume d " + clamped.toFixed(2) + " 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SOURCE@ " + clamped.toFixed(2) + " 2>/dev/null || true")
    }

    function toggleMicMute() {
        Bar.BarDataService.micMuted = !Bar.BarDataService.micMuted
        runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Audio org.agility.Daemon.Audio ToggleMicMute 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null || true")
    }

    // ─── Power & Session Controls ───
    function triggerSessionAction(action) {
        root.close()
        if (action === "lock") {
            Bar.BarDataService.lockSession()
        } else if (action === "suspend") {
            runCmd("systemctl suspend 2>/dev/null || true")
        } else if (action === "hibernate") {
            runCmd("systemctl hibernate 2>/dev/null || true")
        } else if (action === "reboot") {
            runCmd("systemctl reboot 2>/dev/null || true")
        } else if (action === "shutdown") {
            runCmd("systemctl poweroff 2>/dev/null || true")
        } else if (action === "logout") {
            runCmd("niri msg action quit --skip-confirmation 2>/dev/null || loginctl terminate-user $USER 2>/dev/null || true")
        }
    }

    // ─── WiFi Network Scan & Connections ───
    property var wifiNetworks: []
    property bool wifiScanning: false

    function scanWifi() {
        root.wifiScanning = true
        wifiScanProc.running = true
    }

    function connectWifi(ssid, password) {
        var cmd = "nmcli device wifi connect \"" + ssid + "\" " + (password ? ("password \"" + password + "\" ") : "") + "2>/dev/null"
        runCmd(cmd)
        scanWifi()
    }

    function disconnectWifi(ssid) {
        var cmd = "nmcli connection down \"" + ssid + "\" 2>/dev/null"
        runCmd(cmd)
        scanWifi()
    }

    Process {
        id: wifiScanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false
                try {
                    var lines = text.trim().split("\n")
                    var seen = {}
                    var nets = []
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].split(":")
                        if (parts.length >= 4) {
                            var ssid = parts[1].trim()
                            if (!ssid || seen[ssid]) continue
                            seen[ssid] = true
                            var inUse = parts[0].trim() === "*"
                            var sig = parseInt(parts[2].trim(), 10) || 0
                            var sec = parts[3].trim()
                            nets.push({
                                "inUse": inUse,
                                "ssid": ssid,
                                "signal": sig,
                                "security": sec,
                                "isSecure": sec !== "--" && sec !== ""
                            })
                        }
                    }
                    root.wifiNetworks = nets
                } catch (e) {}
            }
        }
    }

    // ─── Bluetooth Devices State & Controls ───
    property var bluetoothDevices: []
    property bool bluetoothScanning: false

    function scanBluetooth() {
        root.bluetoothScanning = true
        btScanProc.running = true
    }

    function connectBluetooth(address) {
        var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Connectivity org.agility.Daemon.Connectivity ConnectBluetoothDevice s \"" + address + "\" 2>/dev/null || bluetoothctl connect \"" + address + "\" 2>/dev/null || true"
        runCmd(cmd)
        scanBluetooth()
    }

    function disconnectBluetooth(address) {
        var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Connectivity org.agility.Daemon.Connectivity DisconnectBluetoothDevice s \"" + address + "\" 2>/dev/null || bluetoothctl disconnect \"" + address + "\" 2>/dev/null || true"
        runCmd(cmd)
        scanBluetooth()
    }

    Process {
        id: btScanProc
        command: ["bluetoothctl", "devices"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothScanning = false
                try {
                    var lines = text.trim().split("\n")
                    var devs = []
                    for (var i = 0; i < lines.length; i++) {
                        var parts = lines[i].trim().split(" ")
                        if (parts.length >= 3 && parts[0] === "Device") {
                            var addr = parts[1]
                            var name = parts.slice(2).join(" ")
                            devs.push({ "address": addr, "name": name, "connected": false })
                        }
                    }
                    root.bluetoothDevices = devs
                } catch (e) {}
            }
        }
    }

    // ─── Audio Sinks & Streams State ───
    property var audioSinks: []
    property var audioSources: []
    property var audioStreams: []

    function refreshAudioDevices() {
        audioQueryProc.running = true
    }

    function setDefaultSink(name) {
        runCmd("pactl set-default-sink \"" + name + "\" 2>/dev/null || true")
        refreshAudioDevices()
    }

    function setDefaultSource(name) {
        runCmd("pactl set-default-source \"" + name + "\" 2>/dev/null || true")
        refreshAudioDevices()
    }

    function setAppStreamVolume(sinkInputId, val) {
        var pct = Math.round(val * 100) + "%"
        runCmd("pactl set-sink-input-volume " + sinkInputId + " " + pct + " 2>/dev/null || true")
    }

    function toggleAppStreamMute(sinkInputId) {
        runCmd("pactl set-sink-input-mute " + sinkInputId + " toggle 2>/dev/null || true")
        refreshAudioDevices()
    }

    Process {
        id: audioQueryProc
        command: ["sh", "-c", "echo '===SINKS===' ; pactl list sinks short 2>/dev/null; echo '===SOURCES===' ; pactl list sources short 2>/dev/null; echo '===INPUTS===' ; pactl list sink-inputs 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var sinks = []
                    var sources = []
                    var streams = []

                    var parts = text.split("===SOURCES===")
                    var sinkSection = (parts[0] || "").replace("===SINKS===", "").trim()
                    var rest = parts[1] || ""
                    var restParts = rest.split("===INPUTS===")
                    var sourceSection = (restParts[0] || "").trim()
                    var inputSection = (restParts[1] || "").trim()

                    sinkSection.split("\n").forEach(function(l) {
                        var p = l.trim().split(/\s+/)
                        if (p.length >= 2) sinks.push({ "id": p[0], "name": p[1], "desc": p[1].replace("alsa_output.", "") })
                    })

                    sourceSection.split("\n").forEach(function(l) {
                        var p = l.trim().split(/\s+/)
                        if (p.length >= 2 && p[1].indexOf(".monitor") === -1) sources.push({ "id": p[0], "name": p[1], "desc": p[1].replace("alsa_input.", "") })
                    })

                    var curr = null
                    inputSection.split("\n").forEach(function(l) {
                        var s = l.trim()
                        if (s.startsWith("Sink Input #")) {
                            if (curr && curr.id) streams.push(curr)
                            curr = { "id": s.replace("Sink Input #", "").trim(), "name": "App", "volume": 1.0, "muted": false }
                        } else if (curr && s.indexOf("application.name = ") !== -1) {
                            curr.name = s.split("=")[1].trim().replace(/^["']|["']$/g, "")
                        } else if (curr && s.startsWith("Mute:")) {
                            curr.muted = s.toLowerCase().indexOf("yes") !== -1
                        }
                    })
                    if (curr && curr.id) streams.push(curr)

                    root.audioSinks = sinks
                    root.audioSources = sources
                    root.audioStreams = streams
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (root.activePopout === "wifi") {
                if (!wifiScanProc.running) wifiScanProc.running = true
            } else if (root.activePopout === "bluetooth") {
                if (!btScanProc.running) btScanProc.running = true
            } else if (root.activePopout === "audio_mixer") {
                if (!audioQueryProc.running) audioQueryProc.running = true
            }
        }
    }

    onActivePopoutChanged: {
        if (root.activePopout === "wifi") {
            scanWifi()
        } else if (root.activePopout === "bluetooth") {
            scanBluetooth()
        } else if (root.activePopout === "audio_mixer") {
            refreshAudioDevices()
        }
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
