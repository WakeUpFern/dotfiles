import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth

// Panel que se despliega desde el notch: volumen (+ salida de audio),
// brillo y bateria (+ perfil de energia). `focusTarget` resalta la seccion
// desde la que se abrio.
ColumnLayout {
    id: root

    property string focusTarget: ""      // "volume" | "bluetooth" | "brightness" | "battery"
    signal closeRequested()

    spacing: 16
    focus: true
    Keys.onEscapePressed: root.closeRequested()
    Component.onCompleted: { forceActiveFocus(); BluetoothAudio.refresh(btAudio ? btAudio.name : ""); }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var battery: UPower.displayDevice

    PwObjectTracker { objects: root.sinks }

    // La busqueda de dispositivos gasta bateria: se apaga al cerrar el panel o a los 30 s.
    Timer { interval: 30000; running: root.bt !== null && root.bt.discovering; onTriggered: root.bt.discovering = false }
    Component.onDestruction: if (bt && bt.discovering) bt.discovering = false

    // --- Bluetooth -----------------------------------------------------------
    readonly property var bt: Bluetooth.defaultAdapter
    // Conectados y emparejados primero; mientras se busca, tambien los nuevos con nombre.
    readonly property var btDevices: {
        const a = bt;
        if (!a || !a.enabled) return [];
        // BlueZ pone la direccion MAC como nombre a los dispositivos anonimos: esos no se muestran.
        const isMac = n => /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(n);
        const list = Bluetooth.devices.values.filter(d => d.name !== "" && !isMac(d.name) && (d.paired || d.connected || a.discovering));
        list.sort((x, y) => (y.connected - x.connected) || (y.paired - x.paired) || x.name.localeCompare(y.name));
        return list.slice(0, 4);
    }
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    // Audifonos / altavoz conectado: sus perfiles (calidad / llamadas) se muestran debajo.
    readonly property var btAudio: btConnected.find(d => (d.icon || "").indexOf("audio") === 0) || null
    onBtAudioChanged: BluetoothAudio.refresh(btAudio ? btAudio.name : "")

    function profileLabel(desc) {
        const codec = (desc.match(/codec ([^)]+)\)/) || [])[1] || "";
        if (desc.indexOf("A2DP") >= 0) return "Música · " + codec;
        if (desc.indexOf("HSP/HFP") >= 0) return "Llamadas · " + codec;
        return desc;
    }
    readonly property string btSummary: {
        if (!bt) return "";
        if (!bt.enabled) return "Apagado";
        if (btConnected.length === 0) return bt.discovering ? "Buscando dispositivos…" : "Sin conexiones";
        return btConnected.map(d => d.name + (d.batteryAvailable ? "  " + Math.round(d.battery * 100) + "%" : "")).join("  ·  ");
    }

    // --- helpers -------------------------------------------------------------
    function sectionColor(name) { return focusTarget === name ? Theme.accent : Theme.textDim; }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    readonly property string batteryState: {
        switch (battery.state) {
        case UPowerDeviceState.Charging:     return "Cargando";
        case UPowerDeviceState.Discharging:  return "En bateria";
        case UPowerDeviceState.FullyCharged: return "Completa";
        case UPowerDeviceState.PendingCharge: return "Conectada";
        default: return "";
        }
    }
    readonly property string batteryTime: battery.state === UPowerDeviceState.Charging
        ? formatTime(battery.timeToFull) : formatTime(battery.timeToEmpty)

    // Interruptor con rebote.
    component ToggleSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        implicitWidth: 46
        implicitHeight: 26
        radius: 13
        color: checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.18)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: swArea.pressed ? 24 : 20
            height: 20
            radius: 10
            y: 3
            x: sw.checked ? sw.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }
            Behavior on width { NumberAnimation { duration: 160 } }
        }
        MouseArea { id: swArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    component Glyph: Text {
        color: Theme.text
        font.family: "FontAwesome"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component Label: Text {
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
    }

    // --- Volumen -------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Label {
                text: root.sink && root.sink.audio && root.sink.audio.muted ? "mute" : "vol"
                color: root.sectionColor("volume")
                Layout.preferredWidth: 34
                Behavior on color { ColorAnimation { duration: 200 } }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                }
            }
            Slider {
                Layout.fillWidth: true
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                dimmed: root.sink && root.sink.audio ? root.sink.audio.muted : false
                onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
            }
            Label {
                text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) : "-"
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }

        // Salidas de audio: click para cambiar.
        Repeater {
            model: root.sinks
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool current: root.sink && modelData.id === root.sink.id
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 10
                color: current ? Qt.rgba(1, 1, 1, 0.12) : (rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: (row.current ? "● " : "○ ") + (row.modelData.description || row.modelData.name)
                    color: row.current ? Theme.text : Theme.textDim
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = row.modelData
                }
            }
        }
    }

    // --- Bluetooth -----------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.bt !== null
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Label {
                text: "bt"
                color: root.sectionColor("bluetooth")
                Layout.preferredWidth: 34
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Label {
                Layout.fillWidth: true
                text: root.btSummary
                color: root.btConnected.length > 0 ? Theme.text : Theme.textDim
                elide: Text.ElideRight
            }
            // Buscar dispositivos nuevos
            Rectangle {
                visible: root.bt && root.bt.enabled
                Layout.preferredHeight: 26
                Layout.preferredWidth: scanText.implicitWidth + 24
                radius: 13
                color: root.bt && root.bt.discovering ? Theme.accent : (scanArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                Behavior on color { ColorAnimation { duration: 150 } }
                Label {
                    id: scanText
                    anchors.centerIn: parent
                    text: root.bt && root.bt.discovering ? "Buscando" : "Buscar"
                    color: root.bt && root.bt.discovering ? "#0b1020" : Theme.text
                    font.pixelSize: Theme.fontSize - 1
                }
                MouseArea {
                    id: scanArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.bt.discovering = !root.bt.discovering
                }
            }
            ToggleSwitch {
                checked: root.bt && root.bt.enabled
                onToggled: root.bt.enabled = !root.bt.enabled
            }
        }

        Repeater {
            model: root.btDevices
            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property var d: modelData
                readonly property bool busy: d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting || d.pairing
                property bool connectAfterPair: false

                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 12
                color: d.connected ? Qt.rgba(0.54, 0.71, 1, 0.16) : (devArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }

                function act() {
                    if (busy) return;
                    if (d.connected) d.disconnect();
                    else if (d.paired) d.connect();
                    else { connectAfterPair = true; d.pair(); }
                }
                Connections {
                    target: dev.d
                    function onPairedChanged() {
                        if (dev.d.paired && dev.connectAfterPair) { dev.connectAfterPair = false; dev.d.trusted = true; dev.d.connect(); }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    Glyph {
                        Layout.preferredWidth: 22
                        font.pixelSize: 15
                        color: dev.d.connected ? Theme.accent : Theme.textDim
                        text: dev.d.icon.indexOf("audio") === 0 ? "\uf025"
                            : dev.d.icon.indexOf("keyboard") >= 0 ? "\uf11c"
                            : dev.d.icon.indexOf("phone") >= 0 ? "\uf10b"
                            : dev.d.icon.indexOf("mouse") >= 0 ? "\uf245" : "\uf294"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: dev.d.name
                        color: dev.d.connected ? Theme.text : Theme.textDim
                        elide: Text.ElideRight
                    }
                    Label {
                        text: dev.d.state === BluetoothDeviceState.Connecting ? "Conectando…"
                            : dev.d.state === BluetoothDeviceState.Disconnecting ? "Desconectando…"
                            : dev.d.pairing ? "Emparejando…"
                            : dev.d.connected ? (dev.d.batteryAvailable ? Math.round(dev.d.battery * 100) + "%" : "Conectado")
                            : dev.d.paired ? "" : "Nuevo"
                        color: dev.busy ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                        opacity: dev.busy ? 0.55 + 0.45 * Math.abs(Math.sin(Date.now() / 300)) : 1
                    }
                }
                MouseArea {
                    id: devArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dev.act()
                }
            }
        }
    }

    // --- Perfil del audio Bluetooth ----------------------------------------------
    // "Musica" = A2DP (alta fidelidad, sin microfono); "Llamadas" = HSP/HFP (con microfono, suena peor).
    // SBC-XQ es el A2DP de mayor calidad que ofrece este dispositivo.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.btAudio !== null && BluetoothAudio.profiles.length > 1
        spacing: 6
        Label {
            text: "Calidad del audio"
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: BluetoothAudio.profiles.filter(p => p.name !== "off" && p.available)
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: modelData.index === BluetoothAudio.activeIndex
                    height: 28
                    width: chipLabel.implicitWidth + 24
                    radius: 14
                    color: active ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: chipArea.pressed ? 0.93 : 1
                    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                    Label {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: root.profileLabel(chip.modelData.description)
                        color: chip.active ? "#0b1020" : Theme.text
                        font.pixelSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BluetoothAudio.setProfile(chip.modelData.index)
                    }
                }
            }
        }
    }

    // --- Brillo --------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.available
        spacing: 12
        Label {
            text: "luz"
            color: root.sectionColor("brightness")
            Layout.preferredWidth: 34
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Slider {
            Layout.fillWidth: true
            value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
        Label {
            text: Math.round(Brightness.level * 100)
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    // --- Bateria y perfil de energia ------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.battery.isPresent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "bat"
                color: root.sectionColor("battery")
                Layout.preferredWidth: 34 + 12
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Label {
                Layout.fillWidth: true
                text: Math.round(root.battery.percentage * 100) + "%"
                    + (root.batteryState !== "" ? "  ·  " + root.batteryState : "")
                    + (root.batteryTime !== "" ? "  ·  " + root.batteryTime : "")
                color: root.battery.percentage < 0.2 && root.battery.state !== UPowerDeviceState.Charging ? Theme.urgent : Theme.text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: "Ahorro",      profile: PowerProfile.PowerSaver },
                    { label: "Equilibrado", profile: PowerProfile.Balanced },
                    { label: "Rendimiento", profile: PowerProfile.Performance }
                ].filter(p => p.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: PowerProfiles.profile === modelData.profile
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 15
                    color: active ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    Behavior on color { ColorAnimation { duration: 160 } }
                    scale: chipArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    Label {
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.active ? "#0b1020" : Theme.text
                        font.weight: chip.active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = chip.modelData.profile
                    }
                }
            }
        }
    }
}
