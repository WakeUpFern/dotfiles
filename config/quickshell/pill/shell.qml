//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Punto de entrada. Arrancar con:  qs -c pill
// La pildora es el unico "widget": barra, launcher, notificaciones y estado.
ShellRoot {
    id: root

    // Quien tenga el foco del notch: "idle" | "launcher" | "power" | "controls" | "notification" | "osd"
    property string mode: "idle"
    property string controlsFocus: ""
    property string osdKind: "volume"

    // HUD de volumen/brillo: aparece un momento y vuelve a reposo.
    function showOsd(kind) {
        if (mode !== "idle" && mode !== "osd") return;
        osdKind = kind;
        mode = "osd";
        osdTimer.restart();
    }

    NotificationServer {
        id: notifications
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: false
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            if (root.mode === "idle" || root.mode === "osd") {
                root.mode = "notification";
                notifTimer.restart();
            }
        }
    }

    // Vuelve a "idle" cuando termina el aviso.
    Timer {
        id: notifTimer
        interval: 5000
        onTriggered: if (root.mode === "notification") root.mode = "idle"
    }

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

    // Menu de apagado:  qs -c pill ipc call power toggle   (niri: Mod+Shift+E)
    IpcHandler {
        target: "power"
        function toggle(): void { root.mode = root.mode === "power" ? "idle" : "power"; }
        function open(): void   { root.mode = "power"; }
        function close(): void  { root.mode = "idle"; }
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

    Pill {
        mode: root.mode
        controlsFocus: root.controlsFocus
        osdKind: root.osdKind
        notifications: notifications
        onModeRequested: m => root.mode = m
        onControlsRequested: t => { root.controlsFocus = t; root.mode = "controls"; }
        onVolumeActivity: root.showOsd("volume")
    }
}
