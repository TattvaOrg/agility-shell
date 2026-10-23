import QtQuick
import Quickshell
import qs.Core
import qs.Core.Services
import qs.Core.Utils
pragma Singleton

QtObject {
    id: root

    readonly property bool active: SettingsService.systemTheme === "material"
    readonly property bool isDark: Theme.isDark

    // Quickshell native wallpaper color quantizer
    property ColorQuantizer quantizer: ColorQuantizer {
        id: colorQuant
        source: {
            let p = WallpaperManager.currentWallpaperPath || WallpaperManager.currentWallpaper;
            if (!p || p === "") return "";
            if (p.startsWith("/")) return "file://" + p;
            return p;
        }
        depth: 0 // 2^0 = 1 dominant color
        rescaleSize: 16
    }

    // Dominant base accent color from wallpaper, with sensible fallback
    readonly property color wallpaperSeed: {
        if (quantizer && quantizer.colors && quantizer.colors.length > 0 && quantizer.colors[0]) {
            return quantizer.colors[0];
        }
        return "#a77ef5";
    }

    // Helper functions for Material You tonal math
    function mixColors(c1, c2, ratio) {
        let r = c1.r * (1 - ratio) + c2.r * ratio;
        let g = c1.g * (1 - ratio) + c2.g * ratio;
        let b = c1.b * (1 - ratio) + c2.b * ratio;
        return Qt.rgba(r, g, b, 1.0);
    }

    function withAlpha(col, a) {
        return Qt.rgba(col.r, col.g, col.b, a);
    }

    // Dynamic Material 3 Palette Tokens
    readonly property color m3primary: {
        let seed = wallpaperSeed;
        if (isDark) {
            // Lighter, vibrant pastel for dark theme
            return Qt.hsla(seed.hslHue, Math.min(1.0, seed.hslSaturation * 1.1), 0.76, 1.0);
        } else {
            // Deeper tone for light theme
            return Qt.hsla(seed.hslHue, Math.min(1.0, seed.hslSaturation * 1.2), 0.38, 1.0);
        }
    }

    readonly property color m3onPrimary: isDark ? "#1a102f" : "#ffffff"

    readonly property color m3primaryContainer: {
        let seed = wallpaperSeed;
        if (isDark) {
            return Qt.hsla(seed.hslHue, Math.min(1.0, seed.hslSaturation * 0.9), 0.28, 1.0);
        } else {
            return Qt.hsla(seed.hslHue, Math.min(1.0, seed.hslSaturation * 0.9), 0.88, 1.0);
        }
    }

    readonly property color m3onPrimaryContainer: isDark ? Qt.hsla(wallpaperSeed.hslHue, 0.85, 0.90, 1.0) : Qt.hsla(wallpaperSeed.hslHue, 0.9, 0.15, 1.0)

    readonly property color m3secondary: {
        let seed = wallpaperSeed;
        let hue = (seed.hslHue + 0.05) % 1.0;
        return isDark ? Qt.hsla(hue, 0.45, 0.72, 1.0) : Qt.hsla(hue, 0.55, 0.35, 1.0);
    }

    readonly property color m3secondaryContainer: {
        let seed = wallpaperSeed;
        if (isDark) {
            return mixColors(m3surfaceContainerHigh, seed, 0.22);
        } else {
            return mixColors("#eae4ea", seed, 0.18);
        }
    }

    readonly property color m3onSecondaryContainer: isDark ? "#e8def8" : "#1d192b"

    readonly property color m3background: isDark ? "#121216" : "#fdf8fd"
    readonly property color m3onBackground: isDark ? "#e6e1e6" : "#1c1b1f"

    readonly property color m3surface: isDark ? "#16161b" : "#f8f3f8"
    readonly property color m3surfaceDim: isDark ? "#111115" : "#ded8de"
    readonly property color m3surfaceBright: isDark ? "#38373d" : "#fdf8fd"

    readonly property color m3surfaceContainerLowest: isDark ? "#0d0d11" : "#ffffff"
    readonly property color m3surfaceContainerLow: isDark ? "#19191e" : "#f4eef4"
    readonly property color m3surfaceContainer: isDark ? "#1d1d23" : "#eee8ee"
    readonly property color m3surfaceContainerHigh: isDark ? "#28282e" : "#e8e2e8"
    readonly property color m3surfaceContainerHighest: isDark ? "#333239" : "#e2dce2"

    readonly property color m3onSurface: isDark ? "#e6e1e6" : "#1c1b1f"
    readonly property color m3onSurfaceVariant: isDark ? "#cbc4cf" : "#49454e"
    readonly property color m3outline: isDark ? "#948f99" : "#79747e"
    readonly property color m3outlineVariant: isDark ? "#49454e" : "#cac4cf"

    // Material Elevation & Glass Overlays
    readonly property color pillBackground: isDark ? withAlpha(m3surfaceContainer, 0.88) : withAlpha(m3surfaceContainerLowest, 0.90)
    readonly property color pillBorder: isDark ? withAlpha(m3outlineVariant, 0.35) : withAlpha(m3outlineVariant, 0.45)
    readonly property color cardBackground: isDark ? withAlpha(m3surfaceContainerHigh, 0.82) : withAlpha(m3surfaceContainerLowest, 0.88)
    readonly property color cardBorder: isDark ? withAlpha(m3outlineVariant, 0.28) : withAlpha(m3outline, 0.22)

    // Shapes & Metrics
    readonly property int pillRadius: 24
    readonly property int cardRadius: 20
    readonly property int buttonRadius: 16
    readonly property int chipRadius: 12

    // Spring Animation Durations
    readonly property int animDurationFast: 180
    readonly property int animDurationNormal: 320
    readonly property int animDurationSlow: 450
}
