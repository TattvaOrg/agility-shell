/*
 * Adapted from pctrade/end4-pC (modules/ii/background/WidgetsLoader.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import qs.Core.Services

Item {
    id: root

    required property var screen
    required property var canvas
    required property bool widgetsWanted

    readonly property bool animAllowed: SettingsService.desktopCompositionAnimEnabled
        && HyprlandService.enableAnimations
        && !DisplayProfileService.gameModeActive
        && SystemInfoService.powerProfile !== "power-saver"

    readonly property int animDuration: Math.max(150, Math.round(620 / Math.max(0.4, SettingsService.desktopCompositionAnimSpeed)))

    property real revealProgress: 0.0
    property bool _initialized: false

    readonly property bool anyTextFocused: todoWidget.editing || notesWidget.editing || customTextWidget.editing
    readonly property bool isShowing: revealProgress > 0.001 || widgetsWanted

    property alias clockItem: clockWidget
    property alias userCardItem: userCardWidget
    property alias calendarItem: calendarWidget
    property alias weatherItem: weatherWidget
    property alias resourcesItem: resourcesWidget
    property alias todoItem: todoWidget
    property alias worldClockItem: worldClockWidget
    property alias timersItem: timersWidget
    property alias notesItem: notesWidget
    property alias mediaItem: mediaWidget
    property alias imagesItem: imagesWidget
    property alias imageCardItem: imageCardWidget
    property alias customImageItem: customImageWidget
    property alias stickerItem: stickerWidget
    property alias customTextItem: customTextWidget

    function syncReveal() {
        let target = root.widgetsWanted ? 1.0 : 0.0;
        if (!root._initialized || !root.animAllowed) {
            widgetRevealAnim.stop();
            root.revealProgress = target;
            if (SettingsService.settingsLoaded)
                root._initialized = true;
            return;
        }
        if (Math.abs(root.revealProgress - target) < 0.001) {
            widgetRevealAnim.stop();
            root.revealProgress = target;
            return;
        }
        if (widgetRevealAnim.running && Math.abs(widgetRevealAnim.to - target) < 0.001)
            return;
        widgetRevealAnim.stop();
        widgetRevealAnim.duration = root.animDuration;
        widgetRevealAnim.to = target;
        widgetRevealAnim.start();
    }

    onWidgetsWantedChanged: syncReveal()
    onAnimAllowedChanged: syncReveal()
    Component.onCompleted: syncReveal()

    NumberAnimation {
        id: widgetRevealAnim
        target: root
        property: "revealProgress"
        easing.type: Easing.OutCubic
    }

    anchors.fill: parent
    visible: revealProgress > 0.001 || widgetsWanted

    EndVisualizerWidget {
        id: visualizerWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 0
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["visualizer"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndClockWidget {
        id: clockWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 1
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["clock"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndUserCardWidget {
        id: userCardWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 2
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["userCard"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndCalendarWidget {
        id: calendarWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 3
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["calendar"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndWeatherWidget {
        id: weatherWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 4
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["weather"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndResourcesWidget {
        id: resourcesWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 5
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["resources"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndTodoWidget {
        id: todoWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 6
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["todo"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndWorldClockWidget {
        id: worldClockWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 7
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["worldClock"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndTimersWidget {
        id: timersWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 8
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["timers"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndNotesWidget {
        id: notesWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 9
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["notes"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndMediaWidget {
        id: mediaWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 10
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["media"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndImageConverterWidget {
        id: imagesWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 11
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["images"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndImageCardWidget {
        id: imageCardWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 12
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["imageCard"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndCustomImageWidget {
        id: customImageWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 13
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["customImage"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndStickerWidget {
        id: stickerWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 14
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["sticker"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }

    EndCustomTextWidget {
        id: customTextWidget
        screen: root.screen
        canvas: root.canvas
        screenWidth: root.width
        screenHeight: root.height
        staggerIndex: 15
        revealProgress: root.revealProgress
        visible: EndWidgetStore.visibility["customText"] === true && (root.revealProgress > 0.001 || root.widgetsWanted)
    }
}
