pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Core
import qs.Core.Services

Item {
    id: root

    property var sink: Pipewire.defaultAudioSink
    property int currentVolume: (sink && sink.audio) ? Math.round(sink.audio.volume * 100) : 0
    property bool isMuted: (sink && sink.audio) ? sink.audio.muted : false
    property int currentBrightness: 100

    property bool isVisible: false
    property string activeType: "volume" // "volume", "brightness"
    property int displayValue: 0
    property string displayIcon: "volume"
    property string displayLabel: "Volume"

    signal triggered()

    function showVolume(step) {
        activeType = "volume";
        displayValue = isMuted ? 0 : currentVolume;
        displayIcon = (isMuted || displayValue === 0) ? "volume-off" : "volume";
        displayLabel = isMuted ? "Audio Muted" : ("Volume " + displayValue + "%");
        triggerOsd();
    }

    function showBrightness(step) {
        activeType = "brightness";
        brightGetProc.running = false;
        brightGetProc.running = true;
    }

    function triggerOsd() {
        isVisible = true;
        hideTimer.restart();
        triggered();
    }

    property int _lastMonitoredVol: -1
    property bool _lastMonitoredMute: false
    property bool _initialized: false

    onCurrentVolumeChanged: {
        if (!_initialized)
            return;

        if (_lastMonitoredVol !== currentVolume) {
            _lastMonitoredVol = currentVolume;
            showVolume();
        }
    }

    onIsMutedChanged: {
        if (!_initialized)
            return;

        if (_lastMonitoredMute !== isMuted) {
            _lastMonitoredMute = isMuted;
            showVolume();
        }
    }

    Timer {
        id: initTimer

        interval: 1200
        running: true
        repeat: false
        onTriggered: {
            root._lastMonitoredVol = root.currentVolume;
            root._lastMonitoredMute = root.isMuted;
            root._initialized = true;
        }
    }

    Timer {
        id: hideTimer

        interval: 1600
        repeat: false
        onTriggered: {
            root.isVisible = false;
        }
    }

    Process {
        id: brightGetProc

        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;

                let parts = data.trim().split(",");
                if (parts.length >= 4) {
                    let pct = parseInt(parts[3].replace("%", ""));
                    if (!isNaN(pct)) {
                        root.currentBrightness = pct;
                        root.displayValue = pct;
                        root.displayIcon = "sun";
                        root.displayLabel = "Brightness " + pct + "%";
                        root.triggerOsd();
                    }
                }
            }
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
}
