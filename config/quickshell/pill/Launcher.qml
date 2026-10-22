import QtQuick
import QtQuick.Layouts
import Quickshell

// Launcher dentro de la pildora. Escribir busca en todas las apps (nombre, descripcion, palabras
// clave y alias en espanol); sin texto muestra las apps fijadas (cuadricula) o la lista completa
// A-Z. Tab alterna, clic derecho / Ctrl+P fija o desfija, Esc cierra, Enter lanza.
ColumnLayout {
    id: launcher
    signal closeRequested()
    spacing: 8

    readonly property int cols: 5

    property string query: ""
    property string view: PinnedApps.ids.length > 0 ? "pinned" : "all"      // "pinned" | "all"
    property int sel: 0

    readonly property bool searching: query.trim() !== ""
    readonly property bool gridMode: !searching && view === "pinned"

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

    function norm(s) {
        s = (s || "").toLowerCase();
        try { return s.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) { return s; }
    }

    // Menor = mejor; -1 = no coincide.
    function termScore(a, t) {
        const n = norm(a.name);
        if (n.startsWith(t)) return 0;
        if (n.includes(" " + t) || n.includes("-" + t)) return 1;
        if (n.includes(t)) return 2;
        if (norm(a.genericName).includes(t) || (a.keywords || []).some(k => norm(k).includes(t))) return 3;
        if ((a.categories || []).some(c => norm(launcher.aliases[c]).includes(t))) return 3;
        if (norm(a.comment).includes(t) || norm(a.id).includes(t)) return 4;
        return -1;
    }

    function search(q) {
        const terms = q.split(/\s+/).filter(t => t !== "");
        const out = [];
        for (const a of launcher.allApps) {
            let worst = 0;
            for (const t of terms) {
                const s = launcher.termScore(a, t);
                if (s < 0) { worst = -1; break; }
                worst = Math.max(worst, s);
            }
            if (worst >= 0) out.push({ a: a, s: worst });
        }
        out.sort((x, y) => x.s - y.s || x.a.name.localeCompare(y.a.name));
        return out.map(o => o.a);
    }

    readonly property var allApps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var items: {
        if (searching) return search(norm(query).trim());
        return view === "pinned" ? PinnedApps.entries : allApps;
    }

    onQueryChanged: sel = 0
    onViewChanged: sel = 0
    onItemsChanged: sel = Math.max(0, Math.min(sel, items.length - 1))
    onSelChanged: {
        if (gridMode) grid.positionViewAtIndex(sel, GridView.Contain);
        else list.positionViewAtIndex(sel, ListView.Contain);
    }

    function launch(entry) {
        if (!entry) return;
        entry.execute();
        closeRequested();
    }

    function toggleView() { if (!searching) view = view === "pinned" ? "all" : "pinned"; }

    // --- Busqueda ----------------------------------------------------------------------
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
        Keys.onReturnPressed: launcher.launch(launcher.items[launcher.sel])
        Keys.onTabPressed: launcher.toggleView()
        Keys.onDownPressed: launcher.sel = Math.min(launcher.sel + (launcher.gridMode ? launcher.cols : 1), launcher.items.length - 1)
        Keys.onUpPressed: launcher.sel = Math.max(launcher.sel - (launcher.gridMode ? launcher.cols : 1), 0)
        Keys.onLeftPressed: e => {
            if (launcher.gridMode) launcher.sel = Math.max(launcher.sel - 1, 0);
            else e.accepted = false;
        }
        Keys.onRightPressed: e => {
            if (launcher.gridMode) launcher.sel = Math.min(launcher.sel + 1, launcher.items.length - 1);
            else e.accepted = false;
        }
        Keys.onPressed: e => {
            if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_P) {
                const it = launcher.items[launcher.sel];
                if (it) PinnedApps.toggle(it.id);
                e.accepted = true;
            }
        }

        Text {
            visible: input.text === ""
            text: "Buscar aplicaciones..."
            color: Theme.textDim
            font: input.font
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Pestanas (Fijadas / Todas) ----------------------------------------------------------
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

        Chip {
            visible: !launcher.searching
            label: "Fijadas"
            on: launcher.view === "pinned"
            onClicked: launcher.view = "pinned"
        }
        Chip {
            visible: !launcher.searching
            label: "Todas (" + launcher.allApps.length + ")"
            on: launcher.view === "all"
            onClicked: launcher.view = "all"
        }
        Text {
            visible: launcher.searching
            text: launcher.items.length + (launcher.items.length === 1 ? " resultado" : " resultados")
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 1
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "Tab alterna  ·  clic derecho fija"
            color: Theme.textDim
            opacity: 0.7
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
        }
    }

    // --- Contenido ---------------------------------------------------------------------------
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
                        else launcher.launch(tile.modelData);
                    }
                }
            }
        }

        // Todas / resultados: lista con letras de seccion.
        ListView {
            id: list
            anchors.fill: parent
            visible: !launcher.gridMode
            clip: true
            spacing: 2
            model: launcher.gridMode ? [] : launcher.items
            currentIndex: launcher.sel
            boundsBehavior: Flickable.StopAtBounds

            delegate: Column {
                id: rowItem
                required property var modelData
                required property int index
                width: list.width
                readonly property bool current: index === launcher.sel
                readonly property string letter: launcher.norm(modelData.name).charAt(0).toUpperCase()
                readonly property bool sectionStart: !launcher.searching && launcher.view === "all"
                    && (index === 0 || launcher.norm(launcher.items[index - 1].name).charAt(0).toUpperCase() !== letter)
                readonly property bool pinned: PinnedApps.ids.indexOf(modelData.id) >= 0

                Text {
                    visible: rowItem.sectionStart
                    height: visible ? implicitHeight + 8 : 0
                    verticalAlignment: Text.AlignBottom
                    leftPadding: 10
                    text: rowItem.letter
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 1
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 12
                    color: rowItem.current ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: launcher.sel = rowItem.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) PinnedApps.toggle(rowItem.modelData.id);
                            else launcher.launch(rowItem.modelData);
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        spacing: 12
                        Image {
                            width: 24; height: 24
                            sourceSize: Qt.size(24, 24)
                            source: Quickshell.iconPath(rowItem.modelData.icon, "application-x-executable")
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowItem.modelData.name
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontSize + 1
                        }
                    }
                    // Chincheta: fijada = acento; sin fijar solo se ve al pasar el raton.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 14
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
                            onClicked: PinnedApps.toggle(rowItem.modelData.id)
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
            visible: launcher.items.length === 0
            text: launcher.searching ? "Nada coincide con \"" + launcher.query.trim() + "\""
                                     : "Aún no hay apps fijadas.\nEn \"Todas\", clic derecho en una app para fijarla."
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
