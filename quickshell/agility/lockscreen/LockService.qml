pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Session lock state
    property bool isLocked: false
    property bool authenticating: false
    property bool isLockedOut: false
    property int failedAttempts: 0
    property real remainingLockoutSecs: 0.0
    property string errorMessage: ""

    // User profile information
    property string username: Quickshell.env("USER") ?? "user"
    property string userRealName: ""
    property string avatarPath: ""
    property string blurredWallpaperPath: ""

    // Host system info
    property string hostname: ""

    // Authentication Signals
    signal authFailed()
    signal authSuccess()
    signal lockRequested()

    // ─── Lock Session Action ───
    function lockSession() {
        root.isLocked = true
        root.errorMessage = ""
        root.fetchLockStatus()
        root.refreshUserInfo()

        // Call D-Bus LockSession to inform daemon and systemd logind
        lockDbusProc.command = ["busctl", "--user", "call", "org.agility.Daemon", "/org/agility/Daemon/Lock", "org.agility.Daemon.Lock", "LockSession"]
        lockDbusProc.running = true
    }

    // ─── Unlock Session Action ───
    function unlockSession() {
        root.isLocked = false
        root.errorMessage = ""
        root.authenticating = false
        root.failedAttempts = 0
        root.isLockedOut = false
        root.remainingLockoutSecs = 0.0
        root.authSuccess()
    }

    // ─── Authenticate via PAM Worker ───
    function authenticate(password) {
        if (root.authenticating || root.isLockedOut) return
        if (!password || password.length === 0) return

        root.authenticating = true
        root.errorMessage = ""

        authProc.currentPw = password
        authProc.command = [
            "busctl", "--user", "call",
            "org.agility.Daemon",
            "/org/agility/Daemon/Lock",
            "org.agility.Daemon.Lock",
            "Authenticate",
            "s", password
        ]
        authProc.running = true
    }

    // ─── Query Rate Limiting Status from Daemon ───
    function fetchLockStatus() {
        statusProc.command = [
            "busctl", "--user", "call",
            "org.agility.Daemon",
            "/org/agility/Daemon/Lock",
            "org.agility.Daemon.Lock",
            "GetStatus"
        ]
        statusProc.running = true
    }

    // ─── Refresh User Profile & Blurred Wallpaper ───
    function refreshUserInfo() {
        probeUserProc.running = true
    }

    // D-Bus LockSession Process
    Process {
        id: lockDbusProc
    }

    // PAM Authenticate Process
    Process {
        id: authProc
        property string currentPw: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim()
                authProc.currentPw = "" // volatile wipe in JS memory

                if (out.indexOf("b true") !== -1) {
                    root.unlockSession()
                } else {
                    root.authenticating = false
                    root.failedAttempts += 1
                    root.authFailed()
                    root.fetchLockStatus()

                    if (root.isLockedOut) {
                        root.errorMessage = "Too many attempts. Locked for " + Math.ceil(root.remainingLockoutSecs) + "s"
                    } else {
                        root.errorMessage = "Incorrect password"
                    }
                }
            }
        }

        onExited: function(exitCode) {
            authProc.currentPw = ""
            if (exitCode !== 0 && root.authenticating) {
                root.authenticating = false
                root.failedAttempts += 1
                root.authFailed()
                root.fetchLockStatus()
                if (root.errorMessage === "") {
                    root.errorMessage = "Authentication failed"
                }
            }
        }
    }

    // Status Query Process
    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Extract JSON string from busctl output: s "{...}"
                    var match = text.match(/s\s+"(.*)"/)
                    var jsonStr = match ? match[1].replace(/\\"/g, '"') : text.trim()
                    var status = JSON.parse(jsonStr)

                    if (status.is_locked_out !== undefined) root.isLockedOut = status.is_locked_out
                    if (status.failed_attempts !== undefined) root.failedAttempts = status.failed_attempts
                    if (status.remaining_lockout_secs !== undefined) root.remainingLockoutSecs = status.remaining_lockout_secs

                    if (root.isLockedOut && root.remainingLockoutSecs > 0) {
                        root.errorMessage = "Too many attempts. Locked for " + Math.ceil(root.remainingLockoutSecs) + "s"
                    }
                } catch (e) {
                    // Ignore parse error
                }
            }
        }
    }

    // User Avatar & Name Probe Process
    Process {
        id: probeUserProc
        command: [
            "python3", "-c",
            "import os, pwd, socket\n" +
            "u = os.environ.get('USER', 'user')\n" +
            "av = next((p for p in ['/var/lib/AccountsService/icons/' + u, os.path.expanduser('~/.face'), os.path.expanduser('~/.face.icon')] if os.path.isfile(p)), '')\n" +
            "rn = ''\n" +
            "try:\n" +
            "    rn = pwd.getpwnam(u).pw_gecos.split(',')[0]\n" +
            "except Exception:\n" +
            "    pass\n" +
            "bw = next((p for p in [os.path.expanduser('~/.cache/agility-shell/wallpaper_blurred'), os.path.expanduser('~/.cache/agility/wallpaper_blurred')] if os.path.isfile(p)), '')\n" +
            "hn = socket.gethostname()\n" +
            "print(av)\n" +
            "print(rn)\n" +
            "print(bw)\n" +
            "print(hn)\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split("\n")
                if (lines.length > 0 && lines[0].trim() !== "") root.avatarPath = lines[0].trim()
                if (lines.length > 1 && lines[1].trim() !== "") root.userRealName = lines[1].trim()
                if (lines.length > 2 && lines[2].trim() !== "") root.blurredWallpaperPath = lines[2].trim()
                if (lines.length > 3 && lines[3].trim() !== "") root.hostname = lines[3].trim()
            }
        }
    }

    // Rate Limit Countdown Timer
    Timer {
        interval: 1000
        running: root.isLocked && root.remainingLockoutSecs > 0
        repeat: true
        onTriggered: {
            root.remainingLockoutSecs = Math.max(0, root.remainingLockoutSecs - 1)
            if (root.remainingLockoutSecs === 0) {
                root.isLockedOut = false
                if (root.errorMessage.indexOf("Locked for") !== -1) {
                    root.errorMessage = ""
                }
            } else if (root.isLockedOut) {
                root.errorMessage = "Too many attempts. Locked for " + Math.ceil(root.remainingLockoutSecs) + "s"
            }
        }
    }

    // Background D-Bus Monitor for LockRequested signals
    Process {
        id: dbusSignalProc
        command: ["busctl", "--user", "monitor", "org.agility.Daemon"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("LockRequested") !== -1 || text.indexOf("lock_requested") !== -1) {
                    root.lockSession()
                }
            }
        }
    }

    Component.onCompleted: {
        root.refreshUserInfo()
        root.fetchLockStatus()
    }
}
