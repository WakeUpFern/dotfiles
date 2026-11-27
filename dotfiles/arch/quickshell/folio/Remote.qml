pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The computers Moonlight has paired with (read from Moonlight's own settings) and whether
// their Sunshine answers. Each host is asked for /serverinfo on its LAN address first, then
// on its Tailscale address; the first that answers with the paired uuid is the route, so the
// same row works at home and away. Probed while something shows it: the launcher, the
// network pane, or a page that says it is watching.
QtObject {
    id: remote
    property var watchers: ({})
    readonly property bool watching: ShellState.asking || ShellState.panel === "net" || Object.keys(watchers).length > 0
    function watch(key: string, on: bool): void {
        if (on === (watchers[key] === true))
            return;
        const next = Object.assign({}, watchers);
        if (on)
            next[key] = true;
        else
            delete next[key];
        watchers = next;
    }

    // [{ uuid, name, lan, manual, apps: [{ id, name }] }]
    property var paired: []
    // lowercased Tailscale host name -> its IPv4 address
    property var peers: ({})
    // uuid -> { address, ms, tailscale, game }, or absent when nothing answered
    property var seen: ({})
    // a Moonlight client runs on this machine
    property bool client: false
    // uuid -> "stream" | "leave" while that is under way
    property var busy: ({})
    property string trouble: ""
    // { address, pin } while a pairing waits for the PIN to be typed into Sunshine
    property var pairing: null

    readonly property var hosts: paired.map(h => {
        const s = seen[h.uuid] ?? null;
        const app = s ? h.apps.find(a => a.id === s.game) : null;
        return {
            uuid: h.uuid,
            name: h.name,
            apps: h.apps,
            awake: s !== null,
            ms: s ? s.ms : 0,
            tailscale: s ? s.tailscale : false,
            address: s ? s.address : (h.manual || h.lan || h.name),
            running: s && s.game !== 0 ? (app ? app.name : "an app") : "",
            streaming: remote.client && s !== null && s.game !== 0,
            busy: remote.busy[h.uuid] ?? ""
        };
    })
    readonly property bool streaming: hosts.some(h => h.streaming)
    function host(uuid: string): var {
        return hosts.find(h => h.uuid === uuid) ?? null;
    }
    function word(h): string {
        if (h.busy === "stream")
            return "starting…";
        if (h.busy === "leave")
            return "leaving…";
        if (!h.awake)
            return "not answering";
        return (h.streaming ? "streaming " + h.running.toLowerCase() + " · " : "") + h.ms + " ms" + (h.tailscale ? " · tailscale" : "");
    }

    // QSettings INI: [hosts] holds keys like 1\hostname and 1\apps\2\name; values with
    // commas or quotes are wrapped in double quotes.
    function unquote(v: string): string {
        if (v.length >= 2 && v[0] === '"' && v[v.length - 1] === '"')
            return v.slice(1, -1).replace(/\\(["\\])/g, "$1");
        return v;
    }
    function parse(text: string): var {
        const found = {};
        let section = "";
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("[")) {
                section = line.slice(1, -1);
                continue;
            }
            const eq = line.indexOf("=");
            if (section !== "hosts" || eq < 0)
                continue;
            const key = line.slice(0, eq).split("\\");
            const value = unquote(line.slice(eq + 1));
            if (!/^\d+$/.test(key[0]))
                continue;
            const h = found[key[0]] || (found[key[0]] = { apps: {} });
            if (key[1] === "apps" && key.length === 4 && /^\d+$/.test(key[2])) {
                const a = h.apps[key[2]] || (h.apps[key[2]] = {});
                a[key[3]] = value;
            } else if (key.length === 2) {
                h[key[1]] = value;
            }
        }
        function at(address, port) {
            return address && address.length > 0 ? address + (port && port !== "0" && port !== "47989" ? ":" + port : "") : "";
        }
        return Object.keys(found).sort((a, b) => a - b).map(k => found[k]).filter(h => h.uuid && h.hostname).map(h => ({
                    uuid: h.uuid,
                    name: h.hostname,
                    lan: at(h.localaddress, h.localport),
                    manual: at(h.manualaddress, h.manualport),
                    apps: Object.keys(h.apps).sort((a, b) => a - b).map(k => h.apps[k]).filter(a => a.name && a.hidden !== "true").map(a => ({
                                id: Number(a.id),
                                name: a.name
                            }))
                }));
    }
    property FileView settings: FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/Moonlight Game Streaming Project/Moonlight.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const next = remote.parse(text());
            if (JSON.stringify(next) !== JSON.stringify(remote.paired)) {
                remote.paired = next;
                remote.refresh();
            }
        }
        onLoadFailed: remote.paired = []
    }

    function refresh(): void {
        if (!clientQuery.running)
            clientQuery.running = true;
        if (!peerQuery.running)
            peerQuery.running = true;
        if (!mouseQuery.running && !mouseSwitch.running)
            mouseQuery.running = true;
    }

    // The mouse lent over VirtualHere: its server (virtualhere.service, started on demand,
    // allowed by a polkit rule) shares the one device in /etc/virtualhere/mouse.ini, and a
    // client that set "auto-use" takes it. While a client has it, the kernel's usbhid lets go.
    // "missing" (no server installed) | "off" | "waiting" (shared, no one took it) |
    // "lent" (a client has it) | "unplugged" (shared, but the mouse is not here)
    property string mouse: "missing"
    property bool mouseBusy: false
    readonly property bool mouseShared: mouse === "waiting" || mouse === "lent" || mouse === "unplugged"
    readonly property string mouseWord: mouseBusy ? "…" : mouse === "off" ? "here" : mouse === "waiting" ? "shared · waiting for a pc" : mouse === "lent" ? "with " + (hosts.find(h => h.awake)?.name ?? "the other pc") : mouse === "unplugged" ? "shared · not plugged in" : ""
    property string mouseId: ""
    property FileView mouseConfig: FileView {
        path: "/etc/virtualhere/mouse.ini"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^\s*AllowedDevices\s*=\s*([0-9a-fA-F]+)\/([0-9a-fA-F]+)/mi);
            remote.mouseId = m ? m[1].toLowerCase().padStart(4, "0") + ":" + m[2].toLowerCase().padStart(4, "0") : "";
        }
    }
    readonly property string mouseScript: 'load=$(systemctl show -p LoadState --value virtualhere.service); [ "$load" = loaded ] || { echo missing; exit 0; }; systemctl -q is-active virtualhere.service || { echo off; exit 0; }; [ -n "$1" ] || { echo waiting; exit 0; }; dev=unplugged; for d in /sys/bus/usb/devices/*; do [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = "$1" ] || continue; dev=lent; for i in "$d"/*:*/driver; do [ "$(basename "$(readlink "$i")")" = usbhid ] && dev=waiting; done; done; echo $dev'
    property Process mouseQuery: Process {
        command: ["sh", "-c", remote.mouseScript, "folio-mouse", remote.mouseId]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (s.length > 0)
                    remote.mouse = s;
            }
        }
    }
    property Process mouseSwitch: Process {
        stderr: StdioCollector {
            id: mouseSaid
        }
        onExited: code => {
            const msg = mouseSaid.text.trim().split("\n").pop() || "";
            if (code !== 0)
                remote.trouble = /auth|polkit|access denied/i.test(msg) ? "the mouse needs the folio polkit rule (run the system profile)" : "mouse: " + (msg.length > 0 ? msg.toLowerCase() : "could not switch");
            remote.mouseBusy = false;
            remote.refresh();
        }
    }
    // Stopping the server hands the mouse back here even if a client still holds it.
    function lend(on: bool): void {
        if (mouseSwitch.running || mouse === "missing")
            return;
        trouble = "";
        mouseBusy = true;
        mouseSwitch.command = ["systemctl", "--no-ask-password", on ? "start" : "stop", "virtualhere.service"];
        mouseSwitch.running = true;
    }
    onWatchingChanged: {
        if (pairing === null)
            trouble = "";
        if (watching)
            refresh();
    }
    property Timer tick: Timer {
        interval: 4000
        repeat: true
        running: remote.watching
        onTriggered: remote.refresh()
    }

    property Process clientQuery: Process {
        command: ["pgrep", "-x", "moonlight"]
        onExited: code => remote.client = code === 0
    }
    property Process peerQuery: Process {
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                try {
                    const s = JSON.parse(text);
                    for (const p of Object.values(s.Peer || {})) {
                        const ip = (p.TailscaleIPs || []).find(a => a.indexOf(":") < 0);
                        if (ip && p.HostName)
                            next[p.HostName.toLowerCase()] = ip;
                    }
                } catch (error) {}
                remote.peers = next;
            }
        }
        // With or without Tailscale, the LAN and saved addresses still get asked.
        onExited: remote.probeAll()
    }

    // $1 is the paired uuid, the rest are host:port to try in order. Prints the address
    // that answered, Sunshine's serverinfo, and the time it took.
    readonly property string probeScript: 'id=$1; shift; for a in "$@"; do out=$(curl -sf -m 1.5 -w "\\n%{time_total}" "http://$a/serverinfo") || continue; case $out in *"<uniqueid>$id</uniqueid>"*) printf "%s\\n%s\\n" "$a" "$out"; exit 0;; esac; done; exit 1'
    function routes(h): var {
        const ts = peers[h.name.toLowerCase()];
        const all = [h.lan, h.manual, ts ? ts + ":47989" : ""].filter(a => a.length > 0).map(a => a.indexOf(":") < 0 ? a + ":47989" : a);
        return all.filter((a, i) => all.indexOf(a) === i);
    }
    property var probing: ({})
    function probeAll(): void {
        for (const h of paired) {
            if (probing[h.uuid])
                continue;
            const to = routes(h);
            if (to.length === 0)
                continue;
            const p = Object.assign({}, probing);
            p[h.uuid] = true;
            probing = p;
            probe.createObject(remote, {
                uuid: h.uuid,
                tailscaleAt: peers[h.name.toLowerCase()] || "",
                command: ["sh", "-c", probeScript, "folio-remote", h.uuid].concat(to)
            }).running = true;
        }
    }
    function note(uuid: string, s): void {
        const next = Object.assign({}, seen);
        if (s)
            next[uuid] = s;
        else
            delete next[uuid];
        if (JSON.stringify(next) !== JSON.stringify(seen))
            seen = next;
    }
    property Component probe: Component {
        Process {
            id: job
            property string uuid
            property string tailscaleAt
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    if (lines.length < 3)
                        return;
                    const xml = lines.slice(1, -1).join("\n");
                    const game = xml.match(/<currentgame>(\d+)<\/currentgame>/);
                    let address = lines[0].replace(/:47989$/, "");
                    remote.note(job.uuid, {
                        address: address,
                        ms: Math.max(1, Math.round(Number(lines[lines.length - 1]) * 1000)),
                        tailscale: job.tailscaleAt.length > 0 && address.split(":")[0] === job.tailscaleAt,
                        game: game ? Number(game[1]) : 0
                    });
                }
            }
            onExited: code => {
                if (code !== 0)
                    remote.note(job.uuid, null);
                const p = Object.assign({}, remote.probing);
                delete p[job.uuid];
                remote.probing = p;
                remote.settle(job.uuid);
                destroy();
            }
        }
    }

    function mark(uuid: string, what: string): void {
        const next = Object.assign({}, busy);
        if (what.length > 0)
            next[uuid] = what;
        else
            delete next[uuid];
        busy = next;
    }
    // A start or leave is done once the probe sees it happen, or after a while regardless.
    property var since: ({})
    function settle(uuid: string): void {
        const what = busy[uuid];
        if (!what)
            return;
        const h = host(uuid);
        const done = what === "stream" ? (h && h.streaming) : (!h || !h.streaming);
        if (done || Date.now() - (since[uuid] || 0) > 20000)
            mark(uuid, "");
    }

    // The stream gets a scope of its own so restarting the shell does not end it.
    function stream(uuid: string, app: string): void {
        const h = host(uuid);
        if (!h || h.busy.length > 0)
            return;
        trouble = "";
        since[uuid] = Date.now();
        mark(uuid, "stream");
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "moonlight", "stream", h.address, app || "Desktop"]);
        ShellState.closePanel();
        refresh();
    }
    property Component quitJob: Component {
        Process {
            id: job
            property string uuid
            property string label
            stderr: StdioCollector {
                id: said
            }
            onExited: code => {
                const msg = said.text.trim().split("\n").pop() || "";
                if (code !== 0)
                    remote.trouble = job.label + ": " + (msg.length > 0 ? msg.toLowerCase() : "could not quit");
                remote.refresh();
                destroy();
            }
        }
    }
    // Quits the app on the host, which ends the stream here too.
    function leave(uuid: string): void {
        const h = host(uuid);
        if (!h || h.busy.length > 0)
            return;
        trouble = "";
        since[uuid] = Date.now();
        mark(uuid, "leave");
        quitJob.createObject(remote, {
            uuid: uuid,
            label: h.name,
            command: ["moonlight", "quit", h.address]
        }).running = true;
    }

    // Moonlight pairs with a PIN we choose; the person types it on the host's Sunshine page.
    property Process pairJob: Process {
        stderr: StdioCollector {
            id: pairSaid
        }
        onExited: code => {
            const msg = pairSaid.text.trim().split("\n").pop() || "";
            if (code !== 0 && remote.pairing !== null)
                remote.trouble = "pairing failed" + (msg.length > 0 ? ": " + msg.toLowerCase() : "");
            remote.pairing = null;
            remote.settings.reload();
            remote.refresh();
        }
    }
    function pair(address: string): void {
        address = address.trim();
        if (address.length === 0 || pairJob.running)
            return;
        if (!/^[A-Za-z0-9.:\[\]_-]+$/.test(address)) {
            trouble = "that does not look like an address";
            return;
        }
        trouble = "";
        const pin = String(1000 + Math.floor(Math.random() * 9000));
        pairing = {
            address: address,
            pin: pin
        };
        pairJob.command = ["moonlight", "pair", address, "--pin", pin];
        pairJob.running = true;
    }
    function cancelPair(): void {
        if (pairJob.running)
            pairJob.signal(15);
        pairing = null;
    }
    function open(): void {
        Quickshell.execDetached(["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", "moonlight"]);
        ShellState.closePanel();
    }
}
