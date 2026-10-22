pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Uso del launcher: cuantas veces y cuando se abrio cada app (y cada archivo, con clave "file:ruta") (~/.local/state/pill/launcher-usage).
// Sirve para subir las que mas usas en las busquedas y para la pestana "Recientes".
Singleton {
    id: root

    property var data: ({})                  // id -> [veces, ultima vez (ms)]
    readonly property string file: Quickshell.env("HOME") + "/.local/state/pill/launcher-usage"

    function load() { store.reload(); }

    function bump(id) {
        if (!id) return;
        const d = data[id] || [0, 0];
        const next = Object.assign({}, data);
        next[id] = [d[0] + 1, Date.now()];
        data = next;
        mkdir.running = true;
        store.setText(JSON.stringify(data) + "\n");
    }

    // Bono para ordenar busquedas: crece con las veces y se desvanece con los dias (vida media ~3 semanas).
    function boost(id) {
        const d = data[id];
        if (!d) return 0;
        const days = (Date.now() - d[1]) / 86400000;
        return Math.log(1 + d[0]) * 3 * Math.exp(-days / 30);
    }

    function recentIds(n) {
        return Object.keys(data).filter(k => k.indexOf("file:") !== 0).sort((a, b) => data[b][1] - data[a][1]).slice(0, n);
    }

    Process { id: mkdir; command: ["mkdir", "-p", root.file.replace(/\/[^\/]*$/, "")] }
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
    }
}
