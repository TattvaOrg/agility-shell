/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/images/ImageConverterWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "images"
    displayName: "Image Converter"
    baseWidth: 276
    baseHeight: 250

    readonly property var formats: ["webp", "png", "jpg", "avif", "bmp", "tiff", "pdf"]
    readonly property var acceptedExtensions: ["png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif"]

    property string selectedFormat: EndWidgetStore.getPref("images", "format", "webp")
    property string dropStatus: "idle" // idle | hover | converting | done | error
    property string statusMessage: ""
    property bool hasFfmpeg: true
    property bool hasMagick: true
    property var fileQueue: []
    property int queueTotal: 0
    property int queueDone: 0
    property var batchPaths: []

    Process {
        id: toolCheckProc
        command: ["sh", "-c", "command -v ffmpeg >/dev/null && echo FFMPEG; (command -v magick >/dev/null || command -v convert >/dev/null) && echo MAGICK"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasFfmpeg = text.indexOf("FFMPEG") !== -1;
                root.hasMagick = text.indexOf("MAGICK") !== -1;
            }
        }
    }

    Process {
        id: filePickerProc
        command: ["sh", "-c", "zenity --file-selection --multiple --separator='|' --title='Select Image(s) to Convert' 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = text.trim();
                if (raw !== "") {
                    let paths = raw.split("|").map(p => "file://" + p);
                    root.enqueueFiles(paths);
                }
            }
        }
    }

    Process {
        id: converterProc
        property string inputPath: ""
        property string outputPath: ""
        command: ["ffmpeg", "-y", "-i", inputPath, outputPath]
        onExited: (exitCode) => {
            root.queueDone++;
            if (exitCode !== 0) {
                root.dropStatus = "error";
                root.statusMessage = "Failed: " + inputPath.replace(/.*\//, "");
                root.fileQueue = [];
                root.queueTotal = 0;
                root.queueDone = 0;
                resetTimer.restart();
                return;
            }
            if (root.fileQueue.length > 0) {
                root.statusMessage = "Converting " + root.queueDone + " / " + root.queueTotal + "...";
                root.processNext();
            } else {
                root.dropStatus = "done";
                root.statusMessage = root.queueTotal === 1
                    ? "Saved: " + outputPath.replace(/.*\//, "")
                    : root.queueTotal + " files converted";
                root.queueTotal = 0;
                root.queueDone = 0;
                resetTimer.restart();
            }
        }
    }

    Process {
        id: pdfProc
        property string outputPath: ""
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.dropStatus = "done";
                root.statusMessage = "Saved: " + outputPath.replace(/.*\//, "");
            } else {
                root.dropStatus = "error";
                root.statusMessage = "PDF failed (install ImageMagick)";
            }
            root.batchPaths = [];
            resetTimer.restart();
        }
    }

    Timer {
        id: resetTimer
        interval: 3200
        onTriggered: root.dropStatus = "idle"
    }

    function processNext() {
        let next = fileQueue[0];
        fileQueue = fileQueue.slice(1);
        converterProc.inputPath = next;
        converterProc.outputPath = next.replace(/\.[^/.]+$/, "") + "_converted." + selectedFormat;
        converterProc.running = false;
        converterProc.running = true;
    }

    function enqueueFiles(urls) {
        let valid = [];
        for (let i = 0; i < urls.length; i++) {
            let clean = urls[i].toString().replace(/^file:\/\//, "");
            let ext = clean.split(".").pop().toLowerCase();
            if (acceptedExtensions.indexOf(ext) !== -1)
                valid.push(clean);
        }
        if (valid.length === 0) {
            dropStatus = "error";
            statusMessage = "Unsupported file type";
            resetTimer.restart();
            return;
        }
        if (selectedFormat === "pdf") {
            if (!hasMagick) {
                dropStatus = "error";
                statusMessage = "ImageMagick required for PDF";
                resetTimer.restart();
                return;
            }
            dropStatus = "converting";
            statusMessage = "Creating PDF...";
            let outPdf = valid[0].replace(/\.[^/.]+$/, "") + (valid.length > 1 ? "_merged" : "_converted") + ".pdf";
            pdfProc.outputPath = outPdf;
            pdfProc.command = ["magick"].concat(valid).concat([outPdf]);
            pdfProc.running = false;
            pdfProc.running = true;
            return;
        }
        if (!hasFfmpeg) {
            dropStatus = "error";
            statusMessage = "ffmpeg not installed";
            resetTimer.restart();
            return;
        }
        dropStatus = "converting";
        fileQueue = valid.slice(1);
        queueTotal = valid.length;
        queueDone = 0;
        statusMessage = valid.length > 1 ? ("Converting 0 / " + valid.length + "...") : "Converting...";
        converterProc.inputPath = valid[0];
        converterProc.outputPath = valid[0].replace(/\.[^/.]+$/, "") + "_converted." + selectedFormat;
        converterProc.running = false;
        converterProc.running = true;
    }

    EndWidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "PNG · JPG · WEBP · AVIF · BMP · PDF · TIFF"
                color: EndTheme.onCardMuted
                font.family: SettingsService.fontFamily
                font.pixelSize: 9
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: root.dropStatus === "hover" ? Qt.rgba(EndTheme.primary.r, EndTheme.primary.g, EndTheme.primary.b, 0.22) : EndTheme.chipBg
                border.width: root.dropStatus === "hover" ? 2 : 1
                border.color: root.dropStatus === "error" ? "#ef4444" : (root.dropStatus === "done" ? EndTheme.primary : EndTheme.chipBorder)

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    width: parent.width - 20

                    SvgIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: root.dropStatus === "hover" ? "download" : (root.dropStatus === "done" ? "check" : "picture")
                        iconSize: 28
                        iconColor: root.dropStatus === "hover" || root.dropStatus === "done" ? Theme.accent : Theme.muted
                        flat: true
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: {
                            if (!root.hasFfmpeg && root.selectedFormat !== "pdf")
                                return "ffmpeg unavailable\nDrop disabled";
                            if (root.dropStatus === "idle")
                                return "Drop image(s) here or click\nto convert to ." + root.selectedFormat.toUpperCase();
                            if (root.dropStatus === "hover")
                                return "Release to convert to ." + root.selectedFormat.toUpperCase();
                            return root.statusMessage;
                        }
                        color: root.dropStatus === "idle" ? Theme.muted : Theme.fg
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        filePickerProc.running = false;
                        filePickerProc.running = true;
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onEntered: (drag) => {
                        drag.accept(Qt.CopyAction);
                        root.dropStatus = "hover";
                    }
                    onExited: if (root.dropStatus === "hover") root.dropStatus = "idle"
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0)
                            root.enqueueFiles(drop.urls);
                        else
                            root.dropStatus = "idle";
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Convert to:"
                    color: Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: fmtTxt.implicitWidth + 20
                    implicitHeight: 26
                    radius: 13
                    color: Theme.bgAccent
                    border.width: 1
                    border.color: Theme.accent

                    Text {
                        id: fmtTxt
                        anchors.centerIn: parent
                        text: root.selectedFormat.toUpperCase() + " ▾"
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let idx = root.formats.indexOf(root.selectedFormat);
                            root.selectedFormat = root.formats[(idx + 1) % root.formats.length];
                            EndWidgetStore.setPref("images", "format", root.selectedFormat);
                        }
                    }
                }
            }
        }
    }
}
