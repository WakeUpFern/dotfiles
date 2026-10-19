import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Notifications

// La pildora. Una sola ventana layer-shell; el rectangulo interior cambia de
// tamano con animacion segun el modo. El blur sigue exactamente su forma.
PanelWindow {
    id: win

    property string mode: "idle"
    property NotificationServer notifications
    signal modeRequested(string mode)

    readonly property bool launcherOpen: mode === "launcher"

    // Tamano objetivo de la pildora por modo.
    readonly property real targetWidth:  launcherOpen ? 560 : mode === "notification" ? 440 : idleRow.implicitWidth + 36
    readonly property real targetHeight: launcherOpen ? 400 : mode === "notification" ? 84  : Theme.barHeight

    anchors.top: true
    margins.top: Theme.margin
    implicitWidth: 640                       // superficie fija, mayor que la pildora
    implicitHeight: 420 + Theme.margin
    color: "transparent"

    // Reserva solo la franja de la barra; el resto de la superficie no empuja ventanas.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.barHeight + Theme.margin * 2

    WlrLayershell.namespace: "pill"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Solo la pildora recibe clicks; lo demas deja pasar el raton a las ventanas.
    mask: Region { item: pill }

    // Frosted glass real: niri desenfoca lo que hay detras del rectangulo.
    BackgroundEffect.blurRegion: Region { item: pill; radius: pill.radius }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: win.targetWidth
        height: win.targetHeight
        radius: Math.min(height / 2, 22)
        color: hover.hovered && win.mode === "idle" ? Theme.glassHover : Theme.glass
        border.width: 1
        border.color: Theme.border
        clip: true

        Behavior on width  { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.animMs; easing.type: Easing.OutCubic } }
        Behavior on color  { ColorAnimation  { duration: 150 } }

        HoverHandler { id: hover }

        // Click en la barra en reposo = abrir launcher.
        TapHandler {
            enabled: win.mode === "idle"
            onTapped: win.modeRequested("launcher")
        }

        // --- Modo reposo: workspaces | titulo | estado | reloj ---------------
        RowLayout {
            id: idleRow
            anchors.centerIn: parent
            spacing: 14
            opacity: win.mode === "idle" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: NiriState.workspaces
                    Rectangle {
                        required property var modelData
                        width: modelData.is_active ? 22 : 8
                        height: 8
                        radius: 4
                        color: modelData.is_active ? Theme.accent : Theme.textDim
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: NiriState.focusWorkspace(parent.modelData.idx)
                        }
                    }
                }
            }

            Text {
                visible: text !== ""
                Layout.maximumWidth: 220
                text: NiriState.focusedTitle
                color: Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }

            Text {
                text: audio.volumeText
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
            }

            Text {
                visible: UPower.displayDevice.isPresent
                text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                color: UPower.displayDevice.percentage < 0.2 ? Theme.urgent : Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
            }

            Text {
                text: Qt.formatDateTime(clock.date, "ddd d  HH:mm")
                color: Theme.text
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }

        // --- Modo notificacion -------------------------------------------------
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            active: win.mode === "notification"
            sourceComponent: Row {
                spacing: 12
                readonly property var n: {
                    const list = win.notifications ? win.notifications.trackedNotifications.values : [];
                    return list.length > 0 ? list[list.length - 1] : null;
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 2
                    Text {
                        width: parent.width
                        text: n ? n.summary : ""
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: n ? n.body : ""
                        color: Theme.textDim
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }
                }
            }
            // Click en el aviso lo descarta.
            MouseArea {
                anchors.fill: parent
                onClicked: win.modeRequested("idle")
            }
        }

        // --- Modo launcher -----------------------------------------------------
        Loader {
            anchors.fill: parent
            anchors.margins: 14
            active: win.launcherOpen
            sourceComponent: Launcher {
                onCloseRequested: win.modeRequested("idle")
            }
        }
    }

    // --- Datos ---------------------------------------------------------------
    SystemClock { id: clock; precision: SystemClock.Minutes }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    QtObject {
        id: audio
        readonly property var sink: Pipewire.defaultAudioSink
        readonly property string volumeText: {
            if (!sink || !sink.audio) return "";
            return sink.audio.muted ? "mute" : "vol " + Math.round(sink.audio.volume * 100) + "%";
        }
    }
}
