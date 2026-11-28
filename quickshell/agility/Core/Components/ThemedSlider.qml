import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property string label: ""
    property string icon: ""
    property string suffix: "%"
    property int decimals: 0
    property color accentColor: "#0091FF" // Apple System Vibrant Blue from Sketch asset
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property bool enabled: true
    property bool showValue: true
    readonly property bool pressed: internalSlider.pressed

    signal moved(real val)
    signal iconClicked()

    Layout.fillWidth: true
    implicitHeight: root.label !== "" ? (labelRow.implicitHeight + mainRow.implicitHeight + 4) : 26

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.size2Xs

        RowLayout {
            id: labelRow

            Layout.fillWidth: true
            visible: root.label !== ""

            ThemedText {
                text: root.label
                customSize: 13
                font.weight: Font.Medium
                color: Theme.fg
                Layout.fillWidth: true
            }

            ThemedText {
                text: {
                    let v = root.decimals > 0 ? root.value.toFixed(root.decimals) : Math.round(root.value);
                    return v + (root.suffix !== "" ? root.suffix : "");
                }
                customSize: 11
                color: Theme.muted
                visible: root.showValue && root.icon === ""
            }

        }

        RowLayout {
            id: mainRow

            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: Constants.sizeSm

            // Left Icon
            SvgIcon {
                id: sliderIcon

                icon: root.icon
                iconSize: 18
                flat: true
                iconColor: root.enabled ? Theme.fg : Theme.muted
                bgColor: "transparent"
                visible: root.icon !== ""
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: parent.visible ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.iconClicked()
                }

                Behavior on iconColor {
                    ColorAnimation {
                        duration: Constants.animFast
                    }

                }

            }

            // Center Slider
            Slider {
                id: internalSlider

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 24
                from: root.from
                to: root.to
                stepSize: root.stepSize
                value: root.value
                enabled: root.enabled
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                onMoved: {
                    root.moved(internalSlider.value);
                }

                HoverHandler {
                    id: sliderHover

                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        let step = (root.to - root.from) / 20;
                        if (root.stepSize > 0 && root.stepSize > step)
                            step = root.stepSize;

                        let delta = event.angleDelta.y > 0 ? step : -step;
                        let newVal = Math.max(root.from, Math.min(root.to, root.value + delta));
                        if (newVal !== root.value)
                            root.moved(newVal);

                    }
                }

                // macOS Slider 4px Track
                background: Rectangle {
                    id: trackRect

                    x: internalSlider.leftPadding
                    y: Math.round(internalSlider.topPadding + (internalSlider.availableHeight - height) / 2)
                    width: internalSlider.availableWidth
                    height: 4
                    radius: 2
                    color: Theme.isDark ? Qt.rgba(120 / 255, 120 / 255, 128 / 255, 0.36) : Qt.rgba(0, 0, 0, 0.15)

                    Rectangle {
                        id: progressRect

                        width: internalSlider.visualPosition <= 0 ? 0 : Math.min(parent.width, sliderHandle.x + sliderHandle.width / 2)
                        height: parent.height
                        radius: 2
                        color: root.enabled ? root.accentColor : Theme.muted

                        Behavior on width {
                            enabled: HyprlandService.enableAnimations && !internalSlider.pressed && !sliderHover.hovered

                            NumberAnimation {
                                duration: Constants.animFast
                                easing.type: Easing.OutQuad
                            }

                        }

                    }

                }

                // macOS Slider 24 x 16 Capsule Thumb Handle
                handle: Rectangle {
                    id: sliderHandle

                    readonly property real trackWidth: internalSlider.availableWidth - width

                    x: Math.round(internalSlider.leftPadding + internalSlider.visualPosition * trackWidth)
                    y: Math.round(internalSlider.topPadding + (internalSlider.availableHeight - height) / 2)
                    width: 24
                    height: 16
                    radius: 8
                    color: "#FFFFFF"
                    border.width: 0.5
                    border.color: Theme.isDark ? "#00000030" : "#00000018"
                    scale: internalSlider.pressed ? 1.04 : (sliderHover.hovered ? 1.02 : 1.0)
                    transformOrigin: Item.Center

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        color: "#00000035"
                        radius: 3
                        samples: 9
                        verticalOffset: 1.2
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                    Behavior on x {
                        enabled: HyprlandService.enableAnimations && !internalSlider.pressed && !sliderHover.hovered

                        NumberAnimation {
                            duration: Constants.animFast
                            easing.type: Easing.OutQuad
                        }

                    }

                }

            }

            // Right Value Readout
            ThemedText {
                id: valueLabel

                text: {
                    let v = root.decimals > 0 ? root.value.toFixed(root.decimals) : Math.round(root.value);
                    return v + (root.suffix !== "" ? root.suffix : "");
                }
                customSize: 11
                color: root.enabled ? Theme.fg : Theme.muted
                visible: root.showValue
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
            }

        }

    }

}
