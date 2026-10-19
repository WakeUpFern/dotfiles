import QtQuick
import QtQuick.Layouts
import Quickshell

// Buscador de aplicaciones dentro de la pildora. Esc cierra, Enter lanza.
ColumnLayout {
    id: launcher
    signal closeRequested()
    spacing: 10

    property string query: ""

    readonly property var results: {
        const q = query.trim().toLowerCase();
        const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const scored = q === "" ? apps : apps.filter(a =>
            a.name.toLowerCase().includes(q) ||
            (a.genericName || "").toLowerCase().includes(q) ||
            (a.keywords || []).some(k => k.toLowerCase().includes(q)));
        return scored.sort((a, b) => a.name.localeCompare(b.name)).slice(0, 8);
    }

    function launch(entry) {
        if (!entry) return;
        entry.execute();
        closeRequested();
    }

    TextInput {
        id: input
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize + 3
        selectionColor: Theme.accent
        focus: true
        onTextChanged: { launcher.query = text; list.currentIndex = 0; }
        Component.onCompleted: forceActiveFocus()

        Keys.onEscapePressed: launcher.closeRequested()
        Keys.onReturnPressed: launcher.launch(launcher.results[list.currentIndex])
        Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
        Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)

        Text {
            visible: input.text === ""
            text: "Buscar aplicaciones..."
            color: Theme.textDim
            font: input.font
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 2
        model: launcher.results
        currentIndex: 0
        highlightMoveDuration: 120

        delegate: Rectangle {
            required property var modelData
            required property int index
            width: list.width
            height: 40
            radius: 12
            color: ListView.isCurrentItem ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 12
                Image {
                    width: 24; height: 24
                    sourceSize: Qt.size(24, 24)
                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 1
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: list.currentIndex = index
                onClicked: launcher.launch(modelData)
            }
        }
    }
}
