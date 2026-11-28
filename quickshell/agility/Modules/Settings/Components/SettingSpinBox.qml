import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

SettingRowTemplate {
    id: root

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property real defaultValue: 1
    property string suffix: ""
    property int decimals: 0
    property bool allowOff: false
    property string offText: "Off"

    signal moved(real val)

    RowLayout {
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 4
        opacity: root.enabled ? 1 : 0.5

        // Minus Button
        Rectangle {
            width: 28
            height: 28
            radius: 6
            color: minusArea.containsMouse ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))
            scale: minusArea.pressed ? 0.94 : 1
            border.width: 1
            border.color: Theme.borderSecondary

            SvgIcon {
                anchors.centerIn: parent
                icon: "minus"
                iconSize: 12
                iconColor: root.value <= root.from ? Theme.muted : Theme.fg
                flat: true
            }

            MouseArea {
                id: minusArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let newVal = root.value - root.stepSize;
                    if (newVal < root.from)
                        newVal = root.from;

                    root.moved(newVal);
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuart
                }
            }
        }

        // Center Value Input
        Rectangle {
            Layout.preferredWidth: Math.max(54, contentRow.implicitWidth + 16)
            Layout.preferredHeight: 28
            radius: 6
            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
            border.width: 1
            border.color: valueInput.activeFocus ? Theme.accent : Theme.borderSecondary

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: valueInput.forceActiveFocus()
            }

            Row {
                id: contentRow

                anchors.centerIn: parent
                spacing: 3

                TextInput {
                    id: valueInput

                    function updateDisplay() {
                        text = (root.allowOff && root.value <= 0.001) ? root.offText : root.value.toFixed(root.decimals);
                    }

                    font.family: Constants.fontFamily
                    font.bold: true
                    font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                    color: root.allowOff && root.value <= 0.001 && !activeFocus ? Theme.muted : Theme.fg
                    selectByMouse: true
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    onActiveFocusChanged: {
                        if (activeFocus) {
                            text = root.value.toFixed(root.decimals);
                            selectAll();
                        } else {
                            updateDisplay();
                        }
                    }
                    Component.onCompleted: updateDisplay()
                    onEditingFinished: {
                        let parsed = parseFloat(text);
                        if (isNaN(parsed) || parsed < root.from || parsed > root.to)
                            parsed = root.defaultValue;

                        root.moved(parsed);
                        valueInput.focus = false;
                        updateDisplay();
                    }

                    Connections {
                        function onValueChanged() {
                            if (!valueInput.activeFocus)
                                valueInput.updateDisplay();

                        }

                        target: root
                    }

                }

                ThemedText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.suffix
                    color: Theme.muted
                    customSize: 11
                    visible: root.suffix !== "" && (!root.allowOff || root.value > 0.001 || valueInput.activeFocus)
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

        }

        // Plus Button
        Rectangle {
            width: 28
            height: 28
            radius: 6
            color: plusArea.containsMouse ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)) : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))
            scale: plusArea.pressed ? 0.94 : 1
            border.width: 1
            border.color: Theme.borderSecondary

            SvgIcon {
                anchors.centerIn: parent
                icon: "plus"
                iconSize: 12
                iconColor: root.value >= root.to ? Theme.muted : Theme.fg
                flat: true
            }

            MouseArea {
                id: plusArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    let newVal = root.value + root.stepSize;
                    if (newVal > root.to)
                        newVal = root.to;

                    root.moved(newVal);
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Constants.animFast
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuart
                }

            }

        }

    }

}
