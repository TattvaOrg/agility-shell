/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/images/CustomImage.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "customImage"
    displayName: "Shaped Image"
    sizeModes: ["Cookie4Sided", "Arch", "Flower", "Clover4Leaf", "Heart", "Circle", "Gem"]
    sizeMode: EndWidgetStore.getPref("customImage", "shape", "Cookie4Sided")

    baseWidth: 184
    baseHeight: 184

    property string imagePath: EndWidgetStore.getPref("customImage", "path", "")
    property bool dropHover: false

    Process {
        id: pickerProc
        command: ["sh", "-c", "zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif' --title='Select Shaped Image' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p !== "") {
                    root.imagePath = "file://" + p;
                    EndWidgetStore.setPref("customImage", "path", root.imagePath);
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        MaterialShape {
            id: maskShape
            anchors.fill: parent
            shapeName: root.sizeMode
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
            visible: false
        }

        DropShadow {
            anchors.fill: maskShape
            source: maskShape
            radius: 14
            samples: 15
            verticalOffset: 4
            color: Qt.rgba(0, 0, 0, 0.42)
            transparentBorder: true
        }

        MaterialShape {
            anchors.fill: parent
            shapeName: root.sizeMode
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
            visible: root.imagePath === ""
        }

        Item {
            anchors.fill: parent
            visible: root.imagePath !== ""
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: maskShape
            }

            AnimatedImage {
                anchors.fill: parent
                source: root.imagePath
                fillMode: Image.PreserveAspectCrop
                playing: root.visible
                asynchronous: true
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4
            visible: root.imagePath === ""

            SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.dropHover ? "download" : "sparkles"
                iconSize: 28
                iconColor: root.dropHover ? Theme.accent : Theme.muted
                flat: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drop or click"
                color: Theme.muted
                font.family: SettingsService.fontFamily
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton || root.imagePath === "") {
                    pickerProc.running = false;
                    pickerProc.running = true;
                }
            }
        }

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: (drag) => { drag.accept(Qt.CopyAction); root.dropHover = true; }
            onExited: root.dropHover = false
            onDropped: (drop) => {
                if (drop.hasUrls && drop.urls.length > 0) {
                    root.imagePath = drop.urls[0].toString();
                    EndWidgetStore.setPref("customImage", "path", root.imagePath);
                }
                root.dropHover = false;
            }
        }
    }
}
