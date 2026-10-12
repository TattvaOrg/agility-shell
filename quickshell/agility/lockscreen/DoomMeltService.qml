pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isMelting: false
    property int numColumns: 60
    property int durationMs: 720
    property var columnDelays: []
    property string snapshotPath: ""

    signal meltStarted()
    signal meltFinished()

    // ─── Correlated Random-Walk Delays Algorithm (Iconic Doom Vertical Melt) ───
    function generateDelays(count) {
        var arr = []
        var curr = 0.035
        for (var i = 0; i < count; i++) {
            var delta = (Math.random() - 0.5) * 0.10
            curr = Math.max(0.0, Math.min(0.36, curr + delta))
            arr.push(Math.round(curr * 1000) / 1000)
        }
        return arr
    }

    // ─── Trigger Doom Melt Transition ───
    function triggerMelt(snapshot, duration, cols, delays) {
        var c = cols && cols >= 10 ? cols : 60
        var d = duration && duration >= 200 ? duration : 720
        var del = delays && delays.length === c ? delays : generateDelays(c)

        root.snapshotPath = snapshot ? snapshot : ""
        root.numColumns = c
        root.durationMs = d
        root.columnDelays = del
        root.isMelting = true

        root.meltStarted()
        finishTimer.interval = d + 650
        finishTimer.restart()
    }

    function cancelMelt() {
        root.isMelting = false
        finishTimer.stop()
        root.meltFinished()
    }

    Timer {
        id: finishTimer
        repeat: false
        onTriggered: {
            root.isMelting = false
            root.meltFinished()
        }
    }
}
