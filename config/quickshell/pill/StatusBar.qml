import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Barra de estado de la derecha: iconos sin fondo (con una sombra suave para que se lean sobre
// cualquier ventana) y el reloj. Cada icono abre su menu (PopoverHost); con uno abierto, pulsar
// otro cambia directamente a ese.
PanelWindow {
    id: win

    property string active: ""            // menu abierto ("" = ninguno)
    signal toggled(string name)

    readonly property real barWidth: strip.width
    readonly property real barHeight: Theme.notchHeight

    // Como el notch: en pantalla completa se esconde hacia arriba (salvo con un menu abierto).
    readonly property bool fullscreenFocused: NiriState.focusedWidth >= win.screen.width
                                           && NiriState.focusedHeight >= win.screen.height
    readonly property bool tucked: fullscreenFocused && active === ""

    anchors { top: true; right: true }
    implicitWidth: strip.width + 16
    implicitHeight: Theme.notchHeight + 8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore          // el notch ya reserva la franja superior
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pill-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: strip }

    // --- Datos ------------------------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    PwObjectTracker { objects: [win.sink] }

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt !== null && bt.enabled
    readonly property bool btConnected: Bluetooth.devices.values.some(d => d.connected)

    readonly property var battery: UPower.displayDevice
    readonly property real batteryPct: battery.percentage
    readonly property bool charging: battery.state === UPowerDeviceState.Charging
    SystemClock { id: clock; precision: SystemClock.Minutes }

    // --- Un boton de la barra -----------------------------------------------------------
    component BarButton: Item {
        id: btn
        property string name
        readonly property bool open: win.active === name
        default property alias content: row.data
        signal clicked()
        implicitWidth: row.implicitWidth + 16
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: btn.open ? Qt.rgba(1, 1, 1, 0.20) : (area.pressed ? Qt.rgba(1, 1, 1, 0.22) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 5
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Icono con sombra suave (legible sobre fondos claros u oscuros).
    component BarGlyph: Text {
        font.family: "FontAwesome"
        font.pixelSize: 15
        color: Theme.text
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.55)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    component BarText: Text {
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
        color: Theme.text
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.55)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // --- La barra ---------------------------------------------------------------------------
    Item {
        id: strip
        width: items.implicitWidth + 12
        height: Theme.notchHeight
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: win.tucked ? -(height + 8) : 2
        Behavior on anchors.topMargin { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        Row {
            id: items
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 6
            spacing: 2

            BarButton {
                name: "bluetooth"
                visible: win.bt !== null
                onClicked: win.toggled(name)
                BarGlyph {
                    text: ""
                    color: win.btConnected ? Theme.accent : (win.btOn ? Theme.text : Theme.textDim)
                    opacity: win.btOn ? 1 : 0.7
                }
            }
            BarButton {
                name: "volume"
                onClicked: win.toggled(name)
                BarGlyph {
                    text: win.muted || win.volume <= 0.001 ? "" : (win.volume < 0.5 ? "" : "")
                    color: win.muted ? Theme.textDim : Theme.text
                }
            }
            BarButton {
                name: "battery"
                visible: win.battery.isPresent
                onClicked: win.toggled(name)
                BarGlyph {
                    visible: win.charging
                    text: ""
                    font.pixelSize: 12
                    color: "#ffd479"
                }
                BarGlyph {
                    text: win.batteryPct > 0.875 ? "" : win.batteryPct > 0.625 ? "" : win.batteryPct > 0.375 ? "" : win.batteryPct > 0.125 ? "" : ""
                    color: win.batteryPct < 0.2 && !win.charging ? Theme.urgent : Theme.text
                    font.pixelSize: 17
                }
                BarText {
                    text: Math.round(win.batteryPct * 100) + "%"
                    font.pixelSize: Theme.fontSize - 1
                    color: win.batteryPct < 0.2 && !win.charging ? Theme.urgent : Theme.text
                }
            }
            BarButton {
                name: "clock"
                onClicked: win.toggled(name)
                BarText {
                    text: Qt.formatDateTime(clock.date, "ddd d  HH:mm")
                    font.weight: Font.Medium
                }
            }
        }
    }
}
