import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: sidebarRoot

    property int activeTab: 0
    property bool isDesktopBarExpanded: activeTab === 1 || activeTab === 9
    property string searchQuery: ""
    property int sidebarWidth: 260
    property bool isDarkView: Theme.isDark

    signal tabClicked(int index)
    signal closeRequested()

    Layout.preferredWidth: sidebarWidth
    Layout.minimumWidth: sidebarWidth
    Layout.maximumWidth: sidebarWidth
    Layout.fillHeight: true
    color: SettingsService.settingsCustomBackgroundEnabled
        ? (sidebarRoot.isDarkView ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(255, 255, 255, 0.25))
        : (isDarkView ? "#252527" : "#EBECEF")

    // Vertical Divider on right edge
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: SettingsService.settingsCustomBackgroundEnabled
            ? Qt.rgba(255, 255, 255, 0.08)
            : (sidebarRoot.isDarkView ? "#38383A" : "#DCDCDE")
    }

    readonly property var navOrder: [0, 8, 1, 9, 10, 2, 3, 5, 6, 4, 7]
    readonly property var tabKeywords: ({
        "0": "appearance theme dark light font typography colors accent style",
        "1": "desktop bar dock panel island convex pill solid glass autohide height position layout",
        "2": "visual effects blur opacity window animations shadow bloom glow transitions",
        "3": "windows display monitor screen scale scaling hyprland niri boxed fullscreen tiling gaps",
        "4": "integrations apps weather github notifications dnd launcher sound",
        "5": "mouse touchpad trackpad cursor speed sensitivity natural scrolling gestures acceleration",
        "6": "keyboard clipboard layout shortcuts hotkeys keybinds copy paste history repeat delay",
        "7": "about system general hardware kernel memory ram cpu os specs environment software",
        "8": "wallpaper background image screens crop scale shuffle transition slideshow",
        "9": "bar applets widgets visualizer media cava battery clock weather volume status",
        "10": "widgets desktop material floating notch composition awe end clock"
    })

    function matchesSearch(text, category) {
        if (!searchQuery || searchQuery.trim() === "")
            return true;
        let q = searchQuery.toLowerCase().trim();
        return (text && text.toLowerCase().indexOf(q) !== -1) ||
               (category && category.toLowerCase().indexOf(q) !== -1);
    }

    function matchesSearchWithTab(text, category, tabIndex) {
        if (!searchQuery || searchQuery.trim() === "")
            return true;
        let q = searchQuery.toLowerCase().trim();
        if (text && text.toLowerCase().indexOf(q) !== -1)
            return true;
        if (category && category.toLowerCase().indexOf(q) !== -1)
            return true;
        let kw = tabKeywords[tabIndex];
        return kw && kw.indexOf(q) !== -1;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // Top Toolbar: Traffic Lights (Left) & Dark/Light Toggle (Right)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Traffic Lights on Left
                RowLayout {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    spacing: 8

                    HoverHandler {
                        id: trafficLightsHover
                    }

                    // Close (Red)
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FF5F56"
                        border.width: 1
                        border.color: "#E0443E"

                        ThemedText {
                            anchors.centerIn: parent
                            text: "✕"
                            customSize: 8
                            font.weight: Font.Bold
                            color: "#4D0000"
                            visible: trafficLightsHover.hovered
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                sidebarRoot.closeRequested();
                                AppState.closeWidget("minflair_settings");
                            }
                        }
                    }

                    // Minimize (Yellow)
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#FFBD2E"
                        border.width: 1
                        border.color: "#DEA123"

                        ThemedText {
                            anchors.centerIn: parent
                            text: "―"
                            customSize: 7
                            font.weight: Font.Bold
                            color: "#5C3D00"
                            visible: trafficLightsHover.hovered
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                AppState.closeWidget("minflair_settings");
                            }
                        }
                    }

                    // Zoom / Boxed Toggle (Green)
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: "#27C93F"
                        border.width: 1
                        border.color: "#1AAB29"

                        ThemedText {
                            anchors.centerIn: parent
                            text: "+"
                            customSize: 9
                            font.weight: Font.Bold
                            color: "#0B4D16"
                            visible: trafficLightsHover.hovered
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SettingsService.settingsWindowMode = (SettingsService.settingsWindowMode === "boxed" ? "full" : "boxed");
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // macOS Search Field
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 8

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: SettingsService.settingsCustomBackgroundEnabled
                    ? (sidebarRoot.isDarkView ? Qt.rgba(0, 0, 0, 0.3) : Qt.rgba(255, 255, 255, 0.45))
                    : (sidebarRoot.isDarkView ? "#1E1E1E" : "#FFFFFF")
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : (SettingsService.settingsCustomBackgroundEnabled ? Qt.rgba(255, 255, 255, 0.12) : (sidebarRoot.isDarkView ? "#38383A" : "#DCDCDE"))

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    SvgIcon {
                        icon: "sf-magnifyingglass"
                        iconSize: 13
                        flat: true
                        iconColor: Theme.muted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: 12
                        color: sidebarRoot.isDarkView ? "#FFFFFF" : "#1D1D1F"
                        selectByMouse: true
                        selectionColor: Theme.accent
                        clip: true

                        onTextChanged: {
                            sidebarRoot.searchQuery = text;
                        }

                        onAccepted: {
                            for (let i = 0; i < sidebarRoot.navOrder.length; i++) {
                                let t = sidebarRoot.navOrder[i];
                                if (sidebarRoot.matchesSearchWithTab("", "", t)) {
                                    sidebarRoot.tabClicked(t);
                                    break;
                                }
                            }
                        }

                        ThemedText {
                            anchors.fill: parent
                            text: "Search"
                            customSize: 12
                            color: Theme.muted
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    // Clear button
                    Rectangle {
                        visible: searchInput.text !== ""
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.muted
                        Layout.alignment: Qt.AlignVCenter

                        ThemedText {
                            anchors.centerIn: parent
                            text: "✕"
                            customSize: 7
                            color: Theme.bg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                sidebarRoot.searchQuery = "";
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // Scrollable Navigation List (Clean & Direct)
        // ==========================================
        Flickable {
            id: navFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: navCol.implicitHeight + 20

            ColumnLayout {
                id: navCol
                width: navFlickable.width
                spacing: 2

                // Appearance (Tab 0)
                Item {
                    id: appearanceRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Appearance", "Theme", 0)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#007AFF"
                        iconName: "sf-paintpalette"
                        labelText: "Appearance"
                        isActive: sidebarRoot.activeTab === 0
                        onRowClicked: sidebarRoot.tabClicked(0)
                    }
                }

                // Wallpaper (Tab 8)
                Item {
                    id: wallpaperRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Wallpaper", "Background", 8)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#00C7BE"
                        iconName: "sf-photo"
                        labelText: "Wallpaper"
                        isActive: sidebarRoot.activeTab === 8
                        onRowClicked: sidebarRoot.tabClicked(8)
                    }
                }

                // Group 1 Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: sidebarRoot.isDarkView ? "#38383A" : "#DCDCDE"
                    visible: sidebarRoot.searchQuery === ""
                }

                // Desktop Bar (Tab 1)
                Item {
                    id: desktopBarRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Desktop Bar", "Panel", 1)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#48484A"
                        iconName: "sf-dock-rectangle"
                        labelText: "Desktop Bar"
                        hasChevron: true
                        isExpanded: sidebarRoot.isDesktopBarExpanded
                        isActive: sidebarRoot.activeTab === 1
                        onRowClicked: {
                            if (sidebarRoot.activeTab === 1) {
                                sidebarRoot.isDesktopBarExpanded = !sidebarRoot.isDesktopBarExpanded;
                            } else {
                                sidebarRoot.isDesktopBarExpanded = true;
                                sidebarRoot.tabClicked(1);
                            }
                        }
                        onChevronClicked: {
                            sidebarRoot.isDesktopBarExpanded = !sidebarRoot.isDesktopBarExpanded;
                        }
                    }
                }

                // Submenu: Bar Applets (Tab 9)
                ColumnLayout {
                    id: appletsSubmenu
                    Layout.fillWidth: true
                    spacing: 2
                    clip: true
                    visible: (sidebarRoot.isDesktopBarExpanded || sidebarRoot.searchQuery !== "") && sidebarRoot.matchesSearchWithTab("Applets", "Bar", 9)
                    Layout.preferredHeight: visible ? 34 : 0
                    opacity: visible ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Constants.animFast; easing.type: Easing.OutQuad }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        Layout.rightMargin: 10
                        Layout.preferredHeight: 34

                        SidebarNavRow {
                            anchors.fill: parent
                            badgeColor: "#30B0C7"
                            iconName: "sf-slider-horizontal-3"
                            labelText: "Bar Applets"
                            isActive: sidebarRoot.activeTab === 9
                            onRowClicked: sidebarRoot.tabClicked(9)
                        }
                    }
                }

                // Desktop Widgets (Tab 10)
                Item {
                    id: widgetsRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Widgets", "Desktop", 10)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#FF9500"
                        iconName: "sf-square-grid-2x2"
                        labelText: "Widgets"
                        isActive: sidebarRoot.activeTab === 10
                        onRowClicked: sidebarRoot.tabClicked(10)
                    }
                }

                // Visual Effects (Tab 2)
                Item {
                    id: effectsRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Visual Effects", "Animations", 2)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#AF52DE"
                        iconName: "sf-sparkles"
                        labelText: "Visual Effects"
                        isActive: sidebarRoot.activeTab === 2
                        onRowClicked: sidebarRoot.tabClicked(2)
                    }
                }

                // Windows & Displays (Tab 3)
                Item {
                    id: windowsRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Windows & Display", "Monitor", 3)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#0A84FF"
                        iconName: "sf-display"
                        labelText: "Displays & Windows"
                        isActive: sidebarRoot.activeTab === 3
                        onRowClicked: sidebarRoot.tabClicked(3)
                    }
                }

                // Group 2 Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: sidebarRoot.isDarkView ? "#38383A" : "#DCDCDE"
                    visible: sidebarRoot.searchQuery === ""
                }

                // Mouse & Trackpad (Tab 5)
                Item {
                    id: mouseRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Mouse & Touchpad", "Trackpad", 5)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#5E5CE6"
                        iconName: "sf-computermouse"
                        labelText: "Mouse & Trackpad"
                        isActive: sidebarRoot.activeTab === 5
                        onRowClicked: sidebarRoot.tabClicked(5)
                    }
                }

                // Keyboard & Clipboard (Tab 6)
                Item {
                    id: keyboardRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Keyboard & Clipboard", "Shortcuts", 6)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#FF2D55"
                        iconName: "sf-keyboard"
                        labelText: "Keyboard & Clipboard"
                        isActive: sidebarRoot.activeTab === 6
                        onRowClicked: sidebarRoot.tabClicked(6)
                    }
                }

                // Group 3 Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    color: sidebarRoot.isDarkView ? "#38383A" : "#DCDCDE"
                    visible: sidebarRoot.searchQuery === ""
                }

                // Apps & Integrations (Tab 4)
                Item {
                    id: integrationsRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("Integrations & Apps", "Applications", 4)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#34C759"
                        iconName: "sf-app-badge"
                        labelText: "Apps & Integrations"
                        isActive: sidebarRoot.activeTab === 4
                        onRowClicked: sidebarRoot.tabClicked(4)
                    }
                }

                // About System (Tab 7)
                Item {
                    id: aboutRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.preferredHeight: 34
                    visible: sidebarRoot.matchesSearchWithTab("About System", "General", 7)

                    SidebarNavRow {
                        anchors.fill: parent
                        badgeColor: "#8E8E93"
                        iconName: "sf-gearshape"
                        labelText: "General & About"
                        isActive: sidebarRoot.activeTab === 7
                        onRowClicked: sidebarRoot.tabClicked(7)
                    }
                }

                Item {
                    Layout.preferredHeight: 16
                }
            }

            ScrollBar.vertical: ScrollBar {
                parent: navFlickable
                anchors.right: navFlickable.right
                anchors.top: navFlickable.top
                anchors.bottom: navFlickable.bottom
                policy: ScrollBar.AsNeeded
                width: 4
            }
        }
    }
}
