import QtQuick
import QtQuick.Layouts
import Quickshell

// Pagina de VPN: perfiles de NetworkManager (vpn / wireguard) y Tailscale, cada uno con su interruptor.
ColumnLayout {
    id: root
    spacing: 8

    Component.onCompleted: { NetworkState.error = ""; NetworkState.refresh(); }

    Repeater {
        model: NetworkState.vpns
        delegate: HoverRow {
            id: row
            required property var modelData
            readonly property bool working: NetworkState.busy === modelData.id
            Layout.fillWidth: true
            height: 44
            highlighted: modelData.active
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10
                UiGlyph { text: ""; font.pixelSize: 14; Layout.preferredWidth: 22; color: row.modelData.active ? Theme.accent : Theme.textDim }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    UiLabel { Layout.fillWidth: true; text: row.modelData.name; elide: Text.ElideRight; color: row.modelData.active ? Theme.text : Theme.textDim }
                    UiLabel {
                        text: row.working ? "Conectando…" : (row.modelData.active ? "Conectada" : "Desconectada")
                        color: row.working ? Theme.accent : Theme.textDim
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
                ToggleSwitch {
                    checked: row.modelData.active
                    onToggled: NetworkState.toggleVpn(row.modelData)
                }
            }
        }
    }

    UiLabel {
        visible: NetworkState.vpns.length === 0
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.textDim
        text: "No hay VPN configuradas. Importa un perfil WireGuard con\nnmcli connection import type wireguard file ~/mi.conf\n(para OpenVPN instala network-manager-openvpn)."
        font.pixelSize: Theme.fontSize - 1
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
