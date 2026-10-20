import QtQuick
import Quickshell
import Quickshell.Wayland

// Capa transparente a pantalla completa que existe solo mientras hay un menu
// abierto: un click en cualquier parte fuera del notch lo cierra (como en
// cualquier menu de escritorio). El notch queda excluido de su region de
// entrada, asi que los clicks sobre el notch siguen llegando a el.
PanelWindow {
    id: win

    property bool active: false
    property real pillWidth: 0
    property real pillHeight: 0
    signal dismissed()

    visible: active
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "pill-dismiss"

    mask: Region {
        x: 0; y: 0; width: win.width; height: win.height
        regions: [
            Region {
                x: (win.width - win.pillWidth) / 2 - 2
                y: 0
                width: win.pillWidth + 4
                height: win.pillHeight + 2
                intersection: Intersection.Subtract
            }
        ]
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: win.dismissed()
    }
}
