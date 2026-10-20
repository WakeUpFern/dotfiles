import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

// Menu contextual de un icono de la bandeja, dibujado con el estilo del resto (en vez del menu nativo
// de la app). Soporta submenus (se entra con click y se vuelve con la fila "Atras"), casillas y
// opciones, y entradas desactivadas.
ColumnLayout {
    id: root
    spacing: 4
    signal closeRequested()

    property var item: null                // SystemTrayItem
    property var stack: []                 // submenus abiertos (QsMenuEntry), el ultimo es el visible
    readonly property var currentMenu: stack.length > 0 ? stack[stack.length - 1] : (item ? item.menu : null)
    onItemChanged: stack = []

    QsMenuOpener { id: opener; menu: root.currentMenu }

    function iconSrc(name) {
        if (!name) return "";
        if (name.indexOf("/") >= 0 || name.indexOf(":") >= 0) return name;
        return Quickshell.iconPath(name, true);
    }

    // --- Cabecera: la app (y "Atras" en un submenu) ---------------------------------
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: 12
        color: backArea.containsMouse && root.stack.length > 0 ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            UiLabel { visible: root.stack.length > 0; text: "‹"; font.pixelSize: 20; color: Theme.accent }
            Image {
                visible: root.stack.length === 0 && root.item !== null
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                sourceSize: Qt.size(40, 40)
                source: root.item ? root.item.icon : ""
            }
            UiLabel {
                Layout.fillWidth: true
                text: root.stack.length > 0 ? "Atrás" : (root.item ? (root.item.tooltipTitle || root.item.title || root.item.id) : "")
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.stack.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stack = root.stack.slice(0, -1)
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Entradas ---------------------------------------------------------------------
    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 440)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: opener.children

        delegate: Item {
            id: row
            required property var modelData
            readonly property bool sep: modelData.isSeparator
            width: list.width
            height: sep ? 9 : 34

            Rectangle {
                visible: row.sep
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 8; anchors.rightMargin: 8
                height: 1
                color: Theme.border
            }

            Rectangle {
                visible: !row.sep
                anchors.fill: parent
                radius: 10
                color: rowArea.containsMouse && row.modelData.enabled ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                opacity: row.modelData.enabled ? 1 : 0.4

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // casilla / opcion
                    UiGlyph {
                        Layout.preferredWidth: 16
                        visible: row.modelData.buttonType !== QsMenuButtonType.None
                        text: row.modelData.buttonType === QsMenuButtonType.RadioButton
                              ? (row.modelData.checkState === Qt.Checked ? "" : "")
                              : (row.modelData.checkState === Qt.Checked ? "" : "")
                        color: row.modelData.checkState === Qt.Checked ? Theme.accent : Theme.textDim
                        font.pixelSize: 14
                    }
                    Image {
                        visible: row.modelData.icon !== ""
                        Layout.preferredWidth: 18; Layout.preferredHeight: 18
                        sourceSize: Qt.size(36, 36)
                        source: root.iconSrc(row.modelData.icon)
                    }
                    UiLabel {
                        Layout.fillWidth: true
                        text: row.modelData.text.replace(/_/g, "")      // quita los atajos "_Archivo"
                        elide: Text.ElideRight
                    }
                    UiLabel { visible: row.modelData.hasChildren; text: "›"; font.pixelSize: 18; color: Theme.textDim }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (row.modelData.hasChildren) root.stack = root.stack.concat([row.modelData]);
                        else { row.modelData.triggered(); root.closeRequested(); }
                    }
                }
            }
        }
    }
}
