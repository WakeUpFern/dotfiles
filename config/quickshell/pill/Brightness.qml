pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Brillo de pantalla via brightnessctl. Escribe con throttle para que arrastrar
// el slider no lance un proceso por cada pixel.
Singleton {
    id: root

    property real level: 0.5          // 0..1
    property bool available: false
    property real pending: -1

    readonly property real minLevel: 0.03   // nunca dejar la pantalla en negro

    function set(v) {
        level = Math.max(minLevel, Math.min(1, v));
        pending = level;
        throttle.restart();
    }
    function step(delta) { set(level + delta); }
    function refresh() { readProc.running = true; }

    function flush() {
        if (pending < 0) return;
        if (writeProc.running) { throttle.restart(); return; }
        writeProc.command = ["brightnessctl", "-q", "set", Math.round(pending * 100) + "%"];
        pending = -1;
        writeProc.running = true;
    }

    Timer { id: throttle; interval: 60; onTriggered: root.flush() }

    Process { id: writeProc }

    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "amdgpu_bl0,backlight,16679,26%,64764"
                const f = text.trim().split(",");
                if (f.length >= 5 && parseInt(f[4]) > 0) {
                    root.level = parseInt(f[2]) / parseInt(f[4]);
                    root.available = true;
                }
            }
        }
    }

    // Por si el brillo cambia desde fuera (otra herramienta, teclas del firmware).
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: if (!writeProc.running && root.pending < 0) root.refresh()
    }

    Component.onCompleted: refresh()
}
