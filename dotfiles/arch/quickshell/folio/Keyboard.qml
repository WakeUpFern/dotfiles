pragma Singleton
import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// The keyboard layouts sway was given, and which one is in use: read from sway
// at runtime and kept live through its input events.
QtObject {
    id: keyboard
    property var names: []
    property int active: 0
    readonly property string activeName: names[active] ?? ""
    readonly property string activeCode: code(activeName)
    // A three-letter label for a layout name as sway reports it: "English (US)" -> "eng".
    function code(name: string): string {
        const exact = {
            // "Spanish (Latin American)": "lat"
        };
        if (exact[name])
            return exact[name];
        const language = String(name || "").replace(/\s*\(.*$/, "").trim();
        const known = {
            "English": "eng",
            "Spanish": "esp",
            "French": "fra",
            "German": "deu",
            "Portuguese": "por",
            "Italian": "ita",
            "Russian": "rus"
        };
        return known[language] || language.slice(0, 3).toLowerCase();
    }
    function choose(index: int): void {
        if (index < 0 || index >= names.length)
            return;
        active = index;
        I3.dispatch("input type:keyboard xkb_switch_layout " + index);
    }
    // The power and sleep buttons, the video bus and the ThinkPad hotkeys all register
    // as keyboards and carry the layouts too; the one typed on is called "... keyboard".
    function pick(inputs) {
        const boards = inputs.filter(i => i.type === "keyboard" && (i.xkb_layout_names || []).length > 0 && !/virtual/i.test(i.name || ""));
        return boards.find(i => /keyboard/i.test(i.name || "")) || boards.find(i => !/button|bus|switch|hotkey/i.test(i.name || "")) || boards[0] || null;
    }
    property bool pending: false
    function refresh(): void {
        pending = true;
        debounce.restart();
    }
    property Timer debounce: Timer {
        interval: 40
        onTriggered: {
            if (!keyboard.query.running) {
                keyboard.pending = false;
                keyboard.query.running = true;
            }
        }
    }
    property Process query: Process {
        command: ["swaymsg", "-r", "-t", "get_inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const board = keyboard.pick(JSON.parse(text));
                    const next = board ? board.xkb_layout_names : [];
                    if (JSON.stringify(next) !== JSON.stringify(keyboard.names))
                        keyboard.names = next;
                    keyboard.active = board ? Math.max(0, board.xkb_active_layout_index ?? 0) : 0;
                } catch (error) {
                    console.warn("Folio keyboard:", error);
                }
            }
        }
        onExited: {
            if (keyboard.pending)
                keyboard.debounce.restart();
        }
    }
    property I3IpcListener events: I3IpcListener {
        subscriptions: ["input"]
        onIpcEvent: event => {
            if (event.type === "input")
                keyboard.refresh();
        }
    }
    Component.onCompleted: refresh()
}
