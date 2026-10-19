import QtQuick
import Quickshell
import Quickshell.Wayland

// Fondo de pantalla en la capa Background. Es lo que niri desenfoca detras de
// las ventanas con blur, asi que sin esto el frosted glass no se ve.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-wallpaper"
        color: "#0b0f0c"

        Image {
            anchors.fill: parent
            source: Theme.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }
    }
}
