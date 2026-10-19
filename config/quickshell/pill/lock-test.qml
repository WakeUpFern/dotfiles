import QtQuick
import Quickshell
import Quickshell.Io

// Instancia de PRUEBA del bloqueo propio (no es parte de la sesion normal).
// Bloquea al arrancar y se desbloquea sola tras N segundos como red de seguridad.
//   scripts/lock-test.sh            (contrasena real, 45 s de seguridad)
// Variables: PILL_TEST_SECONDS, PILL_TEST_PAM, PILL_TEST_PAMDIR, PILL_TEST_IPC=1
ShellRoot {
    id: shell

    property bool started: false

    LockScreen {
        id: ls
        pamConfig: Quickshell.env("PILL_TEST_PAM") || "login"
        pamConfigDirectory: Quickshell.env("PILL_TEST_PAMDIR") || "/etc/pam.d"
        onLockedChanged: if (!locked && shell.started) Qt.quit()
    }

    Timer {
        interval: Number(Quickshell.env("PILL_TEST_SECONDS") || 45) * 1000
        running: ls.locked
        onTriggered: ls.release()
    }

    Component.onCompleted: { started = true; ls.lockNow(); }

    // Solo para pruebas automaticas (teclado virtual por IPC).
    IpcHandler {
        enabled: Quickshell.env("PILL_TEST_IPC") === "1"
        target: "locktest"
        function type(s: string): void { for (const c of s) ls.type(c); }
        function backspace(): void { ls.backspace(); }
        function submit(): void { ls.submit(); }
        function state(): string { return ls.state + "|" + ls.message + "|" + ls.shapes.count; }
    }
}
