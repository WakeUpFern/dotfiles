pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// A panel hung from the top line. A full-screen overlay rather than a Sheet so it can
// take the keyboard (wifi passwords) and grow without remapping; drawn like a Sheet.
PanelWindow {
    id: pane
    required property string name
    readonly property bool open: ShellState.panel === name
    readonly property real u: Theme.unit(screen)
    property real pad: 22 * u
    default property alias contents: inside.data
    screen: ShellState.panelScreen || Quickshell.screens[0]
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: open
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    onVisibleChanged: if (visible) box.forceActiveFocus()
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: ShellState.closePanel()
    }
    FocusScope {
        id: box
        readonly property real edge: ShellState.panelX < 0 ? pane.width - 36 * pane.u : ShellState.panelX
        width: Math.ceil(inside.childrenRect.width + 2 * pane.pad)
        height: Math.ceil(inside.childrenRect.height + 2 * pane.pad)
        x: Math.round(Math.max(36 * pane.u, Math.min(edge - width + pane.pad, pane.width - width - 36 * pane.u)))
        y: Math.round((54 - (1 - opacity) * 10) * pane.u)
        opacity: pane.visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        focus: true
        Keys.onEscapePressed: ShellState.closePanel()
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border {
                width: 1
                color: Theme.fg
            }
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }
        Item {
            id: inside
            x: pane.pad
            y: pane.pad
        }
    }
}
