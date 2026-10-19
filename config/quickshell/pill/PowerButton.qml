import QtQuick

// Boton de una accion de PowerActions. `compact` = solo icono (launcher);
// normal = icono + etiqueta (menu de apagado).
Rectangle {
    id: btn

    required property var action
    property bool compact: false
    property bool selected: false          // resaltado por teclado
    signal done()                          // la accion se ejecuto

    readonly property bool armed: PowerActions.armedId === action.id
    readonly property bool hot: selected || area.containsMouse

    function trigger() { if (PowerActions.request(action.id)) btn.done(); }

    implicitWidth: compact ? 40 : 84
    implicitHeight: compact ? 40 : 88
    radius: compact ? 20 : 22
    color: armed ? Theme.urgent : (hot ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07))
    border.width: selected && !compact ? 1 : 0
    border.color: Theme.border

    scale: area.pressed ? 0.9 : (armed ? 1.08 : (hot ? 1.04 : 1))
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

    Column {
        anchors.centerIn: parent
        spacing: compact ? 0 : 8

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.action.glyph
            color: btn.armed ? "white" : Theme.text
            font.family: "FontAwesome"
            font.pixelSize: btn.compact ? 16 : 24
        }
        Text {
            visible: !btn.compact
            anchors.horizontalCenter: parent.horizontalCenter
            text: btn.armed ? "Confirmar" : btn.action.label
            color: btn.armed ? "white" : Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
            font.weight: btn.armed ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.trigger()
    }
}
