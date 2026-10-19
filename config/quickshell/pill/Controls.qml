import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Panel que se despliega desde el notch: volumen (+ salida de audio),
// brillo y bateria (+ perfil de energia). `focusTarget` resalta la seccion
// desde la que se abrio.
ColumnLayout {
    id: root

    property string focusTarget: ""      // "volume" | "brightness" | "battery"
    signal closeRequested()

    spacing: 16
    focus: true
    Keys.onEscapePressed: root.closeRequested()
    Component.onCompleted: forceActiveFocus()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var battery: UPower.displayDevice

    PwObjectTracker { objects: root.sinks }

    // --- helpers -------------------------------------------------------------
    function sectionColor(name) { return focusTarget === name ? Theme.accent : Theme.textDim; }

    function formatTime(seconds) {
        if (!seconds || seconds <= 0) return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? h + " h " + m + " min" : m + " min";
    }

    readonly property string batteryState: {
        switch (battery.state) {
        case UPowerDeviceState.Charging:     return "Cargando";
        case UPowerDeviceState.Discharging:  return "En bateria";
        case UPowerDeviceState.FullyCharged: return "Completa";
        case UPowerDeviceState.PendingCharge: return "Conectada";
        default: return "";
        }
    }
    readonly property string batteryTime: battery.state === UPowerDeviceState.Charging
        ? formatTime(battery.timeToFull) : formatTime(battery.timeToEmpty)

    component Label: Text {
        color: Theme.text
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize
    }

    // --- Volumen -------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Label {
                text: root.sink && root.sink.audio && root.sink.audio.muted ? "mute" : "vol"
                color: root.sectionColor("volume")
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
            Label {
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

                Label {
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
        Label {
            text: "luz"
            color: root.sectionColor("brightness")
            Layout.preferredWidth: 34
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Slider {
            Layout.fillWidth: true
            value: Brightness.level
            onMoved: v => Brightness.set(v)
        }
        Label {
            text: Math.round(Brightness.level * 100)
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
        }
    }

    // --- Bateria y perfil de energia ------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.battery.isPresent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "bat"
                color: root.sectionColor("battery")
                Layout.preferredWidth: 34 + 12
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Label {
                Layout.fillWidth: true
                text: Math.round(root.battery.percentage * 100) + "%"
                    + (root.batteryState !== "" ? "  ·  " + root.batteryState : "")
                    + (root.batteryTime !== "" ? "  ·  " + root.batteryTime : "")
                color: root.battery.percentage < 0.2 && root.battery.state !== UPowerDeviceState.Charging ? Theme.urgent : Theme.text
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [
                    { label: "Ahorro",      profile: PowerProfile.PowerSaver },
                    { label: "Equilibrado", profile: PowerProfile.Balanced },
                    { label: "Rendimiento", profile: PowerProfile.Performance }
                ].filter(p => p.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool active: PowerProfiles.profile === modelData.profile
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 15
                    color: active ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    Behavior on color { ColorAnimation { duration: 160 } }
                    scale: chipArea.pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                    Label {
                        anchors.centerIn: parent
                        text: chip.modelData.label
                        color: chip.active ? "#0b1020" : Theme.text
                        font.weight: chip.active ? Font.DemiBold : Font.Normal
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = chip.modelData.profile
                    }
                }
            }
        }
    }
}
