import QtQuick

Item {
    id: toggle
    property var screen
    property bool on
    property bool busy: false
    signal flipped
    readonly property real u: Theme.unit(screen)
    implicitWidth: 40 * u
    implicitHeight: 20 * u
    opacity: busy ? 0.5 : 1
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border {
            width: 1
            color: Theme.fg
        }
        Rectangle {
            x: toggle.on ? parent.width - width - 4 * toggle.u : 4 * toggle.u
            anchors.verticalCenter: parent.verticalCenter
            width: 12 * toggle.u
            height: width
            radius: width / 2
            color: toggle.on ? Theme.fg : Theme.dim
            Behavior on x {
                NumberAnimation {
                    duration: 140
                }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8 * toggle.u
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.flipped()
    }
}
