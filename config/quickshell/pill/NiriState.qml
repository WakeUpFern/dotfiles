pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Estado de niri via `niri msg --json`. Escucha el event-stream y, ante cualquier
// evento, vuelve a consultar workspaces y ventana enfocada (barato y robusto).
Singleton {
    id: root

    property var workspaces: []        // [{id, idx, name, is_active, is_focused, output}]
    property string focusedTitle: ""
    property string focusedAppId: ""
    property real focusedWidth: 0       // tamano logico de la ventana enfocada
    property real focusedHeight: 0

    function focusWorkspace(idx) {
        focusProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        focusProc.running = true;
    }

    Process {
        id: focusProc
    }

    // Enfoca la ventana de una app: por app-id (desktopEntry de la notificacion) o,
    // si no hay coincidencia exacta, por nombre. Prefiere la que pide atencion.
    function focusApp(desktopEntry, appName) {
        raiseTarget = { entry: (desktopEntry || "").toLowerCase(), name: (appName || "").toLowerCase() };
        raiseQuery.running = true;
    }
    property var raiseTarget: ({ entry: "", name: "" })

    Process {
        id: raiseQuery
        command: ["niri", "msg", "--json", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const t = root.raiseTarget;
                    const all = JSON.parse(text);
                    const id = w => (w.app_id || "").toLowerCase();
                    let m = all.filter(w => t.entry !== "" && id(w) === t.entry);
                    if (m.length === 0 && t.name !== "") m = all.filter(w => id(w).includes(t.name) || t.name.includes(id(w)) && id(w) !== "");
                    if (m.length === 0) return;
                    m.sort((a, b) => (b.is_urgent ? 1 : 0) - (a.is_urgent ? 1 : 0));
                    root.focusById(m[0].id);
                } catch (e) { console.warn("focusApp:", e); }
            }
        }
    }

    function focusById(id) {
        focusProc.command = ["niri", "msg", "action", "focus-window", "--id", String(id)];
        focusProc.running = true;
    }

    Process {
        id: events
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: _ => debounce.restart()
        }
        // Si niri se reinicia, el stream muere: reintentar.
        onRunningChanged: if (!running) retry.start()
    }

    Timer { id: retry; interval: 1500; onTriggered: events.running = true }
    Timer { id: debounce; interval: 40; onTriggered: { wsQuery.running = true; winQuery.running = true; } }

    Process {
        id: wsQuery
        command: ["niri", "msg", "--json", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text);
                    // Solo el monitor con foco, ordenado por indice.
                    const focused = all.find(w => w.is_focused);
                    const out = focused ? focused.output : (all[0] ? all[0].output : "");
                    root.workspaces = all.filter(w => w.output === out).sort((a, b) => a.idx - b.idx);
                } catch (e) { console.warn("niri workspaces:", e); }
            }
        }
    }

    Process {
        id: winQuery
        command: ["niri", "msg", "--json", "focused-window"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const w = JSON.parse(text);
                    root.focusedTitle = w ? (w.title || "") : "";
                    root.focusedAppId = w ? (w.app_id || "") : "";
                    const sz = w && w.layout ? w.layout.window_size : null;
                    root.focusedWidth = sz ? sz[0] : 0;
                    root.focusedHeight = sz ? sz[1] : 0;
                } catch (e) { root.focusedTitle = ""; root.focusedAppId = ""; root.focusedWidth = 0; root.focusedHeight = 0; }
            }
        }
    }

    Component.onCompleted: debounce.start()
}
