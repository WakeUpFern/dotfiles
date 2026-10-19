import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// Fondo del overview (Mod+O): el wallpaper actual, desenfocado y oscurecido, en
// lugar del color solido. niri solo lo muestra en el overview (layer-rule
// `place-within-backdrop`), el wallpaper nitido normal no cambia.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-backdrop"
        color: "#0b0f0c"

        Image {
            id: wall
            anchors.fill: parent
            visible: false
            source: Theme.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(960, 540)     // menos pixeles = blur mas barato y suave
            asynchronous: true
        }

        MultiEffect {
            anchors.fill: parent
            source: wall
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            brightness: -0.18
            saturation: -0.1
            autoPaddingEnabled: false
        }
    }
}
