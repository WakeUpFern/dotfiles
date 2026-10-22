import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Selector de fondos de pantalla dentro del notch (Mod+Shift+W). Muestra miniaturas de las imagenes de
// ~/Pictures/Wallpapers, ~/Wallpapers y ~/Pictures. Flechas para moverte, Enter o clic para aplicar,
// Esc cierra. Al aplicar cambia el fondo, el del overview y la paleta de colores (acento).
FocusScope {
    id: root
    signal closeRequested()

    readonly property int cols: 3
    readonly property string home: Quickshell.env("HOME")
    readonly property var dirs: [home + "/Pictures/Wallpapers", home + "/Wallpapers", home + "/Pictures"]

    property var images: []                 // [{ path, name }]
    property int sel: 0

    function applySel() {
        const it = images[sel];
        if (it) Theme.setWallpaper(it.path);
    }

    Component.onCompleted: { scan.running = true; forceActiveFocus(); }

    Process {
        id: scan
        command: ["sh", "-c",
            'for d in "$@"; do [ -d "$d" ] && find "$d" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" -o -iname "*.bmp" \\); done | sort -u',
            "_"].concat(root.dirs)
        stdout: StdioCollector {
            onStreamFinished: {
                const list = text.split("\n").filter(l => l !== "").map(p => ({ path: p, name: p.split("/").pop().replace(/\.[^.]+$/, "") }));
                root.images = list;
                const cur = list.findIndex(i => i.path === Theme.wallpaperPath);
                root.sel = cur >= 0 ? cur : 0;
            }
        }
    }

    onSelChanged: grid.positionViewAtIndex(sel, GridView.Contain)

    Keys.onEscapePressed: closeRequested()
    Keys.onReturnPressed: applySel()
    Keys.onLeftPressed: sel = Math.max(sel - 1, 0)
    Keys.onRightPressed: sel = Math.min(sel + 1, images.length - 1)
    Keys.onUpPressed: sel = Math.max(sel - cols, 0)
    Keys.onDownPressed: sel = Math.min(sel + cols, images.length - 1)

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            UiLabel { text: "Fondos de pantalla"; font.pixelSize: Theme.fontSize + 3; font.weight: Font.DemiBold; Layout.fillWidth: true }
            UiLabel { text: root.images.length + (root.images.length === 1 ? " imagen" : " imágenes"); color: Theme.textDim }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: grid
                anchors.fill: parent
                clip: true
                cellWidth: Math.floor(width / root.cols)
                cellHeight: 138
                model: root.images
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: modelData.path === Theme.wallpaperPath
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 14
                        color: cell.index === root.sel ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        border.width: cell.current ? 2 : 0
                        border.color: Theme.accent

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 9
                                color: Qt.rgba(1, 1, 1, 0.06)
                                clip: true
                                Image {
                                    id: thumb
                                    anchors.fill: parent
                                    source: "file://" + cell.modelData.path
                                    sourceSize: Qt.size(400, 225)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                }
                                UiLabel {
                                    anchors.centerIn: parent
                                    width: parent.width - 16
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    visible: thumb.status === Image.Error
                                    text: "Sin vista previa\n(falta qt6-image-formats-plugins)"
                                    color: Theme.textDim
                                    font.pixelSize: Theme.fontSize - 3
                                }
                            }
                            UiLabel {
                                Layout.fillWidth: true
                                text: cell.modelData.name
                                elide: Text.ElideMiddle
                                font.pixelSize: Theme.fontSize - 2
                                color: cell.current ? Theme.accent : Theme.textDim
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.sel = cell.index
                        onClicked: { root.sel = cell.index; root.applySel(); }
                    }
                }
            }

            UiLabel {
                anchors.centerIn: parent
                visible: root.images.length === 0
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.textDim
                text: "No hay imágenes. Pon tus fondos en ~/Pictures/Wallpapers."
            }
        }

        RowLayout {
            Layout.fillWidth: true
            UiLabel {
                Layout.fillWidth: true
                text: "Enter o clic aplica  ·  ~/Pictures/Wallpapers, ~/Wallpapers y ~/Pictures"
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
                elide: Text.ElideRight
            }
        }
    }
}
