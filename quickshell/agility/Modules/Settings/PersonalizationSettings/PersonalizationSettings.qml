import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components
import qs.Modules.DesktopWidgets.End as EndSuite

AppContainer {
    id: appearanceRoot

    property bool showingDark: Theme.isDark
    property var availableFonts: ["Geist"]
    property string currentFontName: SettingsService.fontFamily || "Geist"
    property int currentFontSize: Math.round(11 * SettingsService.fontScale) || 11

    function applyFont() {
        SettingsService.fontFamily = appearanceRoot.currentFontName;
        SettingsService.applyFont(appearanceRoot.currentFontName, appearanceRoot.currentFontSize);
    }

    Component.onCompleted: {
        if (appearanceRoot.availableFonts.indexOf(appearanceRoot.currentFontName) === -1) {
            let arr = appearanceRoot.availableFonts.slice();
            arr.unshift(appearanceRoot.currentFontName);
            appearanceRoot.availableFonts = arr;
        }
    }

    Connections {
        function onFontFamilyChanged() {
            if (appearanceRoot.currentFontName !== SettingsService.fontFamily)
                appearanceRoot.currentFontName = SettingsService.fontFamily || "Geist";

        }

        function onFontScaleChanged() {
            appearanceRoot.currentFontSize = Math.round(11 * SettingsService.fontScale) || 11;
        }

        target: SettingsService
    }

    Process {
        id: imagePickerProc

        command: ["sh", "-c", "zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg *.webp *.gif' --title='Select Settings Window Background Image' 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (data) => {
                let path = ("" + data).trim();
                if (path && path !== "") {
                    SettingsService.settingsCustomBackgroundImage = path;
                    SettingsService.settingsCustomBackgroundSource = "custom";
                }
            }
        }
    }

    Process {
        id: fetchFontsProc

        command: ["sh", "-c", "fc-list : family | cut -d, -f1 | sort -u"]
        Component.onCompleted: running = true

        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    let lines = data.split('\n').map((x) => {
                        return x.trim();
                    }).filter((x) => {
                        return x !== "";
                    });
                    let arr = appearanceRoot.availableFonts.slice();
                    let changed = false;
                    lines.forEach((l) => {
                        if (arr.indexOf(l) === -1) {
                            arr.push(l);
                            changed = true;
                        }
                    });
                    if (arr.indexOf(appearanceRoot.currentFontName) === -1) {
                        arr.unshift(appearanceRoot.currentFontName);
                        changed = true;
                    }
                    if (changed)
                        appearanceRoot.availableFonts = arr;

                }
            }
        }

    }

    AppGroup {
        title: "Color Theme"
        icon: "color-palette"

        SettingToggle {
            label: "Dynamic Colors"
            description: "Generate color scheme from current wallpaper"
            checked: Theme.generateFromWallpaper
            onCheckedChanged: {
                if (checked !== Theme.generateFromWallpaper) {
                    Theme.generateFromWallpaper = checked;
                    if (checked) {
                        if (WallpaperManager.currentWallpaperPath !== "")
                            Theme.generateTheme(WallpaperManager.currentWallpaperPath);

                    } else {
                        let t = Theme.themes[0];
                        let baseName = Theme.currentScheme.replace(" Light", "");
                        for (let i = 0; i < Theme.themes.length; i++) {
                            if (Theme.themes[i].name === baseName) {
                                t = Theme.themes[i];
                                break;
                            }
                        }
                        let scheme = appearanceRoot.showingDark ? t.dark : t.light;
                        Theme.applyScheme(scheme);
                    }
                }
            }
        }

        ThemedSelect {
            label: "Static Theme"
            description: "Color scheme when dynamic colors are off"
            enabled: !Theme.generateFromWallpaper
            opacity: enabled ? 1 : 0.5
            model: {
                let m = [];
                for (let i = 0; i < Theme.themes.length; i++) {
                    m.push(Theme.themes[i].name);
                }
                return m;
            }
            currentIndex: {
                let baseName = Theme.currentScheme.replace(" Light", "");
                let idx = -1;
                for (let i = 0; i < Theme.themes.length; i++) {
                    if (Theme.themes[i].name === baseName) {
                        idx = i;
                        break;
                    }
                }
                return idx !== -1 ? idx : 0;
            }
            onActivated: (index) => {
                let t = Theme.themes[index];
                let scheme = appearanceRoot.showingDark ? t.dark : t.light;
                Theme.applyScheme(scheme);
            }
        }

        SettingToggle {
            id: darkModeToggle

            label: "Dark Mode"
            description: "Use dark variant of the selected theme"
            checked: Theme.isDark
            onToggled: (val) => {
                if (val !== Theme.isDark) {
                    if (!Theme.generateFromWallpaper) {
                        let t = Theme.themes[0];
                        let scheme = val ? t.dark : t.light;
                        Theme.applyScheme(scheme);
                    } else {
                        Theme.applyWallpaperTheme(val);
                    }
                }
            }

            Connections {
                target: Theme
                function onIsDarkChanged() {
                    darkModeToggle.checked = Theme.isDark;
                }
            }
        }

    }

    AppGroup {
        title: "Settings Window Appearance"
        icon: "window"

        SettingToggle {
            label: "Borderless Window"
            description: "Remove window frame borders for a seamless edge-to-edge floating canvas"
            checked: SettingsService.settingsBorderlessMode
            onToggled: (val) => {
                SettingsService.settingsBorderlessMode = val;
            }
        }

        SettingToggle {
            label: "Custom Window Background"
            description: "Display an immersive wallpaper or custom image inside the Settings window"
            checked: SettingsService.settingsCustomBackgroundEnabled
            onToggled: (val) => {
                SettingsService.settingsCustomBackgroundEnabled = val;
            }
        }

        ThemedSelect {
            label: "Background Source"
            description: "Choose between your desktop wallpaper or a custom local image file"
            model: ["Desktop Wallpaper", "Custom Image File"]
            currentIndex: SettingsService.settingsCustomBackgroundSource === "custom" ? 1 : 0
            onActivated: (index) => {
                SettingsService.settingsCustomBackgroundSource = index === 1 ? "custom" : "wallpaper";
            }
        }

        SettingRowTemplate {
            label: "Custom Background Image"
            description: SettingsService.settingsCustomBackgroundSource === "custom" && SettingsService.settingsCustomBackgroundImage !== ""
                ? SettingsService.settingsCustomBackgroundImage
                : "Using current desktop wallpaper. Click Browse to pick any local image file."

            RowLayout {
                spacing: 8
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Rectangle {
                    width: 36
                    height: 22
                    radius: 4
                    clip: true
                    color: "#2C2C2E"
                    border.width: 1
                    border.color: Theme.border

                    Image {
                        anchors.fill: parent
                        source: {
                            if (SettingsService.settingsCustomBackgroundSource === "custom" && SettingsService.settingsCustomBackgroundImage !== "")
                                return "file://" + SettingsService.settingsCustomBackgroundImage;
                            if (WallpaperManager.currentWallpaperPath && WallpaperManager.currentWallpaperPath !== "")
                                return "file://" + WallpaperManager.currentWallpaperPath;
                            return "file:///home/cachy/Pictures/Wallpapers/3.png";
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Rectangle {
                    implicitWidth: 92
                    implicitHeight: 28
                    radius: 6
                    color: browseHover.hovered ? (Theme.isDark ? "#3A3A3C" : "#E5E5EA") : (Theme.isDark ? "#2C2C2E" : "#F2F2F7")
                    border.width: 1
                    border.color: Theme.border

                    HoverHandler {
                        id: browseHover
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        SvgIcon {
                            icon: "picture"
                            iconSize: 14
                            flat: true
                            iconColor: Theme.fg
                        }

                        ThemedText {
                            text: "Browse..."
                            customSize: 12
                            font.weight: Font.Medium
                            color: Theme.fg
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            imagePickerProc.running = false;
                            imagePickerProc.running = true;
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 64
                    implicitHeight: 28
                    radius: 6
                    visible: SettingsService.settingsCustomBackgroundSource === "custom"
                    color: resetHover.hovered ? (Theme.isDark ? "#3A3A3C" : "#E5E5EA") : (Theme.isDark ? "#2C2C2E" : "#F2F2F7")
                    border.width: 1
                    border.color: Theme.border

                    HoverHandler {
                        id: resetHover
                    }

                    ThemedText {
                        anchors.centerIn: parent
                        text: "Reset"
                        customSize: 12
                        font.weight: Font.Medium
                        color: Theme.muted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsService.settingsCustomBackgroundSource = "wallpaper";
                            SettingsService.settingsCustomBackgroundImage = "";
                        }
                    }
                }
            }
        }

        ThemedSlider {
            label: "Background Dimming"
            suffix: "%"
            from: 10
            to: 95
            stepSize: 1
            value: Math.round(SettingsService.settingsCustomBackgroundDim * 100)
            onMoved: (val) => {
                SettingsService.settingsCustomBackgroundDim = Math.max(0.1, Math.min(0.95, val / 100));
            }
        }

        ThemedSlider {
            label: "Background Blur"
            suffix: "px"
            from: 0
            to: 60
            stepSize: 2
            value: SettingsService.settingsCustomBackgroundBlur
            onMoved: (val) => {
                SettingsService.settingsCustomBackgroundBlur = val;
            }
        }
    }

    AppGroup {
        title: "System Fonts"
        icon: "font"

        ThemedSelect {
            id: fontSelect

            function updateSelection() {
                for (let i = 0; i < appearanceRoot.availableFonts.length; i++) {
                    if (appearanceRoot.availableFonts[i] === appearanceRoot.currentFontName) {
                        fontSelect.currentIndex = i;
                        return ;
                    }
                }
                fontSelect.currentIndex = 0;
            }

            label: "System Font"
            description: "Global font for GTK, Qt and Shell"
            comboWidth: 260
            searchable: true
            model: appearanceRoot.availableFonts
            Component.onCompleted: updateSelection()
            onModelChanged: updateSelection()
            onActivated: (index) => {
                let newFont = model[index];
                if (appearanceRoot.currentFontName !== newFont) {
                    appearanceRoot.currentFontName = newFont;
                    appearanceRoot.applyFont();
                }
            }

            Connections {
                function onCurrentFontNameChanged() {
                    fontSelect.updateSelection();
                }

                target: appearanceRoot
            }

        }

        SettingSpinBox {
            label: "Global Font Scale"
            description: "Scales fonts across Quickshell, GTK and Qt"
            from: 0.7
            to: 2.5
            stepSize: 0.05
            value: SettingsService.fontScale
            suffix: "x"
            decimals: 2
            onMoved: (val) => {
                let newSize = Math.round(11 * val);
                if (appearanceRoot.currentFontSize !== newSize) {
                    appearanceRoot.currentFontSize = newSize;
                    SettingsService.fontScale = val;
                    appearanceRoot.applyFont();
                } else {
                    SettingsService.fontScale = val;
                }
            }
        }

    }

    AppGroup {
        id: desktopCompositionGroup

        readonly property var shapeOptions: ["Arch", "Cookie7Sided", "Cookie4Sided", "Clover4Leaf", "Pill", "Circle", "Square", "Gem", "Flower"]

        title: "Desktop Wallpaper & Widgets"
        icon: "widgets"
        badge: SettingsService.desktopWidgetProvider === "end" ? "End" : "Awe"

        SettingToggle {
            label: "Wallpaper Composition"
            description: "Show dimmed active wallpaper with a centered focal shape on the desktop"
            checked: SettingsService.desktopCompositionEnabled
            onToggled: (val) => {
                SettingsService.desktopCompositionEnabled = val;
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: SettingsService.desktopCompositionEnabled
            opacity: enabled ? 1.0 : 0.45

            SettingToggle {
                label: "Background Dimming"
                description: "Visibly dim the full-screen desktop wallpaper behind the focal shape"
                checked: SettingsService.desktopBackdropDimEnabled
                onToggled: (val) => {
                    SettingsService.desktopBackdropDimEnabled = val;
                }
            }

            ThemedSlider {
                label: "Dim Strength"
                from: 0
                to: 90
                stepSize: 5
                suffix: "%"
                decimals: 0
                enabled: SettingsService.desktopCompositionEnabled && SettingsService.desktopBackdropDimEnabled
                value: Math.round(SettingsService.desktopBackdropDimStrength * 100)
                onMoved: (val) => {
                    SettingsService.desktopBackdropDimStrength = Math.round(val) / 100.0;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd
            enabled: SettingsService.desktopCompositionEnabled
            opacity: enabled ? 1.0 : 0.45

            SettingToggle {
                label: "Central Wallpaper Shape"
                description: "Highlight a brighter, larger crop of the active wallpaper in the center"
                checked: SettingsService.desktopCenterShapeEnabled
                onToggled: (val) => {
                    SettingsService.desktopCenterShapeEnabled = val;
                }
            }

            ThemedSelect {
                label: "Focal Shape"
                description: "Silhouette for the centered wallpaper frame"
                enabled: SettingsService.desktopCompositionEnabled && SettingsService.desktopCenterShapeEnabled
                opacity: enabled ? 1.0 : 0.5
                model: desktopCompositionGroup.shapeOptions
                currentIndex: {
                    let idx = desktopCompositionGroup.shapeOptions.indexOf(SettingsService.desktopCenterShape);
                    return idx !== -1 ? idx : 0;
                }
                onActivated: (idx) => {
                    SettingsService.desktopCenterShape = desktopCompositionGroup.shapeOptions[idx];
                }
            }

            ThemedSlider {
                label: "Central Shape Size"
                from: 32
                to: 76
                stepSize: 2
                suffix: "%"
                decimals: 0
                enabled: SettingsService.desktopCompositionEnabled && SettingsService.desktopCenterShapeEnabled
                value: Math.round(SettingsService.desktopCenterShapeSize * 100)
                onMoved: (val) => {
                    SettingsService.desktopCenterShapeSize = Math.round(val) / 100.0;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd

            SettingToggle {
                label: "Reveal & Hide Animation"
                description: "Animate wallpaper composition and desktop widgets smoothly on toggle"
                checked: SettingsService.desktopCompositionAnimEnabled
                onToggled: (val) => {
                    SettingsService.desktopCompositionAnimEnabled = val;
                }
            }

            ThemedSlider {
                label: "Animation Speed"
                from: 0.5
                to: 2.0
                stepSize: 0.1
                suffix: "x"
                decimals: 1
                enabled: SettingsService.desktopCompositionAnimEnabled
                value: SettingsService.desktopCompositionAnimSpeed
                onMoved: (val) => {
                    SettingsService.desktopCompositionAnimSpeed = Math.round(val * 10) / 10;
                }
            }
        }

        SettingToggle {
            label: "Enable Desktop Widgets"
            description: "Display interactive widgets on the desktop"
            checked: SettingsService.desktopWidgetsEnabled
            onToggled: (val) => {
                SettingsService.desktopWidgetsEnabled = val;
            }
        }

        SettingSegmented {
            label: "Widget Source"
            description: "Switch exclusively between Agility's Awe widgets and End widgets"
            enabled: SettingsService.desktopWidgetsEnabled
            opacity: enabled ? 1.0 : 0.5
            model: [
                { "text": "Awe", "value": "awe" },
                { "text": "End", "value": "end" }
            ]
            currentValue: SettingsService.desktopWidgetProvider
            onActivated: (val) => {
                SettingsService.desktopWidgetProvider = val;
            }
        }

        SettingRowTemplate {
            label: "Widget Layout Edit Mode"
            description: SettingsService.desktopWidgetsEditMode
                ? "Edit mode active — drag widgets or corner handles on the desktop"
                : "Unlock widget positions and resize handles without blocking normal clicks"
            enabled: SettingsService.desktopWidgetsEnabled
            opacity: enabled ? 1.0 : 0.5

            RowLayout {
                spacing: Constants.sizeXs

                Rectangle {
                    visible: SettingsService.desktopWidgetProvider === "end"
                    implicitWidth: resetEndTxt.implicitWidth + 20
                    implicitHeight: Constants.size3Xl
                    radius: Constants.sizeXs
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        id: resetEndTxt
                        anchors.centerIn: parent
                        text: "Reset Layout"
                        customSize: 11
                        font.weight: Font.Medium
                        color: Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: EndSuite.EndWidgetStore.resetLayouts()
                    }
                }

                Rectangle {
                    implicitWidth: editModeTxt.implicitWidth + 24
                    implicitHeight: Constants.size3Xl
                    radius: Constants.sizeXs
                    color: SettingsService.desktopWidgetsEditMode ? Theme.accent : Theme.bgAccent
                    border.width: 1
                    border.color: Theme.accent

                    ThemedText {
                        id: editModeTxt
                        anchors.centerIn: parent
                        text: SettingsService.desktopWidgetsEditMode ? "Lock Layout" : "Edit Layout"
                        customSize: 11
                        font.weight: Font.Bold
                        color: SettingsService.desktopWidgetsEditMode ? (Theme.isDark ? "#000000" : "#ffffff") : Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsService.desktopWidgetsEditMode = !SettingsService.desktopWidgetsEditMode
                    }
                }
            }
        }

        // Individual End widget toggles when End provider is selected
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm
            visible: SettingsService.desktopWidgetProvider === "end" && SettingsService.desktopWidgetsEnabled

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeXs

                ThemedText {
                    text: "End Widgets (" + EndSuite.EndWidgetStore.widgetCatalog.length + ")"
                    customSize: Constants.sizeSm
                    font.weight: Font.Bold
                    color: Theme.fg
                    Layout.fillWidth: true
                }

                Repeater {
                    model: [
                        { label: "Defaults", action: "defaults" },
                        { label: "All On", action: "all" },
                        { label: "All Off", action: "none" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: actTxt.implicitWidth + 14
                        implicitHeight: 26
                        radius: Constants.sizeXs
                        color: Theme.bgSecondary
                        border.width: 1
                        border.color: Theme.border

                        ThemedText {
                            id: actTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            customSize: 10
                            font.weight: Font.Medium
                            color: Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "defaults")
                                    EndSuite.EndWidgetStore.applyDefaultVisibility();
                                else if (modelData.action === "all")
                                    EndSuite.EndWidgetStore.setAllVisibility(true);
                                else
                                    EndSuite.EndWidgetStore.setAllVisibility(false);
                            }
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: Constants.sizeXs
                columnSpacing: Constants.sizeSm

                Repeater {
                    model: EndSuite.EndWidgetStore.widgetCatalog

                    delegate: Rectangle {
                        id: endCardDelegate
                        required property var modelData
                        readonly property bool isEnabled: EndSuite.EndWidgetStore.visibility[modelData.id] === true

                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        radius: Constants.sizeXs
                        color: isEnabled ? Theme.bgSecondary : Theme.bgTertiary
                        border.width: 1
                        border.color: isEnabled ? Theme.border : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Constants.sizeXs
                            spacing: Constants.sizeXs

                            SvgIcon {
                                icon: endCardDelegate.modelData.icon
                                iconSize: 14
                                iconColor: endCardDelegate.isEnabled ? Theme.accent : Theme.muted
                                flat: true
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                ThemedText {
                                    Layout.fillWidth: true
                                    text: endCardDelegate.modelData.name
                                    customSize: 11
                                    font.weight: Font.Bold
                                    color: endCardDelegate.isEnabled ? Theme.fg : Theme.muted
                                    elide: Text.ElideRight
                                }
                                ThemedText {
                                    Layout.fillWidth: true
                                    text: endCardDelegate.modelData.cat
                                    customSize: 9
                                    color: Theme.muted
                                    elide: Text.ElideRight
                                }
                            }

                            MacSwitch {
                                checked: endCardDelegate.isEnabled
                                onToggled: (val) => EndSuite.EndWidgetStore.setWidgetEnabled(endCardDelegate.modelData.id, val)
                            }
                        }
                    }
                }
            }
        }

    }

}
