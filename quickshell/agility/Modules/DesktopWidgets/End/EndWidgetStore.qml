pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Services

/*
 * Persistent configuration and per-monitor layout store for the End widget suite.
 * Stored in ~/.config/agility-shell/end_widgets.json (separate from Awe widget_settings.json).
 */
Item {
    id: store

    property bool loaded: false
    property string storePath: Quickshell.env("HOME") + "/.config/agility-shell/end_widgets.json"
    property int layoutRevision: 0

    readonly property var widgetCatalog: [
        { id: "clock",       name: "Clock",            cat: "Core",         icon: "clock",        desc: "Expressive digital, cookie, daily badge, or stacked clock", defaultEnabled: true },
        { id: "userCard",    name: "User Card",        cat: "Core",         icon: "info",         desc: "Avatar, greeting, uptime, and quick lock/power actions",    defaultEnabled: true },
        { id: "calendar",    name: "Calendar",         cat: "Core",         icon: "calendar",     desc: "Day badge, week strip, or interactive monthly calendar",    defaultEnabled: true },
        { id: "weather",     name: "Weather",          cat: "Network",      icon: "sun",          desc: "Live temperature, conditions, humidity, and wind",          defaultEnabled: true },
        { id: "resources",   name: "System Resources", cat: "System",       icon: "cpu",          desc: "CPU, RAM, and Battery/Disk cards with shape badges",        defaultEnabled: true },
        { id: "todo",        name: "To-Do List",       cat: "Productivity", icon: "square-rounded-check", desc: "Interactive task checklist with inline add & delete", defaultEnabled: true },
        { id: "worldClock",  name: "World Clock",      cat: "Core",         icon: "clock",        desc: "Local time plus multi-timezone cards with day/night icons", defaultEnabled: true },
        { id: "timers",      name: "Timers",           cat: "Productivity", icon: "3s",           desc: "Focus Pomodoro, Stopwatch, and quick Countdown cards",      defaultEnabled: true },
        { id: "notes",       name: "Notes",            cat: "Productivity", icon: "clipboard",    desc: "Color-coded quick notes with inline editor",               defaultEnabled: true },
        { id: "media",       name: "Media Player",     cat: "Media",        icon: "music",        desc: "MPRIS track info, album art, and playback controls",        defaultEnabled: true },
        { id: "images",      name: "Image Converter",  cat: "Media",        icon: "picture-spark", desc: "Drop or pick images to convert via ffmpeg/ImageMagick",    defaultEnabled: true },
        { id: "visualizer",  name: "Audio Visualizer", cat: "Media",        icon: "music",        desc: "Bottom Cava audio spectrum bars or ring visualizer",        defaultEnabled: true },
        { id: "imageCard",   name: "Image Card",       cat: "Media",        icon: "picture",      desc: "Rounded photo card supporting drag-and-drop or file pick",  defaultEnabled: false },
        { id: "customImage", name: "Shaped Image",     cat: "Media",        icon: "sparkles",     desc: "Material-3 shaped photo frame with selectable silhouette",  defaultEnabled: false },
        { id: "sticker",     name: "Sticker",          cat: "Media",        icon: "star",         desc: "Floating sticker image with outline and rotation",          defaultEnabled: false },
        { id: "customText",  name: "Custom Text",      cat: "Core",         icon: "font",         desc: "Double-click editable desktop quote or label",              defaultEnabled: false }
    ]

    property var visibility: ({
        "clock": true,
        "userCard": true,
        "calendar": true,
        "weather": true,
        "resources": true,
        "todo": true,
        "worldClock": true,
        "timers": true,
        "notes": true,
        "media": true,
        "images": true,
        "visualizer": true,
        "imageCard": false,
        "customImage": false,
        "sticker": false,
        "customText": false
    })

    // Per-monitor layouts: { "<screenKey>": { "<widgetId>": { x, y, scale, sizeMode, vertical, ... } } }
    property var layouts: ({})

    // Persistent widget content & options
    property var widgetPrefs: ({
        "clock": { "style": "digital", "showDate": false, "vertical": false },
        "userCard": { "sizeMode": "1x2" },
        "calendar": { "sizeMode": "1x2" },
        "weather": { "sizeMode": "1x3" },
        "resources": { "vertical": false },
        "todo": {
            "items": [
                { "content": "Review desktop layout", "done": false },
                { "content": "Customize theme & wallpaper", "done": true },
                { "content": "Stay hydrated", "done": false }
            ]
        },
        "worldClock": {
            "sizeMode": "2x2",
            "vertical": false,
            "clockCount": 4,
            "timezones": ["Asia/Manila", "Asia/Kolkata", "Asia/Tokyo", "Asia/Seoul"]
        },
        "timers": { "vertical": false },
        "notes": {
            "items": [
                { "id": 1, "content": "Agility Shell • End Widgets" },
                { "id": 2, "content": "Click + to add a quick note" },
                { "id": 3, "content": "Edit layout in Settings -> Appearance" }
            ]
        },
        "media": { "sizeMode": "1x3" },
        "images": { "format": "webp" },
        "visualizer": { "style": "bars", "ringSize": 340 },
        "imageCard": { "path": "", "sizeMode": "1x2" },
        "customImage": { "path": "", "shape": "Cookie4Sided", "size": 190 },
        "sticker": { "path": "", "size": 160, "rotation": 0 },
        "customText": { "content": "Stay focused", "fontSize": 48, "alignment": "center" }
    })

    property bool showGridInEdit: true
    property bool snapToGrid: true
    property int gridSize: 12

    function screenKey(screen) {
        if (!screen)
            return "default";
        return (screen.name || "screen") + "_" + Math.round(screen.width) + "x" + Math.round(screen.height);
    }

    function isWidgetEnabled(widgetId) {
        return visibility[widgetId] === true;
    }

    function setWidgetEnabled(widgetId, enabled) {
        let next = Object.assign({}, visibility);
        next[widgetId] = Boolean(enabled);
        visibility = next;
        scheduleSave();
    }

    function applyDefaultVisibility() {
        let next = {};
        for (let i = 0; i < widgetCatalog.length; i++) {
            next[widgetCatalog[i].id] = widgetCatalog[i].defaultEnabled;
        }
        visibility = next;
        scheduleSave();
    }

    function setAllVisibility(enabled) {
        let next = {};
        for (let i = 0; i < widgetCatalog.length; i++) {
            next[widgetCatalog[i].id] = Boolean(enabled);
        }
        visibility = next;
        scheduleSave();
    }

    function getPref(widgetId, key, fallback) {
        let wp = widgetPrefs[widgetId];
        if (!wp || wp[key] === undefined)
            return fallback;
        return wp[key];
    }

    function setPref(widgetId, key, value) {
        let all = Object.assign({}, widgetPrefs);
        let cur = Object.assign({}, all[widgetId] || {});
        cur[key] = value;
        all[widgetId] = cur;
        widgetPrefs = all;
        scheduleSave();
    }

    function baseDimensions(widgetId, sizeMode, isVertical) {
        switch (widgetId) {
            case "clock":
                return { w: 280, h: 112 };
            case "userCard":
                if (sizeMode === "1x1") return { w: 128, h: 118 };
                if (sizeMode === "2x2") return { w: 276, h: 250 };
                if (sizeMode === "2x3") return { w: 420, h: 250 };
                return { w: 276, h: 118 };
            case "calendar":
                if (sizeMode === "1x1") return { w: 132, h: 118 };
                if (sizeMode === "2x2") return { w: 276, h: 250 };
                if (sizeMode === "2x3") return { w: 420, h: 250 };
                return { w: 276, h: 118 };
            case "weather":
                if (sizeMode === "1x1") return { w: 132, h: 118 };
                if (sizeMode === "1x2") return { w: 276, h: 118 };
                if (sizeMode === "2x2") return { w: 276, h: 250 };
                if (sizeMode === "2x3") return { w: 420, h: 250 };
                return { w: 420, h: 118 };
            case "resources":
                return isVertical ? { w: 132, h: 384 } : { w: 420, h: 118 };
            case "timers":
                return isVertical ? { w: 132, h: 384 } : { w: 420, h: 118 };
            case "todo":
                return { w: 276, h: 250 };
            case "notes":
                return { w: 276, h: 250 };
            case "worldClock":
                if (sizeMode === "4x1")
                    return isVertical ? { w: 132, h: 516 } : { w: 564, h: 118 };
                return { w: 276, h: 250 };
            case "media":
                if (sizeMode === "1x1") return { w: 132, h: 118 };
                if (sizeMode === "1x2") return { w: 276, h: 118 };
                if (sizeMode === "2x2") return { w: 276, h: 250 };
                if (sizeMode === "2x3") return { w: 420, h: 250 };
                return { w: 420, h: 118 };
            case "images":
                return { w: 276, h: 250 };
            case "imageCard":
                if (sizeMode === "1x1") return { w: 132, h: 118 };
                if (sizeMode === "2x2") return { w: 276, h: 250 };
                if (sizeMode === "2x3") return { w: 420, h: 250 };
                return { w: 276, h: 118 };
            case "customImage":
                return { w: 180, h: 180 };
            case "sticker":
                return { w: 160, h: 160 };
            case "customText":
                return { w: 260, h: 76 };
            case "visualizer":
                return { w: 600, h: 180 };
            default:
                return { w: 240, h: 120 };
        }
    }

    function computeDefaultLayout(screenWidth, screenHeight) {
        let w = Math.max(640, screenWidth || 1920);
        let h = Math.max(480, screenHeight || 1080);
        let topBar = 52;
        let margin = Math.max(16, Math.round(Math.min(w, h) * 0.022));
        let gap = Math.max(10, Math.round(Math.min(w, h) * 0.012));

        let shapeFrac = SettingsService.desktopCenterShapeSize || 0.54;
        let shapeSize = Math.round(Math.min(w, h) * shapeFrac);
        let cx = w / 2;
        let cy = h / 2;
        let shapeLeft = Math.round(cx - shapeSize / 2);
        let shapeRight = Math.round(cx + shapeSize / 2);
        let shapeTop = Math.round(cy - shapeSize / 2);
        let shapeBottom = Math.round(cy + shapeSize / 2);

        let isPortrait = h > w * 1.05;
        let sideWidth = Math.max(120, shapeLeft - margin - gap);

        // Compute scale so cards never overlap the central shape or clip off-screen
        let baseScale = 1.0;
        if (isPortrait) {
            baseScale = Math.max(0.62, Math.min(0.92, (w - margin * 2) / 960));
        } else {
            let widthScale = sideWidth / 580;
            let heightScale = (h - topBar - margin * 2) / 940;
            baseScale = Math.max(0.58, Math.min(1.0, Math.min(widthScale, heightScale)));
        }
        baseScale = Math.round(baseScale * 100) / 100;

        function clampPos(x, y, ww, hh) {
            let maxX = Math.max(margin, w - ww - margin);
            let maxY = Math.max(topBar, h - hh - margin);
            return {
                x: Math.round(Math.max(margin, Math.min(maxX, x))),
                y: Math.round(Math.max(topBar, Math.min(maxY, y)))
            };
        }

        let res = {};

        if (isPortrait) {
            // Compact portrait stack: top band above central shape, bottom band below central shape
            let s = baseScale;
            let cW = Math.round(280 * s);
            let uW = Math.round(276 * s);
            let wW = Math.round(420 * s);
            let row1Y = topBar + 10;
            let row2Y = row1Y + Math.round(118 * s) + gap;
            let botY1 = Math.min(h - Math.round(420 * s), shapeBottom + gap);
            let botY2 = botY1 + Math.round(128 * s) + gap;

            res["clock"]      = { x: Math.round(cx - cW / 2), y: row1Y, scale: s };
            res["userCard"]   = { x: margin, y: row2Y, scale: s, sizeMode: "1x2" };
            res["calendar"]   = { x: w - margin - uW, y: row2Y, scale: s, sizeMode: "1x2" };
            res["weather"]    = { x: Math.round(cx - wW / 2), y: row2Y + Math.round(118 * s) + gap, scale: s, sizeMode: "1x3" };
            res["resources"]  = { x: margin, y: botY1, scale: s, vertical: false };
            res["media"]      = { x: w - margin - wW, y: botY1, scale: s, sizeMode: "1x3" };
            res["todo"]       = { x: margin, y: botY2, scale: s };
            res["worldClock"] = { x: Math.round(cx - uW / 2), y: botY2, scale: s, sizeMode: "2x2" };
            res["notes"]      = { x: w - margin - uW, y: botY2, scale: s };
            res["timers"]     = { x: margin, y: botY2 + Math.round(250 * s) + gap, scale: s, vertical: false };
            res["images"]     = { x: w - margin - uW, y: botY2 + Math.round(250 * s) + gap, scale: s };
        } else if (sideWidth >= 540 && h >= 880) {
            // Spacious widescreen composition matching reference screenshot without overlap
            let s = baseScale;
            let topRowY = Math.max(topBar + 8, Math.round((shapeTop - topBar - 120 * s) * 0.5 + topBar));
            let midTopY = Math.max(topRowY + Math.round(124 * s) + gap, Math.round(shapeTop + 16));
            let midRowY = midTopY + Math.round(118 * s) + gap;
            let botRowY = midRowY + Math.round(250 * s) + gap;

            res["clock"]      = { x: Math.round(cx - 140 * s), y: topRowY - 4, scale: s };
            res["userCard"]   = { x: Math.max(margin, Math.round(shapeLeft - 276 * s - 22)), y: topRowY, scale: s, sizeMode: "1x2" };
            res["calendar"]   = { x: Math.min(w - margin - 276 * s, Math.round(shapeRight + 22)), y: topRowY, scale: s, sizeMode: "1x2" };

            res["resources"]  = { x: margin, y: midTopY, scale: s, vertical: false };
            res["todo"]       = { x: margin, y: midRowY, scale: s };
            res["worldClock"] = { x: margin + Math.round(276 * s) + gap, y: midRowY, scale: s, sizeMode: "2x2" };
            res["timers"]     = { x: margin, y: botRowY, scale: s, vertical: false };

            res["weather"]    = { x: w - margin - Math.round(420 * s), y: midTopY, scale: s, sizeMode: "1x3" };
            res["images"]     = { x: Math.max(shapeRight + gap, w - margin - Math.round((276 * 2 + 12) * s)), y: midRowY, scale: s };
            res["notes"]      = { x: w - margin - Math.round(276 * s), y: midRowY, scale: s };
            res["media"]      = { x: w - margin - Math.round(420 * s), y: botRowY, scale: s, sizeMode: "1x3" };
        } else {
            // Compact layout for smaller laptop / 1366x768 / 1280x720 screens
            let s = Math.max(0.56, Math.min(0.80, sideWidth / 430));
            s = Math.round(s * 100) / 100;
            let colW = Math.round(276 * s);
            let wideW = Math.round(420 * s);
            let topY = topBar + 6;
            let row1Y = Math.max(topY + Math.round(118 * s) + gap, Math.round(cy - 210 * s));
            let row2Y = row1Y + Math.round(118 * s) + gap;
            let row3Y = row2Y + Math.round(250 * s) + gap;

            let useWideLeft = sideWidth >= wideW + 4;
            res["clock"]      = { x: Math.round(cx - 140 * s), y: topY, scale: s };
            res["userCard"]   = { x: margin, y: topY, scale: s, sizeMode: "1x2" };
            res["calendar"]   = { x: w - margin - colW, y: topY, scale: s, sizeMode: "1x2" };

            res["resources"]  = { x: margin, y: row1Y, scale: s, vertical: !useWideLeft };
            res["todo"]       = { x: useWideLeft ? margin : (margin + Math.round(132 * s) + gap), y: row2Y, scale: s };
            res["worldClock"] = { x: margin, y: Math.min(h - margin - Math.round(250 * s), row3Y), scale: s, sizeMode: "2x2" };
            res["timers"]     = { x: Math.round(cx - (useWideLeft ? wideW / 2 : colW / 2)), y: Math.min(h - margin - Math.round(118 * s), shapeBottom + gap), scale: s, vertical: false };

            res["weather"]    = { x: w - margin - (useWideLeft ? wideW : colW), y: row1Y, scale: s, sizeMode: useWideLeft ? "1x3" : "1x2" };
            res["notes"]      = { x: w - margin - colW, y: row2Y, scale: s };
            res["media"]      = { x: w - margin - (useWideLeft ? wideW : colW), y: Math.min(h - margin - Math.round(118 * s), row3Y), scale: s, sizeMode: useWideLeft ? "1x3" : "1x2" };
            res["images"]     = { x: Math.max(margin, shapeRight + gap), y: Math.min(h - margin - Math.round(250 * s), row2Y), scale: s };
        }

        // Remaining optional widgets + visualizer
        res["visualizer"]  = { x: 0, y: Math.max(0, h - 180), scale: 1.0, style: "bars" };
        res["imageCard"]   = { x: margin, y: Math.max(topBar, h - Math.round(140 * baseScale)), scale: baseScale, sizeMode: "1x2" };
        res["customImage"] = { x: Math.max(margin, w - margin - Math.round(190 * baseScale)), y: Math.max(topBar, h - Math.round(200 * baseScale)), scale: baseScale };
        res["sticker"]     = { x: Math.min(w - margin - Math.round(160 * baseScale), shapeRight + gap), y: Math.max(topBar, shapeBottom - Math.round(150 * baseScale)), scale: baseScale };
        res["customText"]  = { x: Math.round(cx - Math.round(130 * baseScale)), y: Math.min(h - margin - 80, shapeBottom + gap), scale: baseScale };

        // Clamp every widget strictly within monitor bounds
        for (let k in res) {
            if (k === "visualizer") continue;
            let entry = res[k];
            let dims = baseDimensions(k, entry.sizeMode || "", Boolean(entry.vertical));
            let s = entry.scale || 1.0;
            let clamped = clampPos(entry.x, entry.y, dims.w * s, dims.h * s);
            entry.x = clamped.x;
            entry.y = clamped.y;
        }
        return res;
    }

    function getWidgetLayout(screen, widgetId) {
        let key = screenKey(screen);
        let w = screen ? screen.width : 1920;
        let h = screen ? screen.height : 1080;
        let monMap = layouts[key];
        let defaults = computeDefaultLayout(w, h);
        let defEntry = defaults[widgetId] || { x: 40, y: 80, scale: 1.0 };
        if (!monMap || !monMap[widgetId])
            return defEntry;
        return Object.assign({}, defEntry, monMap[widgetId]);
    }

    function setWidgetLayout(screen, widgetId, patch) {
        let key = screenKey(screen);
        let nextLayouts = Object.assign({}, layouts);
        let monMap = Object.assign({}, nextLayouts[key] || {});
        let cur = getWidgetLayout(screen, widgetId);
        monMap[widgetId] = Object.assign({}, cur, patch);
        nextLayouts[key] = monMap;
        layouts = nextLayouts;
        scheduleSave();
    }

    function resetLayouts() {
        layouts = ({});
        layoutRevision++;
        scheduleSave();
    }

    function scheduleSave() {
        saveTimer.restart();
    }

    Process {
        id: loadProc
        command: ["python3", "-c", "import json, os; p=os.path.expanduser('~/.config/agility-shell/end_widgets.json'); print(open(p).read() if os.path.exists(p) else '{}')"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim() || "{}");
                    if (parsed.visibility && typeof parsed.visibility === "object")
                        store.visibility = Object.assign({}, store.visibility, parsed.visibility);
                    if (parsed.layouts && typeof parsed.layouts === "object")
                        store.layouts = parsed.layouts;
                    if (parsed.widgetPrefs && typeof parsed.widgetPrefs === "object") {
                        let merged = Object.assign({}, store.widgetPrefs);
                        for (let k in parsed.widgetPrefs) {
                            merged[k] = Object.assign({}, merged[k] || {}, parsed.widgetPrefs[k]);
                        }
                        store.widgetPrefs = merged;
                    }
                    if (parsed.showGridInEdit !== undefined)
                        store.showGridInEdit = Boolean(parsed.showGridInEdit);
                    if (parsed.snapToGrid !== undefined)
                        store.snapToGrid = Boolean(parsed.snapToGrid);
                } catch (e) {
                    console.warn("EndWidgetStore: failed to parse config, using defaults:", e);
                }
                store.loaded = true;
            }
        }
    }

    Process {
        id: saveProc
        running: false
    }

    Timer {
        id: saveTimer
        interval: 120
        repeat: false
        onTriggered: {
            let payload = JSON.stringify({
                "visibility": store.visibility,
                "layouts": store.layouts,
                "widgetPrefs": store.widgetPrefs,
                "showGridInEdit": store.showGridInEdit,
                "snapToGrid": store.snapToGrid
            });
            let py = "import json, os, tempfile; " +
                "p = os.path.expanduser('~/.config/agility-shell/end_widgets.json'); " +
                "os.makedirs(os.path.dirname(p), exist_ok=True); " +
                "d = json.loads(" + JSON.stringify(payload) + "); " +
                "fd, tmp = tempfile.mkstemp(prefix='endw_', suffix='.tmp', dir=os.path.dirname(p)); " +
                "f = os.fdopen(fd, 'w', encoding='utf-8'); json.dump(d, f, indent=2); f.close(); " +
                "os.replace(tmp, p)";
            saveProc.command = ["python3", "-c", py];
            saveProc.running = false;
            saveProc.running = true;
        }
    }

    Component.onCompleted: {
        loadProc.running = true;
    }
}
