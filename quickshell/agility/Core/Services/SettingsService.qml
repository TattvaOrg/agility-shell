import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.modules.common
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
    property string barStyle: "convex"
    property bool barIslandMode: barStyle === "island"
    property bool barConvexMode: barStyle === "convex"
    property bool barPillMode: barStyle === "pill"
    property string islandRightMode: "auto"
    property int pillBarWidthPercent: 60
    property string pillPopupStyle: "center"
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
        {"id": "edgeLighting", "title": "Toggle Edge Lighting", "key": "Mod+Shift+Z", "cmd": ["agl", "toggle", "edgelight"]}
    ]
    property var customShortcuts: []

    // System Theme & Desktop Presets (Material Theme Engine)
    property string systemTheme: "default" // "default", "material"
    property string desktopPreset: "full_canvas" // "full_canvas", "compact_island", "bottom_waffle", "custom"
    property bool widgetClockEnabled: true
    property bool widgetResourcesEnabled: true
    property bool widgetMediaEnabled: true
    property bool widgetNoteEnabled: true
    property string noteContent: "Welcome to Agility Shell Material Theme!\n• Switch presets in Settings\n• Enjoy wallpaper-adaptive dynamic colors\n• Sub-15ms lightning fast performance"

    function applyDesktopPreset(preset) {
        desktopPreset = preset;
        if (preset === "full_canvas") {
            widgetClockEnabled = true;
            widgetResourcesEnabled = true;
            widgetMediaEnabled = true;
            widgetNoteEnabled = true;
            barStyle = "pill";
            if (typeof Config !== "undefined" && Config.options) {
                Config.options.panelFamily = "ii";
                if (Config.options.bar) {
                    Config.options.bar.bottom = false;
                    Config.options.bar.cornerStyle = 0;
                }
                if (Config.options.dock) Config.options.dock.enable = true;
            }
        } else if (preset === "compact_island") {
            widgetClockEnabled = true;
            widgetResourcesEnabled = false;
            widgetMediaEnabled = true;
            widgetNoteEnabled = false;
            barStyle = "island";
            if (typeof Config !== "undefined" && Config.options) {
                Config.options.panelFamily = "ii";
                if (Config.options.bar) {
                    Config.options.bar.bottom = false;
                    Config.options.bar.cornerStyle = 1;
                }
                if (Config.options.dock) Config.options.dock.enable = false;
            }
        } else if (preset === "bottom_waffle") {
            widgetClockEnabled = false;
            widgetResourcesEnabled = true;
            widgetMediaEnabled = false;
            widgetNoteEnabled = false;
            barStyle = "pill";
            if (typeof Config !== "undefined" && Config.options) {
                Config.options.panelFamily = "waffle";
                if (Config.options.bar) {
                    Config.options.bar.bottom = true;
                    Config.options.bar.cornerStyle = 2;
                }
            }
        }
        if (settingsLoaded)
            saveSettings();
    }

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
    onBarGlassModeChanged: { if (settingsLoaded) saveSettings(); }
    onBarGlassOpacityChanged: { if (settingsLoaded) saveSettings(); }
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
                "caffeineActive": DisplayProfileService.caffeineActive,
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
                "systemTheme": settingsService.systemTheme,
                "desktopPreset": settingsService.desktopPreset,
                "widgetClockEnabled": settingsService.widgetClockEnabled,
                "widgetResourcesEnabled": settingsService.widgetResourcesEnabled,
                "widgetMediaEnabled": settingsService.widgetMediaEnabled,
                "widgetNoteEnabled": settingsService.widgetNoteEnabled,
                "noteContent": settingsService.noteContent
            };
            syncShortcuts();
            settingsSaver.command = ["sh", "-c", "mkdir -p ~/.cache/quickshell /var/tmp/sddm-theme && cat << 'EOF' > ~/.cache/quickshell/settings_prefs.json
" + JSON.stringify(data) + "
EOF
cp ~/.cache/quickshell/settings_prefs.json /var/tmp/sddm-theme/settings_prefs.json 2>/dev/null && chmod 666 /var/tmp/sddm-theme/settings_prefs.json 2>/dev/null || true"];
            settingsSaver.running = true;
        }
    }

    Process {
        id: settingsLoader

        command: ["cat", Quickshell.env("HOME") + "/.cache/quickshell/settings_prefs.json"]
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

                        if (prefs.caffeineActive !== undefined)
                            DisplayProfileService.caffeineActive = prefs.caffeineActive;

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

                        if (prefs.systemTheme !== undefined)
                            settingsService.systemTheme = prefs.systemTheme;
                        if (prefs.desktopPreset !== undefined)
                            settingsService.desktopPreset = prefs.desktopPreset;
                        if (prefs.widgetClockEnabled !== undefined)
                            settingsService.widgetClockEnabled = Boolean(prefs.widgetClockEnabled);
                        if (prefs.widgetResourcesEnabled !== undefined)
                            settingsService.widgetResourcesEnabled = Boolean(prefs.widgetResourcesEnabled);
                        if (prefs.widgetMediaEnabled !== undefined)
                            settingsService.widgetMediaEnabled = Boolean(prefs.widgetMediaEnabled);
                        if (prefs.widgetNoteEnabled !== undefined)
                            settingsService.widgetNoteEnabled = Boolean(prefs.widgetNoteEnabled);
                        if (prefs.noteContent !== undefined)
                            settingsService.noteContent = prefs.noteContent;

                    } catch (e) {
                        console.error("Error loading settings: " + e);
                        SystemInfoService.applyProfile("balanced");
                    }
                }
                settingsService.settingsLoaded = true;
                if (!settingsService.bluetoothOnStartup) {
                    bluetoothStartupProc.running = true;
                }
                HyprlandService.triggerStartupTimer();
            } else {
                SystemInfoService.applyProfile("balanced");
                settingsService.saveSettings();
                settingsService.settingsLoaded = true;
                if (!settingsService.bluetoothOnStartup) {
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
