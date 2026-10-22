import QtQuick

// Fila de lista de los menus: resalta al pasar el raton, clic y clic derecho. El contenido va encima
// del area de raton (los botones de dentro reciben sus propios clics).
Rectangle {
    id: row
    property bool highlighted: false
    readonly property bool hovered: area.containsMouse
    default property alias content: inner.data
    signal clicked()
    signal rightClicked()

    implicitHeight: 38
    radius: 12
    color: highlighted ? Theme.accentSoft : (hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => { if (mouse.button === Qt.RightButton) row.rightClicked(); else row.clicked(); }
    }
    Item { id: inner; anchors.fill: parent }
}
