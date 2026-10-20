import QtQuick
import QtQuick.Layouts
import QtQml.Models
import Quickshell
import Quickshell.Io

// Historial del portapapeles (cliphist) dentro del notch. Teclado: escribe para
// filtrar, Arriba/Abajo mueven, Enter copia, Supr borra la entrada, Esc cierra.
// Click en una tarjeta la copia; la "x" la borra.
FocusScope {
    id: root

    signal closeRequested()

    property string query: ""
    property var entries: []                       // [{ id, preview, image, meta, mime }]
    readonly property var results: {
        const q = query.trim().toLowerCase();
        return q === "" ? entries : entries.filter(e => e.preview.toLowerCase().includes(q));
    }

    readonly property string cacheDir: Quickshell.env("XDG_RUNTIME_DIR") + "/pill-clip"

    function refresh() { listProc.running = true; }

    function pick(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c",
            e.image ? 'cliphist decode "$1" | wl-copy --type "$2"' : 'cliphist decode "$1" | wl-copy',
            "_", e.id, e.mime]);
        closeRequested();
    }

    function remove(e) {
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "_", e.id]);
        refreshSoon.restart();
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        refreshSoon.restart();
    }

    Timer { id: refreshSoon; interval: 180; onTriggered: root.refresh() }

    // "Borrar todo" pide un segundo click (3 s), igual que apagar/reiniciar.
    property bool wipeArmed: false
    Timer { id: wipeTimer; interval: 3000; onTriggered: root.wipeArmed = false }

    Component.onCompleted: { refresh(); input.forceActiveFocus(); }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab), prev = line.slice(tab + 1);
                    const m = prev.match(/^\[\[ binary data (.+?) (png|jpg|jpeg|bmp|gif|webp) (\d+x\d+) \]\]$/);
                    out.push({
                        id: id, preview: prev, image: !!m,
                        meta: m ? m[1] + "  ·  " + m[3] : "",
                        mime: m ? "image/" + (m[2] === "jpg" ? "jpeg" : m[2]) : "text/plain"
                    });
                    if (out.length >= 300) break;
                }
                root.entries = out;
                list.currentIndex = 0;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // --- Cabecera: buscador + borrar todo ------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                radius: 21
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Theme.textDim
                    font.family: "FontAwesome"
                    font.pixelSize: 15
                }
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 42
                    anchors.rightMargin: 16
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 2
                    selectionColor: Theme.accent
                    clip: true
                    focus: true
                    onTextChanged: { root.query = text; list.currentIndex = 0; }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) { root.closeRequested(); }
                        else if (event.key === Qt.Key_Down) { list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1); }
                        else if (event.key === Qt.Key_Up) { list.currentIndex = Math.max(list.currentIndex - 1, 0); }
                        else if (event.key === Qt.Key_PageDown) { list.currentIndex = Math.min(list.currentIndex + 5, list.count - 1); }
                        else if (event.key === Qt.Key_PageUp) { list.currentIndex = Math.max(list.currentIndex - 5, 0); }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.pick(root.results[list.currentIndex]); }
                        else if (event.key === Qt.Key_Delete) { root.remove(root.results[list.currentIndex]); }
                        else return;
                        event.accepted = true;
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Buscar en el portapapeles..."
                        color: Theme.textDim
                        font: input.font
                    }
                }
            }

            Rectangle {
                id: wipeBtn
                Layout.preferredWidth: wipeText.implicitWidth + 32
                Layout.preferredHeight: 42
                radius: 21
                color: root.wipeArmed ? Theme.urgent : (wipeArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                scale: wipeArea.pressed ? 0.93 : 1
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Text {
                    id: wipeText
                    anchors.centerIn: parent
                    text: root.wipeArmed ? "¿Seguro?" : "Borrar todo"
                    color: root.wipeArmed ? "white" : Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                }
                MouseArea {
                    id: wipeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.wipeArmed) { root.wipeArmed = true; wipeTimer.restart(); }
                        else { root.wipeArmed = false; wipeTimer.stop(); root.wipe(); }
                    }
                }
            }
        }

        // --- Lista ------------------------------------------------------------------
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: ScriptModel { values: root.results }
            currentIndex: 0
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            // Las tarjetas entran en cascada con rebote.
            populate: Transition {
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PropertyAction { property: "scale"; value: 0.88 }
                    PauseAnimation { duration: Math.min(ViewTransition.index, 10) * 32 }
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; to: 1; duration: 160 }
                        NumberAnimation { property: "scale"; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                    }
                }
            }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
                    NumberAnimation { property: "scale"; from: 0.88; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                }
            }
            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                    NumberAnimation { property: "scale"; to: 0.85; duration: 200; easing.type: Easing.InBack }
                }
            }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index

                readonly property bool current: ListView.isCurrentItem
                readonly property string thumb: root.cacheDir + "/" + modelData.id + ".img"
                property bool thumbReady: false

                width: list.width
                height: (modelData.image ? 132 : Math.max(52, textBlock.implicitHeight + 24))
                radius: 18
                color: current ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
                border.width: current ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.20)
                Behavior on color { ColorAnimation { duration: 120 } }

                // Miniatura de imagenes: se decodifica a un archivo la primera vez.
                Process {
                    running: card.modelData.image
                    command: ["sh", "-c", 'mkdir -p "$2" && { [ -s "$3" ] || cliphist decode "$1" > "$3"; }',
                              "_", card.modelData.id, root.cacheDir, card.thumb]
                    onExited: card.thumbReady = true
                }

                // Texto
                Text {
                    id: textBlock
                    visible: !card.modelData.image
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 44
                    text: card.modelData.preview
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 1
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                // Imagen
                Row {
                    visible: card.modelData.image
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 14
                    Rectangle {
                        width: 150
                        height: parent.height
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.06)
                        clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize: Qt.size(300, 220)
                            source: card.thumbReady ? "file://" + card.thumb : ""
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: "Imagen"; color: Theme.text; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize + 1; font.weight: Font.DemiBold }
                        Text { text: card.modelData.meta; color: Theme.textDim; font.family: Theme.fontSans; font.pixelSize: Theme.fontSize - 1 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = card.index
                    onClicked: root.pick(card.modelData)
                }

                // "x" para borrar la entrada (visible al seleccionar).
                Text {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 14
                    text: "✕"
                    color: delArea.containsMouse ? Theme.urgent : Theme.textDim
                    font.pixelSize: 13
                    opacity: card.current ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    MouseArea {
                        id: delArea
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.remove(card.modelData)
                    }
                }
            }
        }

        // --- Pie ----------------------------------------------------------------------
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.results.length === 0
                ? (root.entries.length === 0 ? "Aún no hay nada copiado" : "Sin resultados")
                : "Enter copiar   ·   Supr borrar   ·   ↑ ↓ mover   ·   Esc cerrar"
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
