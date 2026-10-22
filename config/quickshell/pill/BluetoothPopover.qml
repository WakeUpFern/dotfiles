import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

// Menu de Bluetooth: interruptor, dispositivos, busqueda y calidad del audio.
ColumnLayout {
    id: root
    spacing: 16

    property string detail: ""        // dispositivo conectado cuyos detalles estan abiertos (ahi se desconecta)

    // La busqueda de dispositivos gasta bateria: se apaga al cerrar el menu o a los 30 s.
    Timer { interval: 30000; running: root.bt !== null && root.bt.discovering; onTriggered: root.bt.discovering = false }
    Component.onDestruction: if (bt && bt.discovering) bt.discovering = false
    Component.onCompleted: BluetoothAudio.refresh(btAudio ? btAudio.name : "")

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

    // --- Bluetooth -----------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.bt !== null
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            UiLabel {
                text: "bt"
                color: Theme.textDim
                Layout.preferredWidth: 34
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            UiLabel {
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
                UiLabel {
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
                readonly property bool detailOpen: root.detail === d.address && d.connected

                Layout.fillWidth: true
                Layout.preferredHeight: 38 + (detailOpen ? 46 : 0)
                clip: true
                radius: 12
                color: d.connected ? Qt.rgba(0.54, 0.71, 1, 0.16) : (devArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }

                function act() {
                    if (busy) return;
                    if (d.connected) root.detail = detailOpen ? "" : d.address;     // desconectar: en los detalles
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
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 38
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    UiGlyph {
                        Layout.preferredWidth: 22
                        font.pixelSize: 15
                        color: dev.d.connected ? Theme.accent : Theme.textDim
                        text: dev.d.icon.indexOf("audio") === 0 ? "\uf025"
                            : dev.d.icon.indexOf("keyboard") >= 0 ? "\uf11c"
                            : dev.d.icon.indexOf("phone") >= 0 ? "\uf10b"
                            : dev.d.icon.indexOf("mouse") >= 0 ? "\uf245" : "\uf294"
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: dev.d.name
                        color: dev.d.connected ? Theme.text : Theme.textDim
                        elide: Text.ElideRight
                    }
                    UiLabel {
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
                // Detalles del dispositivo conectado
                Row {
                    visible: dev.detailOpen
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 10
                    UiLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dev.d.batteryAvailable ? "Batería " + Math.round(dev.d.battery * 100) + "%" : "Conectado"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                    Rectangle {
                        width: discText.implicitWidth + 28
                        height: 30
                        radius: 15
                        color: discArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiLabel { id: discText; anchors.centerIn: parent; text: "Desconectar" }
                        MouseArea {
                            id: discArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.detail = ""; dev.d.disconnect(); }
                        }
                    }
                }
                MouseArea {
                    id: devArea
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 38
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
        UiLabel {
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
                    UiLabel {
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

}
