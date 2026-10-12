import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-notification-drawer"
    WlrLayershell.keyboardFocus: NotificationService.drawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: NotificationService.drawerOpen

    // ─── Click Outside Dismissal ───
    MouseArea {
        id: outsideDismiss
        anchors.fill: parent
        onClicked: NotificationService.closeDrawer()
    }

    // ─── Slide-in Liquid Glass Drawer Container ───
    GlassCard {
        id: drawerCard
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        anchors.rightMargin: NotificationService.drawerOpen ? 12 : -width
        width: 380
        radius: 20

        opacity: NotificationService.drawerOpen ? 1.0 : 0.0

        Behavior on anchors.rightMargin {
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Prevent clicks on drawer from reaching outsideDismiss
        MouseArea {
            anchors.fill: parent
            z: -1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // ─── Top Header: Title + Unread Count + Close Button ───
            Row {
                width: parent.width
                spacing: 10

                GlassIcon {
                    source: "bell"
                    size: 22
                    color: Theme.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Notifications"
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                GlassPill {
                    visible: NotificationService.unreadCount > 0
                    text: NotificationService.unreadCount.toString()
                    pillHeight: 22
                    active: true
                    activeColor: Theme.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    width: Math.max(0, parent.width - childrenRect.width)
                    height: 1
                }

                // Close Drawer Button
                GlassIcon {
                    source: "x"
                    size: 18
                    color: Theme.colTextSec
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.closeDrawer()
                    }
                }
            }

            // ─── Action Controls: DND Toggle + Clear All Button ───
            Row {
                width: parent.width
                spacing: 8

                // Do Not Disturb Toggle Pill
                GlassPill {
                    id: dndPill
                    text: NotificationService.dndEnabled ? "DND Active" : "Do Not Disturb"
                    iconSource: NotificationService.dndEnabled ? "bell-slash" : "bell"
                    pillHeight: 30
                    active: NotificationService.dndEnabled
                    activeColor: Theme.colAccentWarning
                    onClicked: NotificationService.toggleDnd()
                }

                Item {
                    width: Math.max(0, parent.width - childrenRect.width)
                    height: 1
                }

                // Clear All Button
                GlassButton {
                    text: "Clear All"
                    iconSource: "trash"
                    height: 30
                    visible: NotificationService.historyItems.length > 0
                    onClicked: NotificationService.clearAllHistory()
                }
            }

            // Separator Rim Line
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.isGlass ? "#1AFFFFFF" : Theme.borderColor
            }

            // ─── History Notification List ───
            Item {
                width: parent.width
                height: parent.height - 110

                ListView {
                    id: historyListView
                    anchors.fill: parent
                    spacing: 10
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    model: NotificationService.historyItems

                    delegate: GlassCard {
                        id: itemCard
                        width: historyListView.width
                        radius: 14
                        isTile: true
                        implicitHeight: itemCol.implicitHeight + 20

                        Column {
                            id: itemCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            // Header: Icon + App Name + Timestamp + Dismiss
                            Row {
                                width: parent.width
                                spacing: 8

                                GlassIcon {
                                    source: modelData.app_icon || "notification"
                                    size: 16
                                    color: Theme.colAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: modelData.app_name || "Notification"
                                    color: Theme.colTextSec
                                    font.family: Theme.fontMain
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 80
                                    elide: Text.ElideRight
                                }

                                Item {
                                    width: Math.max(0, parent.width - childrenRect.width)
                                    height: 1
                                }

                                // Dismiss Item Button
                                GlassIcon {
                                    source: "x"
                                    size: 13
                                    color: Theme.colTextSec
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            NotificationService.dismissFromHistory(modelData.id)
                                        }
                                    }
                                }
                            }

                            // Summary (Title)
                            Text {
                                text: modelData.summary || ""
                                color: Theme.colText
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                width: parent.width
                                wrapMode: Text.Wrap
                                visible: text !== ""
                            }

                            // Body Text
                            Text {
                                text: modelData.body || ""
                                color: Theme.colTextSec
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            // Actions
                            Row {
                                width: parent.width
                                spacing: 6
                                visible: modelData.actions && modelData.actions.length > 0

                                Repeater {
                                    model: modelData.actions || []

                                    GlassPill {
                                        text: modelData.label || "Action"
                                        pillHeight: 24
                                        active: true
                                        activeColor: Theme.colAccent
                                        onClicked: {
                                            NotificationService.invokeAction(modelData.id, modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── Empty State Indicator ───
                Item {
                    anchors.fill: parent
                    visible: NotificationService.historyItems.length === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        GlassIcon {
                            source: "bell-slash"
                            size: 42
                            color: Theme.colTextSec
                            opacity: 0.35
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "No Notifications"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "You're all caught up!"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            opacity: 0.65
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
