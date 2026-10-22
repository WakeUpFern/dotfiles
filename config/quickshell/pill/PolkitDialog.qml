import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit

// Agente polkit propio: cuando algo pide permisos de administrador (montar discos, ajustes del sistema,
// pkexec...) sale una tarjeta de vidrio al centro con el mensaje y el campo de contrasena, en lugar del
// dialogo de otro toolkit. Solo puede haber un agente por sesion: ver docs/power.md.
Scope {
    id: root

    readonly property var flow: agent.flow
    readonly property bool open: agent.isActive && flow !== null && !flow.isCompleted

    PolkitAgent { id: agent }

    PanelWindow {
        id: win
        visible: root.open || card.opacity > 0.01
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "pill-polkit"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

        // Fondo que oscurece lo de atras para que no pase desapercibido.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            opacity: root.open ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 440
            height: col.implicitHeight + 44
            radius: 22
            color: Theme.glass
            border.width: 1
            border.color: Theme.border
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 44
                        radius: 14
                        color: Theme.accentSoft
                        UiGlyph { anchors.centerIn: parent; text: ""; font.pixelSize: 20; color: Theme.accent }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        UiLabel { text: "Se requiere autenticación"; font.pixelSize: Theme.fontSize + 3; font.weight: Font.DemiBold }
                        UiLabel {
                            Layout.fillWidth: true
                            text: root.flow ? root.flow.message : ""
                            color: Theme.textDim
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Mensaje del sistema ("Contrasena incorrecta, intenta de nuevo", etc.)
                UiLabel {
                    visible: root.flow !== null && root.flow.supplementaryMessage !== ""
                    Layout.fillWidth: true
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? Theme.urgent : Theme.textDim
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontSize - 1
                }

                // Contrasena
                Rectangle {
                    visible: root.flow !== null && root.flow.isResponseRequired
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 12
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: input.activeFocus ? 1 : 0
                    border.color: Theme.accent
                    TextInput {
                        id: input
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.text
                        selectionColor: Theme.accent
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize + 1
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        focus: true
                        Keys.onEscapePressed: root.cancel()
                        onAccepted: root.submit()
                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.flow && root.flow.inputPrompt !== "" ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Contraseña"
                            color: Theme.textDim
                            font: input.font
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: cancelText.implicitWidth + 36
                        radius: 18
                        color: cancelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiLabel { id: cancelText; anchors.centerIn: parent; text: "Cancelar" }
                        MouseArea { id: cancelArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancel() }
                    }
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: okText.implicitWidth + 36
                        radius: 18
                        color: Theme.accent
                        opacity: okArea.pressed ? 0.8 : 1
                        UiLabel { id: okText; anchors.centerIn: parent; text: "Autenticar"; color: "#0b1020"; font.weight: Font.DemiBold }
                        MouseArea { id: okArea; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                    }
                }
            }
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired) return;
        flow.submit(input.text);
        input.text = "";
    }
    function cancel() {
        if (flow) flow.cancelAuthenticationRequest();
        input.text = "";
    }

    // Cada nueva peticion (o reintento) vuelve a poner el foco en el campo.
    onOpenChanged: if (open) { input.text = ""; input.forceActiveFocus(); }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() { if (root.flow && root.flow.isResponseRequired) { input.text = ""; input.forceActiveFocus(); } }
    }

    // Para pruebas:  qs -c pill ipc call polkit status
    IpcHandler {
        target: "polkit"
        function status(): string { return "registrado=" + agent.isRegistered + " activo=" + agent.isActive; }
        function cancel(): void { root.cancel(); }
    }
}
