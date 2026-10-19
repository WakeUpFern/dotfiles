import QtQuick

// Slider horizontal 0..1. No escribe nada por si mismo: emite `moved(v)` y el
// que lo usa decide (asi `value` sigue ligado al valor real del sistema).
Item {
    id: root

    property real value: 0
    property bool dimmed: false
    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 24

    readonly property bool dragging: area.pressed
    readonly property real clamped: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.15)

        Rectangle {
            id: bar
            height: parent.height
            radius: 3
            width: parent.width * root.clamped
            color: root.dimmed ? Theme.textDim : Theme.accent
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // Perilla: crece al arrastrar, con rebote.
    Rectangle {
        id: knob
        width: area.pressed ? 18 : 12
        height: width
        radius: width / 2
        color: "white"
        anchors.verticalCenter: parent.verticalCenter
        x: bar.width - width / 2
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        function update(mouse) {
            const x = area.mapToItem(root, mouse.x, 0).x;
            root.moved(Math.max(0, Math.min(1, x / root.width)));
        }
        onPressed: mouse => update(mouse)
        onPositionChanged: mouse => { if (pressed) update(mouse); }
    }
}
