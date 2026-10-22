import QtQuick

// Icono de intensidad de senal: 4 barras crecientes; se encienden segun el porcentaje (0..100).
// Mismos umbrales que NetworkManager: 4 barras desde 80 %, 3 desde 55 %, 2 desde 30 %, 1 desde 5 %.
Item {
    id: root
    property int signal: 0
    property color color: Theme.text
    property color dimColor: Qt.rgba(1, 1, 1, 0.22)
    readonly property int level: signal >= 80 ? 4 : (signal >= 55 ? 3 : (signal >= 30 ? 2 : (signal >= 5 ? 1 : 0)))

    implicitWidth: 18
    implicitHeight: 14
    width: implicitWidth
    height: implicitHeight

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 3
                height: 4 + index * 3
                radius: 1
                anchors.bottom: parent.bottom
                color: index < root.level ? root.color : root.dimColor
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
