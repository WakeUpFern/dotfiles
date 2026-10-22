import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "LauncherLogic.js" as Logic

// Launcher dentro de la pildora: apps, archivos, cuentas, unidades, web y comandos.
//   Escribir busca en todo a la vez: Aplicaciones, Archivos (por nombre, difuso) y "En documentos"
//   (contenido, via localsearch). Si es una cuenta o una conversion de unidades sale el resultado arriba.
//   Prefijos:  > comando    g/d/yt/w/gh/m texto = busqueda web    f texto = solo archivos    = cuenta
//   Sin texto: Fijadas (cuadricula), Recientes (por uso) o Todas A-Z. Tab cambia de pestana.
//   Enter lanza; Ctrl+Enter = abrir la carpeta / ejecutar en terminal; Ctrl+P fija una app; Esc cierra.
ColumnLayout {
    id: launcher
    signal closeRequested()
    spacing: 8

    readonly property int cols: 5
    readonly property string home: Quickshell.env("HOME")

    property string initialQuery: ""          // consulta con la que se abre (IPC: launcher search)
    property string query: ""
    property string view: PinnedApps.ids.length > 0 ? "pinned" : "all"      // "pinned" | "recent" | "all"
    property int sel: 0

    readonly property bool searching: query.trim() !== ""
    readonly property bool gridMode: !searching && view === "pinned"

    // Se vuelve a comprobar fzf al abrir (por si se instalo con el shell en marcha).
    Component.onCompleted: { Fzf.probe(); FileIndex.refresh(false); if (initialQuery !== "") input.text = initialQuery; }

    // Categorias freedesktop -> como las llamaria uno ("explorador de archivos", "navegador"...).
    readonly property var aliases: ({
        "FileManager": "explorador archivos carpetas files file manager",
        "WebBrowser": "navegador web internet browser",
        "TerminalEmulator": "terminal consola shell",
        "TextEditor": "editor texto notas",
        "Player": "reproductor musica video multimedia",
        "AudioVideo": "audio video multimedia",
        "Settings": "configuracion ajustes preferencias",
        "Monitor": "monitor sistema recursos",
        "Graphics": "imagenes dibujo graficos",
        "Office": "oficina documentos",
        "Email": "correo email mail",
        "Network": "red internet",
        "Development": "programacion desarrollo",
        "Game": "juego juegos"
    })

    // --- Apps -----------------------------------------------------------------------------------------
    // Menor = mejor; -1 = no coincide.
    function termScore(a, t) {
        const n = Logic.norm(a.name);
        if (n.startsWith(t)) return 0;
        if (n.includes(" " + t) || n.includes("-" + t)) return 1;
        if (n.includes(t)) return 2;
        if (Logic.norm(a.genericName).includes(t) || (a.keywords || []).some(k => Logic.norm(k).includes(t))) return 3;
        if ((a.categories || []).some(c => Logic.norm(launcher.aliases[c]).includes(t))) return 3;
        // La descripcion y el id solo cuentan si la palabra empieza ahi (si no, "andar" cuadraba con "standard").
        if ((" " + Logic.norm(a.comment).replace(/[^a-z0-9]+/g, " ")).includes(" " + t)
            || (" " + Logic.norm(a.id).replace(/[^a-z0-9]+/g, " ")).includes(" " + t)) return 4;
        return -1;
    }

    readonly property var allApps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // Apps que coinciden con la consulta, mejores primero (el uso frecuente sube); incluye "ffx" -> Firefox.
    // Version sin fzf (puntuador interno); con fzf se usa appSearchFzf.
    function appSearch(q) {
        const terms = q.split(/\s+/).filter(t => t !== "");
        const out = [];
        for (const a of launcher.allApps) {
            let worst = 0;
            for (const t of terms) {
                const s = launcher.termScore(a, t);
                if (s < 0) { worst = -1; break; }
                worst = Math.max(worst, s);
            }
            if (worst < 0 && terms.length === 1) {
                // Abreviaturas ("ffx" -> Firefox): letras en orden, pero la primera debe abrir una palabra del nombre.
                const nm = Logic.norm(a.name);
                const f = Logic.fuzzy(terms[0], nm);
                if (f >= 6 && (" " + nm).includes(" " + terms[0].charAt(0))) worst = 5;
            }
            if (worst >= 0) out.push({ a: a, s: worst * 3 - AppUsage.boost(a.id) });
        }
        // Erratas ("calude" -> Claude): solo si casi nada coincide.
        if (out.length < 1 && terms.length === 1 && terms[0].length >= 4) {
            for (const a of launcher.allApps) {
                const nm = Logic.norm(a.name);
                if (Logic.typoVariants(terms[0]).some(v => nm.indexOf(v) >= 0)) out.push({ a: a, s: 30 - AppUsage.boost(a.id) });
            }
        }
        out.sort((x, y) => x.s - y.s || x.a.name.localeCompare(y.a.name));
        return out.map(o => o.a);
    }

    // fzf busca solo en el NOMBRE de cada app (y el final de su id): con textos largos las letras sueltas coincidirian
    // por casualidad. Las palabras clave, categorias y alias en espanol ("explorador" -> Files) se resuelven por
    // coincidencia directa (termScore) y se anaden despues. Las apps van en orden de uso (desempata fzf).
    readonly property var appPool: {
        void AppUsage.data;
        return allApps.map(a => ({ a: a, text: a.name + " " + a.id.replace(/^.*\./, "") }))
                      .sort((x, y) => AppUsage.boost(y.a.id) - AppUsage.boost(x.a.id));
    }

    function appSearchFzf(q, cb) {
        const lines = appPool.map((p, i) => i + "\t" + p.text.replace(/\s+/g, " "));
        const toApps = out => out.map(l => appPool[parseInt(l)].a);
        // coincidencias por palabras clave / categorias / descripcion (no por nombre: eso ya lo hace fzf)
        const terms = Logic.norm(q).split(/\s+/).filter(t => t !== "");
        const meta = (known) => {
            const seen = {};
            known.forEach(a => seen[a.id] = true);
            const out = [];
            for (const a of allApps) {
                if (seen[a.id]) continue;
                let worst = 0;
                for (const t of terms) { const s = termScore(a, t); if (s < 0) { worst = -1; break; } worst = Math.max(worst, s); }
                if (worst >= 0) out.push({ a: a, s: worst * 3 - AppUsage.boost(a.id) });
            }
            return out.sort((x, y) => x.s - y.s).map(o => o.a);
        };
        Fzf.rankApps(lines, Logic.typoQuery(q), out => {
            const first = toApps(out);
            cb(first.concat(meta(first)));
        });
    }

    function appRow(a, section) {
        return { kind: "app", title: a.name, sub: "", entry: a, section: section || "",
                 icon: Quickshell.iconPath(a.icon, "application-x-executable") };
    }

    // --- Archivos y documentos ---------------------------------------------------------------------------
    function fileRow(p, section, sub) {
        return { kind: "file", title: Logic.baseName(p), sub: sub || Logic.shortPath(Logic.dirName(p), launcher.home), path: p,
                 section: section, icon: Quickshell.iconPath(Logic.fileIcon(p), "text-x-generic") };
    }

    // Contenido de documentos (localsearch): asincrono; solo vale si sigue siendo la misma consulta.
    property var docHits: []                 // [{ path, snippet }]
    property string docQuery: ""
    Timer { id: docTimer; interval: 280; onTriggered: launcher.runDocSearch() }
    function runDocSearch() {
        const q = launcher.query.trim();
        if (q.length < 3 || docProc.running) { if (q.length >= 3) docTimer.restart(); return; }
        docQuery = q;
        docProc.command = ["localsearch", "search", "--disable-color", "-l", "6"].concat(q.split(/\s+/));
        docProc.running = true;
    }
    Process {
        id: docProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (launcher.docQuery !== launcher.query.trim()) { docTimer.restart(); return; }     // ya cambio: repetir
                const hits = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^\s+file:\/\/(\S+)/);
                    if (!m) continue;
                    let snippet = "";
                    if (i + 1 < lines.length && !/^\s*file:\/\//.test(lines[i + 1])) snippet = lines[i + 1].replace(/\s+/g, " ").trim();
                    let p = m[1];
                    try { p = decodeURIComponent(p); } catch (e) {}
                    hits.push({ path: p, snippet: snippet });
                }
                launcher.docHits = hits;
            }
        }
    }
    // Coincidencias de apps y archivos de la consulta actual. Con fzf llegan de forma asincrona; el "token" descarta
    // respuestas viejas (si tecleaste otra cosa entretanto).
    property var appHits: []
    property var fileHits: []
    property int hitToken: 0
    Timer { id: hitTimer; interval: 45; onTriggered: launcher.refreshHits() }

    function refreshHits() {
        const token = ++hitToken;
        const sp = special;
        if (sp.mode === "cmd" || sp.mode === "url" || sp.mode === "web" || mathQuery || sp.text === "") { appHits = []; fileHits = []; return; }
        const q = sp.text;
        if (sp.mode === "files") appHits = [];
        else if (Fzf.available) appSearchFzf(q, hits => { if (token === launcher.hitToken) launcher.appHits = hits; });
        else appHits = appSearch(Logic.norm(q));
        if (q.trim().length < 2) { fileHits = []; return; }
        const limit = sp.mode === "files" ? 14 : 6;
        if (Fzf.available) FileIndex.searchFzf(q, limit, paths => { if (token === launcher.hitToken) launcher.fileHits = paths; });
        else fileHits = FileIndex.search(q, limit);
    }
    // Al terminar de indexar o de probar fzf, repetir la busqueda en curso.
    Connections { target: FileIndex; function onReadyChanged() { hitTimer.restart(); } function onLoadedAtChanged() { hitTimer.restart(); } }
    Connections { target: Fzf; function onAvailableChanged() { hitTimer.restart(); } }

    onQueryChanged: {
        sel = 0;
        docHits = [];
        hitTimer.restart();
        if (query.trim().length >= 3 && specialMode === "" && !mathQuery) docTimer.restart(); else docTimer.stop();
    }

    // --- Modos especiales y resultados --------------------------------------------------------------------
    // "cmd" (> ...), "web" (g texto), "url", "files" (f texto) o "" (busqueda general).
    readonly property var special: {
        const q = query.trim();
        if (q.charAt(0) === ">") return { mode: "cmd", text: q.slice(1).trim() };
        if (/^(https?:\/\/|www\.)\S+$/i.test(q)) return { mode: "url", text: q };
        const m = q.match(/^(\S+)\s+(.+)$/);
        if (m && Theme.launcherWebSearches[m[1].toLowerCase()]) return { mode: "web", key: m[1].toLowerCase(), text: m[2] };
        if (m && m[1].toLowerCase() === "f") return { mode: "files", text: m[2] };
        return { mode: "", text: q };
    }
    readonly property string specialMode: special.mode
    // Una cuenta o conversion: solo el resultado (nada de archivos ni documentos que mencionen "km").
    readonly property bool mathQuery: special.mode === "" && (Logic.calc(special.text) !== null || Logic.convert(special.text) !== null)

    function webRow(key, text) {
        const w = Theme.launcherWebSearches[key];
        return { kind: "web", title: "Buscar «" + text + "» en " + w.name, sub: "Se abre en el navegador",
                 glyph: "", url: w.url.replace("%s", encodeURIComponent(text)), section: "" };
    }

    readonly property var searchRows: {
        const sp = special;
        const rows = [];
        if (sp.mode === "cmd") {
            if (sp.text !== "")
                rows.push({ kind: "cmd", title: "Ejecutar: " + sp.text, sub: "Enter ejecuta · Ctrl+Enter en una terminal", glyph: "", cmd: sp.text, section: "" });
            return rows;
        }
        if (sp.mode === "url") return [{ kind: "url", title: sp.text, sub: "Abrir en el navegador", glyph: "", url: /^www\./i.test(sp.text) ? "https://" + sp.text : sp.text, section: "" }];
        if (sp.mode === "web") return [webRow(sp.key, sp.text)];
        if (sp.mode === "files") {
            for (const p of fileHits) rows.push(fileRow(p, "Archivos"));
            return rows;
        }

        // Busqueda general: resultado / apps / archivos / documentos.
        const c = Logic.calc(sp.text);
        if (c !== null) rows.push({ kind: "calc", title: "= " + c, sub: sp.text + "  ·  Enter copia el resultado", glyph: "", value: c, section: "Resultado" });
        const u = Logic.convert(sp.text);
        if (u !== null) rows.push({ kind: "calc", title: u.text, sub: "Conversión  ·  Enter copia " + u.value, glyph: "", value: u.value, section: "Resultado" });

        if (rows.length > 0) return rows;                    // cuenta o conversion: solo el resultado

        for (const a of appHits.slice(0, 6)) rows.push(appRow(a, "Aplicaciones"));

        const seen = {};
        for (const p of fileHits) { rows.push(fileRow(p, "Archivos")); seen[p] = true; }
        for (const h of docHits) {
            if (seen[h.path]) continue;
            rows.push(fileRow(h.path, "En documentos", h.snippet !== "" ? h.snippet : undefined));
            if (rows.filter(r => r.section === "En documentos").length >= 4) break;
        }

        if (rows.length === 0 && sp.text.length > 1)
            rows.push(webRow(Theme.launcherDefaultSearch, sp.text));
        return rows;
    }

    // Sin texto: Recientes (por uso) o Todas (A-Z con letras de seccion).
    readonly property var browseRows: {
        if (view === "recent") {
            const out = [];
            for (const id of AppUsage.recentIds(14)) {
                const e = DesktopEntries.byId(id);
                if (e && !e.noDisplay) out.push(appRow(e));
            }
            return out;
        }
        return allApps.map(a => appRow(a, Logic.norm(a.name).charAt(0).toUpperCase()));
    }

    readonly property var rows: searching ? searchRows : browseRows
    readonly property var items: PinnedApps.entries            // cuadricula de fijadas
    readonly property int count: gridMode ? items.length : rows.length

    onViewChanged: sel = 0
    onCountChanged: sel = Math.max(0, Math.min(sel, count - 1))
    onSelChanged: {
        if (gridMode) grid.positionViewAtIndex(sel, GridView.Contain);
        else list.positionViewAtIndex(sel, ListView.Contain);
    }

    // --- Acciones -----------------------------------------------------------------------------------------
    function open(target) { Quickshell.execDetached(["xdg-open", target]); }

    function launchApp(entry) {
        if (!entry) return;
        AppUsage.bump(entry.id);
        entry.execute();
        closeRequested();
    }

    // `alt` = Ctrl: carpeta del archivo / comando en una terminal.
    function activate(row, alt) {
        if (!row) return;
        switch (row.kind) {
        case "app":  launchApp(row.entry); return;
        case "file": AppUsage.bump("file:" + row.path); open(alt ? Logic.dirName(row.path) : row.path); break;
        case "web":
        case "url":  open(row.url); break;
        case "calc": Quickshell.execDetached(["wl-copy", "--", row.value]); break;
        case "cmd":
            if (alt) Quickshell.execDetached(["alacritty", "--hold", "-e", "sh", "-c", row.cmd]);
            else Quickshell.execDetached(["sh", "-c", row.cmd]);
            break;
        }
        closeRequested();
    }

    function activateSel(alt) {
        if (gridMode) launchApp(items[sel]);
        else activate(rows[sel], alt);
    }

    function togglePin(row) { if (row && row.kind === "app") PinnedApps.toggle(row.entry.id); }

    readonly property var views: ["pinned", "recent", "all"]
    function toggleView() { if (!searching) view = views[(views.indexOf(view) + 1) % views.length]; }

    readonly property string hint: {
        if (!searching) return "Tab cambia  ·  clic derecho fija";
        const r = rows[sel];
        if (!r) return "> comando  ·  g texto  ·  f archivos  ·  = cuenta";
        switch (r.kind) {
        case "file": return "Enter abre  ·  Ctrl+Enter la carpeta";
        case "cmd":  return "Enter ejecuta  ·  Ctrl+Enter en terminal";
        case "calc": return "Enter copia el resultado";
        case "web":
        case "url":  return "Enter abre en el navegador";
        default:     return "Enter abre  ·  Ctrl+P fija";
        }
    }

    // --- Busqueda ----------------------------------------------------------------------------------------
    TextInput {
        id: input
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize + 3
        selectionColor: Theme.accent
        focus: true
        onTextChanged: launcher.query = text
        Component.onCompleted: forceActiveFocus()

        Keys.onEscapePressed: launcher.closeRequested()
        Keys.onReturnPressed: e => launcher.activateSel((e.modifiers & Qt.ControlModifier) !== 0)
        Keys.onEnterPressed: e => launcher.activateSel((e.modifiers & Qt.ControlModifier) !== 0)
        Keys.onTabPressed: launcher.toggleView()
        Keys.onDownPressed: launcher.sel = Math.min(launcher.sel + (launcher.gridMode ? launcher.cols : 1), launcher.count - 1)
        Keys.onUpPressed: launcher.sel = Math.max(launcher.sel - (launcher.gridMode ? launcher.cols : 1), 0)
        Keys.onLeftPressed: e => {
            if (launcher.gridMode) launcher.sel = Math.max(launcher.sel - 1, 0);
            else e.accepted = false;
        }
        Keys.onRightPressed: e => {
            if (launcher.gridMode) launcher.sel = Math.min(launcher.sel + 1, launcher.count - 1);
            else e.accepted = false;
        }
        Keys.onPressed: e => {
            if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_P) {
                if (launcher.gridMode) { const it = launcher.items[launcher.sel]; if (it) PinnedApps.toggle(it.id); }
                else launcher.togglePin(launcher.rows[launcher.sel]);
                e.accepted = true;
            }
        }

        Text {
            visible: input.text === ""
            text: "Buscar apps, archivos, cuentas…"
            color: Theme.textDim
            font: input.font
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Pestanas ------------------------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        component Chip: Rectangle {
            id: chip
            property string label
            property bool on: false
            signal clicked()
            implicitWidth: chipText.implicitWidth + 20
            implicitHeight: 24
            radius: 12
            color: on ? Qt.rgba(1, 1, 1, 0.16) : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            Text {
                id: chipText
                anchors.centerIn: parent
                text: chip.label
                color: chip.on ? Theme.text : Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize - 1
            }
            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.clicked()
            }
        }

        Chip { visible: !launcher.searching; label: "Fijadas"; on: launcher.view === "pinned"; onClicked: launcher.view = "pinned" }
        Chip { visible: !launcher.searching; label: "Recientes"; on: launcher.view === "recent"; onClicked: launcher.view = "recent" }
        Chip { visible: !launcher.searching; label: "Todas (" + launcher.allApps.length + ")"; on: launcher.view === "all"; onClicked: launcher.view = "all" }
        Text {
            visible: launcher.searching
            text: launcher.rows.length + (launcher.rows.length === 1 ? " resultado" : " resultados")
                  + (FileIndex.loading && !FileIndex.ready ? "  ·  indexando archivos…" : "")
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
        }
        Item { Layout.fillWidth: true }
        Text {
            text: launcher.hint
            color: Theme.textDim
            opacity: 0.7
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
        }
    }

    // --- Contenido ---------------------------------------------------------------------------------------------
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Fijadas: cuadricula de iconos.
        GridView {
            id: grid
            anchors.fill: parent
            visible: launcher.gridMode
            clip: true
            cellWidth: Math.floor(width / launcher.cols)
            cellHeight: 88
            model: launcher.gridMode ? launcher.items : []
            currentIndex: launcher.sel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                readonly property bool current: index === launcher.sel

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 14
                    color: tile.current ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40; height: 40
                        sourceSize: Qt.size(40, 40)
                        source: Quickshell.iconPath(tile.modelData.icon, "application-x-executable")
                    }
                    Text {
                        width: grid.cellWidth - 14
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: tile.modelData.name
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: launcher.sel = tile.index
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) PinnedApps.toggle(tile.modelData.id);
                        else launcher.launchApp(tile.modelData);
                    }
                }
            }
        }

        // Todas / Recientes / resultados: lista con encabezados de seccion.
        ListView {
            id: list
            anchors.fill: parent
            visible: !launcher.gridMode
            clip: true
            spacing: 2
            model: launcher.gridMode ? [] : launcher.rows
            currentIndex: launcher.sel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Column {
                id: rowItem
                required property var modelData
                required property int index
                width: list.width
                readonly property bool current: index === launcher.sel
                readonly property var r: modelData
                readonly property bool sectionStart: r.section !== "" && (index === 0 || launcher.rows[index - 1].section !== r.section)
                readonly property bool pinned: r.kind === "app" && PinnedApps.ids.indexOf(r.entry.id) >= 0

                Text {
                    visible: rowItem.sectionStart
                    height: visible ? implicitHeight + 8 : 0
                    verticalAlignment: Text.AlignBottom
                    leftPadding: 10
                    text: rowItem.r.section
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: parent.width
                    height: rowItem.r.sub !== "" ? 46 : 40
                    radius: 12
                    color: rowItem.current ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: launcher.sel = rowItem.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (rowItem.r.kind === "file") launcher.activate(rowItem.r, true);
                                else launcher.togglePin(rowItem.r);
                            } else launcher.activate(rowItem.r, (mouse.modifiers & Qt.ControlModifier) !== 0);
                        }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 14
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            Image {
                                anchors.fill: parent
                                visible: rowItem.r.icon !== undefined
                                sourceSize: Qt.size(24, 24)
                                source: rowItem.r.icon !== undefined ? rowItem.r.icon : ""
                            }
                            UiGlyph {
                                anchors.centerIn: parent
                                visible: rowItem.r.glyph !== undefined
                                text: rowItem.r.glyph !== undefined ? rowItem.r.glyph : ""
                                font.pixelSize: 17
                                color: Theme.accent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: rowItem.r.title
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize + 1
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: rowItem.r.sub !== ""
                                text: rowItem.r.sub
                                elide: Text.ElideMiddle
                                color: Theme.textDim
                                font.family: Theme.fontSans
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        // Chincheta (solo apps): fijada = acento; sin fijar solo al pasar el raton.
                        Text {
                            visible: rowItem.r.kind === "app"
                            text: ""
                            font.family: "FontAwesome"
                            font.pixelSize: 14
                            color: rowItem.pinned ? Theme.accent : Theme.textDim
                            opacity: rowItem.pinned ? 1 : (rowItem.current ? 0.8 : 0)
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: launcher.togglePin(rowItem.r)
                            }
                        }
                    }
                }
            }
        }

        // Estados vacios
        Text {
            anchors.centerIn: parent
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: launcher.count === 0
            text: launcher.searching ? "Nada coincide con \"" + launcher.query.trim() + "\""
                : (launcher.view === "recent" ? "Aún no has abierto ninguna app desde aquí."
                                              : "Aún no hay apps fijadas.\nEn \"Todas\", clic derecho en una app para fijarla.")
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // Energia: bloquear, suspender, reiniciar, apagar, cerrar sesion.
    // Las destructivas piden un segundo click para confirmar.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            Layout.fillWidth: true
            readonly property var armed: PowerActions.byId(PowerActions.armedId)
            text: armed ? armed.label + ": click otra vez para confirmar" : "Mod+Shift+E  menú de apagado"
            color: armed ? Theme.urgent : Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
            elide: Text.ElideRight
        }

        Repeater {
            model: PowerActions.actions
            delegate: PowerButton {
                required property var modelData
                action: modelData
                compact: true
                onDone: launcher.closeRequested()
            }
        }
    }
}
