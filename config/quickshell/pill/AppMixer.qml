import QtQuick
import QtQuick.Layouts
import Quickshell

// Volumen por aplicacion: una fila por app que este reproduciendo audio ahora mismo.
ColumnLayout {
    id: root
    spacing: 8
    visible: AudioStreams.apps.length > 0

    UiLabel {
        text: "Aplicaciones"
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.8
    }

    Repeater {
        model: AudioStreams.apps.slice(0, 6)

        delegate: RowLayout {
            id: row
            required property var modelData
            readonly property bool muted: AudioStreams.groupMuted(modelData)
            Layout.fillWidth: true
            spacing: 12

            Image {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                sourceSize: Qt.size(44, 44)
                source: Quickshell.iconPath(row.modelData.icon !== "" ? row.modelData.icon : "audio-x-generic", "audio-x-generic")
                opacity: row.muted ? 0.45 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                // Click en el icono = silenciar solo esa app.
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioStreams.toggleGroupMute(row.modelData)
                }
            }
            ColumnLayout {
                Layout.preferredWidth: 96
                spacing: 0
                UiLabel {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                    color: row.muted ? Theme.textDim : Theme.text
                    font.pixelSize: Theme.fontSize - 1
                }
                UiLabel {
                    visible: row.modelData.nodes.length > 1
                    text: row.modelData.nodes.length + " flujos"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 3
                }
            }
            Slider {
                Layout.fillWidth: true
                value: AudioStreams.groupVolume(row.modelData)
                dimmed: row.muted
                onMoved: v => AudioStreams.setGroupVolume(row.modelData, v)
            }
            UiLabel {
                text: Math.round(AudioStreams.groupVolume(row.modelData) * 100)
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                color: row.muted ? Theme.textDim : Theme.text
            }
        }
    }
}
