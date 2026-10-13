pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string soundsDir: {
        var resolved = Qt.resolvedUrl("../../../sounds").toString()
        if (resolved.startsWith("file://")) return resolved.slice(7)
        return "/usr/share/agility-shell/sounds"
    }

    function play(soundName) {
        if (!soundName) return
        var busCmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Sounds org.agility.Daemon.Sounds Play s \"" + soundName + "\" 2>/dev/null"
        var fallbackWav = root.soundsDir + "/" + soundName + ".wav"
        var playerCmd = "pw-play \"" + fallbackWav + "\" 2>/dev/null || paplay \"" + fallbackWav + "\" 2>/dev/null || aplay \"" + fallbackWav + "\" 2>/dev/null || true"
        runCmd(busCmd + " || " + playerCmd)
    }

    function runCmd(cmd) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process { running: false }', root, "SoundProc")
        proc.command = ["sh", "-c", cmd]
        proc.onExited.connect(function() {
            proc.destroy()
        })
        proc.running = true
    }
}
