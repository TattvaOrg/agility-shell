import QtQuick
import ".."
import "../components"
import "../bar" as Bar

Item {
    id: root

    implicitWidth: 340
    implicitHeight: mainCol.implicitHeight + 32

    property string pendingAction: ""
    property string pendingActionTitle: ""

    function requestAction(action, title, requireConfirm) {
        if (!requireConfirm) {
            PopoutService.triggerSessionAction(action)
        } else {
            root.pendingAction = action
            root.pendingActionTitle = title
        }
    }

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ─── Header ───
        Row {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                GlassButton {
                    iconSource: "arrow-left"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.open("control_center")
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Power & Session"
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }

            GlassButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconSource: "x"
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                onClicked: PopoutService.close()
            }
        }

        // ─── Confirmation Modal ───
        GlassCard {
            id: confirmCard
            width: parent.width
            implicitHeight: confirmCol.implicitHeight + 24
            radius: 16
            visible: root.pendingAction !== ""
            color: Qt.rgba(0.94, 0.27, 0.27, 0.15)
            rimColor: "#EF4444"

            Column {
                id: confirmCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                Row {
                    spacing: 8
                    GlassIcon {
                        source: "warning"
                        size: 20
                        color: "#EF4444"
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Confirm " + root.pendingActionTitle
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                Text {
                    text: "Are you sure you want to " + root.pendingActionTitle.toLowerCase() + "? Any unsaved work may be lost."
                    color: Theme.colTextSec
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    GlassButton {
                        text: "Cancel"
                        implicitHeight: 30
                        radius: 8
                        onClicked: {
                            root.pendingAction = ""
                            root.pendingActionTitle = ""
                        }
                    }

                    GlassButton {
                        text: "Confirm"
                        primary: true
                        accentColor: "#EF4444"
                        implicitHeight: 30
                        radius: 8
                        onClicked: {
                            var act = root.pendingAction
                            root.pendingAction = ""
                            root.pendingActionTitle = ""
                            PopoutService.triggerSessionAction(act)
                        }
                    }
                }
            }
        }

        // ─── Session Actions Grid (2 columns x 3 rows) ───
        Grid {
            id: actionsGrid
            width: parent.width
            columns: 2
            spacing: 10
            visible: root.pendingAction === ""

            // 1. Lock
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("lock", "Lock Screen", false)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "lock"
                        size: 20
                        color: Theme.colAccent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Lock"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Lock screen"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 2. Suspend
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("suspend", "Suspend", false)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "moon"
                        size: 20
                        color: "#FBBF24"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Suspend"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Sleep mode"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 3. Hibernate
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("hibernate", "Hibernate", true)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "snowflake"
                        size: 20
                        color: "#38BDF8"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Hibernate"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Save to disk"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 4. Logout
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("logout", "Log Out", true)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "sign-out"
                        size: 20
                        color: "#FB923C"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Log Out"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "End session"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 5. Reboot
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("reboot", "Restart System", true)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "rotate"
                        size: 20
                        color: "#60A5FA"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Restart"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Reboot system"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 6. Shutdown
            GlassCard {
                width: (actionsGrid.width - 10) / 2
                height: 60
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestAction("shutdown", "Power Off", true)
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "power"
                        size: 20
                        color: "#EF4444"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Power Off"
                            color: "#EF4444"
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Shut down"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
