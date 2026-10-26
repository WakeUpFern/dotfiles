pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Monitor del sistema: CPU (total y por nucleo), memoria, temperaturas, ventilador, red, disco, consumo
// de la bateria y los procesos que mas gastan. Todo sale de /proc y /sys (sin procesos externos en
// reposo): la barra solo lee unos pocos archivos cada 2 s. Con el menu abierto (`detail`) muestrea
// cada segundo y ademas trae discos y la lista de procesos.
Singleton {
    id: root

    property bool detail: false               // menu abierto
    function start() { probe.running = true; sampler.running = true; }

    readonly property int historyLen: 60       // muestras que guardan las graficas
    readonly property int interval: detail ? 1000 : 2000

    // --- Valores actuales ----------------------------------------------------------------------
    property real cpu: 0                       // 0..1
    property var cores: []                     // 0..1 por hilo
    property real cpuMhz: 0
    property var load: [0, 0, 0]

    property real ramTotal: 0                  // bytes
    property real ramUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real ram: ramTotal > 0 ? ramUsed / ramTotal : 0

    property real tempCpu: -1                  // grados C (-1 = sin sensor)
    property real tempGpu: -1
    property real tempDisk: -1
    property int fan: -1                       // rpm

    property real netDown: 0                   // bytes/s
    property real netUp: 0
    property real diskRead: 0
    property real diskWrite: 0
    property real diskSize: 0                  // bytes de "/"
    property real diskUsed: 0

    property real power: -1                    // W que sale de la bateria (-1 = sin dato)

    property var topCpu: []                    // [{ name, cpu, mem }] agrupado por programa
    property var topMem: []

    property var cpuHistory: []
    property var ramHistory: []
    property var tempHistory: []
    property var downHistory: []
    property var upHistory: []

    // --- Formatos ------------------------------------------------------------------------------
    // Velocidad corta y de ancho casi fijo: "0K", "850K", "1.2M".
    function rate(b) {
        if (b < 1000) return "0K";
        if (b < 1000 * 1000) return Math.round(b / 1000) + "K";
        if (b < 100 * 1000 * 1000) return (b / 1e6).toFixed(1) + "M";
        return Math.round(b / 1e6) + "M";
    }
    function gib(b) { return (b / 1073741824).toFixed(1) + " GB"; }
    function mem(kib) { return kib >= 1048576 ? (kib / 1048576).toFixed(1) + " GB" : Math.round(kib / 1024) + " MB"; }
    function push(arr, v) { const a = arr.concat([v]); return a.length > historyLen ? a.slice(a.length - historyLen) : a; }

    // --- Muestreo ------------------------------------------------------------------------------
    Timer {
        id: sampler
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload(); meminfo.reload(); netdev.reload(); loadavg.reload();
            if (cpuTemp.path !== "") cpuTemp.reload();
            if (battery.path !== "") battery.reload();
            if (root.detail) {
                cpuinfo.reload(); diskstats.reload();
                if (gpuTemp.path !== "") gpuTemp.reload();
                if (diskTemp.path !== "") diskTemp.reload();
                if (fanFile.path !== "") fanFile.reload();
            }
        }
    }
    onDetailChanged: {
        if (detail) { sampler.restart(); dfProc.running = true; }
        else { root.topCpu = []; root.topMem = []; }
    }

    // Rutas de los sensores (el numero de hwmonN cambia entre arranques; se buscan por nombre).
    Process {
        id: probe
        command: ["sh", "-c", 'for h in /sys/class/hwmon/hwmon*; do echo "$(cat "$h/name" 2>/dev/null) $h"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const by = {};
                for (const l of text.split("\n")) { const p = l.split(" "); if (p.length === 2) by[p[0]] = p[1]; }
                if (by.k10temp) cpuTemp.path = by.k10temp + "/temp1_input";
                else if (by.coretemp) cpuTemp.path = by.coretemp + "/temp1_input";
                if (by.amdgpu) gpuTemp.path = by.amdgpu + "/temp1_input";
                if (by.nvme) diskTemp.path = by.nvme + "/temp1_input";
                if (by.thinkpad) fanFile.path = by.thinkpad + "/fan1_input";
                if (by.dell_smm) fanFile.path = by.dell_smm + "/fan1_input";
            }
        }
    }

    // CPU: porcentaje de tiempo no ocioso entre dos lecturas de /proc/stat.
    property var _prevTotal: ({})
    property var _prevIdle: ({})
    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const cores = [];
            let total = 0;
            for (const l of text().split("\n")) {
                if (l.indexOf("cpu") !== 0) continue;
                const f = l.split(/\s+/);
                const id = f[0];
                const v = f.slice(1, 9).map(Number);
                const all = v.reduce((a, b) => a + b, 0);
                const idle = v[3] + v[4];
                const dt = all - (root._prevTotal[id] || 0), di = idle - (root._prevIdle[id] || 0);
                const pct = root._prevTotal[id] && dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
                root._prevTotal[id] = all; root._prevIdle[id] = idle;
                if (id === "cpu") total = pct; else cores.push(pct);
            }
            root.cpu = total;
            root.cores = cores;
            root.cpuHistory = root.push(root.cpuHistory, total);
        }
    }
    FileView {
        id: cpuinfo
        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const m = text().match(/^cpu MHz\s*:\s*([0-9.]+)/gm) || [];
            const v = m.map(s => Number(s.replace(/^[^:]*:\s*/, "")));
            root.cpuMhz = v.length ? v.reduce((a, b) => a + b, 0) / v.length : 0;
        }
    }
    FileView {
        id: loadavg
        path: "/proc/loadavg"
        printErrors: false
        onLoaded: root.load = text().split(" ").slice(0, 3).map(Number)
    }

    // Memoria usada = total - disponible (lo mismo que `free`).
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const g = {};
            for (const l of text().split("\n")) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) g[m[1]] = Number(m[2]) * 1024; }
            root.ramTotal = g.MemTotal || 0;
            root.ramUsed = Math.max(0, (g.MemTotal || 0) - (g.MemAvailable || 0));
            root.swapTotal = g.SwapTotal || 0;
            root.swapUsed = Math.max(0, (g.SwapTotal || 0) - (g.SwapFree || 0));
            root.ramHistory = root.push(root.ramHistory, root.ram);
        }
    }

    // Red: suma de interfaces fisicas (sin lo, docker, tailscale... para no contar el trafico dos veces).
    property real _netRx: 0
    property real _netTx: 0
    property real _netAt: 0
    FileView {
        id: netdev
        path: "/proc/net/dev"
        printErrors: false
        onLoaded: {
            let rx = 0, tx = 0;
            for (const l of text().split("\n")) {
                const m = l.match(/^\s*([^:\s]+):\s*(.*)$/);
                if (!m || /^(lo|docker|veth|br-|virbr|tailscale|tun|tap)/.test(m[1])) continue;
                const f = m[2].split(/\s+/).map(Number);
                rx += f[0]; tx += f[8];
            }
            const now = Date.now();
            if (root._netAt > 0 && now > root._netAt) {
                const dt = (now - root._netAt) / 1000;
                root.netDown = Math.max(0, (rx - root._netRx) / dt);
                root.netUp = Math.max(0, (tx - root._netTx) / dt);
                root.downHistory = root.push(root.downHistory, root.netDown);
                root.upHistory = root.push(root.upHistory, root.netUp);
            }
            root._netRx = rx; root._netTx = tx; root._netAt = now;
        }
    }

    // Disco: bytes leidos/escritos por segundo (solo discos enteros, no particiones).
    property real _dR: 0
    property real _dW: 0
    property real _dAt: 0
    FileView {
        id: diskstats
        path: "/proc/diskstats"
        printErrors: false
        onLoaded: {
            let r = 0, w = 0;
            for (const l of text().split("\n")) {
                const f = l.trim().split(/\s+/);
                if (f.length < 10 || !/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+)$/.test(f[2])) continue;
                r += Number(f[5]) * 512; w += Number(f[9]) * 512;
            }
            const now = Date.now();
            if (root._dAt > 0 && now > root._dAt) {
                const dt = (now - root._dAt) / 1000;
                root.diskRead = Math.max(0, (r - root._dR) / dt);
                root.diskWrite = Math.max(0, (w - root._dW) / dt);
            }
            root._dR = r; root._dW = w; root._dAt = now;
        }
    }
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=size,used", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n").pop().trim().split(/\s+/);
                if (f.length >= 2) { root.diskSize = Number(f[0]); root.diskUsed = Number(f[1]); }
            }
        }
    }
    Timer { interval: 30000; repeat: true; running: root.detail; onTriggered: dfProc.running = true }

    // Temperaturas y ventilador (milesimas de grado).
    FileView {
        id: cpuTemp
        printErrors: false
        onLoaded: { root.tempCpu = Number(text()) / 1000; root.tempHistory = root.push(root.tempHistory, root.tempCpu); }
    }
    FileView { id: gpuTemp; printErrors: false; onLoaded: root.tempGpu = Number(text()) / 1000 }
    FileView { id: diskTemp; printErrors: false; onLoaded: root.tempDisk = Number(text()) / 1000 }
    FileView { id: fanFile; printErrors: false; onLoaded: root.fan = Number(text()) }

    // Consumo de la bateria (solo mientras se descarga; microvatios en el sistema).
    FileView {
        id: battery
        path: "/sys/class/power_supply/BAT0/power_now"
        printErrors: false
        onLoaded: root.power = status.text().trim() === "Discharging" ? Number(text()) / 1e6 : -1
        onLoadFailed: root.power = -1
    }
    FileView { id: status; path: "/sys/class/power_supply/BAT0/status"; printErrors: false; watchChanges: false }
    Timer { interval: 2000; repeat: true; running: battery.path !== ""; triggeredOnStart: true; onTriggered: status.reload() }

    // Procesos que mas gastan: dos pasadas cortas de `top` (la primera es el acumulado desde el
    // arranque, asi que solo se lee la segunda, que es la del ultimo segundo). Solo con el menu abierto.
    Process {
        id: topProc
        command: ["top", "-b", "-n", "2", "-d", "1", "-w", "200", "-e", "k", "-o", "%CPU"]
        stdout: StdioCollector {
            onStreamFinished: {
                const frames = text.split(/^top - /m);
                const last = frames[frames.length - 1] || "";
                const rows = [];
                for (const line of last.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length < 12 || !/^\d+$/.test(f[0])) continue;
                    rows.push({ name: f.slice(11).join(" "), cpu: Number(f[8].replace(",", ".")), mem: Number(f[5]) });
                }
                root._topRows = rows;
                root._finishTop();
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: root.detail
        triggeredOnStart: true
        onTriggered: if (!topProc.running) topProc.running = true
    }
    property var _topRows: []
    function _finishTop() {
        const by = {};
        for (const r of _topRows) {
            const g = by[r.name] || (by[r.name] = { name: r.name, cpu: 0, mem: 0 });
            g.cpu += r.cpu; g.mem += r.mem;
        }
        const list = Object.values(by);
        topCpu = list.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 5);
        topMem = list.slice().sort((a, b) => b.mem - a.mem).slice(0, 5);
    }
}
