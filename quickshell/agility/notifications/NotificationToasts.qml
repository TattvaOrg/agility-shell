import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:agility-notification-toasts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    implicitWidth: 380
    implicitHeight: Math.min(680, toastColumn.implicitHeight + 64)
    color: "transparent"

    visible: NotificationService.activeToasts.length > 0

    Column {
        id: toastColumn
        anchors.top: parent.top
        anchors.topMargin: 48
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 10
        width: 360

        Repeater {
            model: NotificationService.activeToasts

            Item {
                id: toastWrapper
                width: 360
                height: toastCard.implicitHeight
                clip: false

                property var toastData: modelData
                property bool isHovered: dragArea.containsMouse
                property real dragX: 0

                // ─── Countdown Dismiss Timer ───
                property real remainingTime: toastData.durationMs || 5000
                property real totalTime: toastData.durationMs || 5000

                Timer {
                    id: countdownTimer
                    interval: 50
                    running: !toastWrapper.isHovered && toastWrapper.remainingTime > 0
                    repeat: true
                    onTriggered: {
                        toastWrapper.remainingTime -= 50
                        if (toastWrapper.remainingTime <= 0) {
                            countdownTimer.stop()
                            NotificationService.dismissToast(toastData.id)
                        }
                    }
                }

                GlassCard {
                    id: toastCard
                    width: parent.width
                    radius: 18
                    x: toastWrapper.dragX
                    implicitHeight: contentCol.implicitHeight + 20

                    opacity: Math.max(0.0, 1.0 - (Math.abs(toastWrapper.dragX) / 200.0))

                    Behavior on x {
                        enabled: !dragArea.drag.active
                        NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    }

                    Column {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        // ─── Header: App Icon + Name + Urgency Badge + Close "X" ───
                        Row {
                            width: parent.width
                            spacing: 8

                            GlassIcon {
                                source: toastData.appIcon || "notification"
                                size: 18
                                color: Theme.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: toastData.appName || "Notification"
                                color: Theme.colTextSec
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 80
                                elide: Text.ElideRight
                            }

                            // Urgency Dot
                            Rectangle {
                                width: 7
                                height: 7
                                radius: 3.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: toastData.urgency === 2 ? "#FF5555" : (toastData.urgency === 0 ? "#888888" : Theme.colAccent)
                                visible: toastData.urgency !== 1
                            }

                            Item {
                                width: Math.max(0, parent.width - childrenRect.width)
                                height: 1
                            }

                            // Dismiss Close "X" Button
                            GlassIcon {
                                source: "x"
                                size: 14
                                color: Theme.colTextSec
                                anchors.verticalCenter: parent.verticalCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NotificationService.dismissToast(toastData.id)
                                    }
                                }
                            }
                        }

                        // ─── Summary (Title) ───
                        Text {
                            text: toastData.summary || ""
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            width: parent.width
                            wrapMode: Text.Wrap
                            visible: text !== ""
                        }

                        // ─── Body Text ───
                        Text {
                            text: toastData.body || ""
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        // ─── Action Buttons Row ───
                        Row {
                            width: parent.width
                            spacing: 8
                            visible: toastData.actions && toastData.actions.length > 0

                            Repeater {
                                model: toastData.actions || []

                                GlassPill {
                                    text: modelData.label || "Action"
                                    pillHeight: 26
                                    active: true
                                    activeColor: Theme.colAccent
                                    onClicked: {
                                        NotificationService.invokeAction(toastData.id, modelData.key)
                                    }
                                }
                            }
                        }

                        // ─── Countdown Dismiss Progress Bar ───
                        Item {
                            width: parent.width
                            height: 3

                            Rectangle {
                                anchors.fill: parent
                                radius: 1.5
                                color: Theme.isGlass ? "#18FFFFFF" : Theme.colPillBg
                            }

                            Rectangle {
                                id: progressBar
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: 1.5
                                width: Math.max(0, Math.round(parent.width * (toastWrapper.remainingTime / toastWrapper.totalTime)))
                                color: Theme.colAccent

                                Behavior on width {
                                    NumberAnimation { duration: 60 }
                                }
                            }
                        }
                    }

                    // ─── Swipe-to-Dismiss MouseArea ───
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        drag.target: toastCard
                        drag.axis: Drag.XAxis
                        drag.minimumX: -20
                        drag.maximumX: 400

                        onReleased: {
                            if (toastCard.x > 80) {
                                NotificationService.dismissToast(toastData.id)
                            } else {
                                toastCard.x = 0
                            }
                        }
                    }
                }
            }
        }
    }
}
