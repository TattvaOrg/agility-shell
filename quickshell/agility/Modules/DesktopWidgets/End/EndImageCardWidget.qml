/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/images/ImageCardWidget.qml),
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

    widgetId: "imageCard"
    displayName: "Image Card"
    sizeModes: ["1x2", "1x1", "2x2", "2x3"]
    sizeMode: EndWidgetStore.getPref("imageCard", "sizeMode", "1x2")

    baseWidth: sizeMode === "1x1" ? 132 : (sizeMode === "2x3" ? 420 : 276)
    baseHeight: (sizeMode === "1x1" || sizeMode === "1x2") ? 118 : 250

    property string imagePath: EndWidgetStore.getPref("imageCard", "path", "")
    property bool dropHover: false

    Process {
        id: pickerProc
        command: ["sh", "-c", "zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif' --title='Select Image' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p !== "") {
                    root.imagePath = "file://" + p;
                    EndWidgetStore.setPref("imageCard", "path", root.imagePath);
                }
            }
        }
    }

    EndWidgetCard {
        anchors.fill: parent
        clip: true

        Image {
            id: cardImg
            anchors.fill: parent
            source: root.imagePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.imagePath !== "" && status === Image.Ready
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: cardImg.width
                    height: cardImg.height
                    radius: 24
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4
            visible: root.imagePath === "" || cardImg.status !== Image.Ready

            SvgIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.dropHover ? "download" : "picture"
                iconSize: 28
                iconColor: root.dropHover ? Theme.accent : Theme.muted
                flat: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Drop or click image"
                color: Theme.muted
                font.family: SettingsService.fontFamily
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton | Qt.LeftButton
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
                    EndWidgetStore.setPref("imageCard", "path", root.imagePath);
                }
                root.dropHover = false;
            }
        }
    }
}
