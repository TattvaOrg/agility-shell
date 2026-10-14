import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

QtObject {
    id: root

    property string currentWallpaper: ""
    property string currentWallpaperPath: ""
    property string transitionType: HyprlandService.wpTransitionType
    property int transitionStep: HyprlandService.wpTransitionStep
    property string transitionPos: HyprlandService.wpTransitionPos
    property int transitionFps: HyprlandService.wpTransitionFps
    property int transitionAngle: HyprlandService.wpTransitionAngle
    property string resizeMode: HyprlandService.wpResizeMode
    property string cropGravity: HyprlandService.wpCropGravity
    property bool enableTransitions: HyprlandService.wpEnableTransitions
    property bool autoShuffle: HyprlandService.wpAutoShuffle
    property int shuffleInterval: HyprlandService.wpShuffleInterval
    property Process wallpaperApplyProc
    property Process wallpaperSaveProc
    property Process wallpaperLoader
    property Process randomWallpaperProc
    property Timer shuffleTimer

    function applyWallpaperWithSync(wallpaperName, rawPath) {
        currentWallpaper = wallpaperName;
        currentWallpaperPath = rawPath;
        applyWallpaper(rawPath);
    }

    function reapplyCurrentWallpaper() {
        let p = currentWallpaperPath || currentWallpaper;
        if (p)
            applyWallpaper(p);
    }

    function applyWallpaperInstant(rawPath) {
        applyWallpaper(rawPath);
    }

    function applyWallpaper(rawPath) {
        if (!rawPath)
            return;
        if (HyprlandService.wpAutoShuffle) {
            HyprlandService.wpAutoShuffle = false;
            SettingsService.saveSettings();
        }
        wallpaperApplyProc.running = false;
        let cmd = ["agl", "wallpaper", rawPath];
        if (enableTransitions && SystemInfoService.powerProfile !== "power-saver" && transitionType) {
            cmd.push("--transition", transitionType);
        }
        wallpaperApplyProc.command = cmd;
        wallpaperApplyProc.startDetached();
    }

    function saveCurrentWallpaper(wallName) {
        // Handled automatically by agl wallpaper
    }

    function shuffle() {
        if (!root.autoShuffle)
            return;
        randomWallpaperProc.running = false;
        randomWallpaperProc.running = true;
    }

    Component.onCompleted: {
        wallpaperLoader.running = true;
    }

    shuffleTimer: Timer {
        interval: Math.max(1, root.shuffleInterval) * 60000
        running: root.autoShuffle
        repeat: true
        onTriggered: {
            if (root.autoShuffle)
                root.shuffle();
        }
    }

    wallpaperApplyProc: Process {
    }

    wallpaperSaveProc: Process {
    }

    randomWallpaperProc: Process {
        command: ["agl", "wallpaper", "random"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let path = randomWallOutput.text.trim();
                if (path && path !== "none") {
                    let parts = path.split('/');
                    root.currentWallpaper = parts[parts.length - 1];
                    root.currentWallpaperPath = path;
                }
            }
        }

        stdout: StdioCollector {
            id: randomWallOutput
        }

    }

    wallpaperLoader: Process {
        command: ["agl", "wallpaper", "get"]
        onExited: function(exitCode) {
            if (exitCode === 0) {
                let path = wallpaperLoaderOutput.text.trim();
                if (path && path !== "none") {
                    let parts = path.split('/');
                    root.currentWallpaper = parts[parts.length - 1];
                    root.currentWallpaperPath = path;
                }
            }
        }

        stdout: StdioCollector {
            id: wallpaperLoaderOutput
        }

    }

}
