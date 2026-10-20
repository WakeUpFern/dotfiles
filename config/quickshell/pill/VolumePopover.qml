import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Menu de volumen: deslizador, salidas de audio y brillo de pantalla.
ColumnLayout {
    id: root
    spacing: 16

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    PwObjectTracker { objects: root.sinks }

    // --- Volumen -------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            UiLabel {
                text: root.sink && root.sink.audio && root.sink.audio.muted ? "mute" : "vol"
                color: Theme.textDim
                Layout.preferredWidth: 34
                Behavior on color { ColorAnimation { duration: 200 } }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
                }
            }
            Slider {
                Layout.fillWidth: true
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                dimmed: root.sink && root.sink.audio ? root.sink.audio.muted : false
                onMoved: v => { if (root.sink && root.sink.audio) { root.sink.audio.muted = false; root.sink.audio.volume = v; } }
            }
            UiLabel {
                text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) : "-"
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
            }
        }

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


    // --- Brillo --------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: Brightness.available
        spacing: 12
        UiLabel {
            text: "luz"
            color: Theme.textDim
            Layout.preferredWidth: 34
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Slider {
            Layout.fillWidth: true
            value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
        UiLabel {
            text: Math.round(Brightness.level * 100)
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

}
