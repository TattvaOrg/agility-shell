import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

Scope {
	id: root
	property bool failed;
	property string errorString;

	// Connect to the Quickshell global to listen for the reload signals.
	Connections {
		target: Quickshell

		function onReloadCompleted() {
			root.failed = false;
			popupLoader.loading = true;
		}

		function onReloadFailed(error: string) {
			// Close any existing popup before making a new one.
			popupLoader.active = false;

			root.failed = true;
			root.errorString = error;
			popupLoader.loading = true;
		}
	}

	// Keep the popup in a loader because it isn't needed most of the time
	LazyLoader {
		id: popupLoader

		PanelWindow {
			id: popup

			exclusiveZone: 0
			anchors.top: true
			margins.top: 0

			implicitWidth: rect.width + shadow.radius * 2
			implicitHeight: rect.height + shadow.radius * 2

			WlrLayershell.namespace: "quickshell:reloadPopup"

			// color blending is a bit odd as detailed in the type reference.
			color: "transparent"

			Rectangle {
				id: rect
				anchors.centerIn: parent
				color: failed ?  "#ffe99195" : "#ffD1E8D5"

				implicitHeight: layout.implicitHeight + 30
				implicitWidth: layout.implicitWidth + 30
				radius: 12

				// Fills the whole area of the rectangle, making any clicks go to it,
				// which dismiss the popup.
				MouseArea {
					id: mouseArea
					anchors.fill: parent
					onPressed: {
						popupLoader.active = false
					}

					// makes the mouse area track mouse hovering, so the hide animation
					// can be paused when hovering.
					hoverEnabled: true
				}

				ColumnLayout {
					id: layout
					spacing: 10
					anchors {
						top: parent.top
						topMargin: 10
						horizontalCenter: parent.horizontalCenter
					}

					Text {
						renderType: Text.NativeRendering
						font.family: "Google Sans Flex"
						font.pointSize: 14
						text: root.failed ? "Quickshell: Reload failed" : "Quickshell reloaded"
						color: failed ? "#ff93000A" : "#ff0C1F13"
					}

					Text {
						renderType: Text.NativeRendering
						font.family: "JetBrains Mono NF"
						font.pointSize: 11
						text: root.errorString
						color: failed ? "#ff93000A" : "#ff0C1F13"
						// When visible is false, it also takes up no space.
						visible: root.errorString != ""
					}
				}

				// The popup will hide 1 second after popping up, plus 1 second for each
				// 15 characters of error text.
				Timer {
					id: hideTimer
					interval: 1000 + (root.errorString.length / 15) * 1000
					running: true

					onTriggered: {
						popupLoader.active = false;
					}
				}

				// Pause the hide timer if the mouse is hovering the popup, to give the user
				// time to read it.
				Binding {
					target: hideTimer
					property: "running"
					value: !mouseArea.containsMouse
				}
			}

			// Smooth in and out animations.
			ParallelAnimation {
				id: hideAnim
				running: !popupLoader.loading

				NumberAnimation {
					target: popup
					property: "opacity"
					to: 0
					duration: 500
					easing.type: Easing.OutQuad
				}

				NumberAnimation {
					target: popup.margins
					property: "top"
					to: -popup.height
					duration: 500
					easing.type: Easing.OutQuad
				}

				// When the hide animation finishes, we can set the loader to inactive
				// to destroy the popup.
				onFinished: popupLoader.active = false
			}

			ParallelAnimation {
				id: showAnim
				running: popupLoader.loading

				NumberAnimation {
					target: popup
					property: "opacity"
					from: 0
					to: 1
					duration: 500
					easing.type: Easing.OutQuad
				}

				NumberAnimation {
					target: popup.margins
					property: "top"
					from: -popup.height
					to: 0
					duration: 500
					easing.type: Easing.OutQuad
				}
			}

			// A drop shadow behind the popup.
			RectangularGlow {
				id: shadow
				anchors.fill: rect
				glowRadius: 5
				spread: 0.2
				color: "#40000000"
				cornerRadius: rect.radius + glowRadius
			}
		}
	}
}
