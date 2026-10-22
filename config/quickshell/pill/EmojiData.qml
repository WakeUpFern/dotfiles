pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Datos del selector de emoji: emoji.json (generado con scripts/gen-emoji.py a partir del diccionario
// de GTK/CLDR, con nombres en espanol e ingles), los recientes y el tono de piel preferido, guardados en
// ~/.local/state/pill/emoji.
Singleton {
    id: root

    property var entries: []                     // { text, name, hay, group, tone }
    property var groups: []
    property var toneChars: []                   // modificadores 1F3FB..1F3FF
    property var recent: []                      // textos (con hueco de tono) del mas reciente al mas antiguo
    property int tone: 0                         // 0 = por defecto, 1..5 = tonos de piel
    property bool hasWtype: false                // wtype escribe el emoji directamente en la app

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/pill/emoji"
    readonly property string slot: ""
    readonly property int maxRecent: 24

    function load() { data.reload(); state.reload(); probeTools(); }
    function probeTools() { probe.running = true; }

    function norm(s) {
        s = (s || "").toLowerCase();
        try { return s.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) { return s; }
    }

    // Texto final con el tono elegido (o sin el, si el emoji no admite tono).
    function render(e) { return e.text.split(slot).join(e.tone && tone > 0 ? toneChars[tone - 1] : ""); }

    function recentEntries() {
        const byText = {};
        for (const e of entries) byText[e.text] = e;
        return recent.map(t => byText[t]).filter(e => e);
    }

    function use(e) {
        recent = [e.text].concat(recent.filter(t => t !== e.text)).slice(0, maxRecent);
        save();
    }
    function setTone(t) { tone = t; save(); }

    function save() {
        mkdir.running = true;
        state.setText(JSON.stringify({ recent: recent, tone: tone }) + "\n");
    }

    Process { id: mkdir; command: ["mkdir", "-p", root.stateFile.replace(/\/[^\/]*$/, "")] }
    Process {
        id: probe
        command: ["sh", "-c", "command -v wtype"]
        onExited: code => root.hasWtype = code === 0
    }

    FileView {
        id: data
        path: Quickshell.shellPath("emoji.json")
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.groups = d.groups;
                root.toneChars = d.tones;
                root.entries = d.emoji.map(r => ({ text: r[0], name: r[1], hay: root.norm(r[1] + " " + r[2]), group: r[3], tone: r[4] === 1 }));
            } catch (e) { console.warn("emoji.json invalido:", e); }
        }
    }
    FileView {
        id: state
        path: root.stateFile
        printErrors: false
        onLoaded: {
            try {
                const o = JSON.parse(text());
                if (Array.isArray(o.recent)) root.recent = o.recent;
                if (o.tone >= 0 && o.tone <= 5) root.tone = o.tone;
            } catch (e) {}
        }
    }
}
