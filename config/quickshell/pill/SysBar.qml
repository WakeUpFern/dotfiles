import QtQuick
import Quickshell
import Quickshell.Wayland

// Barra de estado de la izquierda: monitor del sistema (CPU, memoria, temperatura, red) en texto sin
// fondo, con la misma sombra suave que la barra derecha. Un clic abre el detalle (SysPopover).
// Cada valor pasa a naranja/rojo cuando se acerca al limite, y tiene ancho fijo para que no baile.
PanelWindow {
    id: win

    property bool open: false                 // el detalle esta abierto
    signal toggled()

    readonly property real barWidth: strip.width
    readonly property real barHeight: Theme.notchHeight

    // Como el notch: en pantalla completa se esconde hacia arriba (salvo con el detalle abierto).
    readonly property bool fullscreenFocused: NiriState.focusedWidth >= win.screen.width
                                           && NiriState.focusedHeight >= win.screen.height
    readonly property bool tucked: fullscreenFocused && !open

    anchors { top: true; left: true }
    implicitWidth: strip.width + 16
    implicitHeight: Theme.notchHeight + 8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pill-bar-left"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: strip }

    // Color segun lo cerca que este del limite.
    function level(v, warn, urgent) { return v >= urgent ? Theme.urgent : (v >= warn ? Theme.warn : Theme.text); }

    component Label: Text {
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSize - 1
        color: Theme.text
        style: Text.Raised
        styleColor: Qt.rgba(0, 0, 0, 0.55)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }
    // Texto de ancho fijo: el del valor mas largo posible.
    component Value: Item {
        id: v
        property alias text: t.text
        property alias color: t.color
        property string widest: "100%"
        implicitWidth: metrics.width
        implicitHeight: t.implicitHeight
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        TextMetrics { id: metrics; font: t.font; text: v.widest }
        Label { id: t; anchors.right: parent.right; font.weight: Font.Medium }
    }

    Item {
        id: strip
        width: row.implicitWidth + 16
        height: Theme.notchHeight
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.top: parent.top
        anchors.topMargin: win.tucked ? -(height + 8) : 2
        Behavior on anchors.topMargin { NumberAnimation { duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            radius: 8
            color: win.open ? Qt.rgba(1, 1, 1, 0.20) : (area.pressed ? Qt.rgba(1, 1, 1, 0.22) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"))
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            Row {
                visible: Theme.sysmonShow.cpu
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Label { text: "CPU"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 0.4 }
                Value { text: Math.round(SystemStats.cpu * 100) + "%"; color: win.level(SystemStats.cpu, 0.7, 0.9) }
            }
            Row {
                visible: Theme.sysmonShow.ram
                spacing: 5
                anchors.verticalCenter: parent.verticalCenter
                Label { text: "RAM"; color: Theme.textDim; font.pixelSize: Theme.fontSize - 3; font.letterSpacing: 0.4 }
                Value { text: Math.round(SystemStats.ram * 100) + "%"; color: win.level(SystemStats.ram, 0.8, 0.92) }
            }
            Row {
                visible: Theme.sysmonShow.temp && SystemStats.tempCpu >= 0
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: ""
                    font.family: "FontAwesome"
                    font.pixelSize: 13
                    color: Theme.textDim
                    style: Text.Raised
                    styleColor: Qt.rgba(0, 0, 0, 0.55)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Value { widest: "100°"; text: Math.round(SystemStats.tempCpu) + "°"; color: win.level(SystemStats.tempCpu, 75, 88) }
            }
            Row {
                visible: Theme.sysmonShow.net
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: "↓"; color: Theme.textDim }
                    Value { widest: "99.9M"; text: SystemStats.rate(SystemStats.netDown); color: SystemStats.netDown > 1000 ? Theme.text : Theme.textDim }
                }
                Row {
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: "↑"; color: Theme.textDim }
                    Value { widest: "99.9M"; text: SystemStats.rate(SystemStats.netUp); color: SystemStats.netUp > 1000 ? Theme.text : Theme.textDim }
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: win.toggled()
        }
    }
}
