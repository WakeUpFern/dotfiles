import QtQuick
import Quickshell
import Quickshell.Bluetooth

Pane {
    id: pane
    name: "bt"
    onOpenChanged: if (!open)
        Blue.scan(false)
    readonly property var shown: (Blue.on ? Blue.paired : []).concat((Blue.adapter?.discovering ?? false) ? Blue.nearby.slice(0, 8) : [])
    readonly property real nameWidth: Math.min(Theme.wide("M".repeat(24)), Math.max(0, ...shown.map(d => Theme.wide((d.connected ? "→ " : "") + d.name))))
    component Device: Row {
        id: dev
        required property var modelData
        property bool wanted: false
        property bool armed: false
        spacing: 18 * pane.u
        Connections {
            target: dev.modelData
            function onPairedChanged() {
                if (dev.modelData.paired && dev.wanted) {
                    dev.wanted = false;
                    dev.modelData.trusted = true;
                    dev.modelData.connect();
                }
            }
        }
        Timer {
            id: disarm
            interval: 3000
            onTriggered: dev.armed = false
        }
        Small {
            screen: pane.screen
            width: pane.nameWidth
            elide: Text.ElideRight
            lit: dev.modelData.connected
            text: (dev.modelData.connected ? "→ " : "") + dev.modelData.name
        }
        Small {
            screen: pane.screen
            visible: dev.modelData.batteryAvailable
            lit: false
            text: "bat " + Math.round(dev.modelData.battery * 100)
        }
        Small {
            screen: pane.screen
            lit: false
            visible: text.length > 0
            text: dev.modelData.pairing ? "pairing…" : dev.modelData.state === BluetoothDeviceState.Connecting ? "connecting…" : dev.modelData.state === BluetoothDeviceState.Disconnecting ? "…" : ""
        }
        Small {
            screen: pane.screen
            visible: dev.modelData.connected
            link: true
            text: "disconnect"
            onPressed: dev.modelData.disconnect()
        }
        Small {
            screen: pane.screen
            visible: dev.modelData.paired && !dev.modelData.connected
            link: true
            text: "connect"
            onPressed: dev.modelData.connect()
        }
        Small {
            screen: pane.screen
            visible: !dev.modelData.paired && !dev.modelData.pairing
            link: true
            text: "pair"
            onPressed: {
                dev.wanted = true;
                dev.modelData.pair();
            }
        }
        Small {
            screen: pane.screen
            visible: dev.modelData.pairing
            link: true
            text: "cancel"
            onPressed: dev.modelData.cancelPair()
        }
        Small {
            screen: pane.screen
            visible: dev.modelData.paired && !dev.modelData.connected
            link: true
            text: dev.armed ? "really forget?" : "forget"
            color: dev.armed ? Theme.signal : Theme.dim
            onPressed: {
                if (dev.armed)
                    dev.modelData.forget();
                else {
                    dev.armed = true;
                    disarm.restart();
                }
            }
        }
    }
    Column {
        spacing: 14 * pane.u
        Small {
            screen: pane.screen
            visible: Blue.adapter === null
            lit: false
            text: "no bluetooth adapter"
        }
        Row {
            visible: Blue.adapter !== null
            spacing: 18 * pane.u
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                lit: Blue.on
                text: "bluetooth"
            }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                on: Blue.on
                busy: Blue.adapter !== null && (Blue.adapter.state === BluetoothAdapterState.Enabling || Blue.adapter.state === BluetoothAdapterState.Disabling)
                onFlipped: if (Blue.adapter)
                    Blue.adapter.enabled = !Blue.adapter.enabled
            }
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                visible: Blue.on
                link: true
                lit: Blue.adapter?.discovering ?? false
                text: (Blue.adapter?.discovering ?? false) ? "stop looking" : "look for devices"
                onPressed: Blue.scan(!Blue.adapter.discovering)
            }
        }
        Small {
            screen: pane.screen
            visible: Blue.adapter !== null && Blue.adapter.state === BluetoothAdapterState.Blocked
            color: Theme.signal
            text: "blocked by rfkill"
        }
        Small {
            screen: pane.screen
            visible: Blue.on
            lit: false
            text: Blue.paired.length ? "paired" : "nothing paired yet"
        }
        Repeater {
            model: Blue.on ? Blue.paired : []
            Device {}
        }
        Small {
            screen: pane.screen
            visible: Blue.adapter?.discovering ?? false
            lit: false
            text: Blue.nearby.length ? "nearby" : "looking…"
        }
        Repeater {
            model: (Blue.adapter?.discovering ?? false) ? Blue.nearby.slice(0, 8) : []
            Device {}
        }
        Small {
            screen: pane.screen
            link: true
            lit: false
            text: "more settings…"
            onPressed: Blue.settings()
        }
    }
}
