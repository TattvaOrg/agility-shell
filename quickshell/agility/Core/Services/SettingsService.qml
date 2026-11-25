import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
pragma Singleton

Item {
    id: settingsService

    property bool settingsLoaded: false
    property string packageManagerMode: "install"
    property int clipboardMaxItems: 100
    property var enabledKbLayouts: ["us", "latam"]
    property string githubUsername: ""
    property string githubToken: ""
    property string musicPlayer: "none"
    property string musicPlayerCommand: ""
    property bool isSettingsLoading: settingsLoader.running
    property string quoteCategory: "All"
    property string fontFamily: "Geist"
    property real fontScale: 1
    property real hyprScale: 1
    property bool clock24h: true
    property bool clockSeconds: false
    property bool clockShowDate: true
    property string cursorTheme: "Bibata-Modern-Classic"
    property int cursorSize: Constants.size2Xl
    property string barPosition: "top" // "top", "bottom", "left", "right"
    readonly property bool isBarTop: barPosition === "top" || barPosition === ""
    readonly property bool isBarBottom: barPosition === "bottom"
    readonly property bool isBarLeft: barPosition === "left"
    readonly property bool isBarRight: barPosition === "right"
    readonly property bool isBarVertical: isBarLeft || isBarRight
    readonly property bool isBarHorizontal: isBarTop || isBarBottom
    property string barStyle: "convex"
    property bool barIslandMode: barStyle === "island"
    property bool barConvexMode: barStyle === "convex"
    property bool barPillMode: barStyle === "pill"
    property string islandRightMode: "auto"
    property int pillBarWidthPercent: 60
    property string pillPopupStyle: "top"
    property string pillWidgetLayout: "distributed"
    property int pillBarThickness: 38
    property bool bluetoothOnStartup: false
    property bool soundEffectsEnabled: true

    // Bar Icon customization
    property string barIconMode: "cycle" // "cycle", "single", "custom"
    property string barIconShape: "dashboard" // default single shape
    property var barIconCycleShapes: ["dashboard", "sparkle", "flower", "scallop", "hexagon", "arch"]
    property int barIconCycleInterval: 8 // seconds
    property string barIconCustomSvg: ""

    property bool barAutoHide: false
    property bool barOpenOnHover: false
    property string barGlassMode: "solid"
    property string barSolidTone: "black" // "black", "white"
    property int barGlassOpacity: 85
    property bool appletActiveWindow: true
    property string appletActiveWindowAction: "maximize"
    property bool appletDynamicMedia: true
    property bool appletMediaVisualizer: true
    property bool appletWeather: true
    property string appletWeatherUnit: "C"
    property bool appletBattery: true
    property bool appletBatteryShowTime: true
    property bool appletNetwork: false
    property bool appletDnd: false
    property bool dndEnabled: false
    // Desktop Widgets (Awe suite)
    property bool desktopWidgetsEnabled: true
    property bool widgetManagerNotchEnabled: true

    // Dock (macOS / iPadOS dynamic magnification dock)
    property bool dockEnabled: true
    property string dockPosition: "bottom" // "bottom", "left", "right", "top"
    property bool dockAutoHide: true
    property int dockIconSize: 48
    property int dockItemSpacing: 8
    property bool dockMagnification: true
    property var dockPinnedApps: [] // [{ id, name, icon, exec, desktopId, terminal }]
    property bool dockShowLauncher: true
    property bool dockShowTrash: true

    // Spotlight Command Bar
    property bool spotlightEnabled: true
    property alias omniLauncherEnabled: settingsService.spotlightEnabled

    // Dynamic Island / Live Activities Hub
    property bool dynamicIslandEnabled: true

    // Mission Control / Visual Workspace Overview
    property bool missionControlEnabled: true
    readonly property int barWidgetHeight: {
        if (barPillMode) {
            return Math.max(18, Math.min(44, Math.round(pillBarThickness - 10)));
        }
        return 28;
    }
    property bool edgeLightingEnabled: true
    property string edgeLightingColorMode: "album_art"
    property color edgeLightingCustomColor: Theme.accent
    property real edgeLightingSpeed: 1.0
    property real edgeLightingLength: 25.0
    property real edgeLightingThickness: 12.0
    property real edgeLightingGlow: 16.0
    property bool edgeLightingAudioOnly: false
    property string edgeLightingDirection: "clockwise"
    property var actionShortcuts: [
        {"id": "launcher", "title": "Open Launcher", "key": "Mod+Space", "cmd": ["agl", "toggle", "launcher"]},
        {"id": "settings", "title": "Open Settings", "key": "Mod+S", "cmd": ["agl", "toggle", "settings"]},
        {"id": "controlCenter", "title": "Control Center", "key": "Mod+C", "cmd": ["agl", "toggle", "cc"]},
        {"id": "dashboard", "title": "Open Dash", "key": "Mod+D", "cmd": ["agl", "toggle", "dash"]},
        {"id": "wallpaper", "title": "Wallpaper Gallery", "key": "Mod+Shift+W", "cmd": ["agl", "toggle", "WallpaperPicker"]},
        {"id": "clipboard", "title": "Clipboard History", "key": "Mod+V", "cmd": ["agl", "toggle", "clipboard"]},
        {"id": "screenshot", "title": "Screenshot Tool", "key": "Mod+Shift+S", "cmd": ["agl", "toggle", "screenshot"]},
        {"id": "powerMenu", "title": "Power Menu", "key": "Mod+Shift+E", "cmd": ["agl", "toggle", "power"]},
        {"id": "edgeLighting", "title": "Toggle Edge Lighting", "key": "Mod+Shift+Z", "cmd": ["agl", "toggle", "edgelight"]},
        {"id": "spotlight", "title": "Spotlight Command Bar", "key": "Mod+K", "cmd": ["agl", "toggle", "spotlight"]},
        {"id": "dock", "title": "Toggle Dock", "key": "Mod+Alt+D", "cmd": ["agl", "toggle", "dock"]},
        {"id": "dynamicIsland", "title": "Toggle Dynamic Island", "key": "Mod+Alt+I", "cmd": ["agl", "toggle", "island"]}
    ]
    property var customShortcuts: []

    // Settings Window Presentation
    property string settingsWindowMode: "half" // "full", "half", "boxed"
    property int settingsBoxedWidth: 960
    property int settingsBoxedHeight: 680

    function syncShortcuts() {
        let payload = JSON.stringify({
            "actionShortcuts": settingsService.actionShortcuts,
            "customShortcuts": settingsService.customShortcuts
        });
        syncShortcutsProc.command = ["python3", Quickshell.shellDir + "/Modules/Settings/scripts/sync_shortcuts.py", payload];
        syncShortcutsProc.running = false;
        syncShortcutsProc.running = true;
    }

    function _normKey(val) {
        if (!val) return "";
        return String(val).trim().toLowerCase().replace(/\.desktop$/, "");
    }

    function _execBin(execStr) {
        if (!execStr) return "";
        let cleaned = String(execStr).replace(/%[a-zA-Z]/g, "").trim();
        let parts = cleaned.split(/\s+/);
        for (let i = 0; i < parts.length; i++) {
            let p = parts[i];
            if (!p || p === "env" || p.indexOf("=") !== -1) continue;
            let slash = p.lastIndexOf("/");
            return (slash !== -1 ? p.substring(slash + 1) : p).toLowerCase();
        }
        return "";
    }

    function _keysForEntry(entry) {
        let keys = [];
        if (!entry) return keys;
        if (typeof entry === "string") {
            let k = _normKey(entry);
            if (k) keys.push(k);
            return keys;
        }
        let raw = [entry.id, entry.desktopId, entry.rawClass, entry.name];
        for (let i = 0; i < raw.length; i++) {
            let k = _normKey(raw[i]);
            if (k && keys.indexOf(k) === -1) keys.push(k);
        }
        let bin = _execBin(entry.exec);
        if (bin && keys.indexOf(bin) === -1) keys.push(bin);
        return keys;
    }

    function _entriesMatch(a, b) {
        let ka = _keysForEntry(a);
        let kb = _keysForEntry(b);
        for (let i = 0; i < ka.length; i++) {
            if (kb.indexOf(ka[i]) !== -1) return true;
        }
        return false;
    }

    function pinApp(appObj) {
        if (!appObj) return;
        let id = appObj.id || appObj.desktopId || appObj.rawClass || appObj.name;
        if (!id) return;
        let current = Array.isArray(dockPinnedApps) ? dockPinnedApps.slice() : [];
        for (let i = 0; i < current.length; i++) {
            if (_entriesMatch(current[i], appObj)) return;
        }
        current.push({
            "id": String(id),
            "name": appObj.name || String(id),
            "icon": appObj.icon || "application-x-executable",
            "exec": appObj.exec || String(id),
            "desktopId": appObj.desktopId || String(id),
            "rawClass": appObj.rawClass || "",
            "terminal": Boolean(appObj.terminal)
        });
        dockPinnedApps = current;
        if (settingsLoaded) saveSettings();
    }

    function unpinApp(appIdOrObj) {
        if (!appIdOrObj) return;
        let current = Array.isArray(dockPinnedApps) ? dockPinnedApps.slice() : [];
        let filtered = current.filter(item => !_entriesMatch(item, appIdOrObj));
        if (filtered.length !== current.length) {
            dockPinnedApps = filtered;
            if (settingsLoaded) saveSettings();
        }
    }

    function movePinnedApp(fromIndex, toIndex) {
        let current = Array.isArray(dockPinnedApps) ? dockPinnedApps.slice() : [];
        if (fromIndex < 0 || fromIndex >= current.length) return;
        if (toIndex < 0 || toIndex >= current.length || fromIndex === toIndex) return;
        let item = current.splice(fromIndex, 1)[0];
        current.splice(toIndex, 0, item);
        dockPinnedApps = current;
        if (settingsLoaded) saveSettings();
    }

    function isAppPinned(appIdOrObj) {
        if (!appIdOrObj || !Array.isArray(dockPinnedApps)) return false;
        for (let i = 0; i < dockPinnedApps.length; i++) {
            if (_entriesMatch(dockPinnedApps[i], appIdOrObj)) return true;
        }
        return false;
    }

    function togglePinApp(appObj) {
        if (!appObj) return;
        if (isAppPinned(appObj)) {
            unpinApp(appObj);
        } else {
            pinApp(appObj);
        }
    }

    function increaseDockSize() {
        if (dockIconSize < 84) {
            dockIconSize = Math.min(84, dockIconSize + 4);
            if (settingsLoaded) saveSettings();
        }
    }

    function decreaseDockSize() {
        if (dockIconSize > 28) {
            dockIconSize = Math.max(28, dockIconSize - 4);
            if (settingsLoaded) saveSettings();
        }
    }

    function increaseDockSpacing() {
        if (dockItemSpacing < 24) {
            dockItemSpacing = Math.min(24, dockItemSpacing + 2);
            if (settingsLoaded) saveSettings();
        }
    }

    function decreaseDockSpacing() {
        if (dockItemSpacing > 2) {
            dockItemSpacing = Math.max(2, dockItemSpacing - 2);
            if (settingsLoaded) saveSettings();
        }
    }

    function saveSettings() {
        saveTimer.restart();
    }

    function load() {
        if (!settingsLoaded && !isSettingsLoading)
            settingsLoader.running = true;

    }

    function applyCursor(theme, size) {
        let t = theme !== undefined ? theme : cursorTheme;
        let s = size !== undefined ? size : cursorSize;
        applyCursorProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_cursor.py", t, s.toString()];
        applyCursorProc.running = false;
        applyCursorProc.running = true;
    }

    function applyFont(font, size) {
        let f = font !== undefined ? font : fontFamily;
        let s = size !== undefined ? size : Math.round(11 * fontScale);
        applyFontProc.command = ["python3", Quickshell.shellDir + "/Scripts/theme/apply_font.py", f, s.toString()];
        applyFontProc.running = false;
        applyFontProc.running = true;
    }

    Component.onCompleted: {
        load();
    }
    onClipboardMaxItemsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onEnabledKbLayoutsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onGithubUsernameChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onGithubTokenChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onMusicPlayerChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onMusicPlayerCommandChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onQuoteCategoryChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onFontFamilyChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onFontScaleChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyFont(fontFamily, Math.round(11 * fontScale));
        }
    }
    onHyprScaleChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClock24hChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockSecondsChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onClockShowDateChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onCursorThemeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onCursorSizeChanged: {
        if (settingsLoaded) {
            saveSettings();
            applyCursor(cursorTheme, cursorSize);
        }
    }
    onBarStyleChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onIslandRightModeChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onPillBarWidthPercentChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onPillPopupStyleChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onPillWidgetLayoutChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarAutoHideChanged: {
        if (settingsLoaded)
            saveSettings();

    }
    onBarPositionChanged: { if (settingsLoaded) saveSettings(); }
    onDockEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onDockPositionChanged: { if (settingsLoaded) saveSettings(); }
    onDockAutoHideChanged: { if (settingsLoaded) saveSettings(); }
    onDockIconSizeChanged: { if (settingsLoaded) saveSettings(); }
    onDockMagnificationChanged: { if (settingsLoaded) saveSettings(); }
    onDockPinnedAppsChanged: { if (settingsLoaded) saveSettings(); }
    onDockItemSpacingChanged: { if (settingsLoaded) saveSettings(); }
    onDockShowLauncherChanged: { if (settingsLoaded) saveSettings(); }
    onDockShowTrashChanged: { if (settingsLoaded) saveSettings(); }
    onBarOpenOnHoverChanged: { if (settingsLoaded) saveSettings(); }
    onBarGlassModeChanged: { if (settingsLoaded) saveSettings(); }
    onBarSolidToneChanged: { if (settingsLoaded) saveSettings(); }
    onBarGlassOpacityChanged: { if (settingsLoaded) saveSettings(); }
    onPillBarThicknessChanged: { if (settingsLoaded) saveSettings(); }
    onBluetoothOnStartupChanged: { if (settingsLoaded) saveSettings(); }
    onSoundEffectsEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onBarIconModeChanged: { if (settingsLoaded) saveSettings(); }
    onBarIconShapeChanged: { if (settingsLoaded) saveSettings(); }
    onBarIconCycleShapesChanged: { if (settingsLoaded) saveSettings(); }
    onBarIconCycleIntervalChanged: { if (settingsLoaded) saveSettings(); }
    onBarIconCustomSvgChanged: { if (settingsLoaded) saveSettings(); }
    onActionShortcutsChanged: { if (settingsLoaded) saveSettings(); }
    onCustomShortcutsChanged: { if (settingsLoaded) saveSettings(); }
    onSettingsWindowModeChanged: { if (settingsLoaded) saveSettings(); }
    onSettingsBoxedWidthChanged: { if (settingsLoaded) saveSettings(); }
    onSettingsBoxedHeightChanged: { if (settingsLoaded) saveSettings(); }
    onAppletActiveWindowChanged: { if (settingsLoaded) saveSettings(); }
    onAppletActiveWindowActionChanged: { if (settingsLoaded) saveSettings(); }
    onAppletDynamicMediaChanged: { if (settingsLoaded) saveSettings(); }
    onAppletMediaVisualizerChanged: { if (settingsLoaded) saveSettings(); }
    onAppletWeatherChanged: { if (settingsLoaded) saveSettings(); }
    onAppletWeatherUnitChanged: { if (settingsLoaded) saveSettings(); }
    onAppletBatteryChanged: { if (settingsLoaded) saveSettings(); }
    onAppletBatteryShowTimeChanged: { if (settingsLoaded) saveSettings(); }
    onAppletNetworkChanged: { if (settingsLoaded) saveSettings(); }
    onAppletDndChanged: { if (settingsLoaded) saveSettings(); }
    onDndEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingColorModeChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingCustomColorChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingSpeedChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingLengthChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingThicknessChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingGlowChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingAudioOnlyChanged: { if (settingsLoaded) saveSettings(); }
    onEdgeLightingDirectionChanged: { if (settingsLoaded) saveSettings(); }
    onDesktopWidgetsEnabledChanged: { if (settingsLoaded) saveSettings(); }
    onWidgetManagerNotchEnabledChanged: { if (settingsLoaded) saveSettings(); }

    Timer {
        id: saveTimer

        interval: 100
        repeat: false
        onTriggered: {
            let data = {
                "performanceInterval": SystemInfoService.performanceInterval,
                "powerProfile": SystemInfoService.powerProfile,
                "packageManagerChecksEnabled": UpdateService.packageManagerChecksEnabled,
                "packageManagerCheckInterval": UpdateService.packageManagerCheckInterval,
                "clipboardMaxItems": settingsService.clipboardMaxItems,
                "enabledKbLayouts": settingsService.enabledKbLayouts,
                "animationSpeedFactor": HyprlandService.animationSpeedFactor,
                "githubUsername": settingsService.githubUsername,
                "githubToken": settingsService.githubToken,
                "musicPlayer": settingsService.musicPlayer,
                "musicPlayerCommand": settingsService.musicPlayerCommand,
                "nightLightActive": DisplayProfileService.nightLightActive,
                "caffeineActive": false,
                "gameModeActive": DisplayProfileService.gameModeActive,
                "nightLightTemperature": DisplayProfileService.nightLightTemperature,
                "keyboardLayout": HyprlandService.keyboardLayout,
                "wpAutoShuffle": HyprlandService.wpAutoShuffle,
                "wpShuffleInterval": HyprlandService.wpShuffleInterval,
                "wpEnableTransitions": HyprlandService.wpEnableTransitions,
                "wpTransitionType": HyprlandService.wpTransitionType,
                "wpTransitionPos": HyprlandService.wpTransitionPos,
                "wpTransitionStep": HyprlandService.wpTransitionStep,
                "wpTransitionFps": HyprlandService.wpTransitionFps,
                "wpTransitionAngle": HyprlandService.wpTransitionAngle,
                "wpResizeMode": HyprlandService.wpResizeMode,
                "wpCropGravity": HyprlandService.wpCropGravity,
                "wpSourceMode": HyprlandService.wpSourceMode,
                "wpCustomFolderPath": HyprlandService.wpCustomFolderPath,
                "wpClicksEnabled": HyprlandService.wpClicksEnabled,
                "micMuted": AudioService.micMuted,
                "micVolume": AudioService.micVolume,
                "quoteCategory": settingsService.quoteCategory,
                "fontFamily": settingsService.fontFamily,
                "fontScale": settingsService.fontScale,
                "hyprScale": settingsService.hyprScale,
                "clock24h": settingsService.clock24h,
                "clockSeconds": settingsService.clockSeconds,
                "clockShowDate": settingsService.clockShowDate,
                "cursorTheme": settingsService.cursorTheme,
                "cursorSize": settingsService.cursorSize,
                "barPosition": settingsService.barPosition,
                "barStyle": settingsService.barStyle,
                "islandRightMode": settingsService.islandRightMode,
                "pillBarWidthPercent": settingsService.pillBarWidthPercent,
                "pillBarThickness": settingsService.pillBarThickness,
                "pillPopupStyle": settingsService.pillPopupStyle,
                "pillWidgetLayout": settingsService.pillWidgetLayout,
                "bluetoothOnStartup": settingsService.bluetoothOnStartup,
                "soundEffectsEnabled": settingsService.soundEffectsEnabled,
                "barIconMode": settingsService.barIconMode,
                "barIconShape": settingsService.barIconShape,
                "barIconCycleShapes": settingsService.barIconCycleShapes,
                "barIconCycleInterval": settingsService.barIconCycleInterval,
                "barIconCustomSvg": settingsService.barIconCustomSvg,
                "barAutoHide": settingsService.barAutoHide,
                "barOpenOnHover": settingsService.barOpenOnHover,
                "barGlassMode": settingsService.barGlassMode,
                "barSolidTone": settingsService.barSolidTone,
                "barGlassOpacity": settingsService.barGlassOpacity,
                "appletActiveWindow": settingsService.appletActiveWindow,
                "appletActiveWindowAction": settingsService.appletActiveWindowAction,
                "appletDynamicMedia": settingsService.appletDynamicMedia,
                "appletMediaVisualizer": settingsService.appletMediaVisualizer,
                "appletWeather": settingsService.appletWeather,
                "appletWeatherUnit": settingsService.appletWeatherUnit,
                "appletBattery": settingsService.appletBattery,
                "appletBatteryShowTime": settingsService.appletBatteryShowTime,
                "appletNetwork": settingsService.appletNetwork,
                "appletDnd": settingsService.appletDnd,
                "dndEnabled": settingsService.dndEnabled,
                "actionShortcuts": settingsService.actionShortcuts,
                "customShortcuts": settingsService.customShortcuts,
                "settingsWindowMode": settingsService.settingsWindowMode,
                "settingsBoxedWidth": settingsService.settingsBoxedWidth,
                "settingsBoxedHeight": settingsService.settingsBoxedHeight,
                "edgeLightingEnabled": settingsService.edgeLightingEnabled,
                "edgeLightingColorMode": settingsService.edgeLightingColorMode,
                "edgeLightingCustomColor": settingsService.edgeLightingCustomColor.toString(),
                "edgeLightingSpeed": settingsService.edgeLightingSpeed,
                "edgeLightingLength": settingsService.edgeLightingLength,
                "edgeLightingThickness": settingsService.edgeLightingThickness,
                "edgeLightingGlow": settingsService.edgeLightingGlow,
                "edgeLightingAudioOnly": settingsService.edgeLightingAudioOnly,
                "edgeLightingDirection": settingsService.edgeLightingDirection,
                "desktopWidgetsEnabled": settingsService.desktopWidgetsEnabled,
                "widgetManagerNotchEnabled": settingsService.widgetManagerNotchEnabled,
                "dockEnabled": settingsService.dockEnabled,
                "dockPosition": settingsService.dockPosition,
                "dockAutoHide": settingsService.dockAutoHide,
                "dockIconSize": settingsService.dockIconSize,
                "dockItemSpacing": settingsService.dockItemSpacing,
                "dockMagnification": settingsService.dockMagnification,
                "dockPinnedApps": settingsService.dockPinnedApps,
                "dockShowLauncher": settingsService.dockShowLauncher,
                "dockShowTrash": settingsService.dockShowTrash,
                "spotlightEnabled": settingsService.spotlightEnabled,
                "dynamicIslandEnabled": settingsService.dynamicIslandEnabled,
                "missionControlEnabled": settingsService.missionControlEnabled
            };
            syncShortcuts();
            settingsSaver.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/save_settings.py", JSON.stringify(data)];
            settingsSaver.running = false;
            settingsSaver.running = true;
        }
    }

    Process {
        id: settingsLoader

        command: ["python3", Quickshell.shellDir + "/Core/Services/scripts/read_settings.py"]
        stdout: StdioCollector {
            id: settingsLoaderOutput
        }
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (settingsLoaderOutput.text && settingsLoaderOutput.text.trim() !== "") {
                    try {
                        let prefs = JSON.parse(settingsLoaderOutput.text.trim());
                        if (prefs.powerProfile !== undefined) {
                            SystemInfoService.powerProfile = prefs.powerProfile;
                            SystemInfoService.applyProfile(prefs.powerProfile);
                        } else {
                            SystemInfoService.applyProfile("balanced");
                        }
                        if (prefs.performanceInterval !== undefined)
                            SystemInfoService.performanceInterval = prefs.performanceInterval;

                        if (prefs.packageManagerChecksEnabled !== undefined)
                            UpdateService.packageManagerChecksEnabled = prefs.packageManagerChecksEnabled;

                        if (prefs.packageManagerCheckInterval !== undefined)
                            UpdateService.packageManagerCheckInterval = prefs.packageManagerCheckInterval;

                        if (prefs.clipboardMaxItems !== undefined)
                            settingsService.clipboardMaxItems = prefs.clipboardMaxItems;

                        if (prefs.animationSpeedFactor !== undefined)
                            HyprlandService.animationSpeedFactor = prefs.animationSpeedFactor;

                        if (prefs.githubUsername !== undefined)
                            settingsService.githubUsername = prefs.githubUsername;

                        if (prefs.githubToken !== undefined)
                            settingsService.githubToken = prefs.githubToken;

                        if (prefs.musicPlayer !== undefined)
                            settingsService.musicPlayer = prefs.musicPlayer;

                        if (prefs.musicPlayerCommand !== undefined)
                            settingsService.musicPlayerCommand = prefs.musicPlayerCommand;

                        if (prefs.nightLightActive !== undefined)
                            DisplayProfileService.nightLightActive = prefs.nightLightActive;

                        // Caffeine always starts as OFF on fresh boot
                        DisplayProfileService.caffeineActive = false;

                        if (prefs.gameModeActive !== undefined)
                            DisplayProfileService.gameModeActive = prefs.gameModeActive;

                        if (prefs.nightLightTemperature !== undefined)
                            DisplayProfileService.nightLightTemperature = prefs.nightLightTemperature;

                        if (prefs.keyboardLayout !== undefined)
                            HyprlandService.keyboardLayout = prefs.keyboardLayout;

                        if (prefs.enabledKbLayouts !== undefined)
                            settingsService.enabledKbLayouts = prefs.enabledKbLayouts;

                        if (prefs.wpAutoShuffle !== undefined)
                            HyprlandService.wpAutoShuffle = prefs.wpAutoShuffle;

                        if (prefs.wpShuffleInterval !== undefined)
                            HyprlandService.wpShuffleInterval = prefs.wpShuffleInterval;

                        if (prefs.wpEnableTransitions !== undefined)
                            HyprlandService.wpEnableTransitions = prefs.wpEnableTransitions;

                        if (prefs.wpTransitionType !== undefined)
                            HyprlandService.wpTransitionType = prefs.wpTransitionType;

                        if (prefs.wpTransitionPos !== undefined)
                            HyprlandService.wpTransitionPos = prefs.wpTransitionPos;

                        if (prefs.wpTransitionStep !== undefined)
                            HyprlandService.wpTransitionStep = prefs.wpTransitionStep;

                        if (prefs.wpTransitionFps !== undefined)
                            HyprlandService.wpTransitionFps = prefs.wpTransitionFps;

                        if (prefs.wpTransitionAngle !== undefined)
                            HyprlandService.wpTransitionAngle = prefs.wpTransitionAngle;

                        if (prefs.wpResizeMode !== undefined)
                            HyprlandService.wpResizeMode = prefs.wpResizeMode;

                        if (prefs.wpCropGravity !== undefined)
                            HyprlandService.wpCropGravity = prefs.wpCropGravity;

                        if (prefs.wpSourceMode !== undefined)
                            HyprlandService.wpSourceMode = prefs.wpSourceMode;

                        if (prefs.wpCustomFolderPath !== undefined)
                            HyprlandService.wpCustomFolderPath = prefs.wpCustomFolderPath;

                        if (prefs.wpClicksEnabled !== undefined)
                            HyprlandService.wpClicksEnabled = prefs.wpClicksEnabled;

                        if (prefs.micVolume !== undefined) {
                            AudioService.micVolume = AudioService.hasPhysicalMic ? prefs.micVolume : 0;
                            if (AudioService.hasPhysicalMic)
                                AudioService.setMicVolume(prefs.micVolume);

                        }
                        if (prefs.micMuted !== undefined) {
                            AudioService.micMuted = AudioService.hasPhysicalMic ? prefs.micMuted : true;
                            if (AudioService.hasPhysicalMic)
                                AudioService.setMicMuted(prefs.micMuted);

                        }
                        if (prefs.quoteCategory !== undefined)
                            settingsService.quoteCategory = prefs.quoteCategory;

                        if (prefs.fontFamily !== undefined)
                            settingsService.fontFamily = prefs.fontFamily;

                        if (prefs.fontScale !== undefined)
                            settingsService.fontScale = prefs.fontScale;

                        if (prefs.hyprScale !== undefined) {
                            settingsService.hyprScale = prefs.hyprScale;
                            hyprScaleApplyProc.running = true;
                        }
                        if (prefs.clock24h !== undefined)
                            settingsService.clock24h = prefs.clock24h;

                        if (prefs.clockSeconds !== undefined)
                            settingsService.clockSeconds = prefs.clockSeconds;

                        if (prefs.clockShowDate !== undefined)
                            settingsService.clockShowDate = prefs.clockShowDate;

                        if (prefs.cursorTheme !== undefined)
                            settingsService.cursorTheme = prefs.cursorTheme;

                        if (prefs.cursorSize !== undefined)
                            settingsService.cursorSize = prefs.cursorSize;

                        applyCursor(settingsService.cursorTheme, settingsService.cursorSize);
                        applyFont(settingsService.fontFamily, Math.round(11 * settingsService.fontScale));
                        if (prefs.barPosition !== undefined) {
                            settingsService.barPosition = prefs.barPosition;
                        }
                        if (prefs.barStyle !== undefined) {
                            if (prefs.barStyle === "island")
                                settingsService.barStyle = "island";
                            else if (prefs.barStyle === "pill")
                                settingsService.barStyle = "pill";
                            else
                                settingsService.barStyle = "convex";
                        }
                        if (prefs.islandRightMode !== undefined)
                            settingsService.islandRightMode = prefs.islandRightMode;

                        if (prefs.pillBarWidthPercent !== undefined) {
                            let pbw = parseInt(prefs.pillBarWidthPercent);
                            if (!isNaN(pbw) && pbw >= 30 && pbw <= 100)
                                settingsService.pillBarWidthPercent = pbw;
                        }

                        if (prefs.pillBarThickness !== undefined) {
                            let pbt = parseInt(prefs.pillBarThickness);
                            if (!isNaN(pbt) && pbt >= 24 && pbt <= 60)
                                settingsService.pillBarThickness = pbt;
                        }

                        if (prefs.bluetoothOnStartup !== undefined)
                            settingsService.bluetoothOnStartup = Boolean(prefs.bluetoothOnStartup);

                        if (prefs.soundEffectsEnabled !== undefined)
                            settingsService.soundEffectsEnabled = Boolean(prefs.soundEffectsEnabled);

                        if (prefs.barIconMode !== undefined)
                            settingsService.barIconMode = prefs.barIconMode;

                        if (prefs.barIconShape !== undefined)
                            settingsService.barIconShape = prefs.barIconShape;

                        if (prefs.barIconCycleShapes !== undefined && Array.isArray(prefs.barIconCycleShapes))
                            settingsService.barIconCycleShapes = prefs.barIconCycleShapes;

                        if (prefs.barIconCycleInterval !== undefined) {
                            let bci = parseInt(prefs.barIconCycleInterval);
                            if (!isNaN(bci) && bci >= 3 && bci <= 60)
                                settingsService.barIconCycleInterval = bci;
                        }

                        if (prefs.barIconCustomSvg !== undefined)
                            settingsService.barIconCustomSvg = prefs.barIconCustomSvg;

                        if (prefs.pillPopupStyle !== undefined) {
                            if (prefs.pillPopupStyle === "sided" || prefs.pillPopupStyle === "top" || prefs.pillPopupStyle === "center")
                                settingsService.pillPopupStyle = prefs.pillPopupStyle;
                        }

                        if (prefs.pillWidgetLayout !== undefined) {
                            if (prefs.pillWidgetLayout === "distributed" || prefs.pillWidgetLayout === "centered")
                                settingsService.pillWidgetLayout = prefs.pillWidgetLayout;
                        }

                        if (prefs.barAutoHide !== undefined)
                            settingsService.barAutoHide = Boolean(prefs.barAutoHide);

                        if (prefs.barOpenOnHover !== undefined)
                            settingsService.barOpenOnHover = Boolean(prefs.barOpenOnHover);

                        if (prefs.barGlassMode !== undefined)
                            settingsService.barGlassMode = prefs.barGlassMode;
                        if (prefs.barSolidTone !== undefined)
                            settingsService.barSolidTone = prefs.barSolidTone;
                        if (prefs.barGlassOpacity !== undefined)
                            settingsService.barGlassOpacity = prefs.barGlassOpacity;
                        if (prefs.appletActiveWindow !== undefined)
                            settingsService.appletActiveWindow = prefs.appletActiveWindow;
                        if (prefs.appletActiveWindowAction !== undefined)
                            settingsService.appletActiveWindowAction = prefs.appletActiveWindowAction;
                        if (prefs.appletDynamicMedia !== undefined)
                            settingsService.appletDynamicMedia = prefs.appletDynamicMedia;
                        if (prefs.appletMediaVisualizer !== undefined)
                            settingsService.appletMediaVisualizer = prefs.appletMediaVisualizer;
                        if (prefs.appletWeather !== undefined)
                            settingsService.appletWeather = prefs.appletWeather;
                        if (prefs.appletWeatherUnit !== undefined)
                            settingsService.appletWeatherUnit = prefs.appletWeatherUnit;
                        if (prefs.appletBattery !== undefined)
                            settingsService.appletBattery = prefs.appletBattery;
                        if (prefs.appletBatteryShowTime !== undefined)
                            settingsService.appletBatteryShowTime = prefs.appletBatteryShowTime;
                        if (prefs.appletNetwork !== undefined)
                            settingsService.appletNetwork = prefs.appletNetwork;
                        if (prefs.appletDnd !== undefined)
                            settingsService.appletDnd = prefs.appletDnd;
                        if (prefs.dndEnabled !== undefined)
                            settingsService.dndEnabled = prefs.dndEnabled;

                        if (prefs.actionShortcuts !== undefined)
                            settingsService.actionShortcuts = prefs.actionShortcuts;

                        if (prefs.customShortcuts !== undefined)
                            settingsService.customShortcuts = prefs.customShortcuts;

                        if (prefs.settingsWindowMode !== undefined)
                            settingsService.settingsWindowMode = prefs.settingsWindowMode;
                        if (prefs.settingsBoxedWidth !== undefined)
                            settingsService.settingsBoxedWidth = prefs.settingsBoxedWidth;
                        if (prefs.settingsBoxedHeight !== undefined)
                            settingsService.settingsBoxedHeight = prefs.settingsBoxedHeight;

                        if (prefs.edgeLightingEnabled !== undefined)
                            settingsService.edgeLightingEnabled = prefs.edgeLightingEnabled;
                        if (prefs.edgeLightingColorMode !== undefined)
                            settingsService.edgeLightingColorMode = prefs.edgeLightingColorMode;
                        if (prefs.edgeLightingCustomColor !== undefined)
                            settingsService.edgeLightingCustomColor = prefs.edgeLightingCustomColor;
                        if (prefs.edgeLightingSpeed !== undefined)
                            settingsService.edgeLightingSpeed = prefs.edgeLightingSpeed;
                        if (prefs.edgeLightingLength !== undefined)
                            settingsService.edgeLightingLength = prefs.edgeLightingLength;
                        if (prefs.edgeLightingThickness !== undefined)
                            settingsService.edgeLightingThickness = prefs.edgeLightingThickness;
                        if (prefs.edgeLightingGlow !== undefined)
                            settingsService.edgeLightingGlow = prefs.edgeLightingGlow;
                        if (prefs.edgeLightingAudioOnly !== undefined)
                            settingsService.edgeLightingAudioOnly = prefs.edgeLightingAudioOnly;
                        if (prefs.edgeLightingDirection !== undefined)
                            settingsService.edgeLightingDirection = prefs.edgeLightingDirection;
                        if (prefs.desktopWidgetsEnabled !== undefined)
                            settingsService.desktopWidgetsEnabled = prefs.desktopWidgetsEnabled;
                        if (prefs.widgetManagerNotchEnabled !== undefined)
                            settingsService.widgetManagerNotchEnabled = prefs.widgetManagerNotchEnabled;
                        if (prefs.dockEnabled !== undefined)
                            settingsService.dockEnabled = Boolean(prefs.dockEnabled);
                        if (prefs.dockPosition !== undefined && (prefs.dockPosition === "bottom" || prefs.dockPosition === "top" || prefs.dockPosition === "left" || prefs.dockPosition === "right"))
                            settingsService.dockPosition = prefs.dockPosition;
                        if (prefs.dockAutoHide !== undefined)
                            settingsService.dockAutoHide = Boolean(prefs.dockAutoHide);
                        if (prefs.dockIconSize !== undefined) {
                            let dis = parseInt(prefs.dockIconSize);
                            if (!isNaN(dis))
                                settingsService.dockIconSize = Math.max(28, Math.min(84, dis));
                        }
                        if (prefs.dockItemSpacing !== undefined) {
                            let dsp = parseInt(prefs.dockItemSpacing);
                            if (!isNaN(dsp))
                                settingsService.dockItemSpacing = Math.max(2, Math.min(24, dsp));
                        }
                        if (prefs.dockMagnification !== undefined)
                            settingsService.dockMagnification = Boolean(prefs.dockMagnification);
                        if (prefs.dockPinnedApps !== undefined && Array.isArray(prefs.dockPinnedApps))
                            settingsService.dockPinnedApps = prefs.dockPinnedApps;
                        if (prefs.dockShowLauncher !== undefined)
                            settingsService.dockShowLauncher = Boolean(prefs.dockShowLauncher);
                        if (prefs.dockShowTrash !== undefined)
                            settingsService.dockShowTrash = Boolean(prefs.dockShowTrash);
                        if (prefs.spotlightEnabled !== undefined)
                            settingsService.spotlightEnabled = prefs.spotlightEnabled;
                        else if (prefs.omniLauncherEnabled !== undefined)
                            settingsService.spotlightEnabled = prefs.omniLauncherEnabled;
                        if (prefs.dynamicIslandEnabled !== undefined)
                            settingsService.dynamicIslandEnabled = prefs.dynamicIslandEnabled;
                        if (prefs.missionControlEnabled !== undefined)
                            settingsService.missionControlEnabled = prefs.missionControlEnabled;

                    } catch (e) {
                        console.error("Error loading settings: " + e);
                        SystemInfoService.applyProfile("balanced");
                    }
                }
                settingsService.settingsLoaded = true;
                if (!settingsService.bluetoothOnStartup) {
                    bluetoothStartupProc.running = false;
                    bluetoothStartupProc.running = true;
                }
                HyprlandService.triggerStartupTimer();
            } else {
                settingsService.settingsLoaded = true;
                SystemInfoService.applyProfile("balanced");
                settingsService.saveSettings();
                if (!settingsService.bluetoothOnStartup) {
                    bluetoothStartupProc.running = false;
                    bluetoothStartupProc.running = true;
                }
                HyprlandService.triggerStartupTimer();
                settingsService.applyCursor(settingsService.cursorTheme, settingsService.cursorSize);
                settingsService.applyFont(settingsService.fontFamily, Math.round(11 * settingsService.fontScale));
            }
        }
    }

    Process {
        id: bluetoothStartupProc
        command: ["bluetoothctl", "power", "off"]
    }

    Process {
        id: syncShortcutsProc
    }

    Process {
        id: settingsSaver

        onExited: function(exitCode) {
            if (exitCode !== 0) {
                console.error("Agility Shell: settingsSaver exited with code " + exitCode);
            }
        }
    }

    Process {
        id: hyprScaleApplyProc

        command: ["sh", "-c", Quickshell.shellDir + "/Scripts/system/hypr_scale.sh " + settingsService.hyprScale]
    }

    Process {
        id: applyCursorProc
    }

    Process {
        id: applyFontProc
    }

}
