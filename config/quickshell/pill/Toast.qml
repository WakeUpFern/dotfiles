import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Una notificacion como tarjeta de vidrio en la esquina superior derecha.
// Entra deslizandose con rebote y sale hacia la derecha. Una ventana por
// tarjeta: asi el blur sigue exactamente la forma de cada una.
PanelWindow {
    id: win

    required property var entry                 // ver Toasts.qml (copia de los datos)
    required property int slot                  // posicion en la pila (0 = arriba)
    required property real baseTop              // y de la primera tarjeta (bajo la barra / el menu)
    signal finished()

    readonly property var n: entry.n            // puede ser null si la app ya la cerro
    readonly property bool critical: entry.critical
    readonly property int cardW: 380
    readonly property int cardH: 88
    property bool closing: false

    anchors { top: true; right: true }
    margins.top: baseTop + slot * (cardH + 12)
    Behavior on margins.top { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

    implicitWidth: 420
    implicitHeight: cardH + 8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pill-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: card }
    BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

    // 0 = fuera (a la derecha), 1 = en su sitio; pasa de 1 al entrar (rebote).
    property real p: 0

    // Click en la tarjeta: invoca la accion por defecto de la app (si la hay) y enfoca su
    // ventana, como hacen los demonios de notificaciones de escritorio.
    function activate() {
        if (closing) return;
        if (n) {
            const def = n.actions.find(a => a.identifier === "default");
            if (def) def.invoke();
        }
        NiriState.focusApp(entry.desktopEntry, entry.appName);
        dismissNow(true);
    }

    function dismissNow(user) {
        if (closing) return;
        closing = true;
        if (n) { if (user) n.dismiss(); else n.expire(); }
        enter.stop();
        leave.start();
    }

    Component.onCompleted: enter.start()

    NumberAnimation {
        id: enter
        target: win; property: "p"; from: 0; to: 1
        duration: 620; easing.type: Easing.OutBack; easing.overshoot: 2.2
    }
    NumberAnimation {
        id: leave
        target: win; property: "p"; to: 0
        duration: 300; easing.type: Easing.InBack; easing.overshoot: 1.4
        onFinished: win.finished()
    }

    // dismissAll() de Toasts.
    Connections {
        target: win.entry
        function onCloseNowChanged() { if (win.entry.closeNow) win.dismissNow(true); }
    }

    // La app puede cerrar la notificacion por su cuenta.
    Connections {
        target: win.n
        function onClosed() { if (!win.closing) { win.closing = true; enter.stop(); leave.start(); } }
    }

    // Autocierre (las criticas se quedan hasta que las cierres).
    Timer {
        interval: win.entry.timeout > 0 ? win.entry.timeout * 1000 : 6500
        running: !win.closing && !win.critical && !hover.hovered
        onTriggered: win.dismissNow(false)
    }

    Rectangle {
        id: card
        x: 20 + (1 - win.p) * (win.cardW + 60)
        y: 4
        width: win.cardW
        height: win.cardH
        radius: 22
        color: hover.hovered ? Theme.glassHover : Theme.glass
        border.width: 1
        border.color: win.critical ? Theme.urgent : Theme.border
        opacity: Math.min(1, win.p * 2.5)
        scale: 0.92 + 0.08 * Math.min(1, win.p)
        Behavior on color { ColorAnimation { duration: 150 } }

        HoverHandler { id: hover }
        TapHandler { onTapped: win.activate() }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            // Icono / imagen de la notificacion.
            Rectangle {
                width: 52
                height: 52
                anchors.verticalCenter: parent.verticalCenter
                radius: 14
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                Image {
                    anchors.centerIn: parent
                    width: win.entry.image !== "" ? parent.width : 32
                    height: width
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(104, 104)
                    source: win.entry.image !== "" ? win.entry.image
                          : Quickshell.iconPath(win.entry.appIcon !== "" ? win.entry.appIcon : "dialog-information", "dialog-information")
                }
            }

            Column {
                width: parent.width - 52 - 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width - 24
                    text: win.entry.appName
                    color: win.critical ? Theme.urgent : Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: win.entry.summary
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 1
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: win.entry.body
                    color: Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }
        }

        // "x" al pasar el raton: solo descarta, sin abrir la app.
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
            text: "✕"
            color: closeArea.containsMouse ? Theme.text : Theme.textDim
            font.pixelSize: 12
            opacity: hover.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            MouseArea {
                id: closeArea
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.dismissNow(true)
            }
        }
    }
}
