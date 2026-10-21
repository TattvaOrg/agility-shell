pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services

Item {
    id: root

    property var _lastPlayed: ({})

    function play(soundName, minIntervalMs = 70) {
        if (!SettingsService.soundEffectsEnabled)
            return;

        let now = Date.now();
        if (_lastPlayed[soundName] && (now - _lastPlayed[soundName]) < minIntervalMs)
            return;
        _lastPlayed[soundName] = now;

        let proc = soundComp.createObject(root, {
            "soundName": soundName
        });
        if (proc) {
            proc.running = true;
        }
    }

    Component {
        id: soundComp

        Process {
            id: procItem
            property string soundName: ""

            command: [
                "sh", "-c",
                "if command -v agl >/dev/null 2>&1; then agl sound play " + soundName + "; elif command -v pw-play >/dev/null 2>&1; then for d in ~/.config/agility-shell/sounds /usr/share/agility-shell/sounds ./sounds; do [ -f \"$d/" + soundName + ".wav\" ] && exec pw-play \"$d/" + soundName + ".wav\"; done; elif command -v paplay >/dev/null 2>&1; then for d in ~/.config/agility-shell/sounds /usr/share/agility-shell/sounds ./sounds; do [ -f \"$d/" + soundName + ".wav\" ] && exec paplay \"$d/" + soundName + ".wav\"; done; fi"
            ]

            onRunningChanged: {
                if (!running) {
                    procItem.destroy();
                }
            }
        }
    }
}
