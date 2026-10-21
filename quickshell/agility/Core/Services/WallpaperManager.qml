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

    property var wallpaperList: []
    property int wallpaperListCount: wallpaperList.length

    property Process fastAwwwProc
    property Process wallpaperApplyProc
    property Process wallpaperSaveProc
    property Process wallpaperLoader
    property Process randomWallpaperProc
    property Process listLoaderProc
    property Timer shuffleTimer

    function setWallpaperList(list) {
        if (!list) return;
        wallpaperList = list;
    }

    function reloadWallpaperList() {
        listLoaderProc.lines = [];
        listLoaderProc.running = false;
        listLoaderProc.running = true;
    }

    function applyWallpaperWithSync(wallpaperName, rawPath, transitionPos) {
        currentWallpaper = wallpaperName;
        currentWallpaperPath = rawPath;
        applyWallpaper(rawPath, "", transitionPos);
    }

    function reapplyCurrentWallpaper() {
        let p = currentWallpaperPath || currentWallpaper;
        if (p)
            applyWallpaper(p);
    }

    function applyWallpaperInstant(rawPath, transitionPos) {
        applyWallpaper(rawPath, "", transitionPos);
    }

    function applyWallpaper(rawPath, forceTransitionType, transitionPos) {
        if (!rawPath)
            return;
        if (HyprlandService.wpAutoShuffle) {
            HyprlandService.wpAutoShuffle = false;
            SettingsService.saveSettings();
        }

        let chosenType = forceTransitionType || ((enableTransitions && SystemInfoService.powerProfile !== "power-saver" && transitionType) ? transitionType : "grow");
        let pos = transitionPos || transitionPos;
        if (!pos) {
            pos = (enableTransitions && HyprlandService.wpTransitionPos) ? HyprlandService.wpTransitionPos : "center";
        }

        // Fast path: Immediately apply wallpaper with awww directly (< 30ms visual switch)
        fastAwwwProc.running = false;
        let awwwArgs = [
            "awww", "img", rawPath,
            "--resize", (resizeMode || "crop"),
            "--filter", "Bilinear",
            "--transition-type", chosenType,
            "--transition-bezier", ".54,0,.34,.99",
            "--transition-duration", "0.25",
            "--transition-step", (transitionStep ? String(transitionStep) : "180"),
            "--transition-fps", (transitionFps ? String(transitionFps) : "60")
        ];
        if (pos) {
            if (pos.indexOf(',') !== -1) {
                awwwArgs.push("--invert-y");
            }
            awwwArgs.push("--transition-pos", pos);
        }
        if (chosenType === "wipe" || chosenType === "wave") {
            awwwArgs.push("--transition-angle", String(transitionAngle || 30));
        }
        fastAwwwProc.command = awwwArgs;
        fastAwwwProc.startDetached();

        // Daemon sync: extracts palette, generates blur, writes cache without double-running awww
        wallpaperApplyProc.running = false;
        let cmd = ["agl", "wallpaper", rawPath, "--skip-backend"];
        wallpaperApplyProc.command = cmd;
        wallpaperApplyProc.startDetached();
    }

    function cycleNextWallpaper(screenX, screenY, screenWidth, screenHeight) {
        if (!wallpaperList || wallpaperList.length === 0) {
            reloadWallpaperList();
            randomWallpaperProc.running = false;
            randomWallpaperProc.running = true;
            return;
        }

        let cur = currentWallpaper ? currentWallpaper.trim() : "";
        let curPath = currentWallpaperPath ? currentWallpaperPath.trim() : "";
        let curIdx = -1;

        for (let i = 0; i < wallpaperList.length; i++) {
            if (wallpaperList[i].rawPath === curPath || wallpaperList[i].name === cur) {
                curIdx = i;
                break;
            }
        }

        let nextIdx = (curIdx + 1) % wallpaperList.length;
        let nextWall = wallpaperList[nextIdx];
        if (!nextWall)
            return;

        currentWallpaper = nextWall.name;
        currentWallpaperPath = nextWall.rawPath;

        let posStr = (screenX !== undefined && screenY !== undefined)
            ? (Math.round(screenX) + "," + Math.round(screenY))
            : "center";

        applyWallpaper(nextWall.rawPath, "grow", posStr);
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
        reloadWallpaperList();
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

    fastAwwwProc: Process {
    }

    wallpaperApplyProc: Process {
    }

    wallpaperSaveProc: Process {
    }

    listLoaderProc: Process {
        property var lines: []
        command: ["agl", "wallpaper", "list"]
        onExited: function(exitCode) {
            let seen = {};
            let uniqueList = [];
            for (let i = 0; i < lines.length; i++) {
                let item = lines[i];
                if (!seen[item.name]) {
                    seen[item.name] = true;
                    uniqueList.push(item);
                }
            }
            uniqueList.sort(function(a, b) {
                return a.name.localeCompare(b.name);
            });
            root.wallpaperList = uniqueList;
            lines = [];
        }

        stdout: SplitParser {
            onRead: function(data) {
                let linesArr = data.split('\n');
                for (let i = 0; i < linesArr.length; i++) {
                    let rawPath = linesArr[i].trim();
                    if (rawPath !== "") {
                        let parts = rawPath.split('/');
                        let fileName = parts[parts.length - 1];
                        listLoaderProc.lines.push({
                            "filePath": "file://" + rawPath,
                            "rawPath": rawPath,
                            "name": fileName
                        });
                    }
                }
            }
        }
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
