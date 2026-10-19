pragma Singleton
import QtQuick
import Quickshell

// Acciones de energia/sesion. Las destructivas (reiniciar, apagar, cerrar
// sesion) piden un segundo click/Enter para confirmar; se desarman solas a los 3 s.
Singleton {
    id: root

    readonly property var actions: [
        { id: "lock",     label: "Bloquear",      glyph: "", key: "l", confirm: false },
        { id: "suspend",  label: "Suspender",     glyph: "", key: "s", confirm: false },
        { id: "reboot",   label: "Reiniciar",     glyph: "", key: "r", confirm: true  },
        { id: "poweroff", label: "Apagar",        glyph: "", key: "p", confirm: true  },
        { id: "logout",   label: "Cerrar sesión", glyph: "", key: "e", confirm: true  }
    ]

    // Accion "armada" esperando confirmacion ("" = ninguna).
    property string armedId: ""

    function byId(id) { return actions.find(a => a.id === id); }
    function disarm() { armedId = ""; armTimer.stop(); }

    // Devuelve true si la accion se ejecuto (false = solo se armo).
    function request(id) {
        const a = byId(id);
        if (!a) return false;
        if (a.confirm && armedId !== id) {
            armedId = id;
            armTimer.restart();
            return false;
        }
        disarm();
        run(id);
        return true;
    }

    function run(id) {
        switch (id) {
        // Colores y opciones en config/swaylock/config (daemonize ya va incluido).
        case "lock":     Quickshell.execDetached(["swaylock", "-i", Theme.wallpaperPath]); break;
        case "suspend":  Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "reboot":   Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        case "logout":   Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]); break;
        }
    }

    Timer { id: armTimer; interval: 3000; onTriggered: root.armedId = "" }
}
