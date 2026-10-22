import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// El notch: pegado al borde superior, esquinas redondas solo abajo.
// Una sola ventana layer-shell; el rectangulo interior cambia de tamano con
// resorte segun el modo (idle / hover / launcher / notificacion / volumen).
// El blur sigue exactamente su forma.
PanelWindow {
    id: win

    property string mode: "idle"      // idle | launcher | emoji | wallpapers | clipboard | media | power | osd
    property string osdKind: "volume" // "volume" | "brightness" | "track" en modo osd
    signal modeRequested(string mode)
    signal volumeActivity()

    // Tamano actual del notch (lo usa Dismiss para dejarlo fuera de su region de clicks).
    readonly property real pillWidth: pill.width
    readonly property real pillHeight: pill.height

    readonly property bool launcherOpen: mode === "launcher"
    readonly property bool peek: mode === "idle" && hover.hovered

    // --- Geometria ----------------------------------------------------------
    // Ancho en reposo: workspaces | icono | reloj. En hover se suma el bloque
    // extra (titulo, volumen, bateria) en el centro.
    // Simetrico: espacios de trabajo a la izquierda, icono de la app en el centro.
    readonly property real collapsedWidth: 2 * (18 + wsRow.implicitWidth + 14) + 22
    readonly property real peekExtra: extraRow.implicitWidth + 14

    readonly property real targetWidth: {
        let w;
        switch (mode) {
        case "launcher":     w = 560; break;
        case "emoji":        w = 560; break;
        case "wallpapers":   w = 640; break;
        case "clipboard":    w = 640; break;
        case "media":        w = 560; break;
        case "power":        w = 500; break;
        case "osd":          w = osdWidth; break;
        default:             w = collapsedWidth + (peek ? peekExtra : 0);
        }
        return tap.pressed ? w - 10 : w;      // "squish" al presionar
    }
    // El portapapeles es el panel grande: hasta ~55 % de la altura de la pantalla.
    readonly property real clipboardHeight: Math.min(win.screen.height * 0.55, 560)

    // Panel multimedia: mas alto si hay varios reproductores (aparece el selector).
    readonly property real mediaHeight: MediaState.players.length > 1 ? 372 : 330
    // El HUD de pista es mas ancho (caratula + titulo) que el de volumen/brillo.
    readonly property real osdWidth: osdKind === "track" ? 400 : 300

    readonly property real targetHeight: {
        switch (mode) {
        case "launcher":     return 450;
        case "emoji":        return 450;
        case "wallpapers":   return 440;
        case "clipboard":    return clipboardHeight;
        case "media":        return mediaHeight;
        case "power":        return 168;
        case "osd":          return 52;
        default:             return peek ? Theme.notchPeekHeight : Theme.notchHeight;
        }
    }

    anchors.top: true
    implicitWidth: 700                        // superficie fija, mayor que el notch
    implicitHeight: Math.max(620, clipboardHeight + 50)
    color: "transparent"

    // Reserva solo la franja del notch en reposo; el resto no empuja ventanas.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.notchHeight

    WlrLayershell.namespace: "pill"
    // Siempre en Overlay: cambiar de capa obliga a recrear la superficie (~600 ms de retraso y
    // un tiron al volver). Las ventanas en pantalla completa tapan la capa Top pero no Overlay,
    // asi que en vez de cambiar de capa el notch se esconde deslizandose hacia arriba cuando hay
    // una ventana a pantalla completa y reaparece (con rebote) en cuanto hay algo que mostrar.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool fullscreenFocused: NiriState.focusedWidth >= win.screen.width
                                           && NiriState.focusedHeight >= win.screen.height
    readonly property bool tucked: fullscreenFocused && mode === "idle"
    Binding { target: CavaState; property: "wanted"; value: MediaState.playing && !win.tucked }
    // Todos los menus capturan el teclado para que Esc los cierre (como los menus de escritorio).
    WlrLayershell.keyboardFocus: (mode === "launcher" || mode === "emoji" || mode === "wallpapers" || mode === "clipboard" || mode === "media" || mode === "power")
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Solo el notch recibe clicks; lo demas deja pasar el raton a las ventanas.
    mask: Region { item: pill }

    // Frosted glass: niri desenfoca lo que hay detras, con la forma del notch.
    BackgroundEffect.blurRegion: Region {
        item: pill
        radius: 0
        bottomLeftRadius: pill.bottomRadius
        bottomRightRadius: pill.bottomRadius
    }

    Rectangle {
        id: pill
        readonly property real bottomRadius: Math.min(height / 2, 26)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: win.tucked ? -(height + 8) : 0
        Behavior on anchors.topMargin { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        width: win.targetWidth
        height: win.targetHeight

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: bottomRadius
        bottomRightRadius: bottomRadius
        color: win.peek ? Theme.glassHover : Theme.glass
        border.width: 1
        border.color: Theme.border
        clip: true

        Behavior on width  { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on height { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }
        Behavior on color  { ColorAnimation  { duration: 200 } }

        HoverHandler { id: hover }

        // Scroll sobre el notch en reposo = volumen.
        WheelHandler {
            enabled: win.mode === "idle"
            onWheel: event => {
                const sink = audio.sink;
                if (!sink || !sink.audio) return;
                const d = event.angleDelta.y > 0 ? 0.03 : -0.03;
                sink.audio.muted = false;
                sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + d));
            }
        }

        // Click en el notch en reposo = abrir launcher.
        TapHandler {
            id: tap
            enabled: win.mode === "idle"
            onTapped: win.modeRequested("launcher")
        }

        // --- Modo reposo / hover ----------------------------------------------
        Item {
            id: idleView
            anchors.fill: parent
            opacity: win.mode === "idle" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Izquierda: workspaces (la pastilla activa se estira).
            Row {
                id: wsRow
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: NiriState.workspaces
                    Rectangle {
                        required property var modelData
                        width: modelData.is_active ? 20 : 7
                        height: 7
                        radius: 3.5
                        color: modelData.is_active ? Theme.accent : Theme.textDim
                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            onClicked: NiriState.focusWorkspace(parent.modelData.idx)
                        }
                    }
                }
            }

            // Derecha: barras de audio (estilo cava) mientras suena algo; click = abrir el reproductor.
            Item {
                id: viz
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: vizRow.implicitWidth
                height: 20
                opacity: MediaState.playing ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 260 } }

                Row {
                    id: vizRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: CavaState.count
                        Rectangle {
                            required property int index
                            width: 3
                            height: 3 + 15 * (CavaState.bars[index] || 0)
                            radius: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.modeRequested("media")
                }
            }

            // Centro: icono de la app activa; en hover se despliega el resto.
            Row {
                anchors.centerIn: parent
                spacing: 0

                Image {
                    id: appIcon
                    width: 22
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    sourceSize: Qt.size(44, 44)
                    visible: NiriState.focusedAppId !== ""
                    source: win.iconSource
                    // Pequeno rebote al cambiar de app.
                    onSourceChanged: bounce.restart()
                    SequentialAnimation {
                        id: bounce
                        NumberAnimation { target: appIcon; property: "scale"; to: 0.6; duration: 70 }
                        NumberAnimation { target: appIcon; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack; easing.overshoot: 3 }
                    }
                }

                Item {
                    id: extraClip
                    // Ancho visible = lo que el notch ya se ha ensanchado (sigue al resorte).
                    readonly property real visibleWidth: Math.max(0, Math.min(win.peekExtra, pill.width - win.collapsedWidth))
                    width: visibleWidth
                    height: parent.height
                    clip: true
                    opacity: win.peekExtra > 0 ? Math.min(1, visibleWidth / win.peekExtra) : 0

                    Row {
                        id: extraRow
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            visible: text !== ""
                            width: Math.min(implicitWidth, 200)
                            text: NiriState.focusedTitle
                            color: Theme.textDim
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: MediaState.playing
                            width: Math.min(implicitWidth, 190)
                            text: "♪ " + MediaState.line
                            color: Theme.accent
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.modeRequested("media")
                            }
                        }
                        Text {
                            visible: MediaState.playing && MediaState.source !== ""
                            width: Math.min(implicitWidth, 130)
                            text: "en " + MediaState.source
                            color: Theme.textDim
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // --- Modo volumen / brillo (OSD) ---------------------------------------
        // Persistente (no un Loader): la barra recuerda su ultimo valor, asi al volver a
        // aparecer solo desliza de lo que habia a lo nuevo (40 -> 50 %), en vez de crecer
        // desde cero cada vez.
        Item {
            id: osdView
            // Tamano FIJO (el final del notch en este modo, menos margenes) y centrado: si
            // siguiera al ancho animado del notch, la pista de la barra creceria con el y el
            // relleno parecería salir desde cero cada vez. Asi el notch solo lo "revela".
            width: win.osdWidth - 32
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: win.mode === "osd" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // Al cambiar de volumen a brillo (o al reves) la barra salta sin animar:
            // son escalas distintas y deslizar de una a otra no significa nada.
            property bool animateBar: true
            Connections {
                target: win
                function onOsdKindChanged() {
                    osdView.animateBar = false;
                    Qt.callLater(() => osdView.animateBar = true);
                }
            }

            // HUD de pista (teclas multimedia): caratula + titulo/artista + estado.
            Row {
                visible: win.osdKind === "track"
                spacing: 12
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    width: 36; height: 36; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.10)
                    clip: true
                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(72, 72)
                        source: MediaState.active ? MediaState.active.trackArtUrl : ""
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36 - 28 - parent.spacing * 2
                    Text {
                        width: parent.width
                        text: MediaState.active && MediaState.active.trackTitle !== "" ? MediaState.active.trackTitle : "Sin reproducción"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: MediaState.active ? MediaState.active.trackArtist : ""
                        color: Theme.textDim
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }
                Text {
                    width: 28
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    text: MediaState.playing ? "\uf04b" : "\uf04c"
                    color: Theme.accent
                    font.family: "FontAwesome"
                    font.pixelSize: 14
                }
            }

            Row {
                visible: win.osdKind !== "track"
                spacing: 14
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.osdKind === "brightness" ? "luz" : (audio.muted ? "mute" : "vol")
                    color: Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    width: 32
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 32 - 40 - parent.spacing * 2
                    height: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.15)
                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: win.osdKind === "volume" && audio.muted ? Theme.textDim : Theme.accent
                        width: parent.width * Math.max(0, Math.min(1, win.osdValue))
                        Behavior on width {
                            enabled: osdView.animateBar
                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(win.osdValue * 100)
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    width: 40
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // --- Multimedia -------------------------------------------------------------
        // Tamano fijo (el final), centrado: el notch solo lo "revela" al crecer.
        Loader {
            width: 560 - 40
            height: win.mediaHeight - 40
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 20
            active: win.mode === "media"
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            sourceComponent: MediaPanel {
                onCloseRequested: win.modeRequested("idle")
            }
        }

        // --- Portapapeles ---------------------------------------------------------
        // Tamano fijo (el final), centrado: el notch solo lo "revela" al crecer.
        Loader {
            width: 640 - 36
            height: win.clipboardHeight - 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            active: win.mode === "clipboard"
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            sourceComponent: ClipboardPanel {
                onCloseRequested: win.modeRequested("idle")
            }
        }

        // --- Menu de apagado ----------------------------------------------------
        Loader {
            anchors.fill: parent
            anchors.margins: 18
            anchors.topMargin: 20
            active: win.mode === "power"
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            sourceComponent: PowerMenu {
                onCloseRequested: win.modeRequested("idle")
            }
        }

        // --- Selector de fondos de pantalla ---------------------------------------
        // Tamano fijo (el final), centrado: el notch solo lo "revela" al crecer.
        Loader {
            width: 640 - 36
            height: 440 - 36
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 18
            active: win.mode === "wallpapers"
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            sourceComponent: WallpaperPanel {
                onCloseRequested: win.modeRequested("idle")
            }
        }

        // --- Selector de emoji -------------------------------------------------
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            active: win.mode === "emoji"
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            sourceComponent: EmojiPanel {
                onCloseRequested: win.modeRequested("idle")
            }
        }

        // --- Modo launcher -----------------------------------------------------
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 12
            active: win.launcherOpen
            opacity: active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            sourceComponent: Launcher {
                onCloseRequested: win.modeRequested("idle")
            }
        }
    }

    // --- Datos ---------------------------------------------------------------
    readonly property real osdValue: osdKind === "brightness" ? Brightness.level : audio.volume

    readonly property string iconSource: {
        const id = NiriState.focusedAppId;
        if (id === "") return "";
        // Depende de la lista de apps para recalcularse cuando termina de cargar.
        if (DesktopEntries.applications.values.length === 0) return "";
        const entry = DesktopEntries.heuristicLookup(id);
        return Quickshell.iconPath(entry ? entry.icon : id.toLowerCase(), "application-x-executable");
    }


    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    QtObject {
        id: audio
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
        readonly property string volumeText: {
            if (!sink || !sink.audio) return "";
            return muted ? "mute" : "vol " + Math.round(volume * 100) + "%";
        }
    }

    // Cambios de volumen/mute => HUD. `armed` evita que salte al arrancar.
    property bool armed: false
    Timer { interval: 2500; running: true; onTriggered: win.armed = true }
    Connections {
        target: audio.sink && audio.sink.audio ? audio.sink.audio : null
        function onVolumeChanged() { if (win.armed) win.volumeActivity(); }
        function onMutedChanged()  { if (win.armed) win.volumeActivity(); }
    }
}
