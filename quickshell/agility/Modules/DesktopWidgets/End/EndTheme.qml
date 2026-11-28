pragma Singleton
import QtQuick
import qs.Core

/*
 * Material 3 Expressive color-role adapter for End widgets, derived dynamically
 * from Agility Shell's active Theme (including wallpaper-extracted schemes).
 */
QtObject {
    id: root

    function luminance(c) {
        return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    }

    function contrastOn(c) {
        return luminance(c) > 0.54 ? Qt.rgba(0.08, 0.09, 0.08, 1.0) : Qt.rgba(0.97, 0.97, 0.98, 1.0);
    }

    function mixColor(a, b, t) {
        return Qt.rgba(
            a.r * (1 - t) + b.r * t,
            a.g * (1 - t) + b.g * t,
            a.b * (1 - t) + b.b * t,
            1.0
        );
    }

    function shiftHue(c, hueDelta, satScale, lightTarget) {
        let h = (c.hslHue >= 0 ? c.hslHue : 0.1) + hueDelta;
        while (h < 0) h += 1.0;
        while (h >= 1.0) h -= 1.0;
        let s = Math.max(0.22, Math.min(0.85, c.hslSaturation * satScale));
        let l = lightTarget !== undefined ? lightTarget : Math.max(0.58, Math.min(0.82, c.hslLightness));
        return Qt.hsla(h, s, l, 1.0);
    }

    // Core M3 roles
    readonly property color primary: Theme.accent
    readonly property color onPrimary: contrastOn(primary)

    // Secondary (sage/cool companion) & Tertiary (warm gold/amber companion)
    readonly property color secondary: {
        let base = Theme.accentComplementary;
        return Qt.hsla(base.hslHue >= 0 ? base.hslHue : 0.35, Math.max(0.32, base.hslSaturation), 0.74, 1.0);
    }
    readonly property color onSecondary: contrastOn(secondary)

    readonly property color tertiary: shiftHue(Theme.accent, -0.22, 1.05, 0.76)
    readonly property color onTertiary: contrastOn(tertiary)

    // Translucent frosted glass tint layered over the undimmed blurred wallpaper
    readonly property color glassTint: {
        let base = mixColor(Theme.bg, Theme.accent, 0.22);
        return Qt.rgba(base.r, base.g, base.b, Theme.isDark ? 0.36 : 0.48);
    }

    // Inner sub-tile / metric pill fill (frosted dark-tinted chip inside cards)
    readonly property color chipBg: Theme.isDark
        ? Qt.rgba(0.05, 0.06, 0.07, 0.34)
        : Qt.rgba(1.0, 1.0, 1.0, 0.45)

    readonly property color chipBorder: Theme.isDark
        ? Qt.rgba(1.0, 1.0, 1.0, 0.14)
        : Qt.rgba(0.0, 0.0, 0.0, 0.12)

    readonly property color glassBorder: Theme.isDark
        ? Qt.rgba(1.0, 1.0, 1.0, 0.18)
        : Qt.rgba(1.0, 1.0, 1.0, 0.55)

    readonly property color glassHighlight: Theme.isDark
        ? Qt.rgba(1.0, 1.0, 1.0, 0.22)
        : Qt.rgba(1.0, 1.0, 1.0, 0.65)

    // Crisp foreground text over frosted wallpaper glass
    readonly property color onCard: Theme.isDark ? Qt.rgba(0.96, 0.97, 0.96, 1.0) : Qt.rgba(0.09, 0.10, 0.11, 1.0)
    readonly property color onCardMuted: Theme.isDark ? Qt.rgba(0.90, 0.92, 0.90, 0.68) : Qt.rgba(0.15, 0.16, 0.18, 0.65)

    // Fallback solid card background when blurred wallpaper is unavailable
    readonly property color cardBg: Theme.isDark
        ? Qt.rgba(Theme.bg.r * 1.15, Theme.bg.g * 1.15, Theme.bg.b * 1.15, 0.78)
        : Qt.rgba(Theme.bg.r * 0.96, Theme.bg.g * 0.96, Theme.bg.b * 0.96, 0.88)
}
