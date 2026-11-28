/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/resources/ResourcesWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "resources"
    displayName: "System Resources"
    supportsFlip: true
    isVertical: EndWidgetStore.getPref("resources", "vertical", false)

    baseWidth: isVertical ? 132 : 420
    baseHeight: isVertical ? 384 : 118

    property int cpuPct: 0
    property int ramPct: 0
    property int diskPct: 0
    property var prevCpu: ({ idle: 0, total: 0 })

    Process {
        id: cpuProc
        command: ["cat", "/proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                let firstLine = text.split("\n")[0];
                let parts = firstLine.trim().split(/\s+/);
                if (parts.length < 5)
                    return;
                let idle = parseInt(parts[4]) + (parseInt(parts[5]) || 0);
                let total = 0;
                for (let i = 1; i < parts.length; i++) {
                    let v = parseInt(parts[i]);
                    if (!isNaN(v)) total += v;
                }
                let dIdle = idle - root.prevCpu.idle;
                let dTotal = total - root.prevCpu.total;
                if (dTotal > 0 && root.prevCpu.total > 0)
                    root.cpuPct = Math.max(0, Math.min(100, Math.round(100 * (1 - dIdle / dTotal))));
                root.prevCpu = { idle: idle, total: total };
            }
        }
    }

    Process {
        id: memProc
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                let total = 0;
                let avail = 0;
                let lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].startsWith("MemTotal:"))
                        total = parseInt(lines[i].replace(/\D/g, "")) || 0;
                    else if (lines[i].startsWith("MemAvailable:"))
                        avail = parseInt(lines[i].replace(/\D/g, "")) || 0;
                }
                if (total > 0)
                    root.ramPct = Math.max(0, Math.min(100, Math.round(((total - avail) / total) * 100)));
            }
        }
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df / --output=pcent | tail -1 | tr -dc '0-9'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(text.trim());
                if (!isNaN(v))
                    root.diskPct = Math.max(0, Math.min(100, v));
            }
        }
    }

    Timer {
        interval: Math.max(1500, SystemInfoService.performanceInterval)
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true;
            if (!memProc.running) memProc.running = true;
        }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!diskProc.running) diskProc.running = true;
        }
    }

    component StatCard: EndWidgetCard {
        property string value: "0%"
        property string label: ""
        property string iconName: "cpu"
        property int shapeType: MaterialShape.Shape.Gem
        property color badgeColor: EndTheme.primary
        property color badgeIconColor: EndTheme.onPrimary

        implicitWidth: 132
        implicitHeight: 118
        width: 132
        height: 118
        trackX: x
        trackY: y

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignRight
                width: 34
                height: 34

                MaterialShape {
                    anchors.fill: parent
                    shape: shapeType
                    color: badgeColor
                }
                SvgIcon {
                    anchors.centerIn: parent
                    icon: iconName
                    iconSize: 16
                    iconColor: badgeIconColor
                    flat: true
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: value
                color: EndTheme.onCard
                font.family: SettingsService.fontFamily
                font.pixelSize: 28
                font.weight: Font.Bold
            }
            Text {
                text: label
                color: EndTheme.onCardMuted
                font.family: SettingsService.fontFamily
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
    }

    Grid {
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        spacing: 12

        StatCard {
            iconName: "cpu"
            value: root.cpuPct + "%"
            label: "CPU"
            shapeType: MaterialShape.Shape.Gem
            badgeColor: EndTheme.tertiary
            badgeIconColor: EndTheme.onTertiary
        }
        StatCard {
            iconName: "box"
            value: root.ramPct + "%"
            label: "RAM"
            shapeType: MaterialShape.Shape.Cookie4Sided
            badgeColor: EndTheme.secondary
            badgeIconColor: EndTheme.onSecondary
        }
        StatCard {
            iconName: SystemInfoService.hasBattery ? "charger" : "monitor"
            value: SystemInfoService.hasBattery ? (SystemInfoService.batteryLevel + "%") : (root.diskPct + "%")
            label: SystemInfoService.hasBattery ? "Battery" : "Disk"
            shapeType: MaterialShape.Shape.Cookie12Sided
            badgeColor: EndTheme.primary
            badgeIconColor: EndTheme.onPrimary
        }
    }
}
