import QtQuick
import QtQuick.Layouts
import Quickshell

// Volumen por aplicacion: una fila por app que este reproduciendo audio ahora mismo.
ColumnLayout {
    id: root
    spacing: 8
    readonly property bool canMove: AudioStreams.sinks.length > 1
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

        delegate: ColumnLayout {
            id: item
            required property var modelData
            property bool open: false
            Layout.fillWidth: true
            spacing: 4

          RowLayout {
            id: row
            property var modelData: item.modelData
            readonly property bool muted: AudioStreams.groupMuted(modelData)
            readonly property var sink: AudioStreams.groupSink(modelData)
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
                Layout.preferredWidth: 132
                spacing: 0
                UiLabel {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                    color: row.muted ? Theme.textDim : Theme.text
                    font.pixelSize: Theme.fontSize - 1
                }
                // Salida actual; con mas de una salida, un clic abre la lista para moverla.
                UiLabel {
                    Layout.fillWidth: true
                    text: (root.canMove ? (item.open ? "▾ " : "▸ ") : "") + (row.sink ? (row.sink.description || row.sink.name) : "—")
                        + (row.modelData.nodes.length > 1 ? "  ·  " + row.modelData.nodes.length + " flujos" : "")
                    elide: Text.ElideRight
                    color: item.open ? Theme.text : Theme.textDim
                    font.pixelSize: Theme.fontSize - 3
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        enabled: root.canMove
                        cursorShape: Qt.PointingHandCursor
                        onClicked: item.open = !item.open
                    }
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

            // Lista de salidas para esta app.
            ColumnLayout {
                visible: item.open && root.canMove
                Layout.fillWidth: true
                Layout.leftMargin: 34
                spacing: 2
                Repeater {
                    // null al final = "seguir la salida predeterminada del sistema"
                    model: AudioStreams.sinks.concat([null])
                    delegate: Rectangle {
                        id: opt
                        required property var modelData
                        readonly property bool auto: modelData === null
                        readonly property bool current: !auto && row.sink && row.sink.id === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 8
                        color: current ? Qt.rgba(1, 1, 1, 0.12) : (optArea.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        UiLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: opt.auto ? "↺ Seguir la salida predeterminada" : (opt.current ? "● " : "○ ") + (opt.modelData.description || opt.modelData.name)
                            color: opt.current ? Theme.text : Theme.textDim
                            font.italic: opt.auto
                            font.pixelSize: Theme.fontSize - 2
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: optArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { AudioStreams.moveGroup(item.modelData, opt.modelData); item.open = false; }
                        }
                    }
                }
            }
        }
    }
}
