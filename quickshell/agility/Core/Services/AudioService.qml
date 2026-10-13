import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: audioService

    property int micVolume: 0
    property bool micMuted: false
    property string defaultSourceName: ""
    property bool hasPhysicalMic: defaultSourceName !== "" && !defaultSourceName.endsWith(".monitor")

    function updateMicStatus() {
        defaultSourceProc.running = false;
        defaultSourceProc.running = true;
    }

    function setMicVolume(val) {
        if (!hasPhysicalMic)
            return ;

        audioService.micVolume = val;
        micSetVolumeProc.setVol(val);
    }

    function setMicMuted(state) {
        if (!hasPhysicalMic)
            return ;

        audioService.micMuted = state;
        micSetMuteProc.setMute(state);
    }

    onMicMutedChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    onMicVolumeChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

    }
    Component.onCompleted: {
        defaultSourceProc.running = true;
    }

    Process {
        id: micVolumeProc

        command: ["pamixer", "--default-source", "--get-volume"]

        stdout: SplitParser {
            onRead: (data) => {
                let val = parseInt(data.trim());
                if (!isNaN(val))
                    audioService.micVolume = val;

            }
        }

    }

    Process {
        id: micMuteProc

        command: ["pamixer", "--default-source", "--get-mute"]

        stdout: SplitParser {
            onRead: (data) => {
                audioService.micMuted = (data.trim() === "true");
            }
        }

    }

    Process {
        id: micSetVolumeProc

        function setVol(val) {
            command = ["pamixer", "--default-source", "--set-volume", String(val)];
            running = false;
            running = true;
        }

    }

    Process {
        id: micSetMuteProc

        function setMute(state) {
            command = ["pamixer", "--default-source", state ? "--mute" : "--unmute"];
            running = false;
            running = true;
        }

    }

    Process {
        id: defaultSourceProc

        command: ["pactl", "get-default-source"]
        running: false
        onExited: (code) => {
            if (code === 0)
                audioService.defaultSourceName = stdoutSource.text.trim();

            if (audioService.hasPhysicalMic) {
                micVolumeProc.running = false;
                micVolumeProc.running = true;
                micMuteProc.running = false;
                micMuteProc.running = true;
            } else {
                audioService.micMuted = true;
                audioService.micVolume = 0;
            }
            if (!SettingsService.settingsLoaded)
                SettingsService.load();

        }

        stdout: StdioCollector {
            id: stdoutSource
        }

    }

    Process {
        id: pactlSubscribeProc

        command: ["pactl", "subscribe"]
        running: true

        stdout: SplitParser {
            onRead: (data) => {
                if (data.includes("source") && SettingsService.settingsLoaded)
                    audioService.updateMicStatus();

            }
        }

    }

}
