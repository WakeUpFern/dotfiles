import QtQuick
import QtQuick.Layouts
import Quickshell

// Selector de emoji dentro del notch (Mod+;). Escribe para buscar (en espanol o ingles), flechas
// para moverte, Enter elige, Tab cambia de categoria, Esc cierra. El emoji se copia y, si esta
// instalado `wtype`, se escribe tambien en la app que tenias enfocada.
FocusScope {
    id: root
    signal closeRequested()

    readonly property int cols: 9
    property string category: EmojiData.recent.length > 0 ? "recent" : "0"     // "recent" | indice de grupo
    property string query: ""
    property int sel: 0
    property bool copied: false

    readonly property var tabs: [{ id: "recent", icon: "🕘" }].concat(
        ["😀", "👋", "🐵", "🍇", "🌍", "🎃", "👓", "🏧", "🏁"].map((e, i) => ({ id: String(i), icon: e })))
    readonly property bool searching: query.trim() !== ""

    readonly property var items: {
        if (searching) {
            const terms = EmojiData.norm(query).split(/\s+/).filter(t => t !== "");
            const out = [];
            for (const e of EmojiData.entries) {
                let s = 9, ok = true;
                for (const t of terms) {
                    const i = e.hay.indexOf(t);
                    if (i < 0) { ok = false; break; }
                    s = Math.min(s, i === 0 ? 0 : (e.hay.charAt(i - 1) === " " ? 1 : 2));
                }
                if (ok) out.push({ e: e, s: s });
            }
            out.sort((a, b) => a.s - b.s);
            return out.map(o => o.e);
        }
        if (category === "recent") return EmojiData.recentEntries();
        const g = parseInt(category);
        return EmojiData.entries.filter(e => e.group === g);
    }

    onQueryChanged: sel = 0
    onCategoryChanged: sel = 0
    onItemsChanged: sel = Math.max(0, Math.min(sel, items.length - 1))
    onSelChanged: grid.positionViewAtIndex(sel, GridView.Contain)

    function pick(e) {
        if (!e || copied) return;
        const text = EmojiData.render(e);
        EmojiData.use(e);
        Quickshell.execDetached(["sh", "-c", 'wl-copy -- "$1"; command -v wtype >/dev/null && { sleep 0.25; wtype -- "$1"; }', "_", text]);
        copied = true;
        closeTimer.start();
    }
    Timer { id: closeTimer; interval: EmojiData.hasWtype ? 80 : 450; onTriggered: root.closeRequested() }

    function nextTab() {
        const i = tabs.findIndex(t => t.id === category);
        category = tabs[(i + 1) % tabs.length].id;
    }

    // Se vuelve a comprobar wtype al abrir (por si se instalo con el shell ya en marcha).
    Component.onCompleted: { input.forceActiveFocus(); EmojiData.probeTools(); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextInput {
            id: input
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize + 3
            selectionColor: Theme.accent
            focus: true
            onTextChanged: root.query = text

            Keys.onEscapePressed: root.closeRequested()
            Keys.onReturnPressed: root.pick(root.items[root.sel])
            Keys.onTabPressed: if (!root.searching) root.nextTab()
            Keys.onDownPressed: root.sel = Math.min(root.sel + root.cols, root.items.length - 1)
            Keys.onUpPressed: root.sel = Math.max(root.sel - root.cols, 0)
            Keys.onLeftPressed: root.sel = Math.max(root.sel - 1, 0)
            Keys.onRightPressed: root.sel = Math.min(root.sel + 1, root.items.length - 1)

            Text {
                visible: input.text === ""
                text: "Buscar emoji… (nombre o palabra clave)"
                color: Theme.textDim
                font: input.font
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // Categorias
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: !root.searching
            Repeater {
                model: root.tabs
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool active: root.category === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 30
                    radius: 10
                    color: active ? Qt.rgba(1, 1, 1, 0.16) : (tabArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: tab.modelData.icon
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 16
                        opacity: tab.active ? 1 : 0.65
                    }
                    MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.category = tab.modelData.id }
                }
            }
        }
        UiLabel {
            visible: root.searching
            Layout.preferredHeight: 30
            verticalAlignment: Text.AlignVCenter
            text: root.items.length + (root.items.length === 1 ? " resultado" : " resultados")
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 1
        }

        // Cuadricula
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / root.cols)
                cellHeight: 46
                model: root.items
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 10
                        color: cell.index === root.sel ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: EmojiData.render(cell.modelData)
                        font.family: "Noto Color Emoji"
                        font.pixelSize: 26
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.sel = cell.index
                        onClicked: root.pick(cell.modelData)
                    }
                }
            }

            UiLabel {
                anchors.centerIn: parent
                visible: root.items.length === 0
                color: Theme.textDim
                text: root.searching ? "Ningún emoji coincide" : "Aún no has usado ningún emoji"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // Pie: nombre del emoji, aviso de copiado y tono de piel
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            spacing: 10
            UiLabel {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSize - 1
                color: root.copied ? Theme.accent : Theme.textDim
                text: root.copied ? (EmojiData.hasWtype ? "Escrito ✓" : "Copiado ✓  pega con Ctrl+V")
                                  : (root.items.length > 0 && root.items[root.sel] ? root.items[root.sel].name : "Tab cambia de categoría  ·  Enter elige")
            }
            // Tono de piel (solo afecta a los emoji que lo admiten)
            Repeater {
                model: ["#ffcc33", "#f7d7c4", "#d8b094", "#b78a66", "#8a5a3b", "#5b3a29"]
                delegate: Rectangle {
                    id: dot
                    required property string modelData
                    required property int index
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: modelData
                    border.width: EmojiData.tone === index ? 2 : 0
                    border.color: Theme.accent
                    scale: dotArea.containsMouse ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                    MouseArea { id: dotArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: EmojiData.setTone(dot.index) }
                }
            }
        }
    }
}
