import QtQuick

// Interruptor con rebote.
Rectangle {
    id: sw
    property bool checked: false
    signal toggled()
    implicitWidth: 46
    implicitHeight: 26
    radius: 13
    color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.18)
    Behavior on color { ColorAnimation { duration: 180 } }
    Rectangle {
        width: swArea.pressed ? 24 : 20
        height: 20
        radius: 10
        y: 3
        x: sw.checked ? sw.width - width - 3 : 3
        color: "white"
        Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
        Behavior on width { NumberAnimation { duration: 160 } }
    }
    MouseArea { id: swArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
}
