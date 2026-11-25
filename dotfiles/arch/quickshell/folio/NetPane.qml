import QtQuick
import Quickshell
import Quickshell.Networking

Pane {
    id: pane
    name: "net"
    property var asking: null
    property var fresh: null
    property string trouble: ""
    readonly property var shown: Net.radio ? Net.nearby.slice(0, 10) : []
    readonly property real gap: 18 * pane.u
    readonly property real sigWidth: Theme.wide("100")
    readonly property real nameCap: Theme.wide("M".repeat(26))
    function span(words): real {
        return words.reduce((w, s) => w + Theme.wide(s), 0) + gap * (words.length - 1);
    }
    property Hold names: Hold {
        open: pane.open
        want: Math.min(pane.nameCap, Math.max(0, ...pane.shown.map(n => Theme.wide("→ " + n.name))))
    }
    readonly property real nameWidth: names.value
    readonly property real wordWidth: Math.max(...["open", "wpa", "wpa2", "wpa3", "wep", "eap", "?"].map(w => Theme.wide(w)))
    readonly property real actWidth: Math.max(span(["saved", "…", "forget"]), span(["…", "leave"]))
    readonly property real portWidth: Math.min(nameCap, Math.max(0, ...Net.wired.map(d => Theme.wide(d.name))))
    readonly property real core: sigWidth + gap + nameWidth + gap + wordWidth
    onOpenChanged: {
        Net.scan(open);
        Vpn.watching = open;
        if (!open) {
            asking = null;
            fresh = null;
            trouble = "";
        }
    }
    function choose(n): void {
        if (n.connected)
            return;
        trouble = "";
        if (n.known || Net.open(n))
            n.connect();
        else if (Net.keyed(n))
            asking = n;
        else
            Net.settings();
    }
    function join(n, key: string): void {
        if (key.length < 8 || key.length > 63) {
            trouble = "wpa passwords are 8 to 63 characters";
            return;
        }
        if (!n.known)
            fresh = n;
        n.connectWithPsk(key);
        asking = null;
    }
    Column {
        spacing: 14 * pane.u
        Row {
            spacing: 18 * pane.u
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                lit: Net.radio
                text: "wifi"
            }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                on: Net.radio
                onFlipped: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                lit: false
                text: Net.wifi && Net.wifi.scannerEnabled ? "looking" : ""
            }
        }
        Small {
            screen: pane.screen
            lit: false
            width: Math.min(implicitWidth, pane.sigWidth + pane.gap + pane.nameCap)
            elide: Text.ElideRight
            text: Net.cable ? "wired · " + Net.cable.name : Net.here ? "on " + Net.here.name : (Net.radio ? "not connected" : "wifi is off")
        }
        Repeater {
            model: pane.shown
            Column {
                id: row
                required property var modelData
                readonly property bool asked: pane.asking === modelData
                spacing: 8 * pane.u
                Connections {
                    target: row.modelData
                    function onConnectionFailed(reason) {
                        pane.trouble = Net.reason(reason);
                        if (pane.fresh === row.modelData) {
                            row.modelData.forget();
                            pane.fresh = null;
                        }
                        if (reason === ConnectionFailReason.NoSecrets && Net.keyed(row.modelData))
                            pane.asking = row.modelData;
                    }
                    function onConnectedChanged() {
                        if (row.modelData.connected && pane.fresh === row.modelData)
                            pane.fresh = null;
                    }
                }
                Row {
                    spacing: pane.gap
                    Small {
                        screen: pane.screen
                        width: pane.sigWidth
                        horizontalAlignment: Text.AlignRight
                        lit: false
                        text: Math.round(row.modelData.signalStrength * 100)
                    }
                    Small {
                        screen: pane.screen
                        width: pane.nameWidth
                        elide: Text.ElideRight
                        link: !row.modelData.connected
                        lit: row.modelData.connected || row.asked
                        text: (row.modelData.connected ? "→ " : "") + row.modelData.name
                        onPressed: pane.choose(row.modelData)
                    }
                    Small {
                        screen: pane.screen
                        width: pane.wordWidth
                        lit: false
                        text: Net.word(row.modelData)
                    }
                    Row {
                        width: pane.actWidth
                        spacing: pane.gap
                        Small {
                            screen: pane.screen
                            visible: row.modelData.known && !row.modelData.connected
                            lit: false
                            text: "saved"
                        }
                        Small {
                            screen: pane.screen
                            visible: row.modelData.stateChanging
                            text: "…"
                        }
                        Small {
                            screen: pane.screen
                            visible: row.modelData.connected
                            link: true
                            text: "leave"
                            onPressed: row.modelData.disconnect()
                        }
                        Small {
                            screen: pane.screen
                            visible: row.modelData.known && !row.modelData.connected
                            link: true
                            lit: false
                            text: "forget"
                            onPressed: row.modelData.forget()
                        }
                    }
                }
                Row {
                    visible: row.asked
                    leftPadding: pane.sigWidth + pane.gap
                    spacing: 18 * pane.u
                    Item {
                        width: Math.max(pane.nameWidth, Theme.wide("M".repeat(16)))
                        height: key.implicitHeight
                        TextInput {
                            id: key
                            width: parent.width
                            echoMode: TextInput.Password
                            color: Theme.fg
                            selectionColor: Theme.fg
                            selectedTextColor: Theme.bg
                            font.family: Theme.mono
                            font.pixelSize: Theme.small(pane.screen)
                            cursorDelegate: Rectangle {
                                width: Math.max(2, 3 * pane.u)
                                color: Theme.signal
                                visible: key.activeFocus
                            }
                            onVisibleChanged: if (visible) {
                                text = "";
                                forceActiveFocus();
                            }
                            onAccepted: pane.join(row.modelData, text)
                            Keys.onEscapePressed: pane.asking = null
                        }
                        Rectangle {
                            anchors.top: parent.bottom
                            anchors.topMargin: -2 * pane.u
                            width: parent.width
                            height: 1
                            color: Theme.fg
                        }
                    }
                    Small {
                        screen: pane.screen
                        link: true
                        text: "join"
                        onPressed: pane.join(row.modelData, key.text)
                    }
                    Small {
                        screen: pane.screen
                        link: true
                        lit: false
                        text: "cancel"
                        onPressed: pane.asking = null
                    }
                }
            }
        }
        Small {
            screen: pane.screen
            visible: Net.wired.length > 0 && !Net.wired.some(d => d.hasLink)
            lit: false
            text: "wired · no cable"
        }
        Repeater {
            model: Net.wired.some(d => d.hasLink) ? Net.wired : []
            Row {
                id: port
                required property var modelData
                spacing: 18 * pane.u
                Small {
                    screen: pane.screen
                    width: pane.portWidth
                    elide: Text.ElideRight
                    lit: port.modelData.connected
                    text: port.modelData.name
                }
                Small {
                    screen: pane.screen
                    lit: false
                    text: port.modelData.hasLink ? (port.modelData.connected ? port.modelData.linkSpeed + " mb/s" : "idle") : "no cable"
                }
                Small {
                    screen: pane.screen
                    visible: port.modelData.hasLink && !port.modelData.connected && port.modelData.network
                    link: true
                    text: "connect"
                    onPressed: port.modelData.network.connect()
                }
            }
        }
        Small {
            screen: pane.screen
            topPadding: 6 * pane.u
            lit: Vpn.tsOn || Vpn.tunnels.some(t => t.active)
            text: "vpn"
        }
        Row {
            visible: Vpn.tsState !== "missing"
            spacing: pane.gap
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                width: pane.portWidth > 0 ? Math.max(pane.portWidth, Theme.wide("tailscale")) : Theme.wide("tailscale")
                lit: Vpn.tsOn
                text: "tailscale"
            }
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                on: Vpn.tsOn
                busy: Vpn.tsBusy
                onFlipped: Vpn.tailscale(!Vpn.tsOn)
            }
            Small {
                anchors.verticalCenter: parent.verticalCenter
                screen: pane.screen
                link: Vpn.tsState === "NeedsLogin"
                lit: Vpn.tsState === "NeedsLogin"
                text: Vpn.tsWord
                onPressed: Vpn.tailscale(true)
            }
        }
        Repeater {
            model: Vpn.tunnels
            Row {
                id: tunnel
                required property var modelData
                readonly property bool working: Vpn.busy[modelData.uuid] === true
                spacing: pane.gap
                Small {
                    screen: pane.screen
                    width: Math.min(implicitWidth, pane.nameCap)
                    elide: Text.ElideRight
                    link: true
                    lit: tunnel.modelData.active
                    text: (tunnel.modelData.active ? "→ " : "") + tunnel.modelData.name
                    onPressed: Vpn.toggle(tunnel.modelData)
                }
                Small {
                    screen: pane.screen
                    lit: false
                    text: tunnel.modelData.kind
                }
                Small {
                    screen: pane.screen
                    link: !tunnel.working
                    lit: tunnel.working || !tunnel.modelData.active
                    text: tunnel.working ? "…" : tunnel.modelData.active ? "leave" : "connect"
                    onPressed: Vpn.toggle(tunnel.modelData)
                }
            }
        }
        Small {
            screen: pane.screen
            visible: Vpn.tsState === "missing" && Vpn.tunnels.length === 0
            lit: false
            text: "no tunnels yet"
        }
        Small {
            screen: pane.screen
            visible: Vpn.trouble.length > 0
            color: Theme.signal
            width: Math.min(implicitWidth, Math.max(pane.core, Theme.wide("M".repeat(20))))
            wrapMode: Text.WordWrap
            text: Vpn.trouble
        }
        Small {
            screen: pane.screen
            visible: pane.trouble.length > 0
            color: Theme.signal
            width: Math.min(implicitWidth, Math.max(pane.core, Theme.wide("M".repeat(20))))
            wrapMode: Text.WordWrap
            text: pane.trouble
        }
        Row {
            spacing: 38 * pane.u
            Small {
                screen: pane.screen
                link: true
                lit: false
                text: "add vpn…"
                onPressed: Vpn.add()
            }
            Small {
                screen: pane.screen
                link: true
                lit: false
                text: "more settings…"
                onPressed: Net.settings()
            }
        }
    }
}
