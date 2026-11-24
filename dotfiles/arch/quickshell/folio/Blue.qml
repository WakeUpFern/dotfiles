pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// BlueZ as folio reads it. Pairing that needs a PIN is confirmed by blueman-applet's agent.
QtObject {
    id: blue
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var all: adapter ? adapter.devices.values : []
    function named(d): bool {
        return d.name.length > 0 && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name);
    }
    readonly property var paired: all.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var nearby: all.filter(d => !d.paired && !d.bonded && named(d))
    readonly property int linked: all.filter(d => d.connected).length
    readonly property string label: !on ? "bt off" : (linked > 0 ? "bt " + linked : "bt")
    property bool looking: false
    function scan(want: bool): void {
        if (!adapter || !adapter.enabled) {
            looking = false;
            return;
        }
        if (want || looking)
            adapter.discovering = want;
        looking = want;
    }
    property Timer stopper: Timer {
        interval: 30000
        running: blue.looking
        onTriggered: blue.scan(false)
    }
    function settings(): void {
        Quickshell.execDetached(["blueman-manager"]);
        ShellState.closePanel();
    }
}
