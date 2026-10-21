import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components

AppContainer {
    id: root

    AppGroup {
        title: "Keyboard Layouts"
        icon: "keyboard"
        showDividers: false

        Repeater {
            model: SettingsService.enabledKbLayouts

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SettingRowTemplate {
                    label: {
                        let nameMap = {
                            "us": "English (US)",
                            "latam": "Spanish (LatAm)",
                            "es": "Spanish (ES)",
                            "fr": "French",
                            "de": "German",
                            "it": "Italian",
                            "pt": "Portuguese",
                            "ru": "Russian"
                        };
                        return nameMap[modelData] || modelData;
                    }
                    description: index === 0 ? "Primary Layout" : "Secondary Layout"

                    SvgIconButton {
                        icon: "trash"
                        visible: SettingsService.enabledKbLayouts.length > 1
                        onClicked: {
                            let layouts = [...SettingsService.enabledKbLayouts];
                            let idx = layouts.indexOf(modelData);
                            if (idx !== -1) {
                                layouts.splice(idx, 1);
                                SettingsService.enabledKbLayouts = layouts;
                            }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    visible: true
                }
            }
        }

        ThemedSelect {
            label: "Add Layout"
            description: "Select a language to add"
            searchable: true
            model: [
                "None",
                "English (US)",
                "Spanish (LatAm)",
                "Spanish (ES)",
                "French",
                "German",
                "Italian",
                "Portuguese",
                "Russian"
            ]
            currentIndex: 0
            onActivated: (index) => {
                if (index === 0) return;
                
                let codeMap = [
                    "", "us", "latam", "es", "fr", "de", "it", "pt", "ru"
                ];
                let code = codeMap[index];
                if (SettingsService.enabledKbLayouts.indexOf(code) === -1) {
                    let layouts = [...SettingsService.enabledKbLayouts];
                    layouts.push(code);
                    SettingsService.enabledKbLayouts = layouts;
                }
                
                // Reset the select back to "None"
                currentIndex = Qt.binding(() => 0);
            }
        }
    }

    AppGroup {
        title: "Keyboard Shortcuts"
        icon: "keybinds-icon"
        showDividers: false

        // Agility Shell Action Shortcuts
        Repeater {
            model: SettingsService.actionShortcuts

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SettingRowTemplate {
                    label: modelData.title
                    description: "Agility Shell Built-in Action"

                    RowLayout {
                        spacing: Constants.sizeSm

                        KeyRecordPill {
                            keyText: modelData.key
                            onKeyRecorded: (newKey) => {
                                if (newKey !== "" && newKey !== modelData.key) {
                                    let updated = JSON.parse(JSON.stringify(SettingsService.actionShortcuts));
                                    updated[index].key = newKey;
                                    SettingsService.actionShortcuts = updated;
                                    SettingsService.saveSettings();
                                }
                            }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    visible: true
                }
            }
        }

        // Custom User Shortcuts Title
        ThemedText {
            text: "Custom Shortcuts"
            font.weight: Font.Bold
            customSize: Constants.sizeSm
            color: Theme.fg
            Layout.topMargin: Constants.sizeSm
            visible: SettingsService.customShortcuts.length > 0
        }

        Repeater {
            model: SettingsService.customShortcuts

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                SettingRowTemplate {
                    label: modelData.name || "Custom"
                    description: modelData.command || ""

                    RowLayout {
                        spacing: Constants.sizeSm

                        KeyRecordPill {
                            keyText: modelData.key
                            onKeyRecorded: (newKey) => {
                                if (newKey !== "" && newKey !== modelData.key) {
                                    let updated = JSON.parse(JSON.stringify(SettingsService.customShortcuts));
                                    updated[index].key = newKey;
                                    SettingsService.customShortcuts = updated;
                                    SettingsService.saveSettings();
                                }
                            }
                        }

                        SvgIconButton {
                            icon: "trash"
                            onClicked: {
                                let updated = JSON.parse(JSON.stringify(SettingsService.customShortcuts));
                                updated.splice(index, 1);
                                SettingsService.customShortcuts = updated;
                                SettingsService.saveSettings();
                            }
                        }
                    }
                }

                Divider {
                    Layout.fillWidth: true
                    visible: true
                }
            }
        }

        // Add New Custom Shortcut Form Card
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Constants.sizeSm
            radius: Constants.sizeSm
            color: Theme.isDark ? Qt.rgba(Theme.bgSecondary.r, Theme.bgSecondary.g, Theme.bgSecondary.b, 0.6) : Theme.bgSecondary
            border.color: Theme.borderSecondary
            border.width: 1
            implicitHeight: addFormLayout.implicitHeight + (Constants.sizeMd * 2)

            ColumnLayout {
                id: addFormLayout
                anchors.fill: parent
                anchors.margins: Constants.sizeMd
                spacing: Constants.sizeMd

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeXs

                    SvgIcon {
                        icon: "keyboard"
                        iconSize: Constants.sizeSm
                        iconColor: Theme.accent
                        flat: true
                    }

                    ThemedText {
                        text: "Add New Custom Shortcut"
                        font.weight: Font.DemiBold
                        customSize: Constants.sizeSm
                        color: Theme.fg
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm

                    ThemedTextField {
                        id: newShortcutName
                        label: "Shortcut Name"
                        placeholderText: "e.g. Terminal, Browser, File Manager"
                        showSubmitHint: false
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: Constants.sizeXs
                        Layout.preferredWidth: 220

                        ThemedText {
                            text: "Shortcut Key"
                            font.bold: true
                            color: Theme.fg
                            customSize: Constants.sizeSm
                        }

                        KeyRecordPill {
                            id: newShortcutKeyPill
                            placeholder: "Click to record key..."
                            Layout.fillWidth: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Constants.sizeSm

                    ThemedTextField {
                        id: newShortcutCmd
                        label: "Command to Execute"
                        placeholderText: "e.g. alacritty, firefox, thunar"
                        showSubmitHint: false
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: Constants.sizeXs
                        Layout.alignment: Qt.AlignBottom

                        Item {
                            implicitHeight: Constants.sizeSm + 4
                            visible: true
                        }

                        Button {
                            id: addShortcutBtn
                            text: "+ Add Shortcut"
                            enabled: newShortcutName.text.trim() !== "" && newShortcutKeyPill.keyText.trim() !== "" && newShortcutCmd.text.trim() !== ""
                            opacity: enabled ? 1.0 : 0.5
                            font.family: Constants.fontFamily
                            font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                            font.weight: Font.Medium
                            implicitHeight: 34
                            implicitWidth: 140
                            contentItem: ThemedText {
                                text: addShortcutBtn.text
                                font.family: Constants.fontFamily
                                font.pixelSize: Math.round(11 * SettingsService.fontScale)
                                font.weight: Font.DemiBold
                                color: addShortcutBtn.enabled ? (addShortcutBtn.hovered ? Theme.bg : Theme.accent) : Theme.muted
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: addShortcutBtn.enabled && addShortcutBtn.hovered ? Theme.accent : Theme.bg
                                border.color: addShortcutBtn.enabled ? Theme.accent : Theme.borderSecondary
                                border.width: 1
                                radius: Constants.sizeXs

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Constants.animFast
                                    }
                                }
                            }
                            onClicked: {
                                let name = newShortcutName.text.trim();
                                let key = newShortcutKeyPill.keyText.trim();
                                let cmd = newShortcutCmd.text.trim();
                                if (name !== "" && key !== "" && cmd !== "") {
                                    let updated = JSON.parse(JSON.stringify(SettingsService.customShortcuts));
                                    updated.push({
                                        "name": name,
                                        "key": key,
                                        "command": cmd
                                    });
                                    SettingsService.customShortcuts = updated;
                                    SettingsService.saveSettings();
                                    newShortcutName.text = "";
                                    newShortcutKeyPill.keyText = "";
                                    newShortcutCmd.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    AppGroup {
        title: "Clipboard"
        icon: "clipboard"

        ThemedSelect {
            label: "Clipboard Max History Items"
            description: "Limit number of clipboard entries displayed"
            model: ["25 items", "50 items", "100 items", "200 items", "500 items"]
            currentIndex: {
                let items = SettingsService.clipboardMaxItems;
                if (items === 25)
                    return 0;

                if (items === 50)
                    return 1;

                if (items === 100)
                    return 2;

                if (items === 200)
                    return 3;

                if (items === 500)
                    return 4;

                return 1;
            }
            onActivated: (index) => {
                let vals = [25, 50, 100, 200, 500];
                SettingsService.clipboardMaxItems = vals[index];
            }
        }

    }

}
