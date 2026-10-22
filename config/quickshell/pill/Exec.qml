pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Ejecuta un comando y entrega (codigo de salida, salida estandar y de error juntas) a un callback:
//   Exec.run(["nmcli", "radio", "wifi"], (code, out) => { ... })
// Cada llamada es un proceso nuevo e independiente, asi que varias a la vez (o una nueva que deja obsoleta a la
// anterior) no se pisan; quien llama decide si ignora un resultado viejo.
Singleton {
    id: root

    Component {
        id: cmdComp
        Process {
            id: p
            property var cb
            stdout: StdioCollector {
                onStreamFinished: {
                    const i = text.indexOf("\n");
                    const code = parseInt(text.slice(0, i));
                    const out = text.slice(i + 1).replace(/\n$/, "");
                    if (p.cb) p.cb(code, out);
                    p.destroy();
                }
            }
        }
    }

    function run(args, cb) {
        const p = cmdComp.createObject(root, {
            command: ["sh", "-c", 'out=$("$@" 2>&1); c=$?; echo $c; echo "$out"', "_"].concat(args),
            cb: cb
        });
        p.running = true;
    }
}
