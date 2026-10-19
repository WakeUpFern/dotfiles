pragma Singleton
import QtQuick
import Quickshell

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

    // Fondo de pantalla. Se puede cambiar sin editar el repo:
    //   PILL_WALLPAPER=/ruta/imagen.png qs -c pill
    readonly property string wallpaper: "file://" + (Quickshell.env("PILL_WALLPAPER")
        || (Quickshell.env("HOME") + "/Pictures/wallhaven-ogj1gl_1920x1080.png"))
}
