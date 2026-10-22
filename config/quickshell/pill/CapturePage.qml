import QtQuick
import QtQuick.Layouts
import Quickshell

// Pagina de Captura (Mod+Shift+S): seleccion / ventana / pantalla, retardo y puntero, y grabacion.
ColumnLayout {
    id: root
    spacing: 14
    signal closeRequested()

    component Big: Rectangle {
        id: big
        property string glyph
        property string label
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 84
        radius: 18
        color: bigArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: bigArea.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            UiGlyph { Layout.alignment: Qt.AlignHCenter; text: big.glyph; font.pixelSize: 24 }
            UiLabel { Layout.alignment: Qt.AlignHCenter; text: big.label }
        }
        MouseArea { id: bigArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: big.clicked() }
    }

    // Se vuelve a comprobar al abrir: asi detecta wf-recorder recien instalado sin reiniciar el shell.
    Component.onCompleted: ScreenCapture.load()

    function shoot(kind) { ScreenCapture.shoot(kind); closeRequested(); }

    // --- Capturas -------------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Big { glyph: ""; label: "Selección"; onClicked: root.shoot("area") }
        Big { glyph: ""; label: "Ventana"; onClicked: root.shoot("window") }
        Big { glyph: ""; label: "Pantalla"; onClicked: root.shoot("screen") }
    }

    // Retardo y puntero
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        UiLabel { text: "Retardo"; color: Theme.textDim; Layout.rightMargin: 4 }
        Repeater {
            model: [0, 3, 5, 10]
            delegate: Rectangle {
                id: chip
                required property int modelData
                readonly property bool active: ScreenCapture.delay === modelData
                Layout.preferredHeight: 28
                Layout.preferredWidth: chipText.implicitWidth + 22
                radius: 14
                color: active ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                Behavior on color { ColorAnimation { duration: 150 } }
                UiLabel { id: chipText; anchors.centerIn: parent; text: chip.modelData === 0 ? "Ya" : chip.modelData + " s"; color: chip.active ? "#0b1020" : Theme.text; font.pixelSize: Theme.fontSize - 1 }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ScreenCapture.delay = chip.modelData }
            }
        }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        Layout.fillWidth: true
        UiLabel { Layout.fillWidth: true; text: "Incluir el puntero"; color: Theme.textDim }
        ToggleSwitch { checked: ScreenCapture.pointer; onToggled: ScreenCapture.pointer = !ScreenCapture.pointer }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Grabacion --------------------------------------------------------------------------------
    UiLabel {
        text: "Grabación de pantalla"
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    RowLayout {
        visible: ScreenCapture.hasRecorder && !ScreenCapture.recording
        Layout.fillWidth: true
        spacing: 8
        Btn { primary: false; label: "Grabar pantalla"; onClicked: { ScreenCapture.record(false); root.closeRequested(); } }
        Btn { primary: false; label: "Grabar selección"; onClicked: { ScreenCapture.record(true); root.closeRequested(); } }
        Item { Layout.fillWidth: true }
    }
    RowLayout {
        visible: ScreenCapture.recording
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            width: 10; height: 10; radius: 5; color: Theme.urgent
            SequentialAnimation on opacity { loops: Animation.Infinite; running: ScreenCapture.recording
                NumberAnimation { to: 0.3; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
        }
        UiLabel { Layout.fillWidth: true; text: "Grabando  " + ScreenCapture.elapsedText }
        Btn { label: "Detener"; onClicked: ScreenCapture.stop() }
    }
    UiLabel {
        visible: !ScreenCapture.hasRecorder
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 1
        text: "Para grabar instala wf-recorder y slurp:  sudo apt install wf-recorder slurp"
    }

    UiLabel {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "Se guardan en ~/Pictures/Screenshots y se copian al portapapeles."
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
    }
    RowLayout {
        Layout.fillWidth: true
        Btn { primary: false; label: "Abrir carpeta de capturas"; onClicked: { ScreenCapture.openFolder(); root.closeRequested(); } }
        Item { Layout.fillWidth: true }
    }
}
