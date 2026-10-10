pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pinnedEntries: [
        { "id": "thunar", "name": "Files", "appId": "thunar", "icon": "files", "exec": "thunar" },
        { "id": "firefox", "name": "Browser", "appId": "firefox", "icon": "firefox", "exec": "firefox" },
        { "id": "kitty", "name": "Terminal", "appId": "kitty", "icon": "terminal", "exec": "kitty" },
        { "id": "code", "name": "Code", "appId": "code", "icon": "code", "exec": "code" },
        { "id": "discord", "name": "Discord", "appId": "discord", "icon": "discord", "exec": "discord" },
        { "id": "spotify", "name": "Spotify", "appId": "spotify", "icon": "spotify", "exec": "spotify" }
    ]

    property var runningWindows: [] // array of { id, appId, title, isFocused }
    property string activeAppId: ""
    property bool autohide: false

    function isRunning(appId) {
        if (!appId || appId === "") return false
        var target = appId.toLowerCase()
        for (var i = 0; i < root.runningWindows.length; i++) {
            var w = root.runningWindows[i]
            if (w.appId && w.appId.toLowerCase().includes(target)) return true
        }
        return false
    }

    function isFocused(appId) {
        if (!appId || appId === "") return false
        var target = appId.toLowerCase()
        for (var i = 0; i < root.runningWindows.length; i++) {
            var w = root.runningWindows[i]
            if (w.isFocused && w.appId && w.appId.toLowerCase().includes(target)) return true
        }
        return false
    }

    function isPinned(appId) {
        if (!appId) return false
        var target = appId.toLowerCase()
        for (var i = 0; i < root.pinnedEntries.length; i++) {
            if (root.pinnedEntries[i].appId.toLowerCase() === target) return true
        }
        return false
    }

    // Merged items list: pinned apps + any running unpinned apps
    readonly property var allDockItems: {
        var list = root.pinnedEntries.slice()
        for (var i = 0; i < root.runningWindows.length; i++) {
            var w = root.runningWindows[i]
            if (!w.appId || isPinned(w.appId)) continue

            // Check if already added to running list
            var alreadyAdded = false
            for (var j = root.pinnedEntries.length; j < list.length; j++) {
                if (list[j].appId.toLowerCase() === w.appId.toLowerCase()) {
                    alreadyAdded = true
                    break
                }
            }
            if (!alreadyAdded) {
                list.push({
                    "id": w.appId,
                    "name": w.title || w.appId,
                    "appId": w.appId,
                    "icon": w.appId,
                    "exec": w.appId,
                    "isDynamic": true
                })
            }
        }
        return list
    }

    function launchApp(exec, appId) {
        if (!exec && !appId) return
        var cmd = "gtk-launch " + appId + " 2>/dev/null || " + exec + " >/dev/null 2>&1 &"
        runCmd(cmd)
    }

    function closeApp(appId) {
        runCmd("niri msg action close-window 2>/dev/null || true")
    }

    function togglePin(appId, name, exec, icon) {
        var exists = false
        var newList = []
        for (var i = 0; i < root.pinnedEntries.length; i++) {
            if (root.pinnedEntries[i].appId.toLowerCase() === appId.toLowerCase()) {
                exists = true
            } else {
                newList.push(root.pinnedEntries[i])
            }
        }
        if (!exists) {
            newList.push({
                "id": appId,
                "name": name || appId,
                "appId": appId,
                "icon": icon || appId,
                "exec": exec || appId
            })
        }
        root.pinnedEntries = newList
        savePinnedEntries()
    }

    function savePinnedEntries() {
        var jsonStr = JSON.stringify(root.pinnedEntries).replace(/'/g, "'\\''")
        var shCmd = "mkdir -p ~/.config/agility-shell && " +
            "if [ -f ~/.config/agility-shell/config.json ]; then " +
            "  jq '.dock.entries = " + JSON.stringify(root.pinnedEntries) + "' ~/.config/agility-shell/config.json > ~/.config/agility-shell/config.json.tmp && " +
            "  mv ~/.config/agility-shell/config.json.tmp ~/.config/agility-shell/config.json; " +
            "else " +
            "  echo '{\"dock\": {\"entries\": " + JSON.stringify(root.pinnedEntries) + "}}' > ~/.config/agility-shell/config.json; " +
            "fi"
        runCmd(shCmd)
    }

    Process {
        id: loadDockConfigProc
        command: ["sh", "-c", "cat ~/.config/agility-shell/config.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    if (data && data.dock) {
                        if (Array.isArray(data.dock.entries) && data.dock.entries.length > 0) {
                            root.pinnedEntries = data.dock.entries
                        }
                        if (data.dock.autohide !== undefined) {
                            root.autohide = data.dock.autohide
                        }
                    }
                } catch (e) {}
            }
        }
    }

    // ─── Query Niri & Windows ───
    Process {
        id: niriQueryProc
        command: [
            "sh", "-c",
            "python3 -c '\n" +
            "import subprocess, json\n" +
            "try:\n" +
            "    r = subprocess.run([\"niri\", \"msg\", \"-j\", \"windows\"], capture_output=True, text=True, timeout=0.3)\n" +
            "    if r.returncode == 0:\n" +
            "        wins = json.loads(r.stdout)\n" +
            "        out = [{\"id\": w.get(\"id\"), \"appId\": w.get(\"app_id\", \"\"), \"title\": w.get(\"title\", \"\"), \"isFocused\": w.get(\"is_focused\", False)} for w in wins]\n" +
            "        print(json.dumps(out))\n" +
            "    else: print(\"[]\")\n" +
            "except Exception: print(\"[]\")\n" +
            "'\n"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.runningWindows = parsed
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!niriQueryProc.running) {
                niriQueryProc.running = true
            }
        }
    }

    Component.onCompleted: {
        loadDockConfigProc.running = true
        niriQueryProc.running = true
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
