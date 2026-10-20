pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tokens visuales. Cambia aqui y se actualiza toda la pildora.
Singleton {
    readonly property color glass:      Qt.rgba(0.07, 0.07, 0.10, 0.55)
    readonly property color glassHover: Qt.rgba(0.12, 0.12, 0.16, 0.65)
    readonly property color border:     Qt.rgba(1, 1, 1, 0.14)
    readonly property color text:       "#f2f2f7"
    readonly property color textDim:    Qt.rgba(1, 1, 1, 0.55)
    readonly property color accent:     "#8ab4ff"
    readonly property color warn:       "#ff9f6e"
    readonly property color urgent:     "#ff5f6d"

    readonly property string fontSans: "Inter"
    readonly property string fontMono: "JetBrains Mono"
    readonly property int fontSize: 13

    // Notch: pegado al borde superior (sin margen), esquinas redondas abajo.
    readonly property int notchHeight: 34
    readonly property int notchPeekHeight: 40
    readonly property int animMs: 420

    // Bloqueo de pantalla: false = swaylock (probado), true = el bloqueo propio del notch
    // (LockScreen.qml). Activar solo despues de probar `scripts/lock-test.sh`.
    readonly property bool nativeLock: true

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
}
