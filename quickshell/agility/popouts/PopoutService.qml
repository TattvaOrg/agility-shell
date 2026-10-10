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
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import subprocess, json\n" +
            "try:\n" +
            "    r = subprocess.run([\"nmcli\", \"-t\", \"-f\", \"IN-USE,SSID,SIGNAL,SECURITY\", \"device\", \"wifi\", \"list\"], capture_output=True, text=True, timeout=3.0)\n" +
            "    lines = r.stdout.strip().splitlines()\n" +
            "    seen = set()\n" +
            "    nets = []\n" +
            "    for line in lines:\n" +
            "        parts = line.split(\":\")\n" +
            "        if len(parts) >= 4:\n" +
            "            in_use = parts[0].strip() == \"*\"\n" +
            "            ssid = parts[1].strip()\n" +
            "            if not ssid or ssid in seen: continue\n" +
            "            seen.add(ssid)\n" +
            "            sig = int(parts[2].strip() or 0)\n" +
            "            sec = parts[3].strip()\n" +
            "            nets.append({\"inUse\": in_use, \"ssid\": ssid, \"signal\": sig, \"security\": sec, \"isSecure\": sec != \"--\" and sec != \"\"})\n" +
            "    print(json.dumps(nets))\n" +
            "except Exception: print(\"[]\")\n" +
            "'\n"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiScanning = false
                try {
                    var parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.wifiNetworks = parsed
                    }
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
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import subprocess, json\n" +
            "try:\n" +
            "    r = subprocess.run([\"bluetoothctl\", \"devices\"], capture_output=True, text=True, timeout=2.0)\n" +
            "    lines = r.stdout.strip().splitlines()\n" +
            "    devs = []\n" +
            "    for line in lines:\n" +
            "        parts = line.split(maxsplit=2)\n" +
            "        if len(parts) >= 3 and parts[0] == \"Device\":\n" +
            "            addr = parts[1]\n" +
            "            name = parts[2]\n" +
            "            devs.append({\"address\": addr, \"name\": name, \"connected\": False})\n" +
            "    print(json.dumps(devs))\n" +
            "except Exception: print(\"[]\")\n" +
            "'\n"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.bluetoothScanning = false
                try {
                    var parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.bluetoothDevices = parsed
                    }
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
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import subprocess, json\n" +
            "out = {\"sinks\": [], \"sources\": [], \"streams\": []}\n" +
            "try:\n" +
            "    r = subprocess.run([\"pactl\", \"list\", \"sinks\", \"short\"], capture_output=True, text=True, timeout=1.0)\n" +
            "    if r.returncode == 0:\n" +
            "        for l in r.stdout.strip().splitlines():\n" +
            "            p = l.split()\n" +
            "            if len(p) >= 2: out[\"sinks\"].append({\"id\": p[0], \"name\": p[1], \"desc\": p[1].replace(\"alsa_output.\", \"\")})\n" +
            "    r2 = subprocess.run([\"pactl\", \"list\", \"sources\", \"short\"], capture_output=True, text=True, timeout=1.0)\n" +
            "    if r2.returncode == 0:\n" +
            "        for l in r2.stdout.strip().splitlines():\n" +
            "            p = l.split()\n" +
            "            if len(p) >= 2 and \".monitor\" not in p[1]: out[\"sources\"].append({\"id\": p[0], \"name\": p[1], \"desc\": p[1].replace(\"alsa_input.\", \"\")})\n" +
            "    r3 = subprocess.run([\"pactl\", \"list\", \"sink-inputs\"], capture_output=True, text=True, timeout=1.0)\n" +
            "    if r3.returncode == 0:\n" +
            "        curr = {}\n" +
            "        for line in r3.stdout.splitlines():\n" +
            "            s = line.strip()\n" +
            "            if s.startswith(\"Sink Input #\"):\n" +
            "                if curr.get(\"id\"): out[\"streams\"].append(curr)\n" +
            "                curr = {\"id\": s.replace(\"Sink Input #\", \"\"), \"name\": \"App\", \"volume\": 1.0, \"muted\": False}\n" +
            "            elif \"application.name = \" in s:\n" +
            "                curr[\"name\"] = s.split(\"=\")[1].strip(\" \\\"\\'\")\n" +
            "            elif s.startswith(\"Mute:\"):\n" +
            "                curr[\"muted\"] = \"yes\" in s.lower()\n" +
            "        if curr.get(\"id\"): out[\"streams\"].append(curr)\n" +
            "    print(json.dumps(out))\n" +
            "except Exception: print(json.dumps(out))\n" +
            "'\n"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data.sinks) root.audioSinks = data.sinks
                    if (data.sources) root.audioSources = data.sources
                    if (data.streams) root.audioStreams = data.streams
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
