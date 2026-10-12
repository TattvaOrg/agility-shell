pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../bar" as Bar

Item {
    id: root

    // ─── Toasts & Drawer State ───
    property var activeToasts: []
    property var historyItems: []
    property int unreadCount: 0
    property bool dndEnabled: false
    property bool drawerOpen: false

    // Path to notification chime
    readonly property string soundPath: {
        var base = Qt.resolvedUrl("../../../sounds/notification.wav").toString()
        if (base.startsWith("file://")) return base.slice(7)
        return "/home/cachy/github-p/github-based/agility-shell/sounds/notification.wav"
    }

    // ─── Drawer Controls ───
    function openDrawer() {
        root.drawerOpen = true
        refreshHistory()
    }

    function closeDrawer() {
        root.drawerOpen = false
    }

    function toggleDrawer() {
        if (root.drawerOpen) {
            root.closeDrawer()
        } else {
            root.openDrawer()
        }
    }

    function toggleDnd() {
        root.dndEnabled = !root.dndEnabled
        Bar.BarDataService.dndEnabled = root.dndEnabled
        runCmd("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications ToggleDnd 2>/dev/null || true")
    }

    // ─── Toast Management ───
    function addToast(item) {
        if (root.dndEnabled) return

        var toastId = item.id || Math.floor(Math.random() * 100000)
        var duration = item.expire_timeout_ms || 5000
        if (duration <= 0) duration = 5000

        var toast = {
            id: toastId,
            appName: item.app_name || "System",
            appIcon: item.app_icon || "notification",
            summary: item.summary || "",
            body: item.body || "",
            actions: item.actions || [],
            urgency: item.urgency || 1,
            timestamp: item.timestamp || Date.now(),
            durationMs: duration,
            progress: 1.0,
            xOffset: 0,
            opacity: 1.0,
            isDismissing: false
        }

        // Add to active toasts (limit to 5 max)
        var current = root.activeToasts.slice()
        // Deduplicate if already present
        current = current.filter(function(t) { return t.id !== toastId })
        current.unshift(toast)
        if (current.length > 5) {
            current = current.slice(0, 5)
        }
        root.activeToasts = current

        // Play chime sound
        playSound()

        // Also refresh history
        refreshHistory()
    }

    function dismissToast(id) {
        var current = root.activeToasts.slice()
        root.activeToasts = current.filter(function(t) { return t.id !== id })
    }

    function invokeAction(id, actionKey) {
        var cleanKey = actionKey.replace(/"/g, "\\\"")
        runCmd("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications InvokeAction us \"" + id + "\" \"" + cleanKey + "\" 2>/dev/null || true")
        dismissToast(id)
        refreshHistory()
    }

    function dismissFromHistory(id) {
        runCmd("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications DismissNotification u \"" + id + "\" 2>/dev/null || true")
        var current = root.historyItems.slice()
        root.historyItems = current.filter(function(n) { return n.id !== id })
        root.unreadCount = Math.max(0, root.historyItems.length)
        Bar.BarDataService.unreadNotifications = root.unreadCount
    }

    function clearAllHistory() {
        runCmd("busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications ClearHistory 2>/dev/null || true")
        root.historyItems = []
        root.unreadCount = 0
        Bar.BarDataService.unreadNotifications = 0
    }

    function playSound() {
        var cmd = "pw-play \"" + root.soundPath + "\" 2>/dev/null || paplay \"" + root.soundPath + "\" 2>/dev/null || aplay \"" + root.soundPath + "\" 2>/dev/null || true"
        runCmd(cmd)
    }

    // ─── Query History from agilityd / Freedesktop Service ───
    Process {
        id: historyProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        // Detect newly arrived notifications to spawn toast banners
                        if (parsed.length > 0 && root.historyItems.length > 0 && parsed.length > root.historyItems.length) {
                            var newest = parsed[0]
                            if (newest && (!root.activeToasts.length || root.activeToasts[0].id !== newest.id)) {
                                root.addToast(newest)
                            }
                        }
                        root.historyItems = parsed
                        root.unreadCount = parsed.length
                        Bar.BarDataService.unreadNotifications = parsed.length
                    }
                } catch (e) {}
            }
        }
    }

    function refreshHistory() {
        if (!historyProc.running) {
            var cmd = "busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications GetHistory 2>/dev/null || " +
                      "python3 -c '\n" +
                      "import subprocess, json\n" +
                      "try:\n" +
                      "    r = subprocess.run([\"busctl\", \"--user\", \"call\", \"org.freedesktop.Notifications\", \"/org/freedesktop/Notifications\", \"org.freedesktop.Notifications\", \"GetHistory\"], capture_output=True, text=True, timeout=0.5)\n" +
                      "    if r.returncode == 0:\n" +
                      "        parts = r.stdout.strip().split(maxsplit=2)\n" +
                      "        if len(parts) >= 3: print(json.loads(parts[2]))\n" +
                      "except Exception: pass\n" +
                      "' 2>/dev/null || true"

            historyProc.command = ["sh", "-c", cmd]
            historyProc.running = true
        }
    }

    // Periodic history poll & sync (1500ms)
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            root.refreshHistory()
        }
    }

    // ─── Command Execution Runner ───
    Process {
        id: execProc
        running: false
    }

    function runCmd(cmd) {
        execProc.command = ["sh", "-c", cmd]
        execProc.running = true
    }

    Component.onCompleted: {
        root.refreshHistory()
    }
}
