pragma Singleton
import QtQuick
import Quickshell

// fzf (https://github.com/junegunn/fzf) como motor de busqueda del launcher: el estandar de facto de busqueda
// difusa. Se usa en modo filtro (`fzf --filter consulta`), que imprime las coincidencias ordenadas por relevancia.
// La sintaxis extendida de fzf funciona en el launcher tal cual: `'exacto`, `^inicio`, `fin$`, `!excluir`, `a | b`.
// Si fzf no esta instalado `available` es false y el launcher usa su puntuador interno (Logic.fuzzy).
Singleton {
    id: root

    property bool available: false
    readonly property string bin: Theme.fzfCommand

    function probe() { Exec.run(["sh", "-c", 'command -v "$1"', "_", bin], code => root.available = code === 0); }

    // Apps: pocas lineas "indice<TAB>texto"; se pasan por argumentos. Solo se compara la 2a columna y, a igualdad
    // de puntuacion, gana el orden en que se pasaron (el del uso). Devuelve las lineas coincidentes, mejores primero.
    function rankApps(lines, query, cb) {
        Exec.run(["sh", "-c", 'f=$1; q=$2; shift 2; printf "%s\\n" "$@" | "$f" --filter "$q" --delimiter "\\t" --nth 2 --tiebreak index',
                  "_", bin, query].concat(lines), (code, out) => cb(out === "" ? [] : out.split("\n")));
    }

    // Archivos: lista en un archivo, lineas "ruta relativa<TAB>ruta absoluta<TAB>fecha"; se compara la ruta relativa.
    function rankFiles(listFile, query, cb) {
        Exec.run(["sh", "-c", '"$1" --filter "$2" --delimiter "\\t" --nth 1 --scheme path < "$3"', "_", bin, query, listFile],
                 (code, out) => cb(out === "" ? [] : out.split("\n")));
    }
}
