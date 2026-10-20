pragma Singleton
import QtQuick
import Quickshell

// Historial de notificaciones (en memoria: se vacia al reiniciar Quickshell) y "No molestar".
// Cada entrada es una copia estable de los datos: la notificacion original puede morir (la app
// la cierra, expira) y el historial la conserva.
Singleton {
    id: root

    property var entries: []              // mas nuevas primero
    property int unread: 0
    property bool dnd: false              // No molestar: no salen tarjetas (las criticas si), pero se guardan
    readonly property int maxEntries: 50
    property int seq: 0

    Component {
        id: entryComp
        QtObject {
            property int uid
            property string summary
            property string body
            property string appName
            property string appIcon
            property string image
            property string desktopEntry
            property bool critical
            property date time
        }
    }

    function add(n, critical) {
        const e = entryComp.createObject(root, {
            uid: seq++, summary: n.summary, body: n.body, appName: n.appName, appIcon: n.appIcon,
            image: n.image, desktopEntry: n.desktopEntry, critical: critical, time: new Date()
        });
        let list = [e].concat(entries);
        if (list.length > maxEntries) {
            list.slice(maxEntries).forEach(d => d.destroy(500));
            list = list.slice(0, maxEntries);
        }
        entries = list;
        unread += 1;
    }

    function remove(e) {
        entries = entries.filter(x => x !== e);
        unread = Math.min(unread, entries.length);
        e.destroy(500);
    }

    function clear() {
        const old = entries;
        entries = [];
        unread = 0;
        old.forEach(d => d.destroy(500));
    }

    function markRead() { unread = 0; }
    function toggleDnd() { dnd = !dnd; }
}
