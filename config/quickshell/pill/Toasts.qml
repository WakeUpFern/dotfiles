import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Services.Notifications

// Pila de notificaciones emergentes (maximo 5 visibles, el resto espera turno).
// `add(n)` recibe una Notification del NotificationServer.
Scope {
    id: root

    property var entries: []
    readonly property int maxVisible: 5
    readonly property var visibleEntries: entries.slice(0, maxVisible)

    // Una copia estable de los datos de cada notificacion: el objeto original puede
    // morir (la app la cierra, expira) mientras la tarjeta aun anima su salida.
    Component {
        id: entryComp
        QtObject {
            property var n
            property string summary
            property string body
            property string appName
            property string desktopEntry
            property string appIcon
            property string image
            property bool critical
            property real timeout
        }
    }

    function add(n) {
        const e = entryComp.createObject(root, {
            n: n,
            summary: n.summary, body: n.body, appName: n.appName, desktopEntry: n.desktopEntry,
            appIcon: n.appIcon, image: n.image,
            critical: n.urgency === NotificationUrgency.Critical,
            timeout: n.expireTimeout
        });
        entries = entries.concat([e]);
    }
    function remove(entry) {
        entries = entries.filter(e => e !== entry);
        entry.destroy(500);
    }

    // ScriptModel + Instantiator: los cambios son incrementales, asi una tarjeta
    // que ya esta en pantalla no reinicia su animacion cuando otra entra o sale.
    Instantiator {
        model: ScriptModel { values: root.visibleEntries }

        delegate: Toast {
            required property var modelData
            entry: modelData
            slot: root.visibleEntries.indexOf(modelData)
            onFinished: root.remove(modelData)
        }
    }
}
