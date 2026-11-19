import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

QuickSettingsTile {
    id: root

    property bool expanded: false
    property bool isScanning: btDiscoveryProc.running
    property bool isConnecting: btConnectProc.running
    property string connectingMac: ""
    property var btList: []
    property bool isVisible: true

    function toggle() {
        btSetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-power"];
        btSetProc.running = true;
    }

    function scan() {
        if (!root.isActive)
            return ;

        btDiscoveryProc.running = false;
        btDiscoveryProc.running = true;
    }

    function connect(mac) {
        root.connectingMac = mac;
        btConnectProc.running = false;
        btConnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-connect", mac];
        btConnectProc.running = true;
    }

    hasMenu: true
    icon: root.isActive ? "bluetooth" : "bluetooth-off"
    label: "Bluetooth"
    subtitle: {
        if (!isActive)
            return "Off";

        for (let i = 0; i < btList.length; i++) {
            if (btList[i].connected)
                return btList[i].name;

        }
        return "Disconnected";
    }
    onClicked: root.toggle()
    onExpandedChanged: {
        if (expanded)
            scan();
        else
            btDiscoveryProc.running = false;
    }
    onIsActiveChanged: {
        if (!isActive) {
            expanded = false;
            btDiscoveryProc.running = false;
            btList = [];
        } else {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }
    onIsVisibleChanged: {
        if (isVisible && isActive) {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }
    Component.onCompleted: {
        if (isActive) {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }

    Timer {
        id: updateTimer

        interval: 2500
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btGetProc.running = true;
        }
    }

    Process {
        id: btGetProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        root.btList = parsed.slice();
                    } else {
                        root.isActive = parsed.powered !== undefined ? parsed.powered : false;
                        if (!btDiscoveryProc.running || root.btList.length === 0) {
                            let devs = (parsed.devices || []).slice();
                            if (devs.length > 0 || !root.isScanning)
                                root.btList = devs;
                        }
                    }
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: btSetProc

        onRunningChanged: {
            if (!running)
                btGetProc.running = true;

        }
    }

    Process {
        id: btDiscoveryProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "scan"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let parsed = JSON.parse(data);
                    if (Array.isArray(parsed)) {
                        root.btList = parsed.slice();
                    } else if (parsed.devices) {
                        root.btList = (parsed.devices || []).slice();
                    } else if (parsed.event === "devices") {
                        root.btList = (parsed.devices || []).slice();
                    }
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: btConnectProc

        onRunningChanged: {
            if (!running) {
                root.connectingMac = "";
                btGetProc.running = false;
                btGetProc.running = true;
            }
        }
    }

}
