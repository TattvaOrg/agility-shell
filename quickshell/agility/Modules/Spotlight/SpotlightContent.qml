import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var widget: null
    property alias initialFocusItem: searchField
    property string activeCategory: "All"
    readonly property var categories: ["All", "Apps", "Windows", "Actions", "Math", "Web"]

    property var allApps: []
    property var rawWindows: []
    property var combinedResults: []
    property int selectedIndex: 0
    property string copyFeedback: ""

    function resetAndFocus() {
        searchField.text = "";
        activeCategory = "All";
        selectedIndex = 0;
        copyFeedback = "";
        if (AppState.launcherApps && AppState.launcherApps.length > 0) {
            root.allApps = AppState.launcherApps;
        } else {
            loadAppsProc.running = true;
        }
        queryWindowsProc.running = true;
        updateResults();
        searchField.forceActiveFocus();
        Qt.callLater(function() {
            searchField.forceActiveFocus();
        });
    }

    function evaluateMath(expr) {
        if (!expr || expr.trim() === "")
            return null;
        let clean = expr.trim();

        // Base conversion formats
        let hexMatch = clean.match(/^0x([0-9a-fA-F]+)\s*(?:in\s*dec)?$/i);
        if (hexMatch) {
            let val = parseInt(hexMatch[1], 16);
            return {
                expression: clean,
                result: val.toString(),
                type: "conversion"
            };
        }
        let toHexMatch = clean.match(/^(\d+)\s+in\s+hex$/i);
        if (toHexMatch) {
            let val = parseInt(toHexMatch[1], 10);
            return {
                expression: clean,
                result: "0x" + val.toString(16).toUpperCase(),
                type: "conversion"
            };
        }
        let toBinMatch = clean.match(/^(\d+)\s+in\s+bin(?:ary)?$/i);
        if (toBinMatch) {
            let val = parseInt(toBinMatch[1], 10);
            return {
                expression: clean,
                result: "0b" + val.toString(2),
                type: "conversion"
            };
        }

        // Sanitize and substitute standard math operations
        let sanitized = clean
            .replace(/\^/g, "**")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/g, "Math.E")
            .replace(/\bsin\b/g, "Math.sin")
            .replace(/\bcos\b/g, "Math.cos")
            .replace(/\btan\b/g, "Math.tan")
            .replace(/\bsqrt\b/g, "Math.sqrt")
            .replace(/\babs\b/g, "Math.abs")
            .replace(/\bround\b/g, "Math.round")
            .replace(/\bfloor\b/g, "Math.floor")
            .replace(/\bceil\b/g, "Math.ceil")
            .replace(/\blog\b/g, "Math.log")
            .replace(/\bpow\b/g, "Math.pow");

        // Safety check: only digits, operators, dots, parens, commas, and Math calls allowed
        if (!/^[\d\s\+\-\*\/\%\.\(\)\,\Math\.\w]+$/.test(sanitized))
            return null;
        if (!/[\+\-\*\/\%\^\(\)]|\bMath\./.test(sanitized))
            return null;

        try {
            let res = Function('"use strict"; return (' + sanitized + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                let formatted = Number.isInteger(res) ? res.toString() : parseFloat(res.toFixed(8)).toString();
                return {
                    expression: clean,
                    result: formatted,
                    type: "math"
                };
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    function executeItem(item) {
        if (!item)
            return;

        if (item.category === "Math") {
            ClipboardService.copyText(item.resultValue);
            root.copyFeedback = "Copied " + item.resultValue + " to clipboard!";
            SoundService.play("widget-placed");
            feedbackTimer.restart();
            return;
        }

        if (item.category === "Web") {
            Quickshell.execDetached(["xdg-open", item.url]);
            closeSpotlight();
            return;
        }

        if (item.category === "Windows") {
            if (AppState.isNiri) {
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(item.winId)]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + item.address]);
            }
            closeSpotlight();
            return;
        }

        if (item.category === "Actions") {
            if (item.actionHandler) {
                item.actionHandler();
            }
            closeSpotlight();
            return;
        }

        if (item.category === "Apps") {
            if (item.terminal) {
                Quickshell.execDetached(["x-terminal-emulator", "-e", item.exec]);
            } else {
                let cmdParts = item.exec.split(" ");
                Quickshell.execDetached(cmdParts);
            }
            closeSpotlight();
            return;
        }
    }

    function closeSpotlight() {
        if (root.widget)
            root.widget.isOpen = false;
        else {
            AppState.closeWidget("spotlight");
            AppState.closeWidget("omni");
        }
    }

    function updateResults() {
        let text = searchField.text.trim();
        let cat = root.activeCategory;
        let results = [];

        // 1. Math Evaluation
        if (cat === "All" || cat === "Math") {
            let mathRes = evaluateMath(text);
            if (mathRes) {
                results.push({
                    category: "Math",
                    title: mathRes.result,
                    subtitle: "Calculation: " + mathRes.expression + " (Press Enter to copy)",
                    icon: "calculator",
                    resultValue: mathRes.result
                });
            }
        }

        // 2. Web Query Shortcuts
        if (cat === "All" || cat === "Web") {
            let lower = text.toLowerCase();
            let webItem = null;
            if (lower.startsWith("g:") || lower.startsWith("g ")) {
                let q = text.substring(2).trim();
                if (q !== "") {
                    webItem = {
                        category: "Web",
                        title: "Google Search: \"" + q + "\"",
                        subtitle: "Open search results in browser",
                        icon: "globe",
                        url: "https://www.google.com/search?q=" + encodeURIComponent(q)
                    };
                }
            } else if (lower.startsWith("gh:") || lower.startsWith("gh ")) {
                let q = text.substring(3).trim();
                if (q !== "") {
                    webItem = {
                        category: "Web",
                        title: "GitHub Search: \"" + q + "\"",
                        subtitle: "Search repositories and code on GitHub",
                        icon: "code",
                        url: "https://github.com/search?q=" + encodeURIComponent(q)
                    };
                }
            } else if (lower.startsWith("yt:") || lower.startsWith("yt ")) {
                let q = text.substring(3).trim();
                if (q !== "") {
                    webItem = {
                        category: "Web",
                        title: "YouTube: \"" + q + "\"",
                        subtitle: "Search videos on YouTube",
                        icon: "play",
                        url: "https://www.youtube.com/results?search_query=" + encodeURIComponent(q)
                    };
                }
            } else if (lower.startsWith("w:") || lower.startsWith("w ")) {
                let q = text.substring(2).trim();
                if (q !== "") {
                    webItem = {
                        category: "Web",
                        title: "Wikipedia: \"" + q + "\"",
                        subtitle: "Search encyclopedia on Wikipedia",
                        icon: "book",
                        url: "https://en.wikipedia.org/wiki/Special:Search?search=" + encodeURIComponent(q)
                    };
                }
            } else if (lower.startsWith("ddg:") || lower.startsWith("ddg ")) {
                let q = text.substring(4).trim();
                if (q !== "") {
                    webItem = {
                        category: "Web",
                        title: "DuckDuckGo: \"" + q + "\"",
                        subtitle: "Search privately with DuckDuckGo",
                        icon: "globe",
                        url: "https://duckduckgo.com/?q=" + encodeURIComponent(q)
                    };
                }
            } else if (lower.startsWith("http://") || lower.startsWith("https://")) {
                webItem = {
                    category: "Web",
                    title: "Open URL: " + text,
                    subtitle: "Open web link in default browser",
                    icon: "globe",
                    url: text
                };
            }

            if (webItem)
                results.push(webItem);
        }

        // 3. Running Windows
        if (cat === "All" || cat === "Windows") {
            let winQuery = text.toLowerCase();
            if (winQuery.startsWith("w:") || winQuery.startsWith("win:")) {
                winQuery = winQuery.replace(/^(w:|win:)\s*/, "");
            }

            for (let i = 0; i < root.rawWindows.length; i++) {
                let w = root.rawWindows[i];
                let title = w.title || "";
                let wClass = w.class || w.app_id || "";
                let wsId = w.workspace ? (w.workspace.id || w.workspace) : (w.workspace_id || 1);

                if (winQuery === "" || title.toLowerCase().includes(winQuery) || wClass.toLowerCase().includes(winQuery)) {
                    results.push({
                        category: "Windows",
                        title: title !== "" ? title : wClass,
                        subtitle: "[Workspace " + wsId + "] " + wClass,
                        icon: wClass,
                        address: w.address || "",
                        winId: w.id !== undefined ? w.id : 0,
                        workspace: wsId
                    });
                }
            }
        }

        // 4. Quick System Actions
        if (cat === "All" || cat === "Actions") {
            let systemActions = [
                {
                    title: "Lock Screen",
                    desc: "Secure the current session",
                    icon: "lock",
                    keywords: "lock secure sleep logout",
                    handler: function() { AppState.openWidget("lockScreen"); }
                },
                {
                    title: "Restart System",
                    desc: "Reboot your computer",
                    icon: "reload",
                    keywords: "reboot restart system",
                    handler: function() { Quickshell.execDetached(["systemctl", "reboot"]); }
                },
                {
                    title: "Shut Down",
                    desc: "Power off the computer",
                    icon: "power",
                    keywords: "shutdown power off halt",
                    handler: function() { Quickshell.execDetached(["systemctl", "poweroff"]); }
                },
                {
                    title: "Suspend / Sleep",
                    desc: "Put computer to low power sleep mode",
                    icon: "moon",
                    keywords: "suspend sleep stand by",
                    handler: function() { Quickshell.execDetached(["systemctl", "suspend"]); }
                },
                {
                    title: "Toggle Dark / Light Theme",
                    desc: "Switch color mode between dark and light",
                    icon: "sun",
                    keywords: "dark light theme mode",
                    handler: function() { SettingsService.darkMode = !SettingsService.darkMode; }
                },
                {
                    title: "Toggle Do Not Disturb",
                    desc: "Mute all notifications and alerts",
                    icon: "bell-off",
                    keywords: "dnd do not disturb mute notifications",
                    handler: function() { SettingsService.dndEnabled = !SettingsService.dndEnabled; }
                },
                {
                    title: "Toggle Desktop Widgets",
                    desc: "Show or hide interactive desktop widgets",
                    icon: "window",
                    keywords: "widgets desktop awe clock weather",
                    handler: function() { SettingsService.desktopWidgetsEnabled = !SettingsService.desktopWidgetsEnabled; }
                },
                {
                    title: "Toggle Dynamic Dock",
                    desc: "Show or hide the floating application dock",
                    icon: "layout",
                    keywords: "dock bar floating apps launcher",
                    handler: function() { SettingsService.dockEnabled = !SettingsService.dockEnabled; }
                },
                {
                    title: "Toggle Dynamic Island",
                    desc: "Show or hide top capsule live activities hub",
                    icon: "music",
                    keywords: "island capsule pill music timer",
                    handler: function() { SettingsService.dynamicIslandEnabled = !SettingsService.dynamicIslandEnabled; }
                },
                {
                    title: "Take Screenshot (Area)",
                    desc: "Select a rectangular screen region to capture",
                    icon: "capture",
                    keywords: "screenshot snipping capture area snip",
                    handler: function() { Quickshell.execDetached(["agl", "screenshot", "area"]); }
                },
                {
                    title: "Take Screenshot (Full)",
                    desc: "Capture the entire active display",
                    icon: "capture",
                    keywords: "screenshot full screen monitor",
                    handler: function() { Quickshell.execDetached(["agl", "screenshot", "full"]); }
                },
                {
                    title: "Open Agility Settings",
                    desc: "Customize shell, widgets, theme, and layout",
                    icon: "settings",
                    keywords: "settings config preferences agility",
                    handler: function() { AppState.openWidget("minflair_settings"); }
                },
                {
                    title: "Open Keybinds Cheat Sheet",
                    desc: "View all Agility and compositor hotkeys",
                    icon: "check",
                    keywords: "keybinds shortcuts cheatsheet hotkeys",
                    handler: function() { AppState.openWidget("minflair_keybinds"); }
                },
                {
                    title: "Reload Quickshell",
                    desc: "Restart and reload shell components",
                    icon: "refresh",
                    keywords: "reload restart quickshell shell reset",
                    handler: function() { Quickshell.execDetached(["quickshell", "-r"]); }
                }
            ];

            let actQuery = text.toLowerCase();
            for (let i = 0; i < systemActions.length; i++) {
                let act = systemActions[i];
                if (actQuery === "" || act.title.toLowerCase().includes(actQuery) || act.keywords.includes(actQuery)) {
                    results.push({
                        category: "Actions",
                        title: act.title,
                        subtitle: act.desc,
                        icon: act.icon,
                        actionHandler: act.handler
                    });
                }
            }
        }

        // 5. Installed Applications
        if (cat === "All" || cat === "Apps") {
            let appQuery = text.toLowerCase();
            if (appQuery.startsWith("app:")) {
                appQuery = appQuery.replace(/^app:\s*/, "");
            }

            for (let i = 0; i < root.allApps.length; i++) {
                let app = root.allApps[i];
                let name = app.name || "";
                let exec = app.exec || "";
                if (appQuery === "" || name.toLowerCase().includes(appQuery) || exec.toLowerCase().includes(appQuery)) {
                    results.push({
                        category: "Apps",
                        title: name,
                        subtitle: exec,
                        icon: app.icon || "rocket",
                        exec: exec,
                        terminal: Boolean(app.terminal)
                    });
                }
            }
        }

        root.combinedResults = results;
        root.selectedIndex = 0;
    }

    implicitWidth: 680
    implicitHeight: 520

    // Windows query process
    Process {
        id: queryWindowsProc
        command: AppState.isNiri ? ["niri", "msg", "-j", "windows"] : ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: windowsOutput
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(windowsOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        root.rawWindows = parsed;
                        root.updateResults();
                    }
                } catch (e) {
                }
            }
        }
    }

    // Apps query process
    Process {
        id: loadAppsProc
        command: ["agl", "get-apps"]

        stdout: StdioCollector {
            id: appsOutput
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(appsOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        AppState.launcherApps = parsed;
                        root.allApps = parsed;
                        root.updateResults();
                    }
                } catch (e) {
                }
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: 2200
        repeat: false
        onTriggered: {
            root.copyFeedback = "";
            root.closeSpotlight();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.sizeMd

        // Top Search Input Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: Constants.sizeXl
            color: Theme.bgSecondary
            border.width: searchField.activeFocus ? 2 : 1
            border.color: searchField.activeFocus ? Theme.accent : Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeLg
                anchors.rightMargin: Constants.sizeLg
                spacing: Constants.sizeMd

                SvgIcon {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    icon: "search"
                    iconSize: 22
                    flat: true
                    iconColor: searchField.activeFocus ? Theme.accent : Theme.muted
                }

                TextInput {
                    id: searchField
                    Layout.fillWidth: true
                    font.pixelSize: Constants.fontSizeLg
                    font.weight: Font.DemiBold
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        anchors.fill: parent
                        text: "Search apps, windows (w:), math (e.g. 42*8), web (g:, gh:), or actions..."
                        color: Theme.muted
                        font: searchField.font
                        verticalAlignment: Text.AlignVCenter
                        visible: !searchField.text && !searchField.activeFocus
                    }

                    onTextChanged: {
                        root.updateResults();
                    }

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            if (root.combinedResults.length > 0) {
                                root.selectedIndex = Math.min(root.combinedResults.length - 1, root.selectedIndex + 1);
                                resultsView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.combinedResults.length > 0) {
                                root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                resultsView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (root.combinedResults.length > 0 && root.selectedIndex >= 0 && root.selectedIndex < root.combinedResults.length) {
                                root.executeItem(root.combinedResults[root.selectedIndex]);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeSpotlight();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            // Cycle category tabs
                            let curIdx = root.categories.indexOf(root.activeCategory);
                            let nextIdx = (curIdx + 1) % root.categories.length;
                            root.activeCategory = root.categories[nextIdx];
                            root.updateResults();
                            event.accepted = true;
                        }
                    }
                }

                // Clear button
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: clearMouse.containsMouse ? Theme.surfaceHover : "transparent"
                    visible: searchField.text !== ""

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Theme.muted
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            searchField.text = "";
                            searchField.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // Category Filter Pills
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            Repeater {
                model: root.categories

                Rectangle {
                    required property string modelData
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: pillText.implicitWidth + 24
                    radius: 14
                    color: root.activeCategory === modelData ? Theme.accent : (pillHover.containsMouse ? Theme.bgSecondary : "transparent")
                    border.width: 1
                    border.color: root.activeCategory === modelData ? Theme.accent : Theme.border

                    Text {
                        id: pillText
                        anchors.centerIn: parent
                        text: parent.modelData
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: root.activeCategory === parent.modelData ? Font.Bold : Font.Normal
                        color: root.activeCategory === parent.modelData ? Theme.bg : Theme.textSecondary
                    }

                    MouseArea {
                        id: pillHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activeCategory = parent.modelData;
                            root.updateResults();
                            searchField.forceActiveFocus();
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Copy feedback toast
            Text {
                text: root.copyFeedback
                color: Theme.success || Theme.accent
                font.pixelSize: Constants.fontSizeSm
                font.weight: Font.DemiBold
                visible: root.copyFeedback !== ""
            }
        }

        // Results View
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Constants.sizeLg
            color: "transparent"
            clip: true

            ListView {
                id: resultsView
                anchors.fill: parent
                model: root.combinedResults
                spacing: Constants.sizeXs
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selectedIndex

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: resultsView.width
                    height: 52
                    radius: Constants.sizeLg
                    color: root.selectedIndex === index ? Theme.bgSecondary : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    border.width: root.selectedIndex === index ? 1 : 0
                    border.color: Theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Constants.sizeMd
                        anchors.rightMargin: Constants.sizeMd
                        spacing: Constants.sizeMd

                        // Category / App Icon
                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32

                            Image {
                                id: delegateIcon
                                anchors.fill: parent
                                sourceSize: Qt.size(64, 64)
                                fillMode: Image.PreserveAspectFit
                                source: {
                                    if (!modelData.icon) return "";
                                    let path = modelData.icon;
                                    let home = Quickshell.env("HOME");
                                    if (path.startsWith("$HOME"))
                                        path = home + path.substring(5);
                                    else if (path.startsWith("~"))
                                        path = home + path.substring(1);
                                    if (path.startsWith("/") || path.startsWith("file://"))
                                        return path.startsWith("file://") ? path : "file://" + path;
                                    return Quickshell.iconPath(path, true);
                                }
                                visible: status === Image.Ready
                            }

                            SvgIcon {
                                anchors.fill: parent
                                icon: {
                                    if (modelData.category === "Math") return "calculator";
                                    if (modelData.category === "Web") return "globe";
                                    if (modelData.category === "Windows") return "window";
                                    if (modelData.category === "Actions") return modelData.icon || "check";
                                    return "rocket";
                                }
                                iconSize: 22
                                flat: true
                                iconColor: root.selectedIndex === index ? Theme.accent : Theme.muted
                                visible: !delegateIcon.visible
                            }
                        }

                        // Title & Subtitle
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                font.pixelSize: Constants.fontSizeMd
                                font.weight: Font.DemiBold
                                color: root.selectedIndex === index ? Theme.text : Theme.textSecondary
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.subtitle
                                font.pixelSize: Constants.fontSizeSm
                                color: Theme.muted
                                elide: Text.ElideRight
                            }
                        }

                        // Category Badge
                        Rectangle {
                            Layout.preferredHeight: 22
                            Layout.preferredWidth: catLabel.implicitWidth + 14
                            radius: 11
                            color: {
                                if (modelData.category === "Math") return Qt.rgba(0.2, 0.8, 0.4, 0.15);
                                if (modelData.category === "Web") return Qt.rgba(0.3, 0.5, 1.0, 0.15);
                                if (modelData.category === "Windows") return Qt.rgba(1.0, 0.6, 0.1, 0.15);
                                if (modelData.category === "Actions") return Qt.rgba(0.8, 0.3, 0.9, 0.15);
                                return Qt.rgba(0.5, 0.5, 0.5, 0.15);
                            }

                            Text {
                                id: catLabel
                                anchors.centerIn: parent
                                text: modelData.category
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: {
                                    if (modelData.category === "Math") return "#4ade80";
                                    if (modelData.category === "Web") return "#60a5fa";
                                    if (modelData.category === "Windows") return "#fb923c";
                                    if (modelData.category === "Actions") return "#c084fc";
                                    return Theme.muted;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = index;
                            root.executeItem(modelData);
                        }
                    }
                }

                // Empty State
                Text {
                    anchors.centerIn: parent
                    text: "No matches found"
                    font.pixelSize: Constants.fontSizeLg
                    color: Theme.muted
                    visible: root.combinedResults.length === 0
                }
            }
        }

        // Bottom Shortcut Hints
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Constants.sizeMd
            color: Theme.bgSecondary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                spacing: Constants.sizeLg

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 22; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "↑↓"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Navigate"; font.pixelSize: 11; color: Theme.muted }
                }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 22; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "↵"; font.pixelSize: 11; color: Theme.textSecondary }
                    }
                    Text { text: "Execute / Copy"; font.pixelSize: 11; color: Theme.muted }
                }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 32; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Tab"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Filter"; font.pixelSize: 11; color: Theme.muted }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 30; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Close"; font.pixelSize: 11; color: Theme.muted }
                }
            }
        }
    }
}
