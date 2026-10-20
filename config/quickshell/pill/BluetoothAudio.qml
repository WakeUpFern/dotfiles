pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Audio Bluetooth: al conectar unos audifonos, (1) la salida de audio se pasa a ellos y
// (2) se elige el mejor perfil de alta calidad (A2DP SBC-XQ si el dispositivo lo ofrece).
// Tambien expone los perfiles del dispositivo para que el panel los muestre y permita cambiarlos.
//
// OJO: PipeWire/WirePlumber ya decide solo algunas cosas (p. ej. cambia a "llamadas" si una app
// abre el microfono); esto solo actua cuando aparece una salida Bluetooth nueva.
Singleton {
    id: root

    // Si no quieres este comportamiento, ponlo en false en Theme.qml.
    readonly property bool autoOutput: Theme.btAutoSwitchOutput
    readonly property bool preferHighQuality: Theme.btPreferHighQuality

    // --- Perfiles del dispositivo mostrado en el panel ------------------------------
    property string deviceName: ""
    property var profiles: []            // [{ index, name, description, available }]
    property int activeIndex: -1

    function refresh(name) {
        if (!name) { deviceName = ""; profiles = []; activeIndex = -1; return; }
        deviceName = name;
        listProc.command = ["python3", Quickshell.shellPath("bt-profile.py"), "list", name];
        listProc.running = true;
    }
    function setProfile(index) {
        if (deviceName === "") return;
        setProc.command = ["python3", Quickshell.shellPath("bt-profile.py"), "set", deviceName, String(index)];
        setProc.running = true;
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.profiles = d.profiles;
                    root.activeIndex = d.active === null ? -1 : d.active;
                } catch (e) { root.profiles = []; root.activeIndex = -1; }
            }
        }
    }
    Process { id: setProc; onExited: refreshLater.restart() }
    Timer { id: refreshLater; interval: 900; onTriggered: root.refresh(root.deviceName) }

    // --- Automatismos al aparecer una salida Bluetooth -------------------------------
    property bool armed: false           // ignora la poblacion inicial (arranque / recarga del shell)
    function start() {}                  // basta con tocar el singleton para que exista
    Timer { interval: 2500; running: true; onTriggered: root.armed = true }

    property var pendingNode: null
    Timer {
        id: settle
        interval: 800                    // que WirePlumber termine de enlazar el nodo nuevo
        onTriggered: {
            const n = root.pendingNode;
            root.pendingNode = null;
            if (!n) return;
            if (root.autoOutput) Pipewire.preferredDefaultAudioSink = n;
            if (root.preferHighQuality) {
                bestProc.command = ["python3", Quickshell.shellPath("bt-profile.py"), "best", n.description];
                bestProc.running = true;
            }
        }
    }
    Process { id: bestProc }

    Connections {
        target: Pipewire.nodes
        function onObjectInsertedPost(object, index) {
            if (!root.armed || !object) return;
            if (object.isSink && !object.isStream && object.name.indexOf("bluez_output") === 0) {
                console.log("BluetoothAudio: salida nueva ->", object.description);
                root.pendingNode = object;
                settle.restart();
            }
        }
    }
}
