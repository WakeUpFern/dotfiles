pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "LauncherLogic.js" as Logic

// Indice de archivos del launcher, sin demonio ni base de datos: `find` lista tu home en ~150 ms (salta lo
// oculto y lo de Theme.fileSearchExcludes) y escribe la lista en un archivo temporal; se relee al abrir el
// launcher si tiene mas de un minuto.
//   Con fzf instalado, fzf filtra ese archivo (Fzf.qml): el estandar de facto.
//   Sin fzf, la lista tambien queda en memoria y se usa el puntuador interno (Logic.fuzzy).
// En los dos casos suben los archivos que abres seguido (AppUsage) y los modificados hace poco.
Singleton {
    id: root

    property var entries: []                 // solo sin fzf: { p, base, rel, m }
    property bool loading: false
    property real loadedAt: 0
    property bool ready: false               // ya hay una lista (aunque este releyendose)
    readonly property string home: Quickshell.env("HOME")
    readonly property string listFile: Quickshell.env("XDG_RUNTIME_DIR") + "/pill-files.tsv"

    function refresh(force) {
        if (loading || (!force && Date.now() - loadedAt < 60000)) return;
        loading = true;
        // Sin dependencias: `find` (siempre esta). Se salta lo oculto (.cache, .config...) y lo de las exclusiones.
        const names = [".*"].concat(Theme.fileSearchExcludes);
        const args = ["sh", "-c", 'f=$1; shift; find "$@" | tee "$f.tmp"; mv -f "$f.tmp" "$f"', "_", listFile, home, "-xdev", "("];
        names.forEach((n, i) => { if (i > 0) args.push("-o"); args.push("-name", n); });
        // linea: ruta relativa, ruta absoluta, fecha de modificacion (separadas por tabulador)
        args.push(")", "-prune", "-o", "-type", "f", "-printf", "%P\\t%p\\t%T@\\n");
        proc.command = args;
        proc.running = true;
    }

    // Sube los archivos de uso frecuente y los modificados hace poco. `hits`: [{ p, m, s }], s = puntos base.
    function boosted(hits, limit) {
        const now = Date.now() / 1000;
        for (const h of hits) {
            const days = Math.max(0, (now - h.m) / 86400);
            h.s += 4 * Math.exp(-days / 14) + AppUsage.boost("file:" + h.p) * 2;
        }
        hits.sort((a, b) => b.s - a.s);
        return hits.slice(0, limit).map(h => h.p);
    }

    // --- Busqueda con fzf (asincrona) ---------------------------------------------------------------------
    // cb(rutas). La consulta ya incluye las variantes con erratas (Logic.typoQuery); fzf ordena y aqui se suman la
    // frecuencia y la recencia.
    function searchFzf(query, limit, cb) {
        Fzf.rankFiles(listFile, Logic.typoQuery(query), lines => {
            const hits = lines.map(l => { const f = l.split("\t"); return { p: f[1], m: parseFloat(f[2]) || 0 }; }).filter(h => h.p);
            cb(boosted(hits.slice(0, 40).map((h, i) => ({ p: h.p, m: h.m, s: 200 - i * 5 })), limit));  // cada posicion de fzf vale 5 puntos: recencia (max 4) y uso solo desempatan
        });
    }

    // --- Busqueda sin fzf (sincrona) ------------------------------------------------------------------------
    function search(query, limit) {
        const terms = Logic.norm(query.trim()).split(/\s+/).filter(t => t !== "");
        if (terms.length === 0 || terms.join("").length < 2) return [];
        let hits = scan(terms, Logic.fuzzyTerms);
        if (hits.length < 3 && terms.join("").length >= 4) hits = hits.concat(scan(terms, Logic.typoTerms, hits));
        return boosted(hits, limit);
    }

    function scan(terms, scorer, already) {
        const skip = {};
        if (already) for (const h of already) skip[h.p] = true;
        const hits = [];
        for (const e of entries) {
            if (skip[e.p]) continue;
            const s = scorer(terms, e.base, e.rel);
            if (s >= 0) hits.push({ s: s, p: e.p, m: e.m });
        }
        return hits;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!Fzf.available) {
                    const list = [];
                    for (const line of text.split("\n")) {
                        const f = line.split("\t");
                        if (f.length < 3) continue;
                        list.push({ p: f[1], base: Logic.norm(Logic.baseName(f[1])), rel: Logic.norm(f[0]), m: parseFloat(f[2]) });
                    }
                    root.entries = list;
                } else root.entries = [];                     // con fzf no hace falta tenerla en memoria
                root.loadedAt = Date.now();
                root.ready = true;
                root.loading = false;
            }
        }
        onExited: root.loading = false
    }
}
