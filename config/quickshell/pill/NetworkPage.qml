import QtQuick
import QtQuick.Layouts
import Quickshell

// Pagina de Red: Wi-Fi (redes, contrasena, red oculta, olvidar) y Ethernet. Todo via NetworkState.
ColumnLayout {
    id: root
    spacing: 10

    property string expanded: ""        // red cuyo campo de contrasena esta abierto
    property string detail: ""          // red conectada cuyos detalles estan abiertos (ahi se desconecta)
    property bool hiddenOpen: false
    property bool hotspotOpen: false

    Component.onCompleted: { NetworkState.error = ""; NetworkState.refresh(); NetworkState.scan(); NetworkState.loadHotspot(); }

    // Interfaces cableadas: las que no tienen cable se resumen en una sola linea.
    readonly property var ethRows: {
        const eth = NetworkState.ethernet;
        const usable = eth.filter(e => e.state !== "unavailable");
        if (usable.length > 0) return usable;
        return eth.length > 0 ? [eth[0]] : [];
    }

    // --- Wi-Fi: interruptor y buscar -----------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: NetworkState.hasWifi
        spacing: 12
        UiGlyph { text: ""; font.pixelSize: 16; Layout.preferredWidth: 22; color: NetworkState.wifiEnabled ? Theme.accent : Theme.textDim }
        UiLabel {
            Layout.fillWidth: true
            text: !NetworkState.wifiEnabled ? "Wi-Fi apagado" : (NetworkState.scanning ? "Buscando redes…" : "Wi-Fi")
            color: NetworkState.wifiEnabled ? Theme.text : Theme.textDim
        }
        Btn {
            visible: NetworkState.wifiEnabled
            primary: false
            label: "Buscar"
            onClicked: NetworkState.scan()
        }
        ToggleSwitch {
            checked: NetworkState.wifiEnabled
            onToggled: NetworkState.setWifiEnabled(!NetworkState.wifiEnabled)
        }
    }

    // --- Redes ------------------------------------------------------------------------------------
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 250)
        visible: NetworkState.hasWifi && NetworkState.wifiEnabled && !NetworkState.hotspotActive && NetworkState.networks.length > 0
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: NetworkState.networks

        delegate: Column {
            id: item
            required property var modelData
            readonly property var n: modelData
            readonly property bool open: root.expanded === n.ssid
            readonly property bool detailOpen: root.detail === n.ssid && n.active
            readonly property bool working: NetworkState.busy === n.ssid
            width: list.width
            spacing: 4

            onOpenChanged: if (open) pw.focusIt()

            HoverRow {
                id: netRow
                width: parent.width
                height: 40
                highlighted: item.n.active
                onClicked: {
                    NetworkState.error = "";
                    if (item.n.active) { root.expanded = ""; root.detail = item.detailOpen ? "" : item.n.ssid; }
                    else if (item.n.known || !item.n.secure) { root.expanded = ""; NetworkState.connectWifi(item.n.ssid, "", false); }
                    else if (item.n.enterprise) NetworkState.error = "Red empresarial: configúrala con nm-connection-editor";
                    else root.expanded = item.open ? "" : item.n.ssid;
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    UiGlyph {
                        text: ""
                        font.pixelSize: 15
                        Layout.preferredWidth: 22
                        color: item.n.active ? Theme.accent : Theme.text
                        opacity: 0.35 + 0.65 * item.n.signal / 100
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: item.n.ssid
                        elide: Text.ElideRight
                        color: item.n.active ? Theme.text : Theme.textDim
                    }
                    UiLabel {
                        visible: netRow.hovered && item.n.known && !item.n.active && !item.working
                        text: "Olvidar"
                        color: Theme.urgent
                        font.pixelSize: Theme.fontSize - 1
                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: NetworkState.forget(item.n.ssid) }
                    }
                    UiLabel {
                        visible: item.working || item.n.active || (item.n.known && !netRow.hovered)
                        text: item.working ? "Conectando…" : (item.n.active ? "Conectado" : "Guardada")
                        color: item.working ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                        opacity: item.working ? 0.55 + 0.45 * Math.abs(Math.sin(Date.now() / 300)) : 1
                    }
                    UiGlyph { visible: item.n.secure; text: ""; font.pixelSize: 12; color: Theme.textDim }
                }
            }

            // Detalles de la red conectada: aqui (y no con un clic suelto) esta Desconectar.
            ColumnLayout {
                visible: item.detailOpen
                width: parent.width
                spacing: 8
                UiLabel {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 1
                    text: "Señal " + item.n.signal + "%  ·  " + (item.n.secure ? item.n.security : "Abierta")
                        + (NetworkState.ips[NetworkState.wifiDevice] ? "  ·  " + NetworkState.ips[NetworkState.wifiDevice] : "")
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    spacing: 8
                    Btn { primary: false; label: "Desconectar"; onClicked: { root.detail = ""; NetworkState.disconnectWifi(); } }
                    Btn { primary: false; tint: Theme.urgent; label: "Olvidar red"; onClicked: { root.detail = ""; NetworkState.forget(item.n.ssid); } }
                }
            }

            // Contrasena de una red nueva
            RowLayout {
                visible: item.open
                width: parent.width
                spacing: 8
                Field {
                    id: pw
                    placeholder: "Contraseña de " + item.n.ssid
                    password: true
                    onAccepted: if (text !== "") { root.expanded = ""; NetworkState.connectWifi(item.n.ssid, text, false); }
                }
                Btn { label: "Conectar"; onClicked: if (pw.text !== "") { root.expanded = ""; NetworkState.connectWifi(item.n.ssid, pw.text, false); } }
            }
        }
    }

    UiLabel {
        visible: NetworkState.hasWifi && NetworkState.wifiEnabled && !NetworkState.hotspotActive && NetworkState.networks.length === 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: NetworkState.scanning ? "Buscando redes…" : "No hay redes a la vista"
        color: Theme.textDim
    }

    // --- Red oculta -----------------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: NetworkState.hasWifi && NetworkState.wifiEnabled && !NetworkState.hotspotActive
        spacing: 8

        HoverRow {
            Layout.fillWidth: true
            height: 36
            onClicked: { root.hiddenOpen = !root.hiddenOpen; if (root.hiddenOpen) hiddenSsid.focusIt(); }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                spacing: 10
                UiGlyph { text: root.hiddenOpen ? "" : ""; font.pixelSize: 12; Layout.preferredWidth: 22; color: Theme.textDim }
                UiLabel { text: "Conectar a una red oculta…"; color: Theme.textDim }
            }
        }
        ColumnLayout {
            visible: root.hiddenOpen
            Layout.fillWidth: true
            spacing: 8
            Field { id: hiddenSsid; placeholder: "Nombre de la red (SSID)"; onAccepted: hiddenPw.focusIt() }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Field {
                    id: hiddenPw
                    placeholder: "Contraseña (vacía si es abierta)"
                    password: true
                    onAccepted: root.connectHidden()
                }
                Btn { label: "Conectar"; onClicked: root.connectHidden() }
            }
        }
    }
    function connectHidden() {
        if (hiddenSsid.text.trim() === "") return;
        NetworkState.connectWifi(hiddenSsid.text.trim(), hiddenPw.text, true);
        hiddenOpen = false;
        hiddenPw.text = "";
        hiddenSsid.text = "";
    }

    // --- Punto de acceso ------------------------------------------------------------------------------
    // Comparte la conexion por Wi-Fi (nmcli, perfil "PillHotspot"). Activarlo ocupa la tarjeta Wi-Fi.
    ColumnLayout {
        Layout.fillWidth: true
        visible: NetworkState.hasWifi && NetworkState.wifiEnabled
        spacing: 8

        HoverRow {
            Layout.fillWidth: true
            height: 36
            highlighted: NetworkState.hotspotActive
            onClicked: root.hotspotOpen = !root.hotspotOpen
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 12
                spacing: 10
                UiGlyph { text: "\uf1e0"; font.pixelSize: 14; Layout.preferredWidth: 22; color: NetworkState.hotspotActive ? Theme.accent : Theme.textDim }
                UiLabel {
                    Layout.fillWidth: true
                    text: NetworkState.hotspotActive ? "Punto de acceso activo" : "Compartir conexión (punto de acceso)"
                    color: NetworkState.hotspotActive ? Theme.text : Theme.textDim
                    elide: Text.ElideRight
                }
                UiLabel {
                    visible: NetworkState.busy === NetworkState.hotspotName
                    text: "Un momento…"
                    color: Theme.accent
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }

        ColumnLayout {
            visible: root.hotspotOpen
            Layout.fillWidth: true
            spacing: 8

            // Activo: datos para conectarse y detener
            UiLabel {
                visible: NetworkState.hotspotActive
                Layout.fillWidth: true
                Layout.leftMargin: 10
                color: Theme.textDim
                wrapMode: Text.WordWrap
                text: "Red: " + NetworkState.hotspotSsid + "\nContraseña: " + NetworkState.hotspotPsk
            }
            RowLayout {
                visible: NetworkState.hotspotActive
                Layout.leftMargin: 10
                Btn { primary: false; label: "Detener"; onClicked: NetworkState.stopHotspot() }
            }

            // Inactivo: nombre, contrasena y aviso
            Field { visible: !NetworkState.hotspotActive; placeholder: "Nombre de la red"; text: NetworkState.hotspotSsid; onTextChanged: NetworkState.hotspotSsid = text; id: hsSsid }
            Field { visible: !NetworkState.hotspotActive; placeholder: "Contraseña (8 a 63 caracteres)"; text: NetworkState.hotspotPsk; onTextChanged: NetworkState.hotspotPsk = text; id: hsPsk }
            UiLabel {
                visible: !NetworkState.hotspotActive && NetworkState.wifiSsid !== ""
                Layout.fillWidth: true
                Layout.leftMargin: 10
                wrapMode: Text.WordWrap
                color: Theme.warn
                font.pixelSize: Theme.fontSize - 1
                text: "Al activarlo dejarás de estar conectado a " + NetworkState.wifiSsid + " (la tarjeta Wi-Fi se usa para compartir)."
            }
            RowLayout {
                visible: !NetworkState.hotspotActive
                Layout.leftMargin: 10
                Btn { label: "Activar"; onClicked: NetworkState.startHotspot(NetworkState.hotspotSsid, NetworkState.hotspotPsk) }
            }
        }
    }

    // --- Ethernet ----------------------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.ethRows.length > 0
        spacing: 4

        UiLabel {
            text: "Cableado"
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }
        Repeater {
            model: root.ethRows
            delegate: ColumnLayout {
              id: ethItem
              required property var modelData
              readonly property bool detailOpen: root.detail === "eth:" + modelData.device && modelData.state === "connected"
              Layout.fillWidth: true
              spacing: 4
              HoverRow {
                id: eth
                readonly property var modelData: ethItem.modelData
                readonly property bool connected: modelData.state === "connected"
                readonly property bool noCable: modelData.state === "unavailable"
                readonly property bool working: NetworkState.busy === modelData.device || modelData.state === "connecting"
                Layout.fillWidth: true
                height: 40
                highlighted: connected
                onClicked: {
                    if (noCable) return;
                    if (connected) root.detail = ethItem.detailOpen ? "" : "eth:" + modelData.device;   // desconectar: en los detalles
                    else NetworkState.toggleEthernet(modelData);
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 10
                    UiGlyph { text: ""; font.pixelSize: 15; Layout.preferredWidth: 22; color: eth.connected ? Theme.accent : Theme.textDim }
                    UiLabel {
                        Layout.fillWidth: true
                        text: "Ethernet" + (eth.connected && eth.modelData.connection !== "" ? "  ·  " + eth.modelData.connection : "")
                        elide: Text.ElideRight
                        color: eth.connected ? Theme.text : Theme.textDim
                    }
                    UiLabel {
                        text: eth.working ? "Conectando…" : (eth.noCable ? "Sin cable" : (eth.connected ? "Conectado" : "Desconectado"))
                        color: eth.working ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
              }
              ColumnLayout {
                visible: ethItem.detailOpen
                Layout.fillWidth: true
                spacing: 8
                UiLabel {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 1
                    text: ethItem.modelData.device + (NetworkState.ips[ethItem.modelData.device] ? "  ·  " + NetworkState.ips[ethItem.modelData.device] : "")
                }
                RowLayout {
                    Layout.leftMargin: 10
                    Btn { primary: false; label: "Desconectar"; onClicked: { root.detail = ""; NetworkState.toggleEthernet(ethItem.modelData); } }
                }
              }
            }
        }
    }

    UiLabel {
        visible: NetworkState.error !== ""
        Layout.fillWidth: true
        text: NetworkState.error
        color: Theme.urgent
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSize - 1
    }
}
