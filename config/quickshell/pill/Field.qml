import QtQuick
import QtQuick.Layouts

// Campo de texto de una linea de los menus (contrasenas, nombres, horas...). Enter emite `accepted`.
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder
    property bool password: false
    property alias inputMethodHints: input.inputMethodHints
    property alias maximumLength: input.maximumLength
    signal accepted()
    function focusIt() { input.forceActiveFocus(); }

    Layout.fillWidth: true
    Layout.preferredHeight: 34
    radius: 10
    color: Qt.rgba(1, 1, 1, 0.08)
    border.width: input.activeFocus ? 1 : 0
    border.color: Theme.accent

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Theme.text
        selectionColor: Theme.accent
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
        echoMode: f.password ? TextInput.Password : TextInput.Normal
        onAccepted: f.accepted()
        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            text: f.placeholder
            color: Theme.textDim
            font: input.font
        }
    }
}
