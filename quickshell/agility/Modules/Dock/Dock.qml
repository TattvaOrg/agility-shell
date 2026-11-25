import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

Item {
    id: root

    // Reactive Combined Dock App Model (Pinned + Running)
    readonly property var dockAppList: {
        let list = [];
        let seenRunningIds = {};
        let seenKeys = {};

        // 1. Pinned Apps from Settings
        let pinned = Array.isArray(SettingsService.dockPinnedApps) ? SettingsService.dockPinnedApps : [];
        for (let i = 0; i < pinned.length; i++) {
            let p = pinned[i];
            if (!p) continue;

            let running = WindowTrackerService.findRunningForPinned(p);
            let pId = (p.id || p.desktopId || p.rawClass || p.name || "").toLowerCase().replace(/\.desktop$/, "");
            if (running && running.id) {
                seenRunningIds[running.id] = true;
            }

            let resolvedIcon = p.icon;
            if (!resolvedIcon || resolvedIcon === "application-x-executable" || resolvedIcon === "applications-other") {
                if (running && running.icon) resolvedIcon = running.icon;
            }

            let entry = {
                "id": running ? running.id : pId,
                "desktopId": p.desktopId || p.id || pId,
                "rawClass": p.rawClass || (running ? running.rawClass : ""),
                "name": p.name || (running ? running.name : pId),
                "icon": resolvedIcon || "application-x-executable",
                "exec": p.exec || (running ? running.exec : pId),
                "terminal": Boolean(p.terminal || (running && running.terminal)),
                "isPinned": true,
                "isRunning": Boolean(running && running.windowCount > 0),
                "isFocused": Boolean(running && running.isFocused),
                "windows": running ? running.windows : [],
                "windowCount": running ? running.windowCount : 0
            };
            list.push(entry);
            if (pId) seenKeys[pId] = true;
            if (p.name) seenKeys[p.name.toLowerCase()] = true;
        }

        // 2. Open / Running Apps from Compositor Window Tracker
        let runningList = WindowTrackerService.runningApps || [];
        for (let j = 0; j < runningList.length; j++) {
            let r = runningList[j];
            if (!r) continue;
            let rId = (r.id || "").toLowerCase().replace(/\.desktop$/, "");
            let rName = (r.name || "").toLowerCase();

            if (!seenRunningIds[rId] && !seenKeys[rId] && !seenKeys[rName]) {
                let entry = {
                    "id": rId,
                    "desktopId": rId,
                    "rawClass": r.rawClass || rId,
                    "name": r.name || rId,
                    "icon": r.icon || "application-x-executable",
                    "exec": r.exec || rId,
                    "terminal": Boolean(r.terminal),
                    "isPinned": false,
                    "isRunning": true,
                    "isFocused": Boolean(r.isFocused),
                    "windows": r.windows || [],
                    "windowCount": r.windowCount || 1
                };
                list.push(entry);
                seenRunningIds[rId] = true;
            }
        }

        return list;
    }

    function resolveIconSource(iconName) {
        if (!iconName) return "";
        let path = String(iconName);
        let home = Quickshell.env("HOME") || "";
        if (path.startsWith("$HOME")) {
            path = home + path.substring(5);
        } else if (path.startsWith("~")) {
            path = home + path.substring(1);
        }
        if (path.startsWith("/") || path.startsWith("file://")) {
            return path.startsWith("file://") ? path : ("file://" + path);
        }
        return Quickshell.iconPath(path, true);
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockPanel
            required property var modelData
            screen: modelData

            readonly property bool isBottom: SettingsService.dockPosition === "bottom" || SettingsService.dockPosition === ""
            readonly property bool isTop: SettingsService.dockPosition === "top"
            readonly property bool isLeft: SettingsService.dockPosition === "left"
            readonly property bool isRight: SettingsService.dockPosition === "right"
            readonly property bool isHorizontal: isBottom || isTop

            readonly property bool sharesEdgeWithBar: {
                if (isBottom && SettingsService.isBarBottom) return true;
                if (isTop && SettingsService.isBarTop) return true;
                if (isLeft && SettingsService.isBarLeft) return true;
                if (isRight && SettingsService.isBarRight) return true;
                return false;
            }

            readonly property bool barReservesSpace: {
                if (!sharesEdgeWithBar) return false;
                if (SettingsService.isBarVertical) return true;
                return !(SettingsService.barAutoHide && (SettingsService.barIslandMode || SettingsService.barPillMode));
            }

            readonly property int barVisualThickness: SettingsService.isBarVertical
                ? 48
                : (BarStyleConfig.barHeight(SettingsService.barStyle) + BarStyleConfig.barMarginTop(SettingsService.barStyle) + 4)

            // Offset cleanly past the bar when both share an edge and the bar is visible
            // (except when compositor already stacks ExclusionMode.Normal below a reserving bar)
            readonly property int barOffsetMargin: {
                if (!sharesEdgeWithBar) return 0;
                if (!SettingsService.dockAutoHide && barReservesSpace) return 0;
                if (barReservesSpace) return barVisualThickness;
                // Auto-hiding bar on same edge: offset while bar is visible (empty workspace or dock revealing at edge)
                if (!AppState.hasWindowOnScreen || (SettingsService.dockAutoHide && revealed)) return barVisualThickness;
                return 0;
            }

            readonly property int edgeGap: 6
            readonly property int capsuleThickness: SettingsService.dockIconSize + 10

            // Per-monitor context menu state
            property var activeMenuApp: null
            property real menuAnchorCenterX: dockPanel.width / 2
            property real menuAnchorCenterY: dockPanel.height / 2

            // Auto-hide state with smooth debounce
            property bool revealed: !SettingsService.dockAutoHide
            readonly property bool rawHovered: stripHoverHandler.hovered || edgeHoverHandler.hovered || activeMenuApp !== null
            readonly property real slideDistance: (isHorizontal ? (dockStrip.height + dockPanel.barOffsetMargin + 18) : (dockStrip.width + dockPanel.barOffsetMargin + 18))
            property real hideOffset: (SettingsService.dockAutoHide && !revealed)
                ? (isBottom ? slideDistance : (isTop ? -slideDistance : (isLeft ? -slideDistance : slideDistance)))
                : 0

            function syncAutoHideState() {
                if (!SettingsService.dockAutoHide) {
                    hideDebounceTimer.stop();
                    revealed = true;
                } else if (rawHovered) {
                    hideDebounceTimer.stop();
                    revealed = true;
                } else {
                    hideDebounceTimer.restart();
                }
            }

            onRawHoveredChanged: syncAutoHideState()

            Connections {
                target: SettingsService
                function onDockAutoHideChanged() {
                    dockPanel.syncAutoHideState();
                }
                function onDockPositionChanged() {
                    dockPanel.activeMenuApp = null;
                    dockPanel.syncAutoHideState();
                }
                function onDockEnabledChanged() {
                    if (!SettingsService.dockEnabled) {
                        dockPanel.activeMenuApp = null;
                    }
                }
            }

            Timer {
                id: hideDebounceTimer
                interval: 260
                repeat: false
                onTriggered: {
                    if (SettingsService.dockAutoHide && !dockPanel.rawHovered) {
                        dockPanel.revealed = false;
                    }
                }
            }

            Behavior on hideOffset {
                NumberAnimation {
                    duration: Constants.animNormal
                    easing.type: Easing.OutCubic
                }
            }

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: SettingsService.dockAutoHide ? ExclusionMode.Ignore : ExclusionMode.Normal
            WlrLayershell.exclusiveZone: SettingsService.dockAutoHide ? 0 : (dockPanel.capsuleThickness + dockPanel.edgeGap + 4)
            color: "transparent"
            focusable: false
            visible: SettingsService.settingsLoaded && SettingsService.dockEnabled && !DisplayProfileService.gameModeActive

            anchors {
                bottom: isBottom || !isHorizontal
                top: isTop || !isHorizontal
                left: isLeft || isHorizontal
                right: isRight || isHorizontal
            }

            implicitWidth: isHorizontal
                ? 0
                : (dockPanel.activeMenuApp !== null
                    ? Math.max(dockStrip.width + dockPanel.barOffsetMargin + 250, 320)
                    : (dockStrip.width + dockPanel.barOffsetMargin + 56))
            implicitHeight: isHorizontal
                ? (dockPanel.activeMenuApp !== null
                    ? Math.max(dockStrip.height + dockPanel.barOffsetMargin + 380, 420)
                    : (dockStrip.height + dockPanel.barOffsetMargin + 52))
                : 0

            mask: Region {
                // 1. Dock capsule region (only interactive when revealed or auto-hide is off)
                Region {
                    readonly property bool stripInteractive: !SettingsService.dockAutoHide || dockPanel.revealed
                    x: stripInteractive ? dockStrip.x : 0
                    y: stripInteractive ? dockStrip.y : 0
                    width: stripInteractive ? dockStrip.width : 0
                    height: stripInteractive ? dockStrip.height : 0
                }
                // 2. Thin screen-edge hover trigger when auto-hide is active
                Region {
                    x: SettingsService.dockAutoHide ? edgeTrigger.x : 0
                    y: SettingsService.dockAutoHide ? edgeTrigger.y : 0
                    width: SettingsService.dockAutoHide ? edgeTrigger.width : 0
                    height: SettingsService.dockAutoHide ? edgeTrigger.height : 0
                }
                // 3. Full-panel dismiss overlay when context menu is open
                Region {
                    readonly property bool menuOpen: dockPanel.activeMenuApp !== null
                    x: 0
                    y: 0
                    width: menuOpen ? dockPanel.width : 0
                    height: menuOpen ? dockPanel.height : 0
                }
            }

            function openContextMenuFor(anchorItem, appData) {
                if (!anchorItem) return;
                let centerPt = anchorItem.mapToItem(dockPanel.contentItem, anchorItem.width / 2, anchorItem.height / 2);
                dockPanel.menuAnchorCenterX = centerPt.x;
                dockPanel.menuAnchorCenterY = centerPt.y;
                dockPanel.activeMenuApp = appData;
            }

            // Dismiss context menu when clicking outside
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                enabled: dockPanel.activeMenuApp !== null
                z: 500
                onClicked: {
                    dockPanel.activeMenuApp = null;
                }
            }

            // Screen edge trigger zone for auto-hide
            Item {
                id: edgeTrigger
                z: 2
                visible: SettingsService.dockAutoHide

                readonly property int triggerOffset: (dockPanel.sharesEdgeWithBar && dockPanel.barReservesSpace)
                    ? dockPanel.barVisualThickness
                    : 0

                anchors {
                    bottom: dockPanel.isBottom ? parent.bottom : undefined
                    top: dockPanel.isTop ? parent.top : undefined
                    left: dockPanel.isLeft ? parent.left : undefined
                    right: dockPanel.isRight ? parent.right : undefined
                    horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                    verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                    bottomMargin: dockPanel.isBottom ? triggerOffset : 0
                    topMargin: dockPanel.isTop ? triggerOffset : 0
                    leftMargin: dockPanel.isLeft ? triggerOffset : 0
                    rightMargin: dockPanel.isRight ? triggerOffset : 0
                }

                width: dockPanel.isHorizontal ? Math.max(240, dockStrip.width + 64) : 6
                height: dockPanel.isHorizontal ? 6 : Math.max(240, dockStrip.height + 64)

                HoverHandler {
                    id: edgeHoverHandler
                    enabled: SettingsService.dockAutoHide
                }
            }

            // Drop shadow rendered strictly BEHIND dockStrip
            ThemedShadow {
                anchors.fill: dockStrip
                radius: dockStrip.radius
                opacity: dockStrip.opacity * 0.40
                active: dockStrip.opacity > 0.01
                z: 9
                transform: Translate {
                    y: dockPanel.isHorizontal ? dockPanel.hideOffset : 0
                    x: !dockPanel.isHorizontal ? dockPanel.hideOffset : 0
                }
            }

            // Floating Capsule Container
            Rectangle {
                id: dockStrip
                z: 10
                opacity: (!SettingsService.dockAutoHide || dockPanel.revealed) ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Constants.animFast
                        easing.type: Easing.OutQuad
                    }
                }

                anchors {
                    bottom: dockPanel.isBottom ? parent.bottom : undefined
                    top: dockPanel.isTop ? parent.top : undefined
                    left: dockPanel.isLeft ? parent.left : undefined
                    right: dockPanel.isRight ? parent.right : undefined
                    horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                    verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                    bottomMargin: dockPanel.isBottom ? (dockPanel.edgeGap + dockPanel.barOffsetMargin) : 0
                    topMargin: dockPanel.isTop ? (dockPanel.edgeGap + dockPanel.barOffsetMargin) : 0
                    leftMargin: dockPanel.isLeft ? (dockPanel.edgeGap + dockPanel.barOffsetMargin) : 0
                    rightMargin: dockPanel.isRight ? (dockPanel.edgeGap + dockPanel.barOffsetMargin) : 0

                    Behavior on bottomMargin { NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on topMargin { NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on leftMargin { NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic } }
                    Behavior on rightMargin { NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutCubic } }
                }

                transform: Translate {
                    y: dockPanel.isHorizontal ? dockPanel.hideOffset : 0
                    x: !dockPanel.isHorizontal ? dockPanel.hideOffset : 0
                }

                width: dockPanel.isHorizontal ? Math.max(40, dockContentGrid.implicitWidth + 14) : dockPanel.capsuleThickness
                height: dockPanel.isHorizontal ? dockPanel.capsuleThickness : Math.max(40, dockContentGrid.implicitHeight + 14)
                radius: Math.min(18, Math.round((dockPanel.isHorizontal ? height : width) / 2))

                color: Theme.isDark
                    ? Qt.rgba(Theme._rawBg.r * 0.65 + 0.03, Theme._rawBg.g * 0.65 + 0.03, Theme._rawBg.b * 0.65 + 0.05, 0.88)
                    : Qt.rgba(0.97, 0.97, 0.99, 0.90)
                border.width: 1
                border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.09)

                // HoverHandler never gets blocked by child MouseAreas
                HoverHandler {
                    id: stripHoverHandler
                    margin: 6
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0) {
                            SettingsService.increaseDockSize();
                        } else if (event.angleDelta.y < 0) {
                            SettingsService.decreaseDockSize();
                        }
                    }
                }

                // Right-click background capsule to open Dock Controls
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: function(mouse) {
                        dockPanel.openContextMenuFor(dockStrip, {
                            "id": "dock_settings",
                            "name": "Dock Controls",
                            "isPinned": false,
                            "isRunning": false,
                            "windows": []
                        });
                    }
                }

                // Unified Horizontal/Vertical Dock Content Grid
                Grid {
                    id: dockContentGrid
                    anchors.centerIn: parent
                    columns: dockPanel.isHorizontal ? 999 : 1
                    spacing: SettingsService.dockItemSpacing
                    horizontalItemAlignment: Grid.AlignHCenter
                    verticalItemAlignment: Grid.AlignVCenter

                    // 1. Applications Launcher Button (Leading slot)
                    Item {
                        id: launcherBtnSlot
                        visible: SettingsService.dockShowLauncher
                        width: SettingsService.dockIconSize
                        height: SettingsService.dockIconSize

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(width * 0.30)
                            color: launcherHover.hovered ? Theme.bgSecondary : "transparent"

                            Behavior on color { ColorAnimation { duration: Constants.animFast } }

                            HoverHandler { id: launcherHover }

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "apps"
                                iconSize: Math.max(14, Math.round(SettingsService.dockIconSize * 0.56))
                                iconColor: launcherHover.hovered ? Theme.accent : Theme.fg
                                flat: true
                            }

                            // Tooltip
                            Rectangle {
                                visible: launcherHover.hovered && dockPanel.activeMenuApp === null
                                anchors.bottom: dockPanel.isBottom ? parent.top : undefined
                                anchors.top: dockPanel.isTop ? parent.bottom : undefined
                                anchors.left: dockPanel.isLeft ? parent.right : undefined
                                anchors.right: dockPanel.isRight ? parent.left : undefined
                                anchors.horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                                anchors.verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                                anchors.margins: 8
                                width: launcherTipText.implicitWidth + 14
                                height: 22
                                radius: 6
                                color: Theme.isDark ? "#12151D" : "#FFFFFF"
                                border.width: 1
                                border.color: Theme.border
                                z: 200

                                ThemedText {
                                    id: launcherTipText
                                    anchors.centerIn: parent
                                    text: "Applications"
                                    customSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        dockPanel.openContextMenuFor(launcherBtnSlot, {
                                            "id": "dock_settings",
                                            "name": "Dock Controls",
                                            "isPinned": false,
                                            "isRunning": false,
                                            "windows": []
                                        });
                                    } else {
                                        dockPanel.activeMenuApp = null;
                                        SoundService.play("click");
                                        AppState.toggleWidget("launcher");
                                    }
                                }
                            }
                        }
                    }

                    // Divider after Launcher
                    Rectangle {
                        visible: SettingsService.dockShowLauncher && (root.dockAppList.length > 0 || SettingsService.dockShowTrash)
                        width: dockPanel.isHorizontal ? 1 : Math.max(14, SettingsService.dockIconSize - 10)
                        height: dockPanel.isHorizontal ? Math.max(14, SettingsService.dockIconSize - 10) : 1
                        color: Theme.border
                        opacity: 0.65
                    }

                    // 2. Apps Central Section (Pinned + Running)
                    Repeater {
                        model: root.dockAppList

                        Item {
                            id: itemWrapper
                            required property var modelData
                            required property int index

                            readonly property real baseSlotSize: SettingsService.dockIconSize
                            readonly property real cursorDist: {
                                if (!stripHoverHandler.hovered || !SettingsService.dockMagnification) return 999;
                                let pointerAxis = dockPanel.isHorizontal
                                    ? stripHoverHandler.point.position.x
                                    : stripHoverHandler.point.position.y;
                                let itemCenter = (dockPanel.isHorizontal
                                    ? (dockContentGrid.x + itemWrapper.x)
                                    : (dockContentGrid.y + itemWrapper.y)) + (baseSlotSize / 2);
                                return Math.abs(pointerAxis - itemCenter);
                            }
                            property real magScale: {
                                if (cursorDist > 80) return 1.0;
                                let ratio = Math.cos((cursorDist / 80) * (Math.PI / 2));
                                return 1.0 + (0.22 * ratio);
                            }

                            Behavior on magScale {
                                NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
                            }

                            width: baseSlotSize
                            height: baseSlotSize
                            z: itemHover.hovered ? 25 : Math.round(magScale * 10)

                            Rectangle {
                                id: iconBox
                                width: itemWrapper.baseSlotSize
                                height: itemWrapper.baseSlotSize
                                radius: Math.round(width * 0.30)
                                color: (itemHover.hovered || (dockPanel.activeMenuApp && dockPanel.activeMenuApp.id === itemWrapper.modelData.id))
                                    ? Theme.bgSecondary
                                    : (itemWrapper.modelData.isFocused ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : "transparent")

                                Behavior on color { ColorAnimation { duration: Constants.animFast } }

                                transformOrigin: dockPanel.isBottom
                                    ? Item.Bottom
                                    : (dockPanel.isTop ? Item.Top : (dockPanel.isLeft ? Item.Left : Item.Right))
                                scale: itemWrapper.magScale

                                HoverHandler { id: itemHover }

                                // App Icon (crisp, proportional to slot)
                                Image {
                                    id: desktopIconImage
                                    anchors.centerIn: parent
                                    width: Math.max(16, itemWrapper.baseSlotSize - 6)
                                    height: width
                                    sourceSize: Qt.size(64, 64)
                                    source: root.resolveIconSource(itemWrapper.modelData.icon)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: "rocket"
                                    iconSize: Math.max(14, Math.round(itemWrapper.baseSlotSize * 0.60))
                                    iconColor: (itemHover.hovered || itemWrapper.modelData.isFocused) ? Theme.accent : Theme.fg
                                    flat: true
                                    visible: desktopIconImage.status !== Image.Ready && desktopIconImage.status !== Image.Loading
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            dockPanel.openContextMenuFor(itemWrapper, itemWrapper.modelData);
                                        } else {
                                            dockPanel.activeMenuApp = null;
                                            SoundService.play("click");
                                            if (itemWrapper.modelData.isRunning) {
                                                WindowTrackerService.focusApp(itemWrapper.modelData);
                                            } else {
                                                WindowTrackerService.launchApp(itemWrapper.modelData);
                                            }
                                        }
                                    }
                                }
                            }

                            // Running Pill/Dots Indicator along outer edge
                            Grid {
                                visible: itemWrapper.modelData.isRunning
                                columns: dockPanel.isHorizontal ? 3 : 1
                                spacing: 2
                                anchors.horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                                anchors.verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                                anchors.top: dockPanel.isBottom ? parent.bottom : undefined
                                anchors.bottom: dockPanel.isTop ? parent.top : undefined
                                anchors.right: dockPanel.isLeft ? parent.left : undefined
                                anchors.left: dockPanel.isRight ? parent.right : undefined
                                anchors.topMargin: dockPanel.isBottom ? 1 : 0
                                anchors.bottomMargin: dockPanel.isTop ? 1 : 0
                                anchors.rightMargin: dockPanel.isLeft ? 1 : 0
                                anchors.leftMargin: dockPanel.isRight ? 1 : 0

                                Repeater {
                                    model: Math.min(3, Math.max(1, itemWrapper.modelData.windowCount))
                                    Rectangle {
                                        width: dockPanel.isHorizontal ? (itemWrapper.modelData.isFocused ? 8 : 4) : 3
                                        height: dockPanel.isHorizontal ? 3 : (itemWrapper.modelData.isFocused ? 8 : 4)
                                        radius: 1.5
                                        color: itemWrapper.modelData.isFocused ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                    }
                                }
                            }

                            // Tooltip popup (unscaled, always inward toward desktop)
                            Rectangle {
                                visible: itemHover.hovered && dockPanel.activeMenuApp === null
                                anchors.bottom: dockPanel.isBottom ? parent.top : undefined
                                anchors.top: dockPanel.isTop ? parent.bottom : undefined
                                anchors.left: dockPanel.isLeft ? parent.right : undefined
                                anchors.right: dockPanel.isRight ? parent.left : undefined
                                anchors.horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                                anchors.verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                                anchors.margins: Math.round(8 + (itemWrapper.magScale - 1.0) * itemWrapper.baseSlotSize)
                                width: tooltipText.implicitWidth + 14
                                height: 22
                                radius: 6
                                color: Theme.isDark ? "#12151D" : "#FFFFFF"
                                border.width: 1
                                border.color: Theme.border
                                z: 200

                                ThemedText {
                                    id: tooltipText
                                    anchors.centerIn: parent
                                    text: itemWrapper.modelData.name + (itemWrapper.modelData.windowCount > 1 ? (" (" + itemWrapper.modelData.windowCount + ")") : "")
                                    customSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                }
                            }
                        }
                    }

                    // Divider before Trash
                    Rectangle {
                        visible: SettingsService.dockShowTrash && (root.dockAppList.length > 0 || SettingsService.dockShowLauncher)
                        width: dockPanel.isHorizontal ? 1 : Math.max(14, SettingsService.dockIconSize - 10)
                        height: dockPanel.isHorizontal ? Math.max(14, SettingsService.dockIconSize - 10) : 1
                        color: Theme.border
                        opacity: 0.65
                    }

                    // 3. Trash Slot (Trailing slot)
                    Item {
                        id: trashBtnSlot
                        visible: SettingsService.dockShowTrash
                        width: SettingsService.dockIconSize
                        height: SettingsService.dockIconSize

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(width * 0.30)
                            color: trashHover.hovered ? Theme.bgSecondary : "transparent"

                            Behavior on color { ColorAnimation { duration: Constants.animFast } }

                            HoverHandler { id: trashHover }

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "trash"
                                iconSize: Math.max(14, Math.round(SettingsService.dockIconSize * 0.54))
                                iconColor: trashHover.hovered ? Theme.accent : Theme.fg
                                flat: true
                            }

                            Rectangle {
                                visible: trashHover.hovered && dockPanel.activeMenuApp === null
                                anchors.bottom: dockPanel.isBottom ? parent.top : undefined
                                anchors.top: dockPanel.isTop ? parent.bottom : undefined
                                anchors.left: dockPanel.isLeft ? parent.right : undefined
                                anchors.right: dockPanel.isRight ? parent.left : undefined
                                anchors.horizontalCenter: dockPanel.isHorizontal ? parent.horizontalCenter : undefined
                                anchors.verticalCenter: !dockPanel.isHorizontal ? parent.verticalCenter : undefined
                                anchors.margins: 8
                                width: trashTipText.implicitWidth + 14
                                height: 22
                                radius: 6
                                color: Theme.isDark ? "#12151D" : "#FFFFFF"
                                border.width: 1
                                border.color: Theme.border
                                z: 200

                                ThemedText {
                                    id: trashTipText
                                    anchors.centerIn: parent
                                    text: "Trash"
                                    customSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        dockPanel.openContextMenuFor(trashBtnSlot, {
                                            "id": "dock_settings",
                                            "name": "Dock Controls",
                                            "isPinned": false,
                                            "isRunning": false,
                                            "windows": []
                                        });
                                    } else {
                                        dockPanel.activeMenuApp = null;
                                        SoundService.play("click");
                                        Quickshell.execDetached(["agl", "launch-exec", "xdg-open trash:///"]);
                                    }
                                }
                            }
                        }
                    }

                    // 4. Fallback empty dock anchor (when Launcher, Trash, and Apps are all empty)
                    Item {
                        id: emptyDockSlot
                        visible: !SettingsService.dockShowLauncher && !SettingsService.dockShowTrash && root.dockAppList.length === 0
                        width: SettingsService.dockIconSize
                        height: SettingsService.dockIconSize

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(width * 0.30)
                            color: emptyHover.hovered ? Theme.bgSecondary : "transparent"

                            HoverHandler { id: emptyHover }

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "dock"
                                iconSize: Math.max(14, Math.round(SettingsService.dockIconSize * 0.54))
                                iconColor: emptyHover.hovered ? Theme.accent : Theme.muted
                                flat: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: {
                                    dockPanel.openContextMenuFor(emptyDockSlot, {
                                        "id": "dock_settings",
                                        "name": "Dock Controls",
                                        "isPinned": false,
                                        "isRunning": false,
                                        "windows": []
                                    });
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────
            // QUICK SELECTOR & RIGHT-CLICK CONTEXT MENU
            // ─────────────────────────────────────────────
            ThemedShadow {
                anchors.fill: contextMenuBox
                radius: contextMenuBox.radius
                opacity: 0.55
                visible: active && contextMenuBox.visible && HyprlandService.hyprShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")
                z: 999
            }

            Rectangle {
                id: contextMenuBox
                visible: dockPanel.activeMenuApp !== null
                width: 224
                height: menuContentCol.implicitHeight + 16
                z: 1000

                x: {
                    if (dockPanel.isHorizontal) {
                        return Math.max(12, Math.min(dockPanel.width - width - 12, dockPanel.menuAnchorCenterX - (width / 2)));
                    }
                    if (dockPanel.isLeft) {
                        return Math.min(dockPanel.width - width - 8, dockStrip.x + dockStrip.width + 10);
                    }
                    return Math.max(8, dockStrip.x - width - 10);
                }

                y: {
                    if (dockPanel.isBottom) {
                        return Math.max(8, dockStrip.y - height - 10);
                    }
                    if (dockPanel.isTop) {
                        return Math.min(dockPanel.height - height - 8, dockStrip.y + dockStrip.height + 10);
                    }
                    return Math.max(12, Math.min(dockPanel.height - height - 12, dockPanel.menuAnchorCenterY - (height / 2)));
                }

                radius: Constants.sizeLg
                color: Theme.isDark ? Qt.rgba(0.08, 0.09, 0.13, 0.96) : Qt.rgba(0.98, 0.98, 1.0, 0.96)
                border.width: 1
                border.color: Theme.border

                // Prevent clicks inside menu from hitting dismiss MouseArea
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                }

                ColumnLayout {
                    id: menuContentCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    // App / Controls Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ThemedText {
                            Layout.fillWidth: true
                            text: dockPanel.activeMenuApp ? dockPanel.activeMenuApp.name : ""
                            font.weight: Font.Bold
                            customSize: 12
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.id !== "dock_settings"
                            width: 6; height: 6; radius: 3
                            color: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.isRunning) ? Theme.accent : Theme.muted
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                        opacity: 0.5
                    }

                    // Windows List (Quick Selector)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.windows && dockPanel.activeMenuApp.windows.length > 0

                        ThemedText {
                            text: "WINDOWS (" + (dockPanel.activeMenuApp && dockPanel.activeMenuApp.windows ? dockPanel.activeMenuApp.windows.length : 0) + ")"
                            customSize: 9
                            color: Theme.muted
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.windows) ? dockPanel.activeMenuApp.windows : []

                            Rectangle {
                                id: winItemRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: 6
                                color: winHover.hovered ? Theme.bgSecondary : "transparent"

                                HoverHandler { id: winHover }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        WindowTrackerService.focusWindow(winItemRow.modelData);
                                        dockPanel.activeMenuApp = null;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 6

                                    Rectangle {
                                        width: 4; height: 4; radius: 2
                                        color: winItemRow.modelData.isFocused ? Theme.accent : "transparent"
                                    }

                                    ThemedText {
                                        Layout.fillWidth: true
                                        text: winItemRow.modelData.title || "Window"
                                        customSize: 10
                                        elide: Text.ElideRight
                                        color: winItemRow.modelData.isFocused ? Theme.accent : Theme.fg
                                    }

                                    // Close single window button
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        color: closeHover.hovered ? Qt.rgba(1, 0.2, 0.2, 0.2) : "transparent"

                                        HoverHandler { id: closeHover }

                                        ThemedText {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            customSize: 9
                                            color: closeHover.hovered ? "#FF4B4B" : Theme.muted
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                WindowTrackerService.closeWindow(winItemRow.modelData);
                                                dockPanel.activeMenuApp = null;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.border
                            opacity: 0.5
                        }
                    }

                    // Action: Launch / New Window
                    Rectangle {
                        visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.id !== "dock_settings"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: launchHover.hovered ? Theme.bgSecondary : "transparent"

                        HoverHandler { id: launchHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            SvgIcon {
                                icon: "rocket"
                                iconSize: 14
                                iconColor: Theme.accent
                                flat: true
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.isRunning) ? "New Window" : "Open Application"
                                customSize: 11
                                color: Theme.accent
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SoundService.play("click");
                                if (dockPanel.activeMenuApp) {
                                    WindowTrackerService.launchApp(dockPanel.activeMenuApp);
                                }
                                dockPanel.activeMenuApp = null;
                            }
                        }
                    }

                    // Action: Pin / Unpin (only for real apps)
                    Rectangle {
                        visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.id !== "dock_settings"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: pinHover.hovered ? Theme.bgSecondary : "transparent"

                        HoverHandler { id: pinHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            SvgIcon {
                                icon: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.isPinned) ? "star-filled" : "star"
                                iconSize: 14
                                iconColor: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.isPinned) ? Theme.accent : Theme.fg
                                flat: true
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: (dockPanel.activeMenuApp && dockPanel.activeMenuApp.isPinned) ? "Unpin from Dock" : "Pin to Dock"
                                customSize: 11
                                color: Theme.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SoundService.play("click");
                                if (dockPanel.activeMenuApp) {
                                    SettingsService.togglePinApp(dockPanel.activeMenuApp);
                                }
                                dockPanel.activeMenuApp = null;
                            }
                        }
                    }

                    // Action: Close All Windows (if running)
                    Rectangle {
                        visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.isRunning
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: closeAllHover.hovered ? Qt.rgba(1, 0.2, 0.2, 0.15) : "transparent"

                        HoverHandler { id: closeAllHover }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            SvgIcon {
                                icon: "x"
                                iconSize: 14
                                iconColor: closeAllHover.hovered ? "#FF4B4B" : Theme.fg
                                flat: true
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: "Close All Windows"
                                customSize: 11
                                color: closeAllHover.hovered ? "#FF4B4B" : Theme.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dockPanel.activeMenuApp && dockPanel.activeMenuApp.windows) {
                                    for (let w = 0; w < dockPanel.activeMenuApp.windows.length; w++) {
                                        WindowTrackerService.closeWindow(dockPanel.activeMenuApp.windows[w]);
                                    }
                                }
                                dockPanel.activeMenuApp = null;
                            }
                        }
                    }

                    Rectangle {
                        visible: dockPanel.activeMenuApp && dockPanel.activeMenuApp.id !== "dock_settings"
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.border
                        opacity: 0.5
                    }

                    // Dock Size & Width Stepper
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 6
                        color: Theme.bgSecondary

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 6

                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: decSizeH.hovered ? Theme.accent : Theme.bg
                                border.width: 1; border.color: Theme.border
                                HoverHandler { id: decSizeH }
                                ThemedText {
                                    anchors.centerIn: parent
                                    text: "−"
                                    customSize: 13
                                    font.weight: Font.Bold
                                    color: decSizeH.hovered ? Theme.bg : Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.decreaseDockSize();
                                        SoundService.play("click");
                                    }
                                }
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Size: " + SettingsService.dockIconSize + "px"
                                customSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.fg
                            }

                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: incSizeH.hovered ? Theme.accent : Theme.bg
                                border.width: 1; border.color: Theme.border
                                HoverHandler { id: incSizeH }
                                ThemedText {
                                    anchors.centerIn: parent
                                    text: "+"
                                    customSize: 13
                                    font.weight: Font.Bold
                                    color: incSizeH.hovered ? Theme.bg : Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.increaseDockSize();
                                        SoundService.play("click");
                                    }
                                }
                            }
                        }
                    }

                    // Dock Spacing / Width Spread Stepper
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 6
                        color: Theme.bgSecondary

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 6

                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: decSpH.hovered ? Theme.accent : Theme.bg
                                border.width: 1; border.color: Theme.border
                                HoverHandler { id: decSpH }
                                ThemedText {
                                    anchors.centerIn: parent
                                    text: "−"
                                    customSize: 13
                                    font.weight: Font.Bold
                                    color: decSpH.hovered ? Theme.bg : Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.decreaseDockSpacing();
                                        SoundService.play("click");
                                    }
                                }
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Spread: " + SettingsService.dockItemSpacing + "px"
                                customSize: 11
                                font.weight: Font.DemiBold
                                color: Theme.fg
                            }

                            Rectangle {
                                width: 22; height: 22; radius: 4
                                color: incSpH.hovered ? Theme.accent : Theme.bg
                                border.width: 1; border.color: Theme.border
                                HoverHandler { id: incSpH }
                                ThemedText {
                                    anchors.centerIn: parent
                                    text: "+"
                                    customSize: 13
                                    font.weight: Font.Bold
                                    color: incSpH.hovered ? Theme.bg : Theme.fg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.increaseDockSpacing();
                                        SoundService.play("click");
                                    }
                                }
                            }
                        }
                    }

                    // Quick Auto-Hide Toggle
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: autoHideMenuH.hovered ? Theme.bgSecondary : "transparent"

                        HoverHandler { id: autoHideMenuH }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            SvgIcon {
                                icon: SettingsService.dockAutoHide ? "eye-off" : "eye"
                                iconSize: 14
                                iconColor: SettingsService.dockAutoHide ? Theme.accent : Theme.fg
                                flat: true
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: SettingsService.dockAutoHide ? "Auto-Hide: On" : "Auto-Hide: Off"
                                customSize: 11
                                color: Theme.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SoundService.play("click");
                                SettingsService.dockAutoHide = !SettingsService.dockAutoHide;
                            }
                        }
                    }

                    // Open Dock Settings
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 6
                        color: dockSettingsMenuH.hovered ? Theme.bgSecondary : "transparent"

                        HoverHandler { id: dockSettingsMenuH }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            SvgIcon {
                                icon: "settings-icon"
                                iconSize: 14
                                iconColor: dockSettingsMenuH.hovered ? Theme.accent : Theme.fg
                                flat: true
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: "Dock Settings..."
                                customSize: 11
                                color: Theme.fg
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                SoundService.play("click");
                                dockPanel.activeMenuApp = null;
                                AppState.pendingSettingsTab = 11;
                                AppState.openWidget("minflair_settings");
                            }
                        }
                    }
                }
            }
        }
    }
}
