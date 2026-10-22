pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Luz nocturna con wlsunset (tinte calido de pantalla). Tres modos, guardados en
// ~/.local/state/pill/nightlight:
//   off  = apagada
//   auto = programada: se calienta de `from` a `to` con una transicion suave de 30 min
//   on   = ahora mismo y de forma constante hasta que la apagues
Singleton {
    id: root

    property string mode: "off"          // "off" | "auto" | "on"
    property int temperature: 4000       // K de la noche (menor = mas calido)
    property string from: "20:00"
    property string to: "07:00"
    readonly property bool enabled: mode !== "off"

    readonly property string file: Quickshell.env("HOME") + "/.local/state/pill/nightlight"

    function load() { store.reload(); }

    function setMode(m) { mode = m; changed(); }
    function setTemperature(k) { temperature = Math.round(Math.max(2500, Math.min(6000, k)) / 100) * 100; changed(); }
    function setSchedule(f, t) {
        if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(f) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(t)) return false;
        from = f; to = t; changed();
        return true;
    }
    // Un clic en el tile: apagada -> ahora; encendida (de cualquier modo) -> apagada.
    function toggle() { setMode(enabled ? "off" : "on"); }

    function changed() { save(); restartProc(); }
    function save() {
        mkdir.running = true;
        store.setText(JSON.stringify({ mode: mode, temperature: temperature, from: from, to: to }) + "\n");
    }

    // wlsunset toma sus ajustes por argumentos: hay que relanzarlo al cambiarlos.
    // "Ahora": -t = -T (+1 por si rechaza que sean iguales) deja una temperatura constante.
    readonly property var command: mode === "on"
        ? ["wlsunset", "-t", String(temperature), "-T", String(temperature + 1)]
        : ["wlsunset", "-t", String(temperature), "-T", "6500", "-s", from, "-S", to, "-d", "1800"]

    function restartProc() { proc.running = false; restartTimer.restart(); }
    Timer { id: restartTimer; interval: 200; onTriggered: proc.running = root.enabled }

    Process {
        id: proc
        command: root.command
        onExited: code => { if (code !== 0 && code !== 15 && root.enabled) console.warn("wlsunset termino con codigo", code); }
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.file.replace(/\/[^\/]*$/, "")]
    }
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (["off", "auto", "on"].indexOf(o.mode) >= 0) root.mode = o.mode;
                if (o.temperature) root.temperature = o.temperature;
                if (o.from) root.from = o.from;
                if (o.to) root.to = o.to;
            } catch (e) {}
            proc.running = root.enabled;
        }
    }
}
