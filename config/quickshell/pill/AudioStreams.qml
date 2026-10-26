pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Flujos de audio de PipeWire agrupados por funcion: apps que reproducen, apps que graban y
// micrófonos. Lo usan el menu de volumen (mezclador) y la barra (punto de "microfono en uso").
Singleton {
    id: root

    // Hace falta enlazar los nodos para poder leer sus propiedades y volumen.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function start() { store.reload(); }   // basta con tocarlo para que exista y enlace los nodos

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

    // --- Salida de cada app ---------------------------------------------------------------------
    // Salidas reales (altavoces, audifonos...), no flujos.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    PwObjectTracker { objects: Pipewire.linkGroups.values }

    // Salida por la que suena un flujo ahora mismo (la deduce de los enlaces), o null.
    function sinkOf(node) {
        for (const lg of Pipewire.linkGroups.values)
            if (lg.source && lg.target && lg.source.id === node.id && lg.target.isSink && !lg.target.isStream) return lg.target;
        return null;
    }
    // Salida de un grupo: la de sus flujos si coinciden; null si estan en salidas distintas o no suenan.
    function groupSink(g) {
        const s = g.nodes.map(sinkOf).filter(x => x);
        return s.length && s.every(x => x.id === s[0].id) ? s[0] : null;
    }
    // Mueve todos los flujos de la app a `sink`; con null vuelve a seguir la salida predeterminada.
    // La eleccion se guarda por nombre de app y se reaplica cuando la app vuelva a abrir audio.
    function moveGroup(g, sink) {
        const next = Object.assign({}, saved);
        if (sink) next[g.name] = sink.name; else delete next[g.name];
        saved = next;
        mkdir.running = true;
        store.setText(JSON.stringify(saved) + "\n");
        for (const n of g.nodes) { applied[key(n)] = true; moveNode(n, sink); }
    }
    function moveNode(n, sink) {
        const id = String(n.id);
        if (sink) Quickshell.execDetached(["pw-metadata", "-n", "default", id, "target.object", sink.name, "Spa:String"]);
        // "-1" hace que WirePlumber olvide la salida que recordaba para esta app; despues se quita la clave.
        else Quickshell.execDetached(["sh", "-c", 'pw-metadata -n default "$1" target.object -1 Spa:Id; pw-metadata -n default -d "$1" target.object', "_", id]);
    }

    // --- Salidas recordadas ---------------------------------------------------------------------
    property var saved: ({})              // nombre de app -> node.name de la salida elegida (~/.local/state/pill/audio-outputs)
    property var applied: ({})            // flujos a los que ya se aplico lo guardado (PipeWire reutiliza los ids: se usa el numero de serie)
    function key(n) { return (n.properties && n.properties["object.serial"]) || n.id; }
    readonly property string file: Quickshell.env("HOME") + "/.local/state/pill/audio-outputs"

    // A cada flujo nuevo de una app con salida guardada se le pone esa salida (si esta conectada).
    // Un flujo recien creado aun esta negociando y WirePlumber ignora el cambio, asi que se comprueba
    // cada medio segundo (hasta 6 veces) que realmente suene por la salida guardada.
    property var pending: ({})            // id de flujo -> { node, sink, tries }
    function applySaved() {
        for (const g of apps) {
            const want = saved[g.name];
            const sink = want ? sinks.find(x => x.name === want) : null;
            if (!sink) continue;
            for (const n of g.nodes) {
                if (applied[key(n)]) continue;
                applied[key(n)] = true;
                pending[n.id] = { node: n, sink: sink, tries: 0 };
                retry.running = true;
            }
        }
    }
    Timer {
        id: retry
        interval: 500
        repeat: true
        onTriggered: {
            const ids = Object.keys(root.pending);
            for (const id of ids) {
                const p = root.pending[id];
                const cur = root.sinkOf(p.node);
                if ((cur && cur.id === p.sink.id) || ++p.tries > 6) delete root.pending[id];
                else root.moveNode(p.node, p.sink);
            }
            if (Object.keys(root.pending).length === 0) running = false;
        }
    }
    onAppsChanged: applySaved()
    onSinksChanged: applySaved()
    onSavedChanged: applySaved()

    Process { id: mkdir; command: ["mkdir", "-p", root.file.replace(/\/[^\/]*$/, "")] }
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: { try { root.saved = JSON.parse(text()); } catch (e) {} }
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
