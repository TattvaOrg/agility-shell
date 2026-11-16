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
    property bool isConnecting: false
    property string connectingSsid: ""
    property string errorMessage: ""
    property string lastAttemptedSsid: ""
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

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Constants.size2Xs

                            ControlCenterListDelegate {
                                Layout.fillWidth: true
                                width: parent.width
                                titleText: modelData.ssid
                                subtitleText: {
                                    if (modelData.active || modelData.in_use) {
                                        let sig = (modelData.signal || modelData.strength);
                                        let quality = sig > 75 ? "Excellent signal" : (sig > 50 ? "Good signal" : "Weak signal");
                                        return "Connected • " + quality;
                                    }
                                    if (root.isConnecting && root.connectingSsid === modelData.ssid)
                                        return "Connecting...";
                                    if (root.errorMessage !== "" && root.lastAttemptedSsid === modelData.ssid)
                                        return root.errorMessage;
                                    let sig = (modelData.signal || modelData.strength);
                                    return sig > 75 ? "Excellent signal" : (sig > 50 ? "Good signal" : "Weak signal");
                                }
                                iconName: root.getWifiIcon(modelData.signal || modelData.strength)
                                isActive: modelData.active || modelData.in_use
                                isConnecting: root.isConnecting && root.connectingSsid === modelData.ssid
                                canForget: true
                                canEditPassword: (modelData.security && modelData.security !== "--" && modelData.security !== "none")
                                onClicked: {
                                    if (modelData.active || modelData.in_use) {
                                        disconnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "disconnect", modelData.ssid];
                                        disconnectProc.running = true;
                                    } else {
                                        root.lastAttemptedSsid = modelData.ssid;
                                        root.connect(modelData.ssid, "");
                                    }
                                }
                                onEditPasswordClicked: {
                                    root.passwordPromptSsid = (root.passwordPromptSsid === modelData.ssid) ? "" : modelData.ssid;
                                }
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

                            // Inline password card for saved network (change password)
                            Rectangle {
                                id: savedPasswordCard
                                visible: root.passwordPromptSsid === modelData.ssid
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Constants.sizeSm
                                color: Theme.bgSecondary
                                border.width: 1
                                border.color: Theme.accent

                                FocusScope {
                                    anchors.fill: parent
                                    focus: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Constants.sizeSm
                                        anchors.rightMargin: Constants.sizeSm
                                        spacing: Constants.sizeSm

                                        SvgIcon {
                                            icon: "lock"
                                            iconSize: Constants.sizeSm + 2
                                            iconColor: Theme.accent
                                            flat: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        TextField {
                                            id: savedPwField
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.alignment: Qt.AlignVCenter
                                            verticalAlignment: TextInput.AlignVCenter
                                            placeholderText: "Enter New Wi-Fi Password"
                                            echoMode: savedRevealPass ? TextInput.Normal : TextInput.Password
                                            color: Theme.fg
                                            placeholderTextColor: Theme.muted
                                            background: null
                                            font.pixelSize: Constants.sizeSm
                                            selectByMouse: true
                                            focus: true

                                            property bool savedRevealPass: false

                                            Component.onCompleted: {
                                                if (savedPasswordCard.visible) {
                                                    forceActiveFocus();
                                                    Qt.callLater(() => forceActiveFocus());
                                                }
                                            }

                                            Connections {
                                                target: savedPasswordCard
                                                function onVisibleChanged() {
                                                    if (savedPasswordCard.visible) {
                                                        savedPwField.text = "";
                                                        savedPwField.forceActiveFocus();
                                                        Qt.callLater(() => savedPwField.forceActiveFocus());
                                                    }
                                                }
                                            }

                                            Keys.priority: Keys.BeforeItem
                                            Keys.onEscapePressed: function(event) {
                                                root.passwordPromptSsid = "";
                                                event.accepted = true;
                                            }

                                            onAccepted: {
                                                if (text.length > 0) {
                                                    root.lastAttemptedSsid = modelData.ssid;
                                                    root.connect(modelData.ssid, text);
                                                    root.passwordPromptSsid = "";
                                                }
                                            }
                                        }

                                        SvgIconButton {
                                            icon: savedPwField.savedRevealPass ? "eye" : "eye-off"
                                            iconSize: Constants.sizeSm
                                            iconColor: Theme.muted
                                            hoverColor: Theme.accent
                                            flat: true
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                savedPwField.savedRevealPass = !savedPwField.savedRevealPass;
                                                savedPwField.forceActiveFocus();
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: 64
                                            implicitHeight: 28
                                            radius: Constants.sizeXs
                                            color: savedPwField.text.length > 0 ? Theme.accent : Theme.bgTertiary
                                            Layout.alignment: Qt.AlignVCenter

                                            ThemedText {
                                                anchors.centerIn: parent
                                                text: (root.isConnecting && root.connectingSsid === modelData.ssid) ? "..." : "Save"
                                                customSize: Constants.sizeXs + 2
                                                font.bold: true
                                                color: savedPwField.text.length > 0 ? Theme.bg : Theme.muted
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (savedPwField.text.length > 0) {
                                                        root.lastAttemptedSsid = modelData.ssid;
                                                        root.connect(modelData.ssid, savedPwField.text);
                                                        root.passwordPromptSsid = "";
                                                    }
                                                }
                                            }
                                        }

                                        SvgIconButton {
                                            icon: "x"
                                            iconSize: Constants.sizeSm
                                            flat: true
                                            Layout.alignment: Qt.AlignVCenter
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
                                subtitleText: {
                                    if (root.isConnecting && root.connectingSsid === modelData.ssid)
                                        return "Connecting...";
                                    if (root.errorMessage !== "" && root.lastAttemptedSsid === modelData.ssid)
                                        return root.errorMessage;
                                    let isSecured = (modelData.security && modelData.security !== "--" && modelData.security !== "none");
                                    let sec = isSecured ? ("Secured (" + modelData.security + ") • ") : "";
                                    let sig = (modelData.signal || modelData.strength);
                                    let quality = sig > 75 ? "Excellent signal" : (sig > 50 ? "Good signal" : "Weak signal");
                                    return sec + quality;
                                }
                                iconName: root.getWifiIcon(modelData.signal || modelData.strength)
                                isActive: false
                                isConnecting: root.isConnecting && root.connectingSsid === modelData.ssid
                                onClicked: {
                                    if (modelData.security && modelData.security !== "--" && modelData.security !== "none") {
                                        root.passwordPromptSsid = (root.passwordPromptSsid === modelData.ssid) ? "" : modelData.ssid;
                                    } else {
                                        root.lastAttemptedSsid = modelData.ssid;
                                        root.connect(modelData.ssid, "");
                                    }
                                }
                            }

                            // Inline password card for secured available network
                            Rectangle {
                                id: availablePasswordCard
                                visible: root.passwordPromptSsid === modelData.ssid
                                Layout.fillWidth: true
                                implicitHeight: 46
                                radius: Constants.sizeSm
                                color: Theme.bgSecondary
                                border.width: 1
                                border.color: Theme.accent

                                FocusScope {
                                    anchors.fill: parent
                                    focus: true

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Constants.sizeSm
                                        anchors.rightMargin: Constants.sizeSm
                                        spacing: Constants.sizeSm

                                        SvgIcon {
                                            icon: "lock"
                                            iconSize: Constants.sizeSm + 2
                                            iconColor: Theme.accent
                                            flat: true
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        TextField {
                                            id: pwField
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.alignment: Qt.AlignVCenter
                                            verticalAlignment: TextInput.AlignVCenter
                                            placeholderText: "Enter Wi-Fi Password"
                                            echoMode: revealPass ? TextInput.Normal : TextInput.Password
                                            color: Theme.fg
                                            placeholderTextColor: Theme.muted
                                            background: null
                                            font.pixelSize: Constants.sizeSm
                                            selectByMouse: true
                                            focus: true

                                            property bool revealPass: false

                                            Component.onCompleted: {
                                                if (availablePasswordCard.visible) {
                                                    forceActiveFocus();
                                                    Qt.callLater(() => forceActiveFocus());
                                                }
                                            }

                                            Connections {
                                                target: availablePasswordCard
                                                function onVisibleChanged() {
                                                    if (availablePasswordCard.visible) {
                                                        pwField.text = "";
                                                        pwField.forceActiveFocus();
                                                        Qt.callLater(() => pwField.forceActiveFocus());
                                                    }
                                                }
                                            }

                                            Keys.priority: Keys.BeforeItem
                                            Keys.onEscapePressed: function(event) {
                                                root.passwordPromptSsid = "";
                                                event.accepted = true;
                                            }

                                            onAccepted: {
                                                if (text.length > 0) {
                                                    root.lastAttemptedSsid = modelData.ssid;
                                                    root.connect(modelData.ssid, text);
                                                    root.passwordPromptSsid = "";
                                                }
                                            }
                                        }

                                        SvgIconButton {
                                            icon: pwField.revealPass ? "eye" : "eye-off"
                                            iconSize: Constants.sizeSm
                                            iconColor: Theme.muted
                                            hoverColor: Theme.accent
                                            flat: true
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                pwField.revealPass = !pwField.revealPass;
                                                pwField.forceActiveFocus();
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
                                                text: (root.isConnecting && root.connectingSsid === modelData.ssid) ? "..." : "Join"
                                                customSize: Constants.sizeXs + 2
                                                font.bold: true
                                                color: pwField.text.length > 0 ? Theme.bg : Theme.muted
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (pwField.text.length > 0) {
                                                        root.lastAttemptedSsid = modelData.ssid;
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
                                            Layout.alignment: Qt.AlignVCenter
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
