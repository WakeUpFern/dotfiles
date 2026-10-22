import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Panel unificado de ajustes rapidos (como GNOME / Windows 11 / macOS): una sola tarjeta con el
// inicio (bateria, volumen, brillo y tiles) y paginas de detalle a las que se entra con la flecha
// de cada tile: Red (Wi-Fi + Ethernet), Bluetooth, Sonido, VPN y Bateria y energia.
// Las notificaciones, el reloj y la bandeja NO forman parte de este panel.
ColumnLayout {
    id: root
    spacing: 14
    signal closeRequested()

    // Pagina pedida desde fuera (IPC); navegar dentro la cambia sin tocar la pedida.
    property string initialPage: "home"
    property string page: initialPage
    onInitialPageChanged: page = initialPage
    property string shownPage: page
    onPageChanged: if (page !== shownPage) swap.restart()

    readonly property var titles: ({
        network: "Red", bluetooth: "Bluetooth", audio: "Sonido", vpn: "VPN", battery: "Batería y energía"
    })

    SequentialAnimation {
        id: swap
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 80 }
        ScriptAction { script: root.shownPage = root.page }
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: 160 }
    }

    // --- Datos -------------------------------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    PwObjectTracker { objects: [root.sink] }

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt !== null && bt.enabled
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property var battery: UPower.displayDevice
    readonly property string profileName: PowerProfiles.profile === PowerProfile.PowerSaver ? "Ahorro"
        : PowerProfiles.profile === PowerProfile.Performance ? "Rendimiento" : "Equilibrado"

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    // --- Piezas ------------------------------------------------------------------------------
    // Tile estilo GNOME: la parte izquierda activa/desactiva, la flecha abre la pagina.
    component Tile: Rectangle {
        id: t
        property string glyph
        property string title
        property string subtitle
        property bool on: false
        property bool hasMore: false
        signal toggled()
        signal more()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 58
        radius: 18
        color: on ? (mainArea.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                  : (mainArea.containsMouse || moreArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Behavior on color { ColorAnimation { duration: 150 } }
        scale: mainArea.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

        readonly property color fg: on ? "#0b1020" : Theme.text
        readonly property color fgDim: on ? Qt.rgba(0.04, 0.06, 0.13, 0.7) : Theme.textDim

        MouseArea {
            id: mainArea
            anchors.fill: parent
            anchors.rightMargin: t.hasMore ? 38 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: t.toggled()
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: t.hasMore ? 38 : 12
            spacing: 10
            UiGlyph { text: t.glyph; font.pixelSize: 18; Layout.preferredWidth: 24; color: t.fg }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                UiLabel { Layout.fillWidth: true; text: t.title; elide: Text.ElideRight; color: t.fg; font.weight: Font.DemiBold }
                UiLabel { Layout.fillWidth: true; text: t.subtitle; elide: Text.ElideRight; color: t.fgDim; font.pixelSize: Theme.fontSize - 2 }
            }
        }
        Item {
            visible: t.hasMore
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 38
            UiGlyph { anchors.centerIn: parent; text: ""; font.pixelSize: 12; color: t.fgDim }
            MouseArea {
                id: moreArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: t.more()
            }
        }
    }

    // Icono pulsable (silenciar, etc.) a la izquierda de un slider.
    component IconButton: Item {
        id: ib
        property string glyph
        property color tint: Theme.text
        signal clicked()
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        UiGlyph { anchors.centerIn: parent; text: ib.glyph; font.pixelSize: 16; color: ib.tint }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }

    // --- Cabecera de las paginas ---------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: root.shownPage !== "home"
        spacing: 8
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
            UiGlyph { anchors.centerIn: parent; text: ""; font.pixelSize: 12 }
            MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "home" }
        }
        UiLabel {
            Layout.fillWidth: true
            text: root.titles[root.shownPage] || ""
            font.pixelSize: Theme.fontSize + 2
            font.weight: Font.DemiBold
        }
    }

    // --- Contenido ---------------------------------------------------------------------------------
    Loader {
        id: body
        Layout.fillWidth: true
        Layout.preferredHeight: item ? item.implicitHeight : 0
        sourceComponent: root.shownPage === "network" ? networkComp
                       : root.shownPage === "bluetooth" ? bluetoothComp
                       : root.shownPage === "audio" ? audioComp
                       : root.shownPage === "vpn" ? vpnComp
                       : root.shownPage === "battery" ? batteryComp : homeComp
    }
    Component { id: networkComp; NetworkPage {} }
    Component { id: bluetoothComp; BluetoothPopover {} }
    Component { id: audioComp; VolumePopover {} }
    Component { id: vpnComp; VpnPage {} }
    Component { id: batteryComp; BatteryPopover {} }

    // --- Inicio --------------------------------------------------------------------------------------
    Component {
        id: homeComp
        ColumnLayout {
            spacing: 14

            // Bateria
            HoverRow {
                Layout.fillWidth: true
                visible: root.battery.isPresent
                height: 34
                onClicked: root.page = "battery"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    UiGlyph {
                        text: root.battery.state === UPowerDeviceState.Charging ? "" : ""
                        font.pixelSize: 16
                        Layout.preferredWidth: 22
                        color: root.battery.percentage < 0.2 && root.battery.state !== UPowerDeviceState.Charging ? Theme.urgent : Theme.text
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        readonly property bool charging: root.battery.state === UPowerDeviceState.Charging
                        readonly property string time: root.formatTime(charging ? root.battery.timeToFull : root.battery.timeToEmpty)
                        text: Math.round(root.battery.percentage * 100) + "%"
                            + (charging ? "  ·  Cargando" : (root.battery.state === UPowerDeviceState.FullyCharged ? "  ·  Completa" : ""))
                            + (time !== "" ? "  ·  " + time : "")
                        elide: Text.ElideRight
                    }
                    UiGlyph { text: ""; font.pixelSize: 11; color: Theme.textDim }
                }
            }

            // Volumen
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                IconButton {
                    glyph: root.muted || !root.sink || !root.sink.audio || root.sink.audio.volume <= 0.001 ? "" : (root.sink.audio.volume < 0.5 ? "" : "")
                    tint: root.muted ? Theme.textDim : Theme.text
                    onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                    dimmed: root.muted
                    onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
                }
                UiLabel {
                    text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) : "-"
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                Item {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 26
                    UiGlyph { anchors.centerIn: parent; text: ""; font.pixelSize: 12; color: audioMore.containsMouse ? Theme.text : Theme.textDim }
                    MouseArea { id: audioMore; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = "audio" }
                }
            }

            // Brillo
            RowLayout {
                Layout.fillWidth: true
                visible: Brightness.available
                spacing: 12
                IconButton { glyph: "" }
                Slider {
                    Layout.fillWidth: true
                    value: Brightness.level
                    onMoved: v => Brightness.set(v)
                }
                UiLabel {
                    text: Math.round(Brightness.level * 100)
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignRight
                }
                Item { Layout.preferredWidth: 24 }
            }

            // Tiles
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                Tile {
                    glyph: NetworkState.kind === "ethernet" ? "" : ""
                    title: NetworkState.label
                    subtitle: NetworkState.kind === "ethernet" ? "Cable" : (NetworkState.hasWifi ? "Wi-Fi" : "Red")
                    on: NetworkState.kind !== "none"
                    hasMore: true
                    // Conectado: el clic abre los detalles (apagar es un acto deliberado, dentro de la pagina).
                    onToggled: {
                        if (NetworkState.hasWifi && !NetworkState.wifiEnabled) NetworkState.setWifiEnabled(true);
                        else root.page = "network";
                    }
                    onMore: root.page = "network"
                }
                Tile {
                    visible: root.bt !== null
                    glyph: ""
                    title: "Bluetooth"
                    subtitle: !root.btOn ? "Apagado" : (root.btConnected.length > 0 ? root.btConnected[0].name : "Encendido")
                    on: root.btOn
                    hasMore: true
                    // Encendido: el clic abre la pagina (apagar, y con ello cortar audifonos, es deliberado).
                    onToggled: { if (!root.btOn) root.bt.enabled = true; else root.page = "bluetooth"; }
                    onMore: root.page = "bluetooth"
                }
                Tile {
                    visible: NetworkState.vpns.length > 0
                    glyph: ""
                    title: "VPN"
                    subtitle: NetworkState.vpnActive ? NetworkState.vpns.filter(v => v.active).map(v => v.name).join(", ") : "Desconectada"
                    on: NetworkState.vpnActive
                    hasMore: true
                    onToggled: {
                        // Activa: el clic abre la pagina (se apaga con su interruptor); inactiva y unica: la enciende.
                        if (!NetworkState.vpnActive && NetworkState.vpns.length === 1) NetworkState.toggleVpn(NetworkState.vpns[0]);
                        else root.page = "vpn";
                    }
                    onMore: root.page = "vpn"
                }
                Tile {
                    glyph: NotificationCenter.dnd ? "" : ""
                    title: "No molestar"
                    subtitle: NotificationCenter.dnd ? "Activado" : "Desactivado"
                    on: NotificationCenter.dnd
                    onToggled: NotificationCenter.toggleDnd()
                }
                Tile {
                    glyph: "\uf0f4"
                    title: "No suspender"
                    subtitle: Idle.caffeine ? "Pantalla siempre activa" : "Desactivado"
                    on: Idle.caffeine
                    onToggled: Idle.toggleCaffeine()
                }
                Tile {
                    visible: root.battery.isPresent
                    glyph: PowerProfiles.profile === PowerProfile.PowerSaver ? "" : (PowerProfiles.profile === PowerProfile.Performance ? "" : "")
                    title: root.profileName
                    subtitle: "Modo de energía"
                    on: PowerProfiles.profile !== PowerProfile.Balanced
                    onToggled: root.page = "battery"
                }
            }

            // Microfono en uso (como el punto naranja de GNOME)
            HoverRow {
                Layout.fillWidth: true
                visible: AudioStreams.micInUse
                height: 32
                onClicked: root.page = "audio"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    Rectangle { width: 8; height: 8; radius: 4; color: Theme.warn; Layout.preferredWidth: 8 }
                    UiLabel {
                        Layout.fillWidth: true
                        text: "Micrófono en uso: " + AudioStreams.micUsers
                        color: Theme.warn
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
