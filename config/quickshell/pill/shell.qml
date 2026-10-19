//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Punto de entrada. Arrancar con:  qs -c pill
// La pildora es el unico "widget": barra, launcher, notificaciones y estado.
ShellRoot {
    id: root

    // Quien tenga el foco del notch: "idle" | "launcher" | "notification" | "osd"
    property string mode: "idle"

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

    // HUD de volumen: aparece un momento y vuelve a reposo.
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

    Wallpaper {}

    Pill {
        mode: root.mode
        notifications: notifications
        onModeRequested: m => root.mode = m
        onVolumeActivity: {
            if (root.mode === "idle" || root.mode === "osd") {
                root.mode = "osd";
                osdTimer.restart();
            }
        }
    }
}
