//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire

// Punto de entrada. Arrancar con:  qs -c pill
// La pildora es el unico "widget": barra, launcher, notificaciones y estado.
ShellRoot {
    id: root

    // Quien tenga el foco del notch: "idle" | "launcher" | "clipboard" | "media" | "power" | "osd"
    property string mode: "idle"
    Component.onCompleted: { BluetoothAudio.start(); AudioStreams.start(); PinnedApps.load(); NetworkState.start(); }

    // Menu abierto de la barra derecha: "" | "quick" (ajustes rapidos) | "notifications" (reloj +
    // campana) | "tray". Notch y menus de la barra son excluyentes (abrir uno cierra el otro).
    property string popover: ""
    property string quickPage: "home"     // pagina del panel "quick": home | network | bluetooth | audio | vpn | battery
    property var trayItem: null           // icono de la bandeja cuyo menu esta abierto (popover "tray")
    onPopoverChanged: {
        if (popover !== "" && mode !== "idle" && mode !== "osd") mode = "idle";
        // Abrir la campana ya muestra todo en la lista: las tarjetas sobran.
        if (popover === "notifications") toasts.dismissAll();
    }
    onModeChanged: if (mode !== "idle" && mode !== "osd" && popover !== "") popover = ""

    property string osdKind: "volume"

    // HUD de volumen/brillo: aparece un momento y vuelve a reposo.
    function showOsd(kind) {
        if (mode !== "idle" && mode !== "osd") return;
        osdKind = kind;
        mode = "osd";
        osdTimer.restart();
    }

    // Notificaciones: tarjetas de vidrio arriba a la derecha (Toasts.qml).
    NotificationServer {
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        keepOnReload: false

        onNotification: n => {
            n.tracked = true;
            const critical = n.urgency === NotificationUrgency.Critical;
            NotificationCenter.add(n, critical);
            // No molestar: no salen tarjetas (las criticas si); queda en el historial y el contador.
            if (NotificationCenter.dnd && !critical) n.expire();
            else toasts.add(n);
        }
    }
    // Las tarjetas se colocan bajo la barra derecha y, con un menu abierto, bajo el menu.
    Toasts {
        id: toasts
        popoverBottom: popoverHost.open ? popoverHost.targetBottom + 10 : 0
    }

    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: if (root.mode === "osd") root.mode = "idle"
    }

    // Nombres de menu (de la barra o del IPC) -> menu real + pagina del panel de ajustes rapidos.
    readonly property var quickPages: ({
        quick: "home", network: "network", wifi: "network", ethernet: "network", bluetooth: "bluetooth",
        volume: "audio", audio: "audio", vpn: "vpn", battery: "battery"
    })
    function popoverFor(name) { return name === "clock" ? "notifications" : (quickPages[name] ? "quick" : name); }
    function togglePopover(name) {
        const p = popoverFor(name);
        const page = quickPages[name] || "home";
        if (popover === p && (p !== "quick" || name === "quick" || quickPage === page)) { popover = ""; return; }
        quickPage = page;
        popover = p;
    }
    function openPopover(name) { quickPage = quickPages[name] || "home"; popover = popoverFor(name); }

    // Control desde fuera:  qs -c pill ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.mode = root.mode === "launcher" ? "idle" : "launcher"; }
        function open(): void   { root.mode = "launcher"; }
        function close(): void  { root.mode = "idle"; }
    }

    // Teclas de brillo (niri las manda aqui):  qs -c pill ipc call brightness up
    IpcHandler {
        target: "brightness"
        function up(): void   { Brightness.step(0.05);  root.showOsd("brightness"); }
        function down(): void { Brightness.step(-0.05); root.showOsd("brightness"); }
    }

    // Multimedia:  qs -c pill ipc call media toggle|playpause|next|previous|select <nombre>
    // Las teclas multimedia de niri llaman aqui; play/next/prev muestran el HUD de la pista.
    IpcHandler {
        target: "media"
        function toggle(): void   { root.mode = root.mode === "media" ? "idle" : "media"; }
        function open(): void     { root.mode = "media"; }
        function close(): void    { root.mode = "idle"; }
        function playpause(): void { MediaState.togglePlaying(); root.showOsd("track"); }
        function next(): void      { MediaState.next();          root.showOsd("track"); }
        function previous(): void  { MediaState.previous();      root.showOsd("track"); }
        function select(name: string): string { return MediaState.select(name); }
        function status(): string {
            const p = MediaState.active;
            return p ? p.identity + "|" + p.playbackState + "|" + p.trackTitle + "|" + p.trackArtist + "|" + Math.round(p.position) + "/" + Math.round(p.length) : "ninguno";
        }
    }

    // Portapapeles:  qs -c pill ipc call clipboard toggle   (niri: Mod+V)
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.mode = root.mode === "clipboard" ? "idle" : "clipboard"; }
        function open(): void   { root.mode = "clipboard"; }
        function close(): void  { root.mode = "idle"; }
    }

    // Menu de apagado:  qs -c pill ipc call power toggle   (niri: Mod+Shift+E)
    IpcHandler {
        target: "power"
        function toggle(): void { root.mode = root.mode === "power" ? "idle" : "power"; }
        function open(): void   { root.mode = "power"; }
        function close(): void  { root.mode = "idle"; }
        function lock(): void   { root.mode = "idle"; PowerActions.run("lock"); }
    }

    // Cambiar el fondo (y el del overview) en vivo:
    //   qs -c pill ipc call wallpaper set ~/Pictures/foto.png
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Theme.setWallpaper(path); }
    }

    // Notificaciones:  qs -c pill ipc call notifications dnd|clear   (No molestar / borrar historial)
    IpcHandler {
        target: "notifications"
        function dnd(): string { NotificationCenter.toggleDnd(); return NotificationCenter.dnd ? "No molestar: activado" : "No molestar: desactivado"; }
        function clear(): void { NotificationCenter.clear(); toasts.dismissAll(); }
        function unread(): int { return NotificationCenter.unread; }
    }

    // Audio por aplicacion:  qs -c pill ipc call audio apps | setapp <nombre> <0..1.5> | mic
    IpcHandler {
        target: "audio"
        function apps(): string {
            return AudioStreams.apps.map(g => g.name + ": " + Math.round(AudioStreams.groupVolume(g) * 100) + "%" + (AudioStreams.groupMuted(g) ? " (silenciada)" : "") + " [" + g.nodes.length + " flujo(s)]").join("\n");
        }
        function setapp(name: string, v: string): string {
            const g = AudioStreams.apps.find(x => x.name.toLowerCase().indexOf(name.toLowerCase()) >= 0);
            if (!g) return "no encontrada";
            AudioStreams.setGroupVolume(g, Number(v));
            return g.name + " -> " + v;
        }
        function dump(): string {
            return Pipewire.nodes.values.map(n => n.id + " | stream=" + n.isStream + " sink=" + n.isSink + " | " + n.name + " | clase=" + JSON.stringify((n.properties || {})["media.class"]) + " | app=" + JSON.stringify((n.properties || {})["application.name"])).join("\n");
        }
        function mic(): string { return AudioStreams.micInUse ? "en uso: " + AudioStreams.micUsers : "libre"; }
    }

    // Bandeja:  qs -c pill ipc call tray list | menu <n>   (n empieza en 0)
    IpcHandler {
        target: "tray"
        function list(): string {
            return SystemTray.items.values.map((it, i) => i + ": " + (it.tooltipTitle || it.title || it.id) + (it.hasMenu ? " (menu)" : "") + (it.onlyMenu ? " (solo menu)" : "")).join("\n");
        }
        function menu(n: int): void {
            const it = SystemTray.items.values[n];
            if (!it) return;
            if (root.popover === "tray" && root.trayItem === it) root.popover = "";
            else { root.trayItem = it; root.popover = "tray"; }
        }
    }

    // Menus de la barra derecha:
    //   qs -c pill ipc call popover toggle quick|network|bluetooth|volume|vpn|battery|notifications|clock
    // (network/bluetooth/volume/vpn/battery abren esa pagina del panel de ajustes rapidos)
    IpcHandler {
        target: "popover"
        function toggle(name: string): void { root.togglePopover(name); }
        function open(name: string): void   { root.openPopover(name); }
        function close(): void              { root.popover = ""; }
    }


    Wallpaper {}
    Backdrop {}

    // Bloqueo propio (solo se usa si Theme.nativeLock; si no, swaylock).
    LockScreen { id: lockScreen }
    Connections {
        target: PowerActions
        function onLockRequested() { lockScreen.lockNow(); }
    }

    // Click en cualquier parte fuera del notch / la barra / el menu abierto lo cierra.
    Dismiss {
        active: root.mode === "launcher" || root.mode === "clipboard" || root.mode === "media" || root.mode === "power" || root.popover !== ""
        pillWidth: pill.pillWidth
        pillHeight: pill.pillHeight
        barWidth: statusBar.barWidth + 16
        barHeight: statusBar.barHeight + 4
        cardWidth: popoverHost.cardWidth
        cardHeight: popoverHost.cardHeight
        cardTop: popoverHost.topGap
        cardRight: popoverHost.rightGap
        onDismissed: { root.mode = "idle"; root.popover = ""; }
    }

    // Barra derecha (iconos + reloj) y su menu desplegable.
    StatusBar {
        id: statusBar
        active: root.popover
        trayItem: root.trayItem
        onToggled: name => root.togglePopover(name)
        onTrayMenu: item => {
            if (root.popover === "tray" && root.trayItem === item) root.popover = "";
            else { root.trayItem = item; root.popover = "tray"; }
        }
    }
    PopoverHost {
        id: popoverHost
        name: root.popover
        quickPage: root.quickPage
        trayItem: root.trayItem
        onCloseRequested: root.popover = ""
    }

    Pill {
        id: pill
        mode: root.mode
        osdKind: root.osdKind
        onModeRequested: m => root.mode = m
        onVolumeActivity: root.showOsd("volume")
    }
}
