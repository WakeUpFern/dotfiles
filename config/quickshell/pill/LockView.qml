import QtQuick
import QtQuick.Effects
import Quickshell

// Lo que se ve en cada pantalla bloqueada: fondo desenfocado, reloj grande y
// la contrasena como figuras que saltan al teclear. `ctx` es el LockScreen
// (estado compartido entre pantallas).
FocusScope {
    id: view

    required property var ctx
    focus: true
    Component.onCompleted: forceActiveFocus()

    readonly property var shapeColors: ["#8ab4ff", "#ffb4c8", "#c3f0a6", "#ffd479", "#d6b8ff", "#8fe3d6"]
    readonly property bool failed: ctx.state === "failed"

    // --- Teclado ---------------------------------------------------------------
    Keys.onPressed: event => {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            ctx.submit();
        } else if (event.key === Qt.Key_Backspace) {
            if (ctrl) ctx.clearAll(); else ctx.backspace();
        } else if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_U)) {
            ctx.clearAll();
        } else {
            const t = event.text;
            const meta = (event.modifiers & Qt.MetaModifier) !== 0;
            if (t.length === 1 && t.charCodeAt(0) >= 32 && t.charCodeAt(0) !== 127 && !ctrl && !meta)
                ctx.type(t);
            else
                return;
        }
        event.accepted = true;
    }

    // --- Fondo -------------------------------------------------------------------
    Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: Theme.wallpaper
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(1280, 720)
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.04
        saturation: 0.10
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0.03, 0.04, 0.05, 0.16) }

    // --- Entrada animada ---------------------------------------------------------
    property real appear: 0
    NumberAnimation on appear { from: 0; to: 1; duration: 800; easing.type: Easing.OutCubic }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -view.height * 0.04 + (1 - view.appear) * 40
        opacity: view.appear
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: Math.min(view.height * 0.22, 190)
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const s = clock.date.toLocaleDateString(Qt.locale("es_MX"), "dddd, d 'de' MMMM");
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Math.min(view.height * 0.028, 26)
        }

        Item { width: 1; height: view.height * 0.05 }

        // --- Caja de la contrasena -------------------------------------------------
        Item {
            id: entryBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(view.width * 0.8, Math.max(320, list.contentWidth + 80))
            height: 76
            Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

            // Sacudida al fallar.
            property real shakeX: 0
            transform: Translate { x: entryBox.shakeX }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: entryBox; property: "shakeX"; to: -22; duration: 60 }
                NumberAnimation { target: entryBox; property: "shakeX"; to: 22;  duration: 90 }
                NumberAnimation { target: entryBox; property: "shakeX"; to: -14; duration: 80 }
                NumberAnimation { target: entryBox; property: "shakeX"; to: 14;  duration: 80 }
                NumberAnimation { target: entryBox; property: "shakeX"; to: -6;  duration: 70 }
                NumberAnimation { target: entryBox; property: "shakeX"; to: 0;   duration: 70 }
            }
            Connections {
                target: view.ctx
                function onStateChanged() { if (view.ctx.state === "failed") shake.restart(); }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: view.failed ? Qt.rgba(1, 0.37, 0.43, 0.18) : Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: view.failed ? Theme.urgent : Qt.rgba(1, 1, 1, 0.22)
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
            }

            // Texto guia cuando no hay nada escrito.
            Text {
                anchors.centerIn: parent
                visible: view.ctx.shapes.count === 0
                text: Quickshell.env("USER") + "   ·   escribe tu contraseña"
                color: Theme.textDim
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSize + 2
            }

            // Las figuras. Cada caracter entra con rebote y sale encogiendose.
            ListView {
                id: list
                anchors.centerIn: parent
                width: Math.min(contentWidth, entryBox.width - 60)
                height: 60
                orientation: ListView.Horizontal
                interactive: false
                clip: true
                model: view.ctx.shapes
                onCountChanged: positionViewAtEnd()

                add: Transition {
                    NumberAnimation { property: "scale"; from: 0; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 3.5 }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
                }
                remove: Transition {
                    NumberAnimation { property: "scale"; to: 0; duration: 220; easing.type: Easing.InBack }
                    NumberAnimation { property: "opacity"; to: 0; duration: 220 }
                }
                displaced: Transition {
                    NumberAnimation { properties: "x"; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                }

                delegate: Item {
                    id: cell
                    required property int kind
                    required property int hue
                    width: 40
                    height: list.height

                    // Saltito al aparecer.
                    property real hop: 0
                    SequentialAnimation on hop {
                        running: true
                        NumberAnimation { to: -16; duration: 140; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 0; duration: 380; easing.type: Easing.OutBounce }
                    }

                    ShapeGlyph {
                        id: glyph
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - height) / 2 + cell.hop
                        size: 30
                        kind: cell.kind
                        color: view.ctx.state === "failed" ? Theme.urgent
                             : view.ctx.state === "success" ? "#7be0a0"
                             : view.shapeColors[cell.hue % view.shapeColors.length]
                        Behavior on color { ColorAnimation { duration: 180 } }
                        opacity: view.ctx.state === "verifying" ? 0.45 + 0.55 * view.pulse : 1
                    }
                }
            }
        }

        // --- Estado ---------------------------------------------------------------------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 24
            text: view.ctx.state === "verifying" ? "Verificando…"
                : view.ctx.state === "success" ? "Bienvenido"
                : view.ctx.message !== "" ? view.ctx.message
                : view.ctx.shapes.count > 0 ? "Enter para entrar" : ""
            color: view.failed || (view.ctx.message !== "" && view.ctx.state === "idle") ? Theme.urgent : Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize + 1
        }
    }

    // Pulso mientras PAM verifica.
    property real pulse: 1
    SequentialAnimation on pulse {
        running: view.ctx.state === "verifying"
        loops: Animation.Infinite
        NumberAnimation { to: 0; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
    }
}
