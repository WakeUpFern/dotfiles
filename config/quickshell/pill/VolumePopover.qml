import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Pagina de Sonido: salidas, volumen por aplicacion y microfono (el volumen y el brillo estan en el inicio del panel).
ColumnLayout {
    id: root
    spacing: 16

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    PwObjectTracker { objects: root.sinks }

    // --- Salidas -------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        // Salidas de audio: click para cambiar.
        Repeater {
            model: root.sinks
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool current: root.sink && modelData.id === root.sink.id
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: 10
                color: current ? Qt.rgba(1, 1, 1, 0.12) : (rowArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                UiLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: (row.current ? "● " : "○ ") + (row.modelData.description || row.modelData.name)
                    color: row.current ? Theme.text : Theme.textDim
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSink = row.modelData
                }
            }
        }
    }


    // --- Aplicaciones (volumen por app) y microfono ---------------------------
    AppMixer { Layout.fillWidth: true }
    MicControl { Layout.fillWidth: true }
}
