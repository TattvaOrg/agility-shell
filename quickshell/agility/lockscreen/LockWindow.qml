import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../bar" as Bar

WlSessionLock {
    id: lockWindow

    locked: LockService.isLocked

    WlSessionLockSurface {
        id: lockSurface
        color: "#080B0F"

        Item {
            id: surfaceRoot
            anchors.fill: parent
            focus: true

            // Date / Time properties
            property string currentTime: Qt.formatTime(new Date(), "hh:mm")
            property string currentDate: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")

            Timer {
                interval: 1000
                running: lockWindow.locked
                repeat: true
                onTriggered: {
                    surfaceRoot.currentTime = Qt.formatTime(new Date(), "hh:mm")
                    surfaceRoot.currentDate = Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                }
            }

            // Keyboard Focus Trap: automatically keep focus on password field
            Keys.onPressed: function(event) {
                if (!passwordInput.activeFocus) {
                    passwordInput.forceActiveFocus()
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 0
                onClicked: {
                    passwordInput.forceActiveFocus()
                }
            }

            // ─── 1. Blurred Wallpaper Background Surface ───
            Image {
                id: blurredWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                z: 1

                source: {
                    if (LockService.blurredWallpaperPath !== "") {
                        return "file://" + LockService.blurredWallpaperPath
                    }
                    if (Theme.dbusTokens.active_wallpaper && Theme.dbusTokens.active_wallpaper !== "") {
                        return "file://" + Theme.dbusTokens.active_wallpaper
                    }
                    return ""
                }
            }

            // Dark Acrylic Glass Tint Backdrop
            Rectangle {
                anchors.fill: parent
                color: Theme.colBg
                opacity: 0.82
                z: 2
            }

            // Ambient Iridescent Radial Glow (Meniscus Glass Depth)
            Rectangle {
                width: Math.min(parent.width * 0.7, 900)
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: "transparent"
                opacity: 0.18
                z: 3

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.colAccent }
                    GradientStop { position: 0.5; color: Theme.colAccentGreen }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ─── 2. Top Header Bar (Battery Status & Session Metadata) ───
            Item {
                id: topBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 28
                height: 44
                z: 10

                // Left: Hostname / Session Security Badge
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    width: sessionRow.implicitWidth + 24
                    radius: 17
                    color: Theme.isGlass ? "#25121E2C" : Theme.colBgTile
                    border.color: Theme.isGlass ? "#1FFFFFFF" : Theme.colBorder
                    border.width: 1

                    Row {
                        id: sessionRow
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔒"
                            font.pixelSize: 13
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (LockService.hostname !== "" ? LockService.hostname : "Wayland Session") + " • Secured"
                            color: Theme.colTextSecondary
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }

                // Right: Real-time Battery Status Widget
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    width: batteryRow.implicitWidth + 24
                    radius: 17
                    color: Theme.isGlass ? "#25121E2C" : Theme.colBgTile
                    border.color: Theme.isGlass ? "#1FFFFFFF" : Theme.colBorder
                    border.width: 1

                    Row {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 8

                        // Battery Graphic
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 13
                            radius: 3
                            color: "transparent"
                            border.color: Bar.BarDataService.batteryPercent <= 20.0 ? Theme.colAccentWarm : Theme.colTextSecondary
                            border.width: 1.5

                            // Fill Level
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 2
                                anchors.verticalCenter: parent.verticalCenter
                                height: parent.height - 4
                                width: Math.max(2, (parent.width - 4) * (Math.min(100, Math.max(0, Bar.BarDataService.batteryPercent)) / 100.0))
                                radius: 1
                                color: Bar.BarDataService.batteryCharging ? Theme.colAccentGreen : (Bar.BarDataService.batteryPercent <= 20.0 ? Theme.colAccentWarm : Theme.colAccent)
                            }

                            // Battery Nipple
                            Rectangle {
                                anchors.left: parent.right
                                anchors.leftMargin: 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 5
                                radius: 1
                                color: Bar.BarDataService.batteryPercent <= 20.0 ? Theme.colAccentWarm : Theme.colTextSecondary
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(Bar.BarDataService.batteryPercent) + "%" + (Bar.BarDataService.batteryCharging ? " ⚡" : "")
                            color: Bar.BarDataService.batteryPercent <= 20.0 ? Theme.colAccentWarm : Theme.colTextPrimary
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }

            // ─── 3. Central Glass Lock Screen Card ───
            GlassCard {
                id: centerCard
                anchors.centerIn: parent
                width: 440
                implicitHeight: cardContent.implicitHeight + 64
                radius: 28
                elevation: 8
                z: 10

                Column {
                    id: cardContent
                    anchors.centerIn: parent
                    width: parent.width - 64
                    spacing: 20

                    // ── User Avatar ──
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 92
                        height: 92

                        // Outer Glowing Ring
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: Theme.colAccent
                            border.width: 2
                            opacity: 0.9
                        }

                        // Inner Avatar Masked Rectangle
                        Rectangle {
                            anchors.centerIn: parent
                            width: 82
                            height: 82
                            radius: width / 2
                            color: Theme.colBgTile
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: LockService.avatarPath !== "" ? ("file://" + LockService.avatarPath) : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: LockService.avatarPath !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: LockService.avatarPath === ""
                                text: LockService.username.length > 0 ? LockService.username.charAt(0).toUpperCase() : "U"
                                font.family: Theme.fontMain
                                font.pixelSize: 36
                                font.bold: true
                                color: Theme.colAccent
                            }
                        }
                    }

                    // ── User Name ──
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: LockService.userRealName !== "" ? LockService.userRealName : LockService.username
                        font.family: Theme.fontMain
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.colTextPrimary
                    }

                    // ── Huge Digital Clock & Date ──
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: surfaceRoot.currentTime
                            font.family: Theme.fontMain
                            font.pixelSize: 64
                            font.bold: true
                            color: Theme.colTextPrimary
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: surfaceRoot.currentDate
                            font.family: Theme.fontMain
                            font.pixelSize: 14
                            color: Theme.colTextSecondary
                        }
                    }

                    // ── Glass Password Input Field ──
                    Rectangle {
                        id: passwordBox
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 48
                        radius: 24
                        color: Theme.isGlass ? "#28121E2C" : Theme.colBgTile
                        antialiasing: true

                        property real shakeOffset: 0
                        property bool isShaking: false

                        transform: Translate {
                            x: passwordBox.shakeOffset
                        }

                        border.width: passwordBox.isShaking ? 2.0 : (passwordInput.activeFocus ? 1.5 : 1.0)
                        border.color: {
                            if (passwordBox.isShaking) return Theme.colAccentWarm
                            if (passwordInput.activeFocus) return Theme.colAccent
                            return Theme.isGlass ? "#22FFFFFF" : Theme.colBorder
                        }

                        Behavior on border.color {
                            ColorAnimation { duration: 150 }
                        }

                        // Failure Shake Animation
                        SequentialAnimation {
                            id: shakeAnim
                            onStarted: passwordBox.isShaking = true
                            onFinished: {
                                passwordBox.isShaking = false
                                passwordBox.shakeOffset = 0
                            }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: -16; duration: 40; easing.type: Easing.OutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: 16; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: -12; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: 12; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: -6; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: 6; duration: 40; easing.type: Easing.InOutQuad }
                            NumberAnimation { target: passwordBox; property: "shakeOffset"; to: 0; duration: 40; easing.type: Easing.OutQuad }
                        }

                        Connections {
                            target: LockService
                            function onAuthFailed() {
                                shakeAnim.restart()
                                passwordInput.selectAll()
                            }
                        }

                        // Lock glyph on left
                        Text {
                            id: lockGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🔑"
                            font.pixelSize: 15
                            opacity: 0.7
                        }

                        // Actual Password Input
                        TextInput {
                            id: passwordInput
                            anchors.left: lockGlyph.right
                            anchors.leftMargin: 10
                            anchors.right: submitButton.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "●"
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            color: Theme.colTextPrimary
                            selectionColor: Theme.colAccent
                            selectedTextColor: "#000000"
                            clip: true
                            focus: true
                            enabled: !LockService.isLockedOut && !LockService.authenticating

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: {
                                    if (LockService.isLockedOut) {
                                        return "Rate limited (" + Math.ceil(LockService.remainingLockoutSecs) + "s)"
                                    }
                                    if (LockService.authenticating) {
                                        return "Authenticating..."
                                    }
                                    return "Enter password..."
                                }
                                color: LockService.isLockedOut ? Theme.colAccentWarm : Theme.colTextSecondary
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                visible: passwordInput.text.length === 0
                            }

                            Keys.onReturnPressed: submit()
                            Keys.onEnterPressed: submit()
                            Keys.onEscapePressed: {
                                passwordInput.text = ""
                                LockService.errorMessage = ""
                            }

                            function submit() {
                                if (text.length > 0 && !LockService.authenticating && !LockService.isLockedOut) {
                                    LockService.authenticate(text)
                                }
                            }
                        }

                        // Submit / Loading Action Button
                        Rectangle {
                            id: submitButton
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 16
                            color: submitArea.containsMouse ? Qt.lighter(Theme.colAccent, 1.1) : Theme.colAccent
                            opacity: passwordInput.text.length > 0 ? 1.0 : 0.45

                            Text {
                                anchors.centerIn: parent
                                text: LockService.authenticating ? "⏳" : "➔"
                                font.pixelSize: 13
                                color: "#000000"
                            }

                            MouseArea {
                                id: submitArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: passwordInput.submit()
                            }
                        }
                    }

                    // ── Error / Lockout Feedback Label ──
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: LockService.errorMessage
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.colAccentWarm
                        visible: LockService.errorMessage !== ""
                    }
                }
            }

            // ─── 4. Bottom Hint ───
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Press Enter to unlock • Esc to clear"
                font.family: Theme.fontMain
                font.pixelSize: 12
                color: Theme.colTextSecondary
                opacity: 0.65
                z: 10
            }

            Component.onCompleted: {
                passwordInput.forceActiveFocus()
            }
        }
    }

    onLockedChanged: {
        if (locked) {
            LockService.refreshUserInfo()
            LockService.fetchLockStatus()
        }
    }
}
