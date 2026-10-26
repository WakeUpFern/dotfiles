import QtQuick
import Quickshell
import Quickshell.Wayland

// Detalle del monitor del sistema: una tarjeta de vidrio anclada bajo la barra izquierda. Crece desde la
// esquina con el mismo resorte que los menus de la derecha (PopoverHost) y su contenido tiene tamano
// fijo para que nada se recoloque mientras anima.
PanelWindow {
    id: host

    property bool open: false
    signal closeRequested()

    readonly property real topGap: Theme.notchHeight + 8
    readonly property real leftGap: 10
    readonly property real contentWidth: 380

    readonly property real targetW: open ? contentWidth : 0
    readonly property real targetH: open ? (loader.item ? loader.item.implicitHeight + 40 : 200) : 0

    // Para el click-fuera (coordenadas de pantalla).
    readonly property real cardWidth: card.width
    readonly property real cardHeight: card.height

    anchors { top: true; left: true }
    margins.top: topGap
    margins.left: leftGap
    implicitWidth: contentWidth + 20
    implicitHeight: 900
    visible: open || card.width > 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pill-popover-left"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: card }
    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

    onOpenChanged: if (open) scope.forceActiveFocus()
    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: host.closeRequested()
    }

    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.left: parent.left
        width: host.targetW
        height: host.targetH
        radius: 22
        color: Theme.glass
        border.width: 1
        border.color: Theme.border
        clip: true

        Behavior on width  { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on height { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

        Loader {
            id: loader
            width: host.contentWidth - 36
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 20
            active: host.visible
            opacity: host.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            sourceComponent: SysMonitor {}
        }
    }
}
