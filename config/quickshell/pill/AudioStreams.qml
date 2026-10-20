pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Flujos de audio de PipeWire agrupados por funcion: apps que reproducen, apps que graban y
// micrófonos. Lo usan el menu de volumen (mezclador) y la barra (punto de "microfono en uso").
Singleton {
    id: root

    // Hace falta enlazar los nodos para poder leer sus propiedades y volumen.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function start() {}                 // basta con tocarlo para que exista y enlace los nodos

    function cls(n) { return (n.properties && n.properties["media.class"]) || ""; }

    readonly property var playback:  Pipewire.nodes.values.filter(n => cls(n) === "Stream/Output/Audio")
    // Solo grabaciones de un microfono: se excluyen las que "escuchan" la salida (visualizadores como
    // cava, grabadores de pantalla...), que Pipewire marca con stream.capture.sink.
    readonly property var recording: Pipewire.nodes.values.filter(n => cls(n) === "Stream/Input/Audio"
        && String(n.properties["stream.capture.sink"]) !== "true")
    readonly property var sources:   Pipewire.nodes.values.filter(n => cls(n) === "Audio/Source")

    // Alguna app tiene el micrófono abierto (un flujo de grabacion existe; puede estar en pausa).
    readonly property bool micInUse: recording.length > 0
    readonly property string micUsers: recording
        .map(n => (n.properties["application.name"] || n.description || "").replace(/ input$/i, ""))
        .filter((v, i, a) => v !== "" && a.indexOf(v) === i).join(", ")

    // Una fila por aplicacion (Chrome puede abrir varios flujos: uno por pestaña con audio).
    readonly property var apps: {
        const byName = {};
        for (const n of playback) {
            const p = n.properties;
            const name = p["application.name"] || n.description || n.name;
            if (!byName[name]) byName[name] = { name: name, icon: p["application.icon-name"] || p["application.process.binary"] || "", nodes: [] };
            byName[name].nodes.push(n);
        }
        return Object.values(byName).sort((a, b) => a.name.localeCompare(b.name));
    }

    // --- Volumen de un grupo de flujos de una misma app ---------------------------------------
    function groupVolume(g) {
        const v = g.nodes.filter(n => n.audio).map(n => n.audio.volume);
        return v.length ? v.reduce((a, b) => a + b, 0) / v.length : 0;
    }
    function groupMuted(g) { return g.nodes.length > 0 && g.nodes.every(n => n.audio && n.audio.muted); }
    function setGroupVolume(g, v) {
        for (const n of g.nodes) if (n.audio) { n.audio.muted = false; n.audio.volume = Math.max(0, Math.min(1.5, v)); }
    }
    function toggleGroupMute(g) {
        const m = !groupMuted(g);
        for (const n of g.nodes) if (n.audio) n.audio.muted = m;
    }
}
