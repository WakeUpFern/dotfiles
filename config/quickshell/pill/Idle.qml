pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

// Inactividad y suspension (lo que antes hacia swayidle):
//   atenuar -> bloquear -> apagar pantalla -> suspender (solo con bateria)
// con los tiempos de Theme.idle*. Usa ext-idle-notify (IdleMonitor), que respeta a las apps que
// inhiben la inactividad (video, presentaciones). Ademas bloquea SIEMPRE antes de suspender (tapa,
// boton, menu o inactividad) con un inhibidor de sueno de tipo "delay" y la senal PrepareForSleep.
Singleton {
    id: root

    // "Mantener despierto": apaga todos los pasos de inactividad (no el bloqueo antes de suspender).
    property bool caffeine: false
    readonly property bool active: Theme.idleEnabled && !caffeine

    function start() {
        Brightness.refresh();           // el singleton es perezoso: que ya conozca el brillo cuando haga falta atenuar
        if (Theme.lockBeforeSleep) { sleepWatch.running = true; inhibitor.running = true; }
    }
    function toggleCaffeine() { caffeine = !caffeine; }

    // --- Atenuar -----------------------------------------------------------------------------
    property real savedBrightness: -1
    function dim(on) {
        if (!Brightness.available) return;
        if (on && savedBrightness < 0) {
            savedBrightness = Brightness.level;
            Brightness.set(Math.min(Brightness.level, 0.15));
        } else if (!on && savedBrightness >= 0) {
            Brightness.set(savedBrightness);
            savedBrightness = -1;
        }
    }
    // Al desactivar el paso mientras esta atenuado (p. ej. cafeina) hay que devolver el brillo.
    onActiveChanged: if (!active) dim(false)

    IdleMonitor {
        enabled: root.active && Theme.idleDimSeconds > 0
        timeout: Theme.idleDimSeconds
        onIsIdleChanged: root.dim(isIdle)
    }
    IdleMonitor {
        enabled: root.active && Theme.idleLockSeconds > 0
        timeout: Theme.idleLockSeconds
        onIsIdleChanged: if (isIdle) PowerActions.run("lock")
    }
    IdleMonitor {
        enabled: root.active && Theme.idleScreenOffSeconds > 0
        timeout: Theme.idleScreenOffSeconds
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"])
    }
    IdleMonitor {
        enabled: root.active && Theme.idleSuspendSeconds > 0 && UPower.onBattery
        timeout: Theme.idleSuspendSeconds
        onIsIdleChanged: if (isIdle) Quickshell.execDetached(["systemctl", "suspend"])
    }

    // --- Bloquear antes de suspender -----------------------------------------------------------
    // El inhibidor retrasa el sueno hasta que lo soltamos (max. InhibitDelayMaxSec de logind, 5 s).
    Process {
        id: inhibitor
        command: ["systemd-inhibit", "--what=sleep", "--who=pill", "--why=Bloquear la pantalla antes de suspender",
                  "--mode=delay", "sleep", "infinity"]
    }
    Process {
        id: sleepWatch
        command: ["dbus-monitor", "--system",
                  "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("boolean true") >= 0) { PowerActions.run("lock"); release.restart(); }
                else if (line.indexOf("boolean false") >= 0) { root.dim(false); inhibitor.running = true; }
            }
        }
    }
    // Margen para que el bloqueo ya este dibujado cuando el equipo se duerma.
    Timer { id: release; interval: 700; onTriggered: inhibitor.running = false }
}
