import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// Pantalla de bloqueo propia: ext-session-lock + PAM. La contrasena se muestra
// como figuras (LockView). Si Quickshell muere con la sesion bloqueada, niri la
// deja bloqueada (es lo que la hace segura): ver docs/lockscreen.md para salir.
Scope {
    id: root

    // Para pruebas: otro servicio PAM y/o directorio. En produccion, los de siempre.
    property string pamConfig: "login"
    property string pamConfigDirectory: "/etc/pam.d"

    readonly property bool locked: lock.locked
    property alias shapes: shapes

    // "idle" | "verifying" | "failed" | "success"
    property string state: "idle"
    property string message: ""
    property string password: ""
    property string pending: ""

    readonly property int shapeKinds: 5
    readonly property int shapeColors: 6

    function lockNow() {
        if (lock.locked) return;
        clearAll();
        state = "idle";
        message = "";
        lock.locked = true;
    }

    // Desbloqueo (tras autenticar, o por el temporizador de seguridad de las pruebas).
    function release() { lock.locked = false; }

    function type(t) {
        if (state !== "idle") return;
        message = "";
        password += t;
        // Nunca dos figuras iguales seguidas.
        const last = shapes.count > 0 ? shapes.get(shapes.count - 1).kind : -1;
        let kind = Math.floor(Math.random() * (shapeKinds - 1));
        if (kind >= last && last >= 0) kind++;
        shapes.append({ kind: kind, hue: Math.floor(Math.random() * shapeColors) });
    }

    function backspace() {
        if (state !== "idle" || password.length === 0) return;
        message = "";
        password = password.slice(0, -1);
        shapes.remove(shapes.count - 1);
    }

    function clearAll() {
        password = "";
        drain.stop();
        shapes.clear();
    }

    function submit() {
        if (state !== "idle" || password.length === 0) return;
        state = "verifying";
        message = "";
        pending = password;
        if (!pam.start()) fail("No se pudo iniciar la autenticación");
    }

    function fail(msg) {
        pending = "";
        message = msg;
        state = "failed";
        failTimer.restart();
    }

    function succeed() {
        pending = "";
        state = "success";
        unlockTimer.restart();
    }

    ListModel { id: shapes }

    PamContext {
        id: pam
        config: root.pamConfig
        configDirectory: root.pamConfigDirectory

        onPamMessage: {
            if (!responseRequired) return;
            if (root.pending !== "") { respond(root.pending); root.pending = ""; }
            else abort();
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.succeed();
            else if (result === PamResult.MaxTries) root.fail("Demasiados intentos");
            else if (result === PamResult.Error) root.fail("Error de autenticación");
            else root.fail("Contraseña incorrecta");
        }
        onError: error => console.warn("lock: pam error", PamError.toString(error))
    }

    // Tras fallar: sacudida (en la vista), luego las figuras se desvanecen en cascada.
    Timer { id: failTimer; interval: 750; onTriggered: { root.password = ""; drain.start(); } }
    Timer {
        id: drain
        interval: 45
        repeat: true
        onTriggered: {
            if (shapes.count > 0) shapes.remove(shapes.count - 1);
            else { stop(); root.state = "idle"; }
        }
    }

    Timer {
        id: unlockTimer
        interval: 550
        onTriggered: { root.release(); root.clearAll(); root.state = "idle"; }
    }

    WlSessionLock {
        id: lock

        WlSessionLockSurface {
            color: "#0b0f0c"
            LockView { anchors.fill: parent; ctx: root }
        }
    }
}
