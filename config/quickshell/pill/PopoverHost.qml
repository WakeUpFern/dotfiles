import QtQuick
import Quickshell
import Quickshell.Wayland

// Contenedor de los menus de la barra derecha. Es UNA sola tarjeta de vidrio anclada abajo-derecha
// de la barra: al abrir crece desde la esquina con rebote y, si pulsas otro icono, cambia de
// tamano (con el mismo resorte) y de contenido sin cerrarse. El contenido tiene tamano fijo y la
// tarjeta lo "revela", asi nada se recoloca mientras anima.
PanelWindow {
    id: host

    property string name: ""               // menu pedido ("" = cerrado)
    signal closeRequested()

    readonly property bool open: name !== ""
    property string shown: ""              // menu cuyo contenido se esta mostrando

    readonly property real topGap: Theme.notchHeight + 8
    readonly property real rightGap: 10

    function widthFor(n) {
        switch (n) {
        case "bluetooth": return 400;
        case "volume":    return 400;
        case "battery":   return 360;
        case "clock":     return 320;
        default:          return 360;
        }
    }
    readonly property real targetW: open ? widthFor(shown !== "" ? shown : name) : 0
    readonly property real targetH: open ? (loader.item ? loader.item.implicitHeight + 40 : 160) : 0

    // Para el click-fuera y las notificaciones (coordenadas de pantalla).
    readonly property real cardWidth: card.width
    readonly property real cardHeight: card.height
    readonly property real targetBottom: topGap + targetH

    anchors { top: true; right: true }
    margins.top: topGap
    margins.right: rightGap
    implicitWidth: 440
    implicitHeight: 760
    visible: open || card.width > 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pill-popover"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: card }
    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

    // --- Cambio de contenido con fundido -------------------------------------------------------
    property real contentFade: 1
    SequentialAnimation {
        id: swap
        NumberAnimation { target: host; property: "contentFade"; to: 0; duration: 90 }
        ScriptAction { script: host.shown = host.name }
        NumberAnimation { target: host; property: "contentFade"; to: 1; duration: 170 }
    }
    onNameChanged: {
        if (name === "") { clearShown.restart(); return; }
        clearShown.stop();
        if (shown === "") { shown = name; contentFade = 1; }
        else if (shown !== name) swap.restart();
        scope.forceActiveFocus();
    }
    Timer { id: clearShown; interval: 700; onTriggered: if (!host.open) host.shown = "" }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: host.closeRequested()
    }

    // --- La tarjeta -----------------------------------------------------------------------------
    Rectangle {
        id: card
        anchors.top: parent.top
        anchors.right: parent.right
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
            // Tamano fijo (el final) y pegado a la derecha: la tarjeta crece hacia la izquierda
            // dejando ver el contenido sin moverlo.
            width: host.widthFor(host.shown) - 36
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 20
            opacity: host.contentFade * (host.open ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: 180 } }
            sourceComponent: host.shown === "bluetooth" ? bluetoothComp
                           : host.shown === "volume"    ? volumeComp
                           : host.shown === "battery"   ? batteryComp
                           : host.shown === "clock"     ? clockComp : null
        }
    }

    Component { id: bluetoothComp; BluetoothPopover {} }
    Component { id: volumeComp;    VolumePopover {} }
    Component { id: batteryComp;   BatteryPopover {} }
    Component {
        id: clockComp
        // Calendario sencillo: mes actual.
        Column {
            spacing: 6
            UiLabel { text: Qt.formatDateTime(new Date(), "dddd, d 'de' MMMM yyyy"); font.pixelSize: Theme.fontSize + 2; font.weight: Font.DemiBold }
            UiLabel { text: Qt.formatDateTime(new Date(), "HH:mm:ss"); color: Theme.textDim }
        }
    }
}
