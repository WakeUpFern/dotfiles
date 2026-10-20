pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Barras de audio para el notch. Si `cava` esta instalado se usa el espectro REAL del audio que
// sale por la salida predeterminada; si no, una animacion simulada que solo se mueve mientras suena.
// Solo trabaja cuando `wanted` es true (suena algo y el notch esta visible), para no gastar CPU.
Singleton {
    id: root

    property bool wanted: false
    readonly property int count: 6
    property var bars: [0, 0, 0, 0, 0, 0]       // 0..1
    property bool hasCava: false
    readonly property bool live: wanted && hasCava

    Process {
        id: probe
        command: ["sh", "-c", "command -v cava"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.hasCava = text.trim() !== "" }
    }

    // Espectro real: cada linea es "12;40;63;..." (una barra por numero, 0..100).
    Process {
        id: cava
        running: root.live
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(";");
                if (p.length < root.count) return;
                const out = [];
                for (let i = 0; i < root.count; i++) out.push(Math.min(1, Math.max(0, Number(p[i]) / 100)));
                root.bars = out;
            }
        }
        onExited: if (root.live) retry.restart()
    }
    Timer { id: retry; interval: 2000; onTriggered: if (root.live) cava.running = true }

    // Sin cava: movimiento simulado (no es el audio real).
    property real t: 0
    Timer {
        interval: 66
        repeat: true
        running: root.wanted && !root.hasCava
        onTriggered: {
            root.t += 0.5;
            const out = [];
            for (let i = 0; i < root.count; i++)
                out.push(0.18 + 0.82 * Math.abs(Math.sin(root.t * (0.55 + i * 0.17) + i * 1.9) * Math.cos(root.t * 0.31 + i)));
            root.bars = out;
        }
    }

    // Al parar, las barras bajan a cero.
    onWantedChanged: if (!wanted) bars = [0, 0, 0, 0, 0, 0]
}
