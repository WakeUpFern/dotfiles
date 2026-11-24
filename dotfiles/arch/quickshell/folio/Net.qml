pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// NetworkManager as folio reads it: the wifi card, the wired ports, what is in use.
QtObject {
    id: net
    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired)
    readonly property bool radio: Networking.wifiEnabled
    readonly property var here: wifi ? (wifi.networks.values.find(n => n.connected) ?? null) : null
    readonly property var cable: wired.find(d => d.connected) ?? null
    readonly property bool online: here !== null || cable !== null
    readonly property var nearby: wifi ? wifi.networks.values.filter(n => n.name.length > 0).sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength)) : []
    readonly property bool doubtful: Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited
    readonly property string label: cable ? "eth" : here ? "wifi " + Math.round(here.signalStrength * 100) + (doubtful ? " ?" : "") : (wifi && !radio ? "wifi off" : "offline")
    function keyed(n): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(n.security);
    }
    function open(n): bool {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }
    function word(n): string {
        switch (n.security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "open";
        case WifiSecurityType.WpaPsk:
            return "wpa";
        case WifiSecurityType.Wpa2Psk:
            return "wpa2";
        case WifiSecurityType.Sae:
            return "wpa3";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
            return "wep";
        case WifiSecurityType.Unknown:
            return "?";
        default:
            return "eap";
        }
    }
    function reason(r): string {
        return r === ConnectionFailReason.NoSecrets ? "that password did not work" : r === ConnectionFailReason.WifiAuthTimeout ? "the network did not answer" : r === ConnectionFailReason.WifiNetworkLost ? "the network went away" : "could not connect";
    }
    function scan(on: bool): void {
        if (wifi)
            wifi.scannerEnabled = on;
    }
    function settings(): void {
        Quickshell.execDetached(["nm-connection-editor"]);
        ShellState.closePanel();
    }
}
