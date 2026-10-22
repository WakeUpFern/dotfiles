pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tokens visuales. Cambia aqui y se actualiza toda la pildora.
Singleton {
    // Paleta dinamica: con `dynamicPalette` el acento y el tinte del vidrio salen del fondo de pantalla
    // (wallpaper-palette.py) y se animan al cambiar de fondo. Estos son los valores por defecto/respaldo.
    property color accent:    "#8ab4ff"
    property color glassBase: Qt.rgba(0.07, 0.07, 0.10, 1)
    Behavior on accent    { ColorAnimation { duration: 700 } }
    Behavior on glassBase { ColorAnimation { duration: 700 } }

    readonly property color accentSoft: Qt.rgba(accent.r, accent.g, accent.b, 0.16)       // fondo de filas activas
    readonly property color glass:      Qt.rgba(glassBase.r, glassBase.g, glassBase.b, 0.55)
    readonly property color glassHover: Qt.rgba(glassBase.r + 0.05, glassBase.g + 0.05, glassBase.b + 0.06, 0.65)
    readonly property color border:     Qt.rgba(1, 1, 1, 0.14)
    readonly property color text:       "#f2f2f7"
    readonly property color textDim:    Qt.rgba(1, 1, 1, 0.55)
    readonly property color warn:       "#ff9f6e"
    readonly property color urgent:     "#ff5f6d"

    readonly property string fontSans: "Inter"
    readonly property string fontMono: "JetBrains Mono"
    readonly property int fontSize: 13

    // Fechas en espanol (el locale del sistema esta en ingles).
    readonly property var dayNames: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var monthNames: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

    // Notch: pegado al borde superior (sin margen), esquinas redondas abajo.
    readonly property int notchHeight: 34
    readonly property int notchPeekHeight: 40
    readonly property int animMs: 420

    // Bloqueo de pantalla: false = swaylock (probado), true = el bloqueo propio del notch
    // (LockScreen.qml). Activar solo despues de probar `scripts/lock-test.sh`.
    readonly property bool nativeLock: true

    // Motor de busqueda del launcher (fzf; ver Fzf.qml). Si no esta instalado se usa un puntuador interno.
    readonly property string fzfCommand: "fzf"

    // Paleta desde el fondo de pantalla. `syncGtkAccent` tambien pone el acento de GNOME mas cercano
    // (org.gnome.desktop.interface accent-color) para que Nautilus y demas apps libadwaita combinen.
    readonly property bool dynamicPalette: true
    readonly property bool syncGtkAccent: true

    // Inactividad (Idle.qml). Segundos sin tocar nada; 0 desactiva ese paso. Un video o cualquier app que
    // pida inhibir la inactividad la retrasa; el tile "No suspender" del panel la apaga del todo.
    readonly property bool idleEnabled: true
    readonly property int idleDimSeconds: 240          // baja el brillo
    readonly property int idleLockSeconds: 300         // bloquea
    readonly property int idleScreenOffSeconds: 330    // apaga la pantalla (se enciende al mover el raton)
    readonly property int idleSuspendSeconds: 900      // suspende, solo con bateria
    readonly property bool lockBeforeSleep: true       // bloquea siempre antes de suspender (tapa, boton, menu)

    // Agente polkit propio (PolkitDialog.qml). Si lo pones en false vuelve a hacer falta otro agente
    // (p. ej. mate-polkit) y hay que quitar el override de ~/.config/autostart (ver docs/power.md).
    readonly property bool polkitAgent: true

    // Avisos de bateria baja (porcentajes, de mayor a menor; el ultimo y el penultimo son criticos).
    // UPower hace el apagado/suspension final (PercentageAction en /etc/UPower/UPower.conf).
    readonly property var batteryWarnLevels: [20, 10, 5]

    // Bluetooth: al conectar unos audifonos pasa la salida de audio a ellos y elige el mejor perfil
    // A2DP (ver BluetoothAudio.qml). Pon false para desactivar cada comportamiento.
    readonly property bool btAutoSwitchOutput: true
    readonly property bool btPreferHighQuality: true

    // --- Fondo de pantalla ---------------------------------------------------
    // Una sola fuente para el fondo (Wallpaper.qml) y el fondo desenfocado del
    // overview (Backdrop.qml). Prioridad: archivo de estado > PILL_WALLPAPER > default.
    //   cambiar en vivo:  qs -c pill ipc call wallpaper set ~/Pictures/foto.png
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/pill/wallpaper"
    property string wallpaperPath: Quickshell.env("PILL_WALLPAPER")
        || (Quickshell.env("HOME") + "/Pictures/wallhaven-ogj1gl_1920x1080.png")
    readonly property string wallpaper: "file://" + wallpaperPath

    function setWallpaper(path) {
        writeState.command = ["sh", "-c",
            'f=$(readlink -f -- "$1") && [ -f "$f" ] && mkdir -p "$(dirname -- "$2")" && printf "%s" "$f" > "$2"',
            "_", path, stateFile];
        writeState.running = true;
    }

    Process {
        id: writeState
        onExited: code => { if (code === 0) loader.reload(); else console.warn("wallpaper: ruta invalida"); }
    }

    FileView {
        id: loader
        path: Theme.stateFile
        printErrors: false      // el archivo no existe hasta el primer cambio
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const p = text().trim(); if (p !== "") Theme.wallpaperPath = p; }
    }

    // --- Paleta del fondo ----------------------------------------------------------------
    function updatePalette() { if (dynamicPalette && wallpaperPath !== "") paletteTimer.restart(); }
    onWallpaperPathChanged: updatePalette()
    Component.onCompleted: updatePalette()

    Timer { id: paletteTimer; interval: 300; onTriggered: { palette.running = false; palette.running = true; } }

    Process {
        id: palette
        command: ["python3", "-I", Quickshell.shellPath("wallpaper-palette.py"), Theme.wallpaperPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text.trim());
                    Theme.accent = p.accent;
                    Theme.glassBase = p.glass;
                    if (Theme.syncGtkAccent && p.gtk)
                        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "accent-color", p.gtk]);
                } catch (e) { console.warn("paleta del fondo: salida invalida"); }
            }
        }
    }
}
