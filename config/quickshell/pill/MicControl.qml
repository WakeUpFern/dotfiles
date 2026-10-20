import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Microfono: volumen y silencio del predeterminado, quien lo esta usando, y elegir otra entrada.
ColumnLayout {
    id: root
    spacing: 8
    visible: AudioStreams.sources.length > 0

    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool muted: mic && mic.audio ? mic.audio.muted : false
    property bool listOpen: false

    UiLabel {
        text: "Micrófono"
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        UiGlyph {
            Layout.preferredWidth: 22
            text: root.muted ? "" : ""
            font.pixelSize: 17
            color: root.muted ? Theme.urgent : (AudioStreams.micInUse ? Theme.warn : Theme.text)
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.mic && root.mic.audio) root.mic.audio.muted = !root.mic.audio.muted
            }
        }
        // Nombre de la entrada (click = desplegar las demas)
        UiLabel {
            Layout.preferredWidth: 96
            text: root.mic ? (root.mic.description || root.mic.name) : "Sin micrófono"
            elide: Text.ElideRight
            font.pixelSize: Theme.fontSize - 1
            color: Theme.textDim
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                enabled: AudioStreams.sources.length > 1
                onClicked: root.listOpen = !root.listOpen
            }
        }
        Slider {
            Layout.fillWidth: true
            value: root.mic && root.mic.audio ? root.mic.audio.volume : 0
            dimmed: root.muted
            onMoved: v => { if (root.mic && root.mic.audio) { root.mic.audio.muted = false; root.mic.audio.volume = v; } }
        }
        UiLabel {
            text: root.mic && root.mic.audio ? Math.round(root.mic.audio.volume * 100) : "-"
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    // Quien tiene el micrófono abierto
    UiLabel {
        visible: AudioStreams.micInUse
        Layout.fillWidth: true
        text: "En uso: " + AudioStreams.micUsers
        color: Theme.warn
        font.pixelSize: Theme.fontSize - 2
        elide: Text.ElideRight
    }

    // Otras entradas
    Repeater {
        model: root.listOpen ? AudioStreams.sources : []
        delegate: Rectangle {
            id: src
            required property var modelData
            readonly property bool current: root.mic && modelData.id === root.mic.id
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: 10
            color: current ? Qt.rgba(1, 1, 1, 0.12) : (srcArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }
            UiLabel {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 10; anchors.rightMargin: 10
                text: (src.current ? "● " : "○ ") + (src.modelData.description || src.modelData.name)
                color: src.current ? Theme.text : Theme.textDim
                elide: Text.ElideRight
            }
            MouseArea {
                id: srcArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { Pipewire.preferredDefaultAudioSource = src.modelData; }
            }
        }
    }
}
