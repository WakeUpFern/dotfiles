pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Avisos de bateria baja en los niveles de Theme.batteryWarnLevels (una vez por descarga). Salen como
// notificaciones normales (tarjeta + historial); los dos ultimos niveles son criticos y atraviesan
// "No molestar". El apagado/suspension final lo hace UPower (PercentageAction).
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    property real simulated: -1                       // para probar: IPC "battery simulate <0..100>"
    readonly property real pct: simulated >= 0 ? simulated : dev.percentage * 100
    readonly property bool discharging: simulated >= 0 || (dev.isPresent && dev.state === UPowerDeviceState.Discharging)

    property int notified: 0                          // nivel ya avisado (0 = ninguno)

    function start() {}                               // basta con tocarlo para que exista

    onPctChanged: check()
    onDischargingChanged: check()

    function check() {
        const levels = Theme.batteryWarnLevels;
        if (!discharging) { notified = 0; return; }
        if (pct > levels[0] + 5) { notified = 0; return; }       // histeresis: se rearma al recargar
        let stage = 0;
        for (let i = 0; i < levels.length; i++) if (pct <= levels[i]) stage = i + 1;
        if (stage === 0 || stage <= notified) return;
        notified = stage;
        const critical = stage >= levels.length - 1;
        const rounded = Math.round(pct);
        Quickshell.execDetached(["notify-send", "-a", "Batería", "-i", critical ? "battery-caution" : "battery-low",
            "-u", critical ? "critical" : "normal",
            "Batería baja: " + rounded + "%",
            stage >= levels.length ? "Conecta el cargador ya: el equipo se apagará o suspenderá en breve." : "Conecta el cargador."]);
    }
}
