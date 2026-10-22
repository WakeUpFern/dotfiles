pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Capturas y grabacion de pantalla.
//   Capturas:  las hace niri (`niri msg action screenshot*`): se guardan segun `screenshot-path` de la config
//              de niri (~/Pictures/Screenshots) y se copian al portapapeles. Aqui solo se lanzan, con un
//              retardo opcional y esperando a que se cierre el panel para que no salga en la foto.
//   Grabacion: wf-recorder (+ slurp para elegir region) -> ~/Videos/Grabacion <fecha>.mp4. Se detiene con
//              SIGINT para que el archivo se cierre bien.
Singleton {
    id: root

    property int delay: 0                 // segundos antes de capturar
    property bool pointer: true           // incluir el puntero
    property bool hasRecorder: false
    property bool recording: false
    property int elapsed: 0
    property string lastFile: ""

    readonly property string shotsDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
    readonly property string videosDir: Quickshell.env("HOME") + "/Videos"
    readonly property string elapsedText: {
        const m = Math.floor(elapsed / 60), s = elapsed % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function load() { probe.running = true; }

    // kind: "area" (la interfaz de seleccion de niri) | "window" | "screen"
    function shoot(kind) {
        const action = kind === "window" ? "screenshot-window" : (kind === "screen" ? "screenshot-screen" : "screenshot");
        // 0.5 s: lo que tarda el panel en cerrarse; despues, el retardo pedido.
        Quickshell.execDetached(["sh", "-c", 'sleep "$1"; shift; exec "$@"', "_", String(0.5 + delay),
            "niri", "msg", "action", action, "--show-pointer", String(pointer)]);
    }

    function record(region) {
        if (recording || rec.running || !hasRecorder) return;
        rec.command = ["sh", "-c",
            'sleep 0.5; mkdir -p "$1"; f="$1/Grabación $(date +%Y-%m-%d_%H-%M-%S).mp4"; echo "$f"; ' +
            'if [ "$2" = region ]; then g=$(slurp) || exit 1; echo REC; exec wf-recorder -g "$g" -f "$f"; ' +
            'else echo REC; exec wf-recorder -f "$f"; fi',
            "_", videosDir, region ? "region" : "screen"];
        rec.running = true;
    }

    function stop() { if (rec.running) rec.signal(2); }          // SIGINT: wf-recorder cierra el archivo

    function openFolder() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1"; exec xdg-open "$1"', "_", shotsDir]);
    }

    Process {
        id: probe
        command: ["sh", "-c", "command -v wf-recorder && command -v slurp"]
        onExited: code => root.hasRecorder = code === 0
    }

    Process {
        id: rec
        stdout: SplitParser {
            onRead: line => {
                if (line === "REC") { root.elapsed = 0; root.recording = true; }
                else if (line !== "") root.lastFile = line;
            }
        }
        onExited: code => {
            const was = root.recording;
            root.recording = false;
            if (was) Quickshell.execDetached(["notify-send", "-a", "Captura", "-i", "video-x-generic",
                "Grabación guardada", root.lastFile.replace(Quickshell.env("HOME"), "~")]);
        }
    }

    Timer { interval: 1000; repeat: true; running: root.recording; onTriggered: root.elapsed++ }
}
