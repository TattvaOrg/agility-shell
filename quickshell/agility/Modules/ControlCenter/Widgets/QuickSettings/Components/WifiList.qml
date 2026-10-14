import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components

Rectangle {
    id: root

    property bool expanded: false
    property bool isActive: false
    property var wifiList: []
    property bool isScanning: false
    property bool timedOut: false
    property bool isVisible: true
    property string passwordPromptSsid: ""
    readonly property var savedList: {
        let res = [];
        for (let i = 0; i < root.wifiList.length; i++) {
            let item = root.wifiList[i];
            if (item.saved || item.active || item.in_use)
                res.push(item);

        }
        return res;
    }
    readonly property var availableList: {
        let res = [];
        for (let i = 0; i < root.wifiList.length; i++) {
            let item = root.wifiList[i];
            if (!item.saved && !item.active && !item.in_use)
                res.push(item);

        }
        return res;
    }

    signal connect(string ssid, string password)
    signal refreshRequested()

    function getWifiIcon(signal) {
        let sig = parseInt(signal) || 0;
        if (sig <= 25)
            return "wifi-0";

        if (sig <= 50)
            return "wifi-1";

        if (sig <= 75)
            return "wifi-2";

        return "wifi";
    }

    Layout.fillWidth: true
    Layout.fillHeight: expanded
    implicitHeight: expanded ? Math.max(wifiListCol.implicitHeight, 80) : 0
    opacity: expanded ? 1 : 0
    visible: opacity > 0
    clip: true
    radius: 0
    color: "transparent"
    border.width: 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Constants.sizeSm
        visible: root.expanded && root.wifiList.length === 0

        Item {
            Layout.alignment: Qt.AlignHCenter
            width: Constants.size2Xl
            height: Constants.size2Xl
            visible: root.isScanning

            SvgIcon {
                anchors.centerIn: parent
                icon: "reload"
                iconColor: Theme.accent
                iconSize: Constants.sizeLg
                flat: true
            }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: Constants.animExpressive * 2
                loops: Animation.Infinite
                running: root.expanded && root.isScanning && root.wifiList.length === 0
            }

        }

        SvgIcon {
            Layout.alignment: Qt.AlignHCenter
            icon: "wifi-off"
            iconColor: Theme.muted
            iconSize: Constants.size2Xl
            flat: true
            visible: !root.isScanning
        }

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            text: root.isScanning ? "Searching for networks..." : "No networks found"
            color: root.isScanning ? Theme.fg : Theme.muted
            font.bold: root.isScanning
        }

        ThemedText {
            Layout.alignment: Qt.AlignHCenter
            text: "Make sure Wi-Fi is turned on or tap reload"
            color: Theme.muted
            customSize: Constants.sizeXs + 2
            visible: !root.isScanning
        }

    }

    ColumnLayout {
        id: wifiListCol

        anchors.fill: parent
        visible: root.wifiList.length > 0

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: parent.width
                spacing: Constants.sizeMd

                // Saved / Known Networks
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm
                    visible: root.savedList.length > 0

                    ThemedText {
                        text: "SAVED NETWORKS"
                        customSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.savedList

                        ControlCenterListDelegate {
                            Layout.fillWidth: true
                            width: parent.width
                            titleText: modelData.ssid
                            subtitleText: (modelData.active || modelData.in_use) ? ("Connected • " + ((modelData.signal || modelData.strength) > 75 ? "Excellent signal" : ((modelData.signal || modelData.strength) > 50 ? "Good signal" : "Weak signal"))) : ((modelData.signal || modelData.strength) > 75 ? "Excellent signal" : ((modelData.signal || modelData.strength) > 50 ? "Good signal" : "Weak signal"))
                            iconName: root.getWifiIcon(modelData.signal || modelData.strength)
                            isActive: modelData.active || modelData.in_use
                            canForget: true
                            onClicked: root.connect(modelData.ssid, "")
                            onActionClicked: {
                                settingsProc.running = true;
                            }
                            onDisconnectClicked: {
                                disconnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "disconnect", modelData.ssid];
                                disconnectProc.running = true;
                            }
                            onForgetClicked: {
                                forgetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "forget", modelData.ssid];
                                forgetProc.running = true;
                            }
                        }

                    }

                }

                // Available Networks (Never connected)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm
                    visible: root.availableList.length > 0

                    ThemedText {
                        text: "AVAILABLE NETWORKS"
                        customSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: Theme.muted
                        Layout.fillWidth: true
                        Layout.leftMargin: Constants.size2Xs
                    }

                    Repeater {
                        model: root.availableList

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Constants.size2Xs

                            ControlCenterListDelegate {
                                Layout.fillWidth: true
                                width: parent.width
                                titleText: modelData.ssid
                                subtitleText: (modelData.security && modelData.security !== "--" && modelData.security !== "none") ? ("Secured (" + modelData.security + ")") : ((modelData.signal || modelData.strength) > 75 ? "Excellent signal" : ((modelData.signal || modelData.strength) > 50 ? "Good signal" : "Weak signal"))
                                iconName: root.getWifiIcon(modelData.signal || modelData.strength)
                                isActive: false
                                onClicked: {
                                    if (modelData.security && modelData.security !== "--" && modelData.security !== "none") {
                                        root.passwordPromptSsid = (root.passwordPromptSsid === modelData.ssid) ? "" : modelData.ssid;
                                    } else {
                                        root.connect(modelData.ssid, "");
                                    }
                                }
                            }

                            // Inline password card for secured network
                            Rectangle {
                                visible: root.passwordPromptSsid === modelData.ssid
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Constants.sizeSm
                                color: Theme.bgSecondary
                                border.width: 1
                                border.color: Theme.accent

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Constants.sizeSm
                                    anchors.rightMargin: Constants.sizeSm
                                    spacing: Constants.sizeSm

                                    TextField {
                                        id: pwField
                                        Layout.fillWidth: true
                                        placeholderText: "Enter Wi-Fi Password"
                                        echoMode: TextInput.Password
                                        color: Theme.fg
                                        placeholderTextColor: Theme.muted
                                        background: null
                                        font.pixelSize: Constants.sizeSm
                                        onAccepted: {
                                            if (text.length > 0) {
                                                root.connect(modelData.ssid, text);
                                                root.passwordPromptSsid = "";
                                            }
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: 64
                                        implicitHeight: 28
                                        radius: Constants.sizeXs
                                        color: pwField.text.length > 0 ? Theme.accent : Theme.bgTertiary
                                        Layout.alignment: Qt.AlignVCenter

                                        ThemedText {
                                            anchors.centerIn: parent
                                            text: "Join"
                                            customSize: Constants.sizeXs + 2
                                            font.bold: true
                                            color: pwField.text.length > 0 ? Theme.bg : Theme.muted
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (pwField.text.length > 0) {
                                                    root.connect(modelData.ssid, pwField.text);
                                                    root.passwordPromptSsid = "";
                                                }
                                            }
                                        }
                                    }

                                    SvgIconButton {
                                        icon: "x"
                                        iconSize: Constants.sizeSm
                                        flat: true
                                        onClicked: {
                                            root.passwordPromptSsid = "";
                                        }
                                    }
                                }
                            }
                        }

                    }

                }

            }

        }

    }

    Process {
        id: settingsProc

        command: ["nm-connection-editor"]
    }

    Process {
        id: disconnectProc

        onRunningChanged: {
            if (!running)
                root.refreshRequested();

        }
    }

    Process {
        id: forgetProc

        onRunningChanged: {
            if (!running)
                root.refreshRequested();

        }
    }

    transform: Translate {
        y: root.expanded ? 0 : -Constants.sizeSm

        Behavior on y {
            NumberAnimation {
                duration: Constants.animNormal
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: root.expanded ? Easing.OutExpo : Easing.OutCubic
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: root.expanded ? Easing.Linear : Easing.OutCubic
        }

    }

}
