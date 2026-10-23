pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath

    function reapplyTheme() {
        themeFileView.reload()
    }

    function applyColors(fileContent) {
        if (!fileContent || fileContent.trim() === "") {
            colorgenProc.running = false;
            colorgenProc.running = true;
            return;
        }
        try {
            const json = JSON.parse(fileContent);
            for (const key in json) {
                if (json.hasOwnProperty(key)) {
                    // Convert snake_case to CamelCase
                    const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
                    const m3Key = `m3${camelCaseKey}`;
                    if (Appearance.m3colors && (m3Key in Appearance.m3colors)) {
                        Appearance.m3colors[m3Key] = json[key];
                    }
                }
            }
            if (Appearance.m3colors && Appearance.m3colors.m3background) {
                Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5);
            }
        } catch (e) {
            console.warn("Failed to apply Material colors:", e);
        }
    }

    Process {
        id: colorgenProc
        command: ["bash", "-c", "STATE_DIR=\"$HOME/.local/state/quickshell\"; mkdir -p \"$STATE_DIR/user/generated\"; img=$(agl wallpaper get 2>/dev/null); [[ -z \"$img\" || ! -f \"$img\" ]] && img=\"$HOME/.local/share/agility-shell/wallpapers/18.jpg\"; if command -v matugen &>/dev/null && [[ -f \"$img\" ]]; then matugen image \"$img\" -m dark --source-color-index 0 --json hex 2>/dev/null | jq '.colors | to_entries | map({key: .key, value: (.value.dark.color // .value.default.color)}) | from_entries' > \"$STATE_DIR/user/generated/colors.json\"; fi"]
        onExited: (code) => {
            themeFileView.reload();
        }
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = true
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options.background
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

	FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
        }
        onLoadFailed: {
            root.resetFilePathNextTime();
            colorgenProc.running = false;
            colorgenProc.running = true;
        }
    }

    function toggleLightDark() {
        const currentlyDark = Appearance.m3colors.darkmode;
        const targetMode = currentlyDark ? "light" : "dark";
        Quickshell.execDetached(["bash", "-c", `STATE_DIR="$HOME/.local/state/quickshell"; mkdir -p "$STATE_DIR/user/generated"; img=$(agl wallpaper get 2>/dev/null); [[ -z "$img" || ! -f "$img" ]] && img="$HOME/.local/share/agility-shell/wallpapers/18.jpg"; if command -v matugen &>/dev/null && [[ -f "$img" ]]; then matugen image "$img" -m ${targetMode} --source-color-index 0 --json hex 2>/dev/null | jq --arg m "${targetMode}" '.colors | to_entries | map({key: .key, value: (.value[$m].color // .value.default.color)}) | from_entries' > "$STATE_DIR/user/generated/colors.json"; fi`]);
    }

    GlobalShortcut {
        name: "toggleLightDark"
        description: "Toggles between dark theme and light theme"

        onPressed: {
            root.toggleLightDark();
        }
    }

    IpcHandler {
        target: "theme"

        function toggleLightDark(): void {
            root.toggleLightDark();
        }
    }
}
