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

    function focusWorkspace(idx) {
        focusProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)];
        focusProc.running = true;
    }

    Process {
        id: focusProc
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
                } catch (e) { root.focusedTitle = ""; root.focusedAppId = ""; }
            }
        }
    }

    Component.onCompleted: debounce.start()
}
