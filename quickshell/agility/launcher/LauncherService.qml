pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    // ─── Modal Open / Closed State ───
    property bool isOpen: false
    property string searchQuery: ""
    property string selectedCategory: "All"
    property int selectedIndex: 0

    // ─── Search Results & Catalog ───
    property var searchResults: []
    property var allApps: []
    property var recentApps: []
    property var pinnedApps: [
        "thunar.desktop",
        "brave-browser.desktop",
        "kitty.desktop",
        "firefox.desktop",
        "code.desktop"
    ]

    // ─── In-line Calculator State ───
    property bool hasMathResult: false
    property string mathExpression: ""
    property string mathResult: ""

    // ─── Web Search Shortcut State ───
    property bool hasWebShortcut: false
    property string webShortcutEngine: ""
    property string webShortcutQuery: ""
    property string webShortcutUrl: ""
    property string webShortcutIcon: "globe"

    // ─── Category Metadata ───
    readonly property var categoryList: [
        { "id": "All", "name": "All", "icon": "squares-four" },
        { "id": "Internet", "name": "Internet", "icon": "globe" },
        { "id": "Development", "name": "Development", "icon": "code" },
        { "id": "Media", "name": "Media", "icon": "film-strip" },
        { "id": "Office", "name": "Office", "icon": "briefcase" },
        { "id": "System", "name": "System", "icon": "gear" },
        { "id": "Utilities", "name": "Utilities", "icon": "wrench" },
        { "id": "Games", "name": "Games", "icon": "game-controller" }
    ]

    // ─── Open / Close / Toggle ───
    function open() {
        root.isOpen = true
        root.searchQuery = ""
        root.selectedIndex = 0
        root.hasMathResult = false
        root.hasWebShortcut = false
        queryIndex("")
    }

    function close() {
        root.isOpen = false
        root.searchQuery = ""
        root.selectedIndex = 0
    }

    function toggle() {
        if (root.isOpen) {
            root.close()
        } else {
            root.open()
        }
    }

    function setCategory(cat) {
        root.selectedCategory = cat
        root.selectedIndex = 0
        queryIndex(root.searchQuery)
    }

    // ─── Query Input Handler ───
    function updateSearch(text) {
        root.searchQuery = text
        root.selectedIndex = 0

        var trimmed = text.trim()

        // 1. Check for web shortcuts
        var webCheck = checkWebShortcut(trimmed)
        if (webCheck.matched) {
            root.hasWebShortcut = true
            root.webShortcutEngine = webCheck.engine
            root.webShortcutQuery = webCheck.query
            root.webShortcutUrl = webCheck.url
            root.webShortcutIcon = webCheck.icon
            root.hasMathResult = false
            queryIndex("")
            return
        } else {
            root.hasWebShortcut = false
        }

        // 2. Check for math evaluation
        var mathCheck = evaluateMathExpression(trimmed)
        if (mathCheck.valid) {
            root.hasMathResult = true
            root.mathExpression = mathCheck.expr
            root.mathResult = mathCheck.result
        } else {
            root.hasMathResult = false
        }

        // 3. Query Nucleo fuzzy matching
        queryIndex(trimmed)
    }

    // ─── Web Shortcut Matcher ───
    function checkWebShortcut(q) {
        if (!q) return { matched: false }

        var lower = q.toLowerCase()
        var prefixes = [
            { p: "g:", engine: "Google", icon: "globe", base: "https://www.google.com/search?q=" },
            { p: "g ", engine: "Google", icon: "globe", base: "https://www.google.com/search?q=" },
            { p: "gh:", engine: "GitHub", icon: "git", base: "https://github.com/search?q=" },
            { p: "gh ", engine: "GitHub", icon: "git", base: "https://github.com/search?q=" },
            { p: "yt:", engine: "YouTube", icon: "play", base: "https://www.youtube.com/results?search_query=" },
            { p: "yt ", engine: "YouTube", icon: "play", base: "https://www.youtube.com/results?search_query=" },
            { p: "ddg:", engine: "DuckDuckGo", icon: "globe", base: "https://duckduckgo.com/?q=" },
            { p: "ddg ", engine: "DuckDuckGo", icon: "globe", base: "https://duckduckgo.com/?q=" }
        ]

        for (var i = 0; i < prefixes.length; i++) {
            var item = prefixes[i]
            if (lower.startsWith(item.p)) {
                var queryPart = q.slice(item.p.length).trim()
                if (queryPart.length > 0) {
                    return {
                        matched: true,
                        engine: item.engine,
                        query: queryPart,
                        icon: item.icon,
                        url: item.base + encodeURIComponent(queryPart)
                    }
                }
            }
        }

        return { matched: false }
    }

    // ─── Safe Math Evaluation ───
    function evaluateMathExpression(raw) {
        if (!raw) return { valid: false }

        var expr = raw
        var isExplicitCalc = false

        if (expr.toLowerCase().startsWith("calc:")) {
            expr = expr.slice(5).trim()
            isExplicitCalc = true
        } else if (expr.startsWith("=")) {
            expr = expr.slice(1).trim()
            isExplicitCalc = true
        }

        // Check for "X% of Y" pattern
        var percentMatch = expr.match(/^(\d+(?:\.\d+)?)\s*%\s+of\s+(\d+(?:\.\d+)?)$/i)
        if (percentMatch) {
            var pVal = parseFloat(percentMatch[1])
            var ofVal = parseFloat(percentMatch[2])
            var res = (pVal / 100.0) * ofVal
            return {
                valid: true,
                expr: raw,
                result: res.toLocaleString("en-US", { maximumFractionDigits: 6 })
            }
        }

        // Must contain arithmetic operators or functions
        var hasOps = /[+\-*\/^%()]/.test(expr) || /\b(sqrt|abs|round|sin|cos|tan)\b/i.test(expr)
        if (!isExplicitCalc && !hasOps) {
            return { valid: false }
        }

        // Sanitize: allow only numbers, whitespace, operators, and basic Math funcs
        var cleaned = expr.replace(/\s+/g, "")
        if (!/^[0-9+\-*\/^%().]|(sqrt|abs|round|sin|cos|tan|pi|e)+$/i.test(cleaned)) {
            return { valid: false }
        }

        try {
            var parsed = safeEvalArithmetic(cleaned)
            if (parsed !== null && !isNaN(parsed) && isFinite(parsed)) {
                return {
                    valid: true,
                    expr: expr,
                    result: parsed.toLocaleString("en-US", { maximumFractionDigits: 6 })
                }
            }
        } catch (e) {}

        return { valid: false }
    }

    // ─── Safe Recursive Descent Arithmetic Evaluator ───
    function safeEvalArithmetic(str) {
        var s = str.replace(/\^/g, "**")
                   .replace(/sqrt\(/gi, "Math.sqrt(")
                   .replace(/abs\(/gi, "Math.abs(")
                   .replace(/round\(/gi, "Math.round(")
                   .replace(/pi/gi, "Math.PI")
                   .replace(/\be\b/gi, "Math.E")

        // Reject dangerous characters
        if (/[^0-9+\-*\/().,%a-zA-Z]/.test(s) || /([a-zA-Z_]\w*)/.test(s.replace(/Math\.(sqrt|abs|round|PI|E)/g, ""))) {
            return null
        }

        var fn = new Function("return (" + s + ")")
        var val = fn()
        return (typeof val === "number") ? val : null
    }

    // ─── Query Daemon / Search Index ───
    Process {
        id: queryProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (Array.isArray(parsed)) {
                        root.searchResults = filterBySelectedCategory(parsed)
                    }
                } catch (e) {}
            }
        }
    }

    function queryIndex(pattern) {
        if (!queryProc.running) {
            var q = pattern.replace(/"/g, "\\\"")
            var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Launcher org.agility.Daemon.Launcher Query s \"" + q + "\" 2>/dev/null || " +
                      "python3 -c '\n" +
                      "import subprocess, json\n" +
                      "cmd = [\"busctl\", \"--user\", \"call\", \"org.agility.Daemon\", \"/org/agility/Daemon/Launcher\", \"org.agility.Daemon.Launcher\", \"Query\", \"s\", \"\"\"" + q + "\"\"\"]\n" +
                      "r = subprocess.run(cmd, capture_output=True, text=True)\n" +
                      "if r.returncode == 0:\n" +
                      "    parts = r.stdout.strip().split(maxsplit=2)\n" +
                      "    if len(parts) >= 3: print(json.loads(parts[2]))\n" +
                      "' 2>/dev/null || true"

            queryProc.command = ["sh", "-c", cmd]
            queryProc.running = true
        }
    }

    function filterBySelectedCategory(items) {
        if (root.selectedCategory === "All" || root.selectedCategory === "") {
            return items
        }

        var targetCat = root.selectedCategory.toLowerCase()
        return items.filter(function(item) {
            var cats = (item.app && item.app.categories) ? item.app.categories : []
            return cats.some(function(c) {
                var cLow = c.toLowerCase()
                if (targetCat === "internet") return cLow.includes("network") || cLow.includes("webbrowser")
                if (targetCat === "media") return cLow.includes("audiovideo") || cLow.includes("audio") || cLow.includes("video")
                if (targetCat === "utilities") return cLow.includes("utility") || cLow.includes("utilities")
                if (targetCat === "games") return cLow.includes("game")
                return cLow === targetCat
            })
        })
    }

    // ─── Actions & Executions ───
    function selectNext() {
        var total = root.searchResults.length + (root.hasMathResult ? 1 : 0) + (root.hasWebShortcut ? 1 : 0)
        if (total > 0) {
            root.selectedIndex = (root.selectedIndex + 1) % total
        }
    }

    function selectPrevious() {
        var total = root.searchResults.length + (root.hasMathResult ? 1 : 0) + (root.hasWebShortcut ? 1 : 0)
        if (total > 0) {
            root.selectedIndex = (root.selectedIndex - 1 + total) % total
        }
    }

    function launchSelected() {
        if (root.hasWebShortcut && root.selectedIndex === 0) {
            openWebUrl(root.webShortcutUrl)
            root.close()
            return
        }

        var mathOffset = (root.hasWebShortcut ? 1 : 0)
        if (root.hasMathResult && root.selectedIndex === mathOffset) {
            copyToClipboard(root.mathResult)
            root.close()
            return
        }

        var appIndex = root.selectedIndex - (root.hasWebShortcut ? 1 : 0) - (root.hasMathResult ? 1 : 0)
        if (appIndex >= 0 && appIndex < root.searchResults.length) {
            var item = root.searchResults[appIndex]
            if (item && item.app) {
                launchApp(item.app)
            }
        } else if (root.searchResults.length > 0) {
            launchApp(root.searchResults[0].app)
        }
        root.close()
    }

    function launchApp(app) {
        if (!app) return

        // Record in recent apps
        recordRecentApp(app)

        var id = app.id || ""
        var exec = app.exec || ""
        var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Launcher org.agility.Daemon.Launcher Launch s \"" + id + "\" 2>/dev/null || " +
                  (exec ? ("(" + exec + ") >/dev/null 2>&1 &") : "true")

        runCmd(cmd)
        root.close()
    }

    function openWebUrl(url) {
        if (!url) return
        var cmd = "xdg-open \"" + url + "\" >/dev/null 2>&1 &"
        runCmd(cmd)
    }

    function copyToClipboard(text) {
        if (!text) return
        var clean = text.replace(/"/g, "\\\"")
        var cmd = "busctl --user call org.agility.Daemon /org/agility/Daemon/Clipboard org.agility.Daemon.Clipboard CopyText s \"" + clean + "\" 2>/dev/null || " +
                  "printf '%s' \"" + clean + "\" | wl-copy 2>/dev/null || true"
        runCmd(cmd)
    }

    function recordRecentApp(app) {
        var copy = root.recentApps.slice()
        copy = copy.filter(function(a) { return a.id !== app.id })
        copy.unshift(app)
        if (copy.length > 10) copy = copy.slice(0, 10)
        root.recentApps = copy
    }

    // ─── CLI Process Runner ───
    Process {
        id: execProc
        running: false
    }

    function runCmd(cmd) {
        execProc.command = ["sh", "-c", cmd]
        execProc.running = true
    }

    Component.onCompleted: {
        root.queryIndex("")
    }
}
