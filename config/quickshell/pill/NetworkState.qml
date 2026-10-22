pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Red: Wi-Fi, Ethernet y VPN, todo via nmcli (NetworkManager) y, si existe, tailscale.
//   Wi-Fi:    encender/apagar, buscar, conectar (con contrasena), red oculta, olvidar, desconectar
//   Ethernet: conectar / desconectar cada interfaz (sin cable = "unavailable")
//   VPN:      perfiles de NetworkManager de tipo vpn (OpenVPN...) y wireguard, y Tailscale
// El estado se refresca con `nmcli monitor` (eventos) y un sondeo lento de respaldo.
Singleton {
    id: root

    // --- Estado ------------------------------------------------------------------------
    property bool hasWifi: false
    property bool wifiEnabled: true
    property string wifiDevice: ""
    property string wifiSsid: ""            // red conectada ("" = ninguna)
    property int wifiSignal: 0              // 0..100 de la red conectada
    property var networks: []               // { ssid, signal, secure, enterprise, known, active }
    property var ethernet: []               // { device, state, connection }
    property var ips: ({})                  // dispositivo -> direccion IPv4 (solo las conectadas)
    property var vpns: []                   // { id, name, kind: "nm" | "ts", active }
    property bool tsAvailable: false
    property bool hotspotActive: false      // el perfil PillHotspot esta activo (la tarjeta Wi-Fi es el punto de acceso)
    property string hotspotSsid: ""
    property string hotspotPsk: ""
    readonly property string hotspotName: "PillHotspot"

    property bool scanning: false
    property string busy: ""                // red / VPN / interfaz que se esta (des)conectando
    property string error: ""

    readonly property bool ethernetConnected: ethernet.some(e => e.state === "connected")
    readonly property string kind: ethernetConnected ? "ethernet" : (wifiSsid !== "" ? "wifi" : (hotspotActive ? "hotspot" : "none"))
    readonly property bool vpnActive: vpns.some(v => v.active)
    readonly property string label: {
        if (ethernetConnected) return "Ethernet";
        if (wifiSsid !== "") return wifiSsid;
        if (hotspotActive) return "Punto de acceso";
        if (hasWifi && !wifiEnabled) return "Wi-Fi apagado";
        return hasWifi || ethernet.length > 0 ? "Sin conexión" : "Sin red";
    }

    function start() { refreshSoon(); monitor.running = true; }

    // --- Ejecutar un comando y recoger (codigo, salida): ver Exec.qml ----------------------------
    function exec(args, cb) { Exec.run(args, cb); }

    // nmcli -t separa con ":" y escapa los ":" y "\" del contenido con "\".
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[++i]; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }
    function rows(out) { return out === "" ? [] : out.split("\n").map(fields); }

    // --- Lectura ---------------------------------------------------------------------------
    property var knownWifi: []

    function refreshSoon() { debounce.restart(); }
    Timer { id: debounce; interval: 250; onTriggered: root.refresh() }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: root.refresh() }

    function refresh() {
        exec(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], (code, out) => {
            if (code !== 0) return;
            const r = rows(out);
            const w = r.find(f => f[1] === "wifi");
            root.hasWifi = !!w;
            root.wifiDevice = w ? w[0] : "";
            root.ethernet = r.filter(f => f[1] === "ethernet" && f[2] !== "unmanaged")
                .map(f => ({ device: f[0], state: f[2], connection: f[3] }));
        });
        exec(["nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "device", "show"], (code, out) => {
            if (code !== 0) return;
            const map = {};
            let dev = "";
            for (const line of out.split("\n")) {
                const i = line.indexOf(":");
                const key = line.slice(0, i), val = line.slice(i + 1);
                if (key === "GENERAL.DEVICE") dev = val;
                else if (key.indexOf("IP4.ADDRESS") === 0 && dev !== "" && !map[dev]) map[dev] = val.replace(/\/\d+$/, "");
            }
            root.ips = map;
        });
        exec(["nmcli", "radio", "wifi"], (code, out) => { if (code === 0) root.wifiEnabled = out === "enabled"; });
        exec(["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"], (code, out) => {
            if (code !== 0) return;
            const r = rows(out);
            root.knownWifi = r.filter(f => f[1] === "802-11-wireless" && f[0] !== root.hotspotName).map(f => f[0]);
            root.hotspotActive = r.some(f => f[0] === root.hotspotName && f[2] === "yes");
            const nm = r.filter(f => f[1] === "vpn" || f[1] === "wireguard")
                .map(f => ({ id: f[0], name: f[0], kind: "nm", active: f[2] === "yes" }));
            root.nmVpns = nm;
            root.rebuildNetworks();
        });
        exec(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"], (code, out) => {
            if (code !== 0 || root.scanning) return;      // durante el escaneo NM devuelve resultados parciales
            root.rawWifi = rows(out);
            root.rebuildNetworks();
        });
        refreshTailscale();
    }

    property var rawWifi: []
    property var nmVpns: []
    property var tsVpn: []

    function rebuildNetworks() {
        const bySsid = {};
        for (const f of rawWifi) {
            const ssid = f[1];
            if (ssid === "") continue;                        // redes ocultas: se agregan a mano
            const sig = parseInt(f[2]) || 0;
            const cur = bySsid[ssid];
            const active = f[0] === "*";
            if (!cur) bySsid[ssid] = { ssid: ssid, signal: sig, security: f[3], secure: f[3] !== "", enterprise: f[3].indexOf("802.1X") >= 0, active: active };
            else {
                cur.signal = Math.max(cur.signal, sig);
                cur.active = cur.active || active;
            }
        }
        const list = Object.values(bySsid).map(n => Object.assign(n, { known: knownWifi.indexOf(n.ssid) >= 0 }));
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
        networks = list;
        const act = list.find(n => n.active);
        wifiSsid = act ? act.ssid : "";
        wifiSignal = act ? act.signal : 0;
        vpns = nmVpns.concat(tsVpn);
    }

    function refreshTailscale() {
        exec(["tailscale", "status", "--json"], (code, out) => {
            if (code !== 0 || out.charAt(0) !== "{") { root.tsAvailable = false; root.tsVpn = []; root.rebuildNetworks(); return; }
            let state = "";
            try { state = JSON.parse(out).BackendState; } catch (e) {}
            root.tsAvailable = true;
            root.tsVpn = [{ id: "tailscale", name: "Tailscale", kind: "ts", active: state === "Running" }];
            root.rebuildNetworks();
        });
    }

    // `nmcli monitor` imprime una linea por cada cambio: solo sirve de aviso para releer.
    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: root.refreshSoon() }
    }

    // --- Acciones ---------------------------------------------------------------------------
    function friendly(out) {
        if (/secrets were required|no secrets|password|802-1x|4-way|wrong key/i.test(out)) return "Contraseña incorrecta o la red la rechazó";
        if (/no network with ssid|not found/i.test(out)) return "No se encontró la red";
        if (/timeout|timed out|activation failed/i.test(out)) return "No se pudo conectar (tiempo agotado)";
        if (/access denied|operator/i.test(out)) return "Sin permiso: ejecuta una vez  sudo tailscale set --operator=$USER";
        const line = out.split("\n").filter(l => l.trim() !== "").pop() || "";
        return line.replace(/^Error:\s*/, "");
    }

    function setWifiEnabled(on) {
        wifiEnabled = on;
        if (!on) { rawWifi = []; rebuildNetworks(); }
        exec(["nmcli", "radio", "wifi", on ? "on" : "off"], () => { root.refreshSoon(); if (on) root.scan(); });
    }

    function scan() {
        if (!hasWifi || !wifiEnabled || scanning) return;
        scanning = true;
        exec(["nmcli", "device", "wifi", "rescan"], () => scanDone.restart());
    }
    Timer { id: scanDone; interval: 4000; onTriggered: { root.scanning = false; root.refresh(); } }

    // Conectar. Con perfil guardado y sin contrasena nueva se reutiliza; si no se crea uno.
    function connectWifi(ssid, password, hidden) {
        if (busy !== "") return;
        error = "";
        busy = ssid;
        const wasKnown = knownWifi.indexOf(ssid) >= 0;
        let cmd;
        if (wasKnown && !password) cmd = ["nmcli", "--wait", "30", "connection", "up", "id", ssid];
        else {
            cmd = ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid];
            if (password) cmd.push("password", password);
            if (hidden) cmd.push("hidden", "yes");
        }
        exec(cmd, (code, out) => {
            root.busy = "";
            if (code !== 0) {
                root.error = root.friendly(out);
                // No dejar un perfil a medias de una red nueva que fallo.
                if (!wasKnown) root.exec(["nmcli", "connection", "delete", "id", ssid], () => root.refreshSoon());
            }
            root.refreshSoon();
        });
    }

    function disconnectWifi() {
        if (wifiDevice === "" || busy !== "") return;
        busy = wifiSsid;
        exec(["nmcli", "device", "disconnect", wifiDevice], () => { root.busy = ""; root.refreshSoon(); });
    }

    function forget(ssid) {
        error = "";
        exec(["nmcli", "connection", "delete", "id", ssid], () => root.refreshSoon());
    }

    function toggleEthernet(e) {
        if (busy !== "") return;
        error = "";
        busy = e.device;
        exec(["nmcli", "device", e.state === "connected" ? "disconnect" : "connect", e.device], (code, out) => {
            root.busy = "";
            if (code !== 0) root.error = root.friendly(out);
            root.refreshSoon();
        });
    }

    function toggleVpn(v) {
        if (busy !== "") return;
        error = "";
        busy = v.id;
        const done = (code, out) => {
            root.busy = "";
            if (code !== 0) root.error = root.friendly(out);
            root.refreshSoon();
        };
        if (v.kind === "ts") exec(v.active ? ["tailscale", "down"] : ["tailscale", "up", "--timeout", "10s"], done);
        else exec(["nmcli", "connection", v.active ? "down" : "up", "id", v.id], done);
    }

    // Lee el perfil guardado (o prepara un nombre y una contrasena por defecto la primera vez).
    function loadHotspot() {
        exec(["nmcli", "-s", "-g", "802-11-wireless.ssid,802-11-wireless-security.psk", "connection", "show", hotspotName], (code, out) => {
            const lines = out.split("\n");
            if (code === 0 && lines.length >= 2 && lines[0] !== "") { root.hotspotSsid = lines[0]; root.hotspotPsk = lines[1]; return; }
            exec(["hostname"], (c, host) => {
                root.hotspotSsid = "Pill-" + (host || "equipo");
                exec(["sh", "-c", "head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 12"], (c2, pw) => root.hotspotPsk = pw);
            });
        });
    }

    // Comparte la conexion con otros dispositivos. OJO: la tarjeta Wi-Fi pasa a ser el punto de acceso,
    // asi que se deja la red Wi-Fi actual (la pagina lo avisa y pide el clic en Activar).
    function startHotspot(ssid, psk) {
        if (busy !== "" || wifiDevice === "") return;
        if (ssid.trim() === "") { error = "Pon un nombre para la red"; return; }
        if (psk.length < 8 || psk.length > 63) { error = "La contraseña debe tener entre 8 y 63 caracteres"; return; }
        error = "";
        busy = hotspotName;
        exec(["nmcli", "connection", "delete", hotspotName], () => {
            exec(["nmcli", "connection", "add", "type", "wifi", "ifname", wifiDevice, "con-name", hotspotName, "autoconnect", "no",
                  "ssid", ssid.trim(), "802-11-wireless.mode", "ap", "802-11-wireless.band", "bg", "ipv4.method", "shared",
                  "wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", psk], (code, out) => {
                if (code !== 0) { root.busy = ""; root.error = root.friendly(out); return; }
                exec(["nmcli", "--wait", "20", "connection", "up", hotspotName], (c2, o2) => {
                    root.busy = "";
                    if (c2 !== 0) root.error = root.friendly(o2);
                    else { root.hotspotSsid = ssid.trim(); root.hotspotPsk = psk; }
                    root.refreshSoon();
                });
            });
        });
    }

    function stopHotspot() {
        if (busy !== "") return;
        busy = hotspotName;
        exec(["nmcli", "connection", "down", hotspotName], () => { root.busy = ""; root.refreshSoon(); });
    }
}

