import QtQuick
import QtQuick.Layouts

// Boton en pildora de los menus. `primary` = relleno de acento; si no, discreto (con `tint` para el texto).
Rectangle {
    id: b
    property string label
    property bool primary: true
    property color tint: Theme.text
    signal clicked()

    Layout.preferredHeight: 34
    Layout.preferredWidth: btnText.implicitWidth + 28
    radius: 17
    color: primary ? Theme.accent : (btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
    opacity: btnArea.pressed ? 0.8 : 1
    UiLabel {
        id: btnText
        anchors.centerIn: parent
        text: b.label
        color: b.primary ? "#0b1020" : b.tint
        font.weight: b.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea { id: btnArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
}
