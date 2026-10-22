import QtQuick
import QtQuick.Layouts
import Quickshell

// Pagina de Luz nocturna: modo (apagada / programada / ahora), temperatura y horario.
ColumnLayout {
    id: root
    spacing: 14

    property string scheduleError: ""

    function applySchedule() {
        if (NightLight.setSchedule(fromField.text.trim(), toField.text.trim())) scheduleError = "";
        else scheduleError = "Usa el formato HH:MM (por ejemplo 20:00)";
    }

    // Modo
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [
                { id: "off",  label: "Apagada" },
                { id: "auto", label: "Programada" },
                { id: "on",   label: "Ahora" }
            ]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool active: NightLight.mode === modelData.id
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.preferredHeight: 32
                radius: 16
                color: active ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                Behavior on color { ColorAnimation { duration: 150 } }
                UiLabel {
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.active ? "#0b1020" : Theme.text
                    font.weight: chip.active ? Font.DemiBold : Font.Normal
                }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NightLight.setMode(chip.modelData.id) }
            }
        }
    }

    // Temperatura (mas a la derecha = mas calido)
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Intensidad"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8; Layout.fillWidth: true }
            UiLabel { text: NightLight.temperature + " K"; color: Theme.textDim }
        }
        Slider {
            Layout.fillWidth: true
            // 6000 K (casi sin tinte) a la izquierda, 2500 K (muy calido) a la derecha.
            value: (6000 - NightLight.temperature) / 3500
            onMoved: v => NightLight.setTemperature(6000 - v * 3500)
        }
    }

    // Horario
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        opacity: NightLight.mode === "auto" ? 1 : 0.55
        UiLabel { text: "Horario"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 2; font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            UiLabel { text: "De"; color: Theme.textDim }
            Field { id: fromField; text: NightLight.from; maximumLength: 5; placeholder: "20:00"; onAccepted: root.applySchedule() }
            UiLabel { text: "a"; color: Theme.textDim }
            Field { id: toField; text: NightLight.to; maximumLength: 5; placeholder: "07:00"; onAccepted: root.applySchedule() }
            Btn { label: "Aplicar"; primary: false; onClicked: root.applySchedule() }
        }
        UiLabel {
            visible: root.scheduleError !== ""
            text: root.scheduleError
            color: Theme.urgent
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
