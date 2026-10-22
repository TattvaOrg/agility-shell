pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services

Item {
    id: root

    property var _lastPlayed: ({})
    property int _procIdx: 0

    // Pool of static Process runners for zero-latency, concurrent audio playback
    Process { id: p0 }
    Process { id: p1 }
    Process { id: p2 }
    Process { id: p3 }

    readonly property var _procs: [p0, p1, p2, p3]

    function play(soundName, minIntervalMs = 60) {
        if (!soundName || !SettingsService.soundEffectsEnabled)
            return;

        let now = Date.now();
        if (_lastPlayed[soundName] && (now - _lastPlayed[soundName]) < minIntervalMs)
            return;
        _lastPlayed[soundName] = now;

        let soundFile = soundName + ".wav";
        let proc = _procs[_procIdx % _procs.length];
        _procIdx++;

        proc.command = [
            "sh", "-c",
            "for p in \"$HOME/.config/agility-shell/sounds/" + soundFile + "\" \"/usr/share/agility-shell/sounds/" + soundFile + "\" \"" + Quickshell.shellDir + "/../../sounds/" + soundFile + "\"; do " +
            "  if [ -f \"$p\" ]; then " +
            "    if command -v pw-play >/dev/null 2>&1; then exec pw-play \"$p\"; " +
            "    elif command -v paplay >/dev/null 2>&1; then exec paplay \"$p\"; " +
            "    elif command -v aplay >/dev/null 2>&1; then exec aplay -q \"$p\"; fi; " +
            "    break; " +
            "  fi; " +
            "done; " +
            "if command -v agl >/dev/null 2>&1; then exec agl sound play " + soundName + " >/dev/null 2>&1; fi"
        ];
        proc.running = false;
        proc.running = true;
    }
}
