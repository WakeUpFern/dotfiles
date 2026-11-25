pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The tunnels folio can switch: Tailscale (through its CLI, which needs this user set as
// operator: `sudo tailscale set --operator=$USER`) and NetworkManager's VPN and WireGuard
// connections (through nmcli). Read on demand and every few seconds while `watching`.
QtObject {
    id: vpn
    property bool watching: false
    property string trouble: ""

    // Tailscale: "missing" (no CLI), "down" (no daemon), or tailscaled's BackendState
    // ("Running", "Stopped", "NeedsLogin", "Starting", "NeedsMachineAuth", ...).
    property string tsState: "missing"
    property string tsAddress: ""
    property string tsTailnet: ""
    property int tsPeers: 0
    property bool tsBusy: false
    readonly property bool tsOn: tsState === "Running"
    readonly property string tsWord: tsBusy ? "…" : tsState === "missing" ? "not installed" : tsState === "down" ? "daemon off" : tsState === "Running" ? tsAddress + (tsPeers > 0 ? " · " + tsPeers + " up" : "") : tsState === "NeedsLogin" ? "log in" : tsState === "NeedsMachineAuth" ? "awaiting approval" : tsState === "Starting" ? "starting" : "off"

    // NetworkManager tunnels: [{ name, uuid, kind, active }]
    property var tunnels: []
    property var busy: ({})

    function refresh(): void {
        if (vpn.tsState === "missing") {
            if (!tsProbe.running)
                tsProbe.running = true;
        } else if (!tsQuery.running)
            tsQuery.running = true;
        if (!nmQuery.running)
            nmQuery.running = true;
    }
    onWatchingChanged: {
        trouble = "";
        if (watching)
            refresh();
    }
    property Timer tick: Timer {
        interval: 3000
        repeat: true
        running: vpn.watching
        onTriggered: vpn.refresh()
    }

    // nmcli -t escapes ":" and "\" inside fields with a backslash.
    function fields(line: string): var {
        const out = [""];
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length)
                out[out.length - 1] += line[++i];
            else if (c === ":")
                out.push("");
            else
                out[out.length - 1] += c;
        }
        return out;
    }

    property Process tsQuery: Process {
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    return;
                try {
                    const s = JSON.parse(text);
                    vpn.tsState = s.BackendState || "Stopped";
                    vpn.tsAddress = (s.Self && s.Self.TailscaleIPs || []).find(a => a.indexOf(":") < 0) || "";
                    vpn.tsTailnet = s.CurrentTailnet ? s.CurrentTailnet.Name : "";
                    vpn.tsPeers = Object.values(s.Peer || {}).filter(p => p.Online).length;
                } catch (error) {
                    vpn.tsState = "down";
                }
            }
        }
        onExited: (code, status) => {
            if (code === 127 || status === Process.Crashed)
                vpn.tsState = "missing";
            else if (code !== 0)
                vpn.tsState = "down";
        }
    }
    property Process tsProbe: Process {
        command: ["sh", "-c", "command -v tailscale"]
        running: true
        onExited: code => {
            if (code === 0) {
                vpn.tsState = "down";
                vpn.tsQuery.running = true;
            }
        }
    }

    // `tailscale up` blocks until login finishes and prints the login URL on stderr; open it.
    property Process tsSwitch: Process {
        stderr: SplitParser {
            onRead: line => {
                const url = line.match(/https:\/\/login\.tailscale\.com\/\S+/);
                if (url)
                    Quickshell.execDetached(["xdg-open", url[0]]);
                else if (/access denied|permission|operator/i.test(line))
                    vpn.trouble = "tailscale needs: sudo tailscale set --operator=$USER";
                else if (/failed to connect|tailscaled/i.test(line))
                    vpn.trouble = "tailscaled is not running";
            }
        }
        onExited: {
            vpn.tsBusy = false;
            vpn.refresh();
        }
    }
    function tailscale(on: bool): void {
        if (tsSwitch.running || tsState === "missing")
            return;
        trouble = "";
        tsBusy = true;
        tsSwitch.command = ["tailscale", on ? "up" : "down"];
        tsSwitch.running = true;
    }

    property Process nmQuery: Process {
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = text.split("\n").filter(l => l.length > 0).map(l => vpn.fields(l)).filter(f => f[2] === "vpn" || f[2] === "wireguard").map(f => ({
                            name: f[0],
                            uuid: f[1],
                            kind: f[2] === "wireguard" ? "wg" : "vpn",
                            active: f[3] === "yes"
                        })).sort((a, b) => (b.active - a.active) || a.name.localeCompare(b.name));
                if (JSON.stringify(next) !== JSON.stringify(vpn.tunnels))
                    vpn.tunnels = next;
            }
        }
    }
    property Component nmSwitch: Component {
        Process {
            id: job
            property string uuid
            property string label
            stderr: StdioCollector {
                onStreamFinished: {
                    const msg = text.trim().split("\n").pop() || "";
                    if (msg.length > 0 && job.exitCode !== 0)
                        vpn.trouble = job.label + ": " + msg.replace(/^Error:\s*/i, "").toLowerCase();
                }
            }
            onExited: {
                const b = Object.assign({}, vpn.busy);
                delete b[uuid];
                vpn.busy = b;
                vpn.refresh();
                destroy();
            }
        }
    }
    function toggle(t): void {
        if (busy[t.uuid])
            return;
        trouble = "";
        const b = Object.assign({}, busy);
        b[t.uuid] = true;
        busy = b;
        const job = nmSwitch.createObject(vpn, {
            uuid: t.uuid,
            label: t.name,
            command: ["nmcli", "--wait", "30", "connection", t.active ? "down" : "up", "uuid", t.uuid]
        });
        job.running = true;
    }
    // NetworkManager's own dialog: pick VPN (OpenVPN, ...), WireGuard, or import a saved file.
    function add(): void {
        Quickshell.execDetached(["nm-connection-editor", "--create"]);
        ShellState.closePanel();
    }
}
