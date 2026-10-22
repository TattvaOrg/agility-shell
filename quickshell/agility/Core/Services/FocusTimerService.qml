pragma Singleton
import QtQuick
import Quickshell
import qs.Core
import qs.Core.Services

Item {
    id: root

    property int totalSeconds: 25 * 60
    property int remainingSeconds: 25 * 60
    property bool isRunning: false
    property string activeMode: "focus" // "focus", "shortBreak", "longBreak"

    readonly property real progress: totalSeconds > 0 ? Math.min(1.0, Math.max(0.0, 1.0 - (remainingSeconds / totalSeconds))) : 0
    readonly property string formattedTime: {
        let mins = Math.floor(remainingSeconds / 60);
        let secs = remainingSeconds % 60;
        return mins.toString().padStart(2, "0") + ":" + secs.toString().padStart(2, "0");
    }

    signal timerFinished(string mode)

    Timer {
        id: ticker

        interval: 1000
        running: root.isRunning
        repeat: true
        onTriggered: {
            if (root.remainingSeconds > 1) {
                root.remainingSeconds--;
            } else if (root.remainingSeconds === 1) {
                root.remainingSeconds = 0;
                root.isRunning = false;
                SoundService.play("alarm");
                root.timerFinished(root.activeMode);

                if (root.activeMode === "focus") {
                    NotificationService.notify("Focus Session Complete! 🎯", "Great job! Time to take a short break.", "clock", "Focus Timer");
                } else {
                    NotificationService.notify("Break Over! ⚡", "Ready to dive back into focus?", "clock", "Focus Timer");
                }
            } else {
                root.isRunning = false;
            }
        }
    }

    function setMode(mode) {
        if (root.isRunning)
            root.isRunning = false;

        root.activeMode = mode;
        if (mode === "focus") {
            root.totalSeconds = 25 * 60;
        } else if (mode === "shortBreak") {
            root.totalSeconds = 5 * 60;
        } else if (mode === "longBreak") {
            root.totalSeconds = 15 * 60;
        }
        root.remainingSeconds = root.totalSeconds;
        SoundService.play("confirm");
    }

    function toggle() {
        if (root.isRunning) {
            pause();
        } else {
            start();
        }
    }

    function start() {
        if (root.remainingSeconds <= 0)
            root.remainingSeconds = root.totalSeconds;

        root.isRunning = true;
        SoundService.play("confirm");
    }

    function pause() {
        root.isRunning = false;
        SoundService.play("confirm");
    }

    function reset() {
        root.isRunning = false;
        root.remainingSeconds = root.totalSeconds;
        SoundService.play("confirm");
    }
}
