import QtQuick
import QtQuick.Layouts

// Menu de apagado del notch (Mod+Shift+E). Teclado: flechas/Tab mueven, Enter
// elige (las destructivas piden Enter otra vez), Esc cierra; atajos directos
// L S R P E. Con el raton: click (y click otra vez para confirmar).
FocusScope {
    id: root

    signal closeRequested()

    property int index: 3          // empieza en "Apagar"
    implicitHeight: col.implicitHeight

    Component.onCompleted: { PowerActions.disarm(); forceActiveFocus(); }
    Component.onDestruction: PowerActions.disarm()

    Keys.onPressed: event => {
        const n = PowerActions.actions.length;
        if (event.key === Qt.Key_Escape) { root.closeRequested(); event.accepted = true; return; }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { index = (index + 1) % n; PowerActions.disarm(); event.accepted = true; return; }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { index = (index + n - 1) % n; PowerActions.disarm(); event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            repeater.itemAt(index).trigger();
            event.accepted = true;
            return;
        }
        const i = PowerActions.actions.findIndex(a => a.key === event.text.toLowerCase());
        if (i >= 0) { index = i; repeater.itemAt(i).trigger(); event.accepted = true; }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Repeater {
                id: repeater
                model: PowerActions.actions
                delegate: PowerButton {
                    required property int index
                    required property var modelData
                    action: modelData
                    selected: index === root.index
                    onDone: root.closeRequested()
                    HoverHandler { onHoveredChanged: if (hovered) root.index = parent.index }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "← →  mover   ·   Enter  elegir   ·   Esc  cerrar"
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize - 2
        }
    }
}
