import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

// Menu de bateria: nivel, estado, tiempo restante y perfil de energia.
ColumnLayout {
    id: root
    spacing: 16

    readonly property var battery: UPower.displayDevice

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

    // --- Bateria y perfil de energia ------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.battery.isPresent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            UiLabel {
                text: "bat"
                color: Theme.textDim
                Layout.preferredWidth: 34 + 12
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            UiLabel {
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

                    UiLabel {
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
