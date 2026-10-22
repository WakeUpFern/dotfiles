pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Apps fijadas del launcher. Se guardan por id de .desktop (uno por linea) en
// ~/.local/state/pill/pinned-apps, asi sobreviven a reinicios y a actualizar el paquete de la app.
Singleton {
    id: root

    property var ids: []
    readonly property string file: Quickshell.env("HOME") + "/.local/state/pill/pinned-apps"

    // Entradas resueltas (las que ya no estan instaladas se omiten sin borrarlas del archivo).
    readonly property var entries: {
        void DesktopEntries.applications.values;     // recalcular cuando termine de cargar la lista
        return ids.map(i => DesktopEntries.byId(i)).filter(e => e && !e.noDisplay);
    }

    // Se llama al arrancar el shell: el singleton es perezoso y asi las fijadas ya estan cargadas
    // cuando se abre el launcher por primera vez.
    function load() { store.reload(); }

    function isPinned(id) { return ids.indexOf(id) >= 0; }

    function toggle(id) {
        if (!id) return;
        ids = isPinned(id) ? ids.filter(i => i !== id) : ids.concat([id]);
        save();
    }

    function save() {
        mkdir.running = true;
        store.setText(ids.join("\n") + "\n");
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.file.replace(/\/[^\/]*$/, "")]
    }

    FileView {
        id: store
        path: root.file
        printErrors: false      // no existe hasta fijar la primera app
        onLoaded: root.ids = text().split("\n").map(l => l.trim()).filter(l => l !== "")
    }
}
