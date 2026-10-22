//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Punto de entrada. Arrancar con:  qs -c pill
// La pildora es el unico "widget": barra, launcher, notificaciones y estado.
ShellRoot {
    id: root

    // Quien tenga el foco del notch: "idle" | "launcher" | "emoji" | "wallpapers" | "clipboard" | "media" | "power" | "osd"
    property string mode: "idle"
    Component.onCompleted: { BluetoothAudio.start(); AudioStreams.start(); PinnedApps.load(); NetworkState.start(); Idle.start(); BatteryAlerts.start(); NightLight.load(); EmojiData.load(); ScreenCapture.load(); AppUsage.load(); Fzf.probe(); }

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

    property string launcherQuery: ""
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
        volume: "audio", audio: "audio", vpn: "vpn", battery: "battery", nightlight: "nightlight", night: "nightlight", capture: "capture"
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
        function toggle(): void { root.launcherQuery = ""; root.mode = root.mode === "launcher" ? "idle" : "launcher"; }
        function open(): void   { root.launcherQuery = ""; root.mode = "launcher"; }
        // Abre el launcher ya escrito:  qs -c pill ipc call launcher search "f informe"
        function search(text: string): void { root.mode = "idle"; root.launcherQuery = text; root.mode = "launcher"; }
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

    // Selector de emoji:  qs -c pill ipc call emoji toggle   (niri: Mod+;)
    IpcHandler {
        target: "emoji"
        function toggle(): void { root.mode = root.mode === "emoji" ? "idle" : "emoji"; }
        function open(): void   { root.mode = "emoji"; }
        function close(): void  { root.mode = "idle"; }
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

    // Inactividad:  qs -c pill ipc call idle caffeine|status   (cafeina = no atenuar, bloquear ni suspender)
    IpcHandler {
        target: "idle"
        function caffeine(): string { Idle.toggleCaffeine(); return Idle.caffeine ? "despierto: activado" : "despierto: desactivado"; }
        function status(): string { return "cafeina=" + Idle.caffeine + " activo=" + Idle.active + " bateria=" + UPower.onBattery; }
    }

    // Pruebas de los avisos de bateria:  qs -c pill ipc call battery simulate 18   (-1 = vuelve a la real)
    IpcHandler {
        target: "battery"
        function simulate(pct: int): void { BatteryAlerts.simulated = pct; if (pct < 0) BatteryAlerts.notified = 0; }
    }

    // Capturas:  qs -c pill ipc call capture area|window|screen|record|recordarea|stop|status
    // (el panel con todas las opciones:  qs -c pill ipc call popover toggle capture   niri: Mod+Shift+S)
    IpcHandler {
        target: "capture"
        function area(): void       { ScreenCapture.shoot("area"); }
        function window(): void     { ScreenCapture.shoot("window"); }
        function screen(): void     { ScreenCapture.shoot("screen"); }
        function record(): void     { ScreenCapture.record(false); }
        function recordarea(): void { ScreenCapture.record(true); }
        function stop(): void       { ScreenCapture.stop(); }
        function status(): string   { return (ScreenCapture.recording ? "grabando " + ScreenCapture.elapsedText : "libre") + " grabador=" + ScreenCapture.hasRecorder; }
    }

    // Luz nocturna:  qs -c pill ipc call nightlight off|auto|on|toggle|status
    IpcHandler {
        target: "nightlight"
        function off(): void    { NightLight.setMode("off"); }
        function auto(): void   { NightLight.setMode("auto"); }
        function on(): void     { NightLight.setMode("on"); }
        function toggle(): void { NightLight.toggle(); }
        function status(): string { return NightLight.mode + " " + NightLight.temperature + "K " + NightLight.from + "-" + NightLight.to; }
    }

    // Selector de fondos:  qs -c pill ipc call wallpaper toggle   (niri: Mod+Shift+W)
    // Cambiar el fondo (y el del overview) en vivo:
    //   qs -c pill ipc call wallpaper set ~/Pictures/foto.png
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Theme.setWallpaper(path); }
        function toggle(): void { root.mode = root.mode === "wallpapers" ? "idle" : "wallpapers"; }
        function open(): void   { root.mode = "wallpapers"; }
        function close(): void  { root.mode = "idle"; }
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

    // Agente polkit con nuestro estilo (si no, hace falta otro agente en la sesion).
    Loader { active: Theme.polkitAgent; sourceComponent: PolkitDialog {} }

    // Bloqueo propio (solo se usa si Theme.nativeLock; si no, swaylock).
    LockScreen { id: lockScreen }
    Connections {
        target: PowerActions
        function onLockRequested() { lockScreen.lockNow(); }
    }

    // Click en cualquier parte fuera del notch / la barra / el menu abierto lo cierra.
    Dismiss {
        active: root.mode === "launcher" || root.mode === "emoji" || root.mode === "wallpapers" || root.mode === "clipboard" || root.mode === "media" || root.mode === "power" || root.popover !== ""
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
        launcherQuery: root.launcherQuery
        osdKind: root.osdKind
        onModeRequested: m => root.mode = m
        onVolumeActivity: root.showOsd("volume")
    }
}
