import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

SettingRowTemplate {
    id: root

    property alias checked: macCheck.checked

    signal toggled(bool checked)

    MacCheckBox {
        id: macCheck
        Layout.alignment: Qt.AlignVCenter
        onToggled: (val) => root.toggled(val)
    }
}
