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
    property string barStyle: "convex"
    property bool barIslandMode: barStyle === "island"
    property bool barConvexMode: barStyle === "convex"
    property bool barPillMode: barStyle === "pill"
    property string islandRightMode: "auto"
    property int pillBarWidthPercent: 60
    property string pillPopupStyle: "center"
    readonly property int barWidgetHeight: 28
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
                "pillPopupStyle": settingsService.pillPopupStyle,
                "actionShortcuts": settingsService.actionShortcuts,
                "customShortcuts": settingsService.customShortcuts,
                "edgeLightingEnabled": settingsService.edgeLightingEnabled,
                "edgeLightingColorMode": settingsService.edgeLightingColorMode,
                "edgeLightingCustomColor": settingsService.edgeLightingCustomColor.toString(),
                "edgeLightingSpeed": settingsService.edgeLightingSpeed,
                "edgeLightingLength": settingsService.edgeLightingLength,
                "edgeLightingThickness": settingsService.edgeLightingThickness,
                "edgeLightingGlow": settingsService.edgeLightingGlow,
                "edgeLightingAudioOnly": settingsService.edgeLightingAudioOnly,
                "edgeLightingDirection": settingsService.edgeLightingDirection
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

                        if (prefs.pillPopupStyle !== undefined) {
                            if (prefs.pillPopupStyle === "sided" || prefs.pillPopupStyle === "top" || prefs.pillPopupStyle === "center")
                                settingsService.pillPopupStyle = prefs.pillPopupStyle;
                        }

                        if (prefs.actionShortcuts !== undefined)
                            settingsService.actionShortcuts = prefs.actionShortcuts;

                        if (prefs.customShortcuts !== undefined)
                            settingsService.customShortcuts = prefs.customShortcuts;

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

                    } catch (e) {
                        console.error("Error loading settings: " + e);
                        SystemInfoService.applyProfile("balanced");
                    }
                }
                settingsService.settingsLoaded = true;
                HyprlandService.triggerStartupTimer();
            } else {
                SystemInfoService.applyProfile("balanced");
                settingsService.saveSettings();
                settingsService.settingsLoaded = true;
                HyprlandService.triggerStartupTimer();
                settingsService.applyCursor(settingsService.cursorTheme, settingsService.cursorSize);
                settingsService.applyFont(settingsService.fontFamily, Math.round(11 * settingsService.fontScale));
            }
        }
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
