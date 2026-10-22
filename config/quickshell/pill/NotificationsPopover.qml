import QtQuick
import QtQuick.Layouts
import QtQml.Models
import Quickshell

// Menu de la campana: "No molestar" y el historial. Click en una tarjeta = ir a la app y quitarla.
ColumnLayout {
    id: root
    spacing: 12
    signal closeRequested()
    property real maxListHeight: 380

    // Mientras esta abierto todo cuenta como leido.
    Component.onCompleted: NotificationCenter.markRead()
    Connections {
        target: NotificationCenter
        function onEntriesChanged() { NotificationCenter.markRead(); }
    }

    // Reloj para los "hace 5 min".
    property date now: new Date()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function ago(t) {
        const s = Math.max(0, Math.floor((root.now - t) / 1000));
        if (s < 45) return "ahora";
        if (s < 3600) return "hace " + Math.max(1, Math.round(s / 60)) + " min";
        if (s < 86400) return "hace " + Math.round(s / 3600) + " h";
        return Qt.formatDateTime(t, "d MMM");
    }

    // --- Cabecera -------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        UiGlyph {
            text: NotificationCenter.dnd ? "" : ""
            color: NotificationCenter.dnd ? Theme.warn : Theme.text
            font.pixelSize: 16
        }
        UiLabel {
            text: "Notificaciones"
            font.pixelSize: Theme.fontSize + 2
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        UiLabel { text: "No molestar"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 1 }
        ToggleSwitch {
            checked: NotificationCenter.dnd
            onToggled: NotificationCenter.toggleDnd()
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Vacio ----------------------------------------------------------------------
    ColumnLayout {
        visible: NotificationCenter.entries.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 110
        spacing: 8
        Item { Layout.fillHeight: true }
        UiGlyph { Layout.alignment: Qt.AlignHCenter; text: ""; font.pixelSize: 26; color: Theme.textDim }
        UiLabel { Layout.alignment: Qt.AlignHCenter; text: NotificationCenter.dnd ? "No molestar está activo" : "Sin notificaciones"; color: Theme.textDim }
        Item { Layout.fillHeight: true }
    }

    // --- Historial ----------------------------------------------------------------------
    ListView {
        id: list
        visible: NotificationCenter.entries.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, root.maxListHeight)
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel { values: NotificationCenter.entries }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 140 }
                NumberAnimation { property: "scale"; to: 0.88; duration: 180; easing.type: Easing.InBack }
            }
        }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property bool hot: cardArea.containsMouse

            width: list.width
            height: Math.max(66, textCol.implicitHeight + 24)
            radius: 16
            color: hot ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
            border.width: modelData.critical ? 1 : 0
            border.color: Theme.urgent
            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                id: ico
                width: 38; height: 38; radius: 11
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                Image {
                    anchors.centerIn: parent
                    width: card.modelData.image !== "" ? parent.width : 24
                    height: width
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(76, 76)
                    source: card.modelData.image !== "" ? card.modelData.image
                          : Quickshell.iconPath(card.modelData.appIcon !== "" ? card.modelData.appIcon : "dialog-information", "dialog-information")
                }
            }

            Column {
                id: textCol
                anchors.left: ico.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 34
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Row {
                    spacing: 8
                    width: parent.width
                    UiLabel {
                        width: Math.min(implicitWidth, parent.width - 70)
                        text: card.modelData.appName
                        color: card.modelData.critical ? Theme.urgent : Theme.textDim
                        font.pixelSize: Theme.fontSize - 2
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                        elide: Text.ElideRight
                    }
                    UiLabel { text: root.ago(card.modelData.time); color: Theme.textDim; font.pixelSize: Theme.fontSize - 2 }
                }
                UiLabel {
                    width: parent.width
                    text: card.modelData.summary
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                UiLabel {
                    width: parent.width
                    visible: text !== ""
                    text: card.modelData.body
                    color: Theme.textDim
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: cardArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    NiriState.focusApp(card.modelData.desktopEntry, card.modelData.appName);
                    NotificationCenter.remove(card.modelData);
                    root.closeRequested();
                }
            }

            // "x": quitar solo esta entrada.
            UiLabel {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
                text: "✕"
                color: xArea.containsMouse ? Theme.urgent : Theme.textDim
                font.pixelSize: 12
                opacity: card.hot ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea {
                    id: xArea
                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NotificationCenter.remove(card.modelData)
                }
            }
        }
    }

    // --- Pie ---------------------------------------------------------------------------------
    RowLayout {
        visible: NotificationCenter.entries.length > 0
        Layout.fillWidth: true
        UiLabel {
            text: NotificationCenter.entries.length + (NotificationCenter.entries.length === 1 ? " notificación" : " notificaciones")
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 1
            Layout.fillWidth: true
        }
        Rectangle {
            Layout.preferredHeight: 28
            Layout.preferredWidth: clearText.implicitWidth + 26
            radius: 14
            color: clearArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }
            UiLabel { id: clearText; anchors.centerIn: parent; text: "Borrar todo"; font.pixelSize: Theme.fontSize - 1 }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationCenter.clear()
            }
        }
    }
}
