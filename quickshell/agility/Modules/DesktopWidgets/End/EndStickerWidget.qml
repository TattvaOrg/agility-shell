/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/images/StickerWidget.qml),
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

    widgetId: "sticker"
    displayName: "Sticker"
    baseWidth: 160
    baseHeight: 160

    property string imagePath: EndWidgetStore.getPref("sticker", "path", "")
    property bool dropHover: false

    Process {
        id: pickerProc
        command: ["sh", "-c", "zenity --file-selection --file-filter='Stickers | *.png *.webp *.svg *.gif' --title='Select Sticker' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p !== "") {
                    root.imagePath = "file://" + p;
                    EndWidgetStore.setPref("sticker", "path", root.imagePath);
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        Image {
            id: stickerImg
            anchors.fill: parent
            source: root.imagePath
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: root.imagePath !== "" && status === Image.Ready
            layer.enabled: true
            layer.effect: DropShadow {
                radius: 4
                spread: 0.35
                samples: 17
                color: "#ffffff"
                transparentBorder: true
            }
        }

        EndWidgetCard {
            anchors.fill: parent
            visible: root.imagePath === "" || stickerImg.status !== Image.Ready

            Column {
                anchors.centerIn: parent
                spacing: 4
                SvgIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: root.dropHover ? "download" : "star"
                    iconSize: 28
                    iconColor: root.dropHover ? Theme.accent : Theme.muted
                    flat: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Drop sticker"
                    color: Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 10
                }
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
                    EndWidgetStore.setPref("sticker", "path", root.imagePath);
                }
                root.dropHover = false;
            }
        }
    }
}
