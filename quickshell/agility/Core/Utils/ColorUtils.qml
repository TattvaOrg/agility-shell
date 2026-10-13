import QtQuick
pragma Singleton

QtObject {
    id: root

    function isDark(color) {
        let brightness = color.r * 0.299 + color.g * 0.587 + color.b * 0.114;
        return brightness <= 0.5;
    }

}
