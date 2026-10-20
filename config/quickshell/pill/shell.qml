//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Punto de entrada. Arrancar con:  qs -c pill
// La pildora es el unico "widget": barra, launcher, notificaciones y estado.
ShellRoot {
    id: root

    // Quien tenga el foco del notch: "idle" | "launcher" | "clipboard" | "media" | "power" | "controls" | "osd"
    property string mode: "idle"
    Component.onCompleted: BluetoothAudio.start()

    property string controlsFocus: ""
    property string osdKind: "volume"

    // HUD de volumen/brillo: aparece un momento y vuelve a reposo.
    function showOsd(kind) {
        if (mode !== "idle" && mode !== "osd") return;
        osdKind = kind;
        mode = "osd";
        osdTimer.restart();
    }

    // Notificaciones: tarjetas de vidrio arriba a la derecha (Toasts.qml).
    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            toasts.add(n);
        }
    }
    Toasts { id: toasts }

    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: if (root.mode === "osd") root.mode = "idle"
    }

    // Control desde fuera:  qs -c pill ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.mode = root.mode === "launcher" ? "idle" : "launcher"; }
        function open(): void   { root.mode = "launcher"; }
        function close(): void  { root.mode = "idle"; }
    }

    // Teclas de brillo (niri las manda aqui):  qs -c pill ipc call brightness up
    IpcHandler {
        target: "brightness"
        function up(): void   { Brightness.step(0.05);  root.showOsd("brightness"); }
        function down(): void { Brightness.step(-0.05); root.showOsd("brightness"); }
    }

    // Multimedia:  qs -c pill ipc call media toggle|playpause|next|previous|select <nombre>
    // Las teclas multimedia de niri llaman aqui; play/next/prev muestran el HUD de la pista.
    IpcHandler {
        target: "media"
        function toggle(): void   { root.mode = root.mode === "media" ? "idle" : "media"; }
        function open(): void     { root.mode = "media"; }
        function close(): void    { root.mode = "idle"; }
        function playpause(): void { MediaState.togglePlaying(); root.showOsd("track"); }
        function next(): void      { MediaState.next();          root.showOsd("track"); }
        function previous(): void  { MediaState.previous();      root.showOsd("track"); }
        function select(name: string): string { return MediaState.select(name); }
        function status(): string {
            const p = MediaState.active;
            return p ? p.identity + "|" + p.playbackState + "|" + p.trackTitle + "|" + p.trackArtist + "|" + Math.round(p.position) + "/" + Math.round(p.length) : "ninguno";
        }
    }

    // Portapapeles:  qs -c pill ipc call clipboard toggle   (niri: Mod+V)
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.mode = root.mode === "clipboard" ? "idle" : "clipboard"; }
        function open(): void   { root.mode = "clipboard"; }
        function close(): void  { root.mode = "idle"; }
    }

    // Menu de apagado:  qs -c pill ipc call power toggle   (niri: Mod+Shift+E)
    IpcHandler {
        target: "power"
        function toggle(): void { root.mode = root.mode === "power" ? "idle" : "power"; }
        function open(): void   { root.mode = "power"; }
        function close(): void  { root.mode = "idle"; }
        function lock(): void   { root.mode = "idle"; PowerActions.run("lock"); }
    }

    // Cambiar el fondo (y el del overview) en vivo:
    //   qs -c pill ipc call wallpaper set ~/Pictures/foto.png
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Theme.setWallpaper(path); }
    }

    // Abrir el panel de controles:  qs -c pill ipc call controls toggle
    IpcHandler {
        target: "controls"
        function toggle(): void { root.controlsFocus = ""; root.mode = root.mode === "controls" ? "idle" : "controls"; }
    }

    Wallpaper {}
    Backdrop {}

    // Bloqueo propio (solo se usa si Theme.nativeLock; si no, swaylock).
    LockScreen { id: lockScreen }
    Connections {
        target: PowerActions
        function onLockRequested() { lockScreen.lockNow(); }
    }

    // Click en cualquier parte fuera del notch cierra el menu abierto.
    Dismiss {
        active: root.mode === "launcher" || root.mode === "clipboard" || root.mode === "media" || root.mode === "power" || root.mode === "controls"
        pillWidth: pill.pillWidth
        pillHeight: pill.pillHeight
        onDismissed: root.mode = "idle"
    }

    Pill {
        id: pill
        mode: root.mode
        controlsFocus: root.controlsFocus
        osdKind: root.osdKind
        onModeRequested: m => root.mode = m
        onControlsRequested: t => { root.controlsFocus = t; root.mode = "controls"; }
        onVolumeActivity: root.showOsd("volume")
    }
}
