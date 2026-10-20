import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray

// Barra de estado de la derecha: iconos sin fondo (con una sombra suave para que se lean sobre
// cualquier ventana) y el reloj. Cada icono abre su menu (PopoverHost); con uno abierto, pulsar
// otro cambia directamente a ese.
PanelWindow {
    id: win

    property string active: ""            // menu abierto ("" = ninguno)
    property var trayItem: null           // icono de la bandeja cuyo menu esta abierto
    signal toggled(string name)
    signal trayMenu(var item)             // pedir el menu de un icono de la bandeja

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

    // Un icono de la bandeja: click = la accion de la app (o su menu si solo tiene menu), click
    // derecho = menu, rueda y boton central = lo que la app defina.
    component TrayButton: Item {
        id: tb
        required property var modelData
        readonly property bool open: win.active === "tray" && win.trayItem === modelData
        implicitWidth: 28
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: tb.open ? Qt.rgba(1, 1, 1, 0.20) : (tbArea.pressed ? Qt.rgba(1, 1, 1, 0.22) : (tbArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            sourceSize: Qt.size(32, 32)
            source: tb.modelData.icon
            smooth: true
        }
        MouseArea {
            id: tbArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) tb.modelData.secondaryActivate();
                else if (mouse.button === Qt.RightButton) {
                    if (tb.modelData.hasMenu) win.trayMenu(tb.modelData); else tb.modelData.secondaryActivate();
                } else if (tb.modelData.onlyMenu && tb.modelData.hasMenu) win.trayMenu(tb.modelData);
                else tb.modelData.activate();
            }
            onWheel: wheel => tb.modelData.scroll(wheel.angleDelta.y, false)
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

            // Bandeja del sistema (apps en segundo plano)
            Repeater {
                model: SystemTray.items
                delegate: TrayButton {}
            }

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
                name: "notifications"
                onClicked: win.toggled(name)
                Item {
                    width: 20; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    BarGlyph {
                        anchors.centerIn: parent
                        text: NotificationCenter.dnd ? "\uf1f6" : "\uf0f3"
                        color: NotificationCenter.dnd ? Theme.warn : Theme.text
                    }
                    // Contador de no leidas
                    Rectangle {
                        visible: NotificationCenter.unread > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -4
                        anchors.rightMargin: -6
                        height: 13
                        width: Math.max(13, badgeText.implicitWidth + 6)
                        radius: 7
                        color: Theme.urgent
                        scale: NotificationCenter.unread > 0 ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 3 } }
                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: NotificationCenter.unread > 9 ? "9+" : NotificationCenter.unread
                            color: "white"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }
                    }
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
