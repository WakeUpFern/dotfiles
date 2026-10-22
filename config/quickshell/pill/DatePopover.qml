import QtQuick
import QtQuick.Layouts
import Quickshell

// Menu del reloj + campana: fecha, calendario del mes y debajo las notificaciones (con No molestar).
// Es independiente del panel de ajustes rapidos.
ColumnLayout {
    id: root
    spacing: 12
    signal closeRequested()

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date now: clock.date

    property int monthOffset: 0
    readonly property date viewMonth: new Date(now.getFullYear(), now.getMonth() + monthOffset, 1)

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }

    // 6 semanas desde el lunes anterior (o igual) al dia 1.
    readonly property var cells: {
        const first = viewMonth;
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(first.getFullYear(), first.getMonth(), 1 - offset + i));
        return out;
    }

    // --- Fecha -------------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            spacing: 0
            UiLabel { text: Qt.formatTime(root.now, "HH:mm"); font.pixelSize: 30; font.weight: Font.DemiBold }
            UiLabel {
                text: Theme.dayNames[root.now.getDay()] + ", " + root.now.getDate() + " de " + Theme.monthNames[root.now.getMonth()] + " de " + root.now.getFullYear()
                color: Theme.textDim
            }
        }
        Item { Layout.fillWidth: true }
    }

    // --- Calendario -----------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            component NavButton: Rectangle {
                id: nb
                property string glyph
                signal clicked()
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: nbArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                UiGlyph { anchors.centerIn: parent; text: nb.glyph; font.pixelSize: 11 }
                MouseArea { id: nbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nb.clicked() }
            }
            UiLabel {
                Layout.fillWidth: true
                text: Theme.monthNames[root.viewMonth.getMonth()].charAt(0).toUpperCase() + Theme.monthNames[root.viewMonth.getMonth()].slice(1) + " " + root.viewMonth.getFullYear()
                font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.monthOffset = 0 }
            }
            NavButton { glyph: ""; onClicked: root.monthOffset--  }
            NavButton { glyph: ""; onClicked: root.monthOffset++ }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 2

            Repeater {
                model: ["L", "M", "X", "J", "V", "S", "D"]
                delegate: UiLabel {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSize - 2
                }
            }
            Repeater {
                model: root.cells
                delegate: Item {
                    id: day
                    required property var modelData
                    readonly property bool today: root.sameDay(modelData, root.now)
                    readonly property bool inMonth: modelData.getMonth() === root.viewMonth.getMonth()
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 30
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28; radius: 14
                        color: day.today ? Theme.accent : "transparent"
                    }
                    UiLabel {
                        anchors.centerIn: parent
                        text: day.modelData.getDate()
                        color: day.today ? "#0b1020" : (day.inMonth ? Theme.text : Theme.textDim)
                        opacity: day.inMonth || day.today ? 1 : 0.5
                        font.weight: day.today ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

    // --- Notificaciones --------------------------------------------------------------------------
    NotificationsPopover {
        Layout.fillWidth: true
        maxListHeight: 230
        onCloseRequested: root.closeRequested()
    }
}
