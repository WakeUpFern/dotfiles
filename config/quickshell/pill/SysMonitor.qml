import QtQuick
import QtQuick.Layouts
import Quickshell

// Detalle del monitor del sistema: graficas de CPU, memoria y red, temperaturas, disco, consumo y los
// programas que mas gastan. Los datos vienen de SystemStats (con el menu abierto muestrea cada segundo).
ColumnLayout {
    id: root
    spacing: 14

    Component.onCompleted: SystemStats.detail = true
    Component.onDestruction: SystemStats.detail = false

    function level(v, warn, urgent) { return v >= urgent ? Theme.urgent : (v >= warn ? Theme.warn : Theme.text); }
    function pct(v) { return Math.round(v * 100) + " %"; }

    // Cabecera de seccion: nombre a la izquierda, valor a la derecha.
    component Head: RowLayout {
        property string title
        property string value
        property color valueColor: Theme.text
        Layout.fillWidth: true
        UiLabel {
            text: parent.title
            color: Theme.textDim
            font.pixelSize: Theme.fontSize - 2
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }
        Item { Layout.fillWidth: true }
        UiLabel { text: parent.value; color: parent.valueColor; font.weight: Font.Medium }
    }
    // Barra de progreso fina.
    component Bar: Rectangle {
        property real frac: 0
        property color fill: Theme.accent
        Layout.fillWidth: true
        implicitHeight: 6
        radius: 3
        color: Qt.rgba(1, 1, 1, 0.12)
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.frac))
            height: parent.height
            radius: 3
            color: parent.fill
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
    component Sub: UiLabel {
        color: Theme.textDim
        font.pixelSize: Theme.fontSize - 2
    }

    // --- CPU ------------------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Head {
            title: "CPU"
            value: root.pct(SystemStats.cpu) + (SystemStats.cpuMhz > 0 ? "  ·  " + (SystemStats.cpuMhz / 1000).toFixed(1) + " GHz" : "")
            valueColor: root.level(SystemStats.cpu, 0.7, 0.9)
        }
        Spark { Layout.fillWidth: true; implicitHeight: 40; values: SystemStats.cpuHistory; max: 1 }
        // Un hilo = una barra vertical.
        Row {
            Layout.fillWidth: true
            spacing: 3
            Repeater {
                model: SystemStats.cores
                delegate: Item {
                    required property real modelData
                    width: (parent.width - (SystemStats.cores.length - 1) * 3) / Math.max(1, SystemStats.cores.length)
                    height: 20
                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.10)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(2, parent.height * parent.modelData)
                        radius: 3
                        color: root.level(parent.modelData, 0.7, 0.9) === Theme.text ? Theme.accent : root.level(parent.modelData, 0.7, 0.9)
                        Behavior on height { NumberAnimation { duration: 300 } }
                    }
                }
            }
        }
        Sub { text: "Carga  " + SystemStats.load.map(v => v.toFixed(2)).join("  ·  ") }
    }

    // --- Memoria --------------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Head {
            title: "Memoria"
            value: SystemStats.gib(SystemStats.ramUsed) + " / " + SystemStats.gib(SystemStats.ramTotal)
            valueColor: root.level(SystemStats.ram, 0.8, 0.92)
        }
        Spark { Layout.fillWidth: true; implicitHeight: 34; values: SystemStats.ramHistory; max: 1 }
        Sub {
            visible: SystemStats.swapTotal > 0
            text: "Swap  " + SystemStats.gib(SystemStats.swapUsed) + " / " + SystemStats.gib(SystemStats.swapTotal)
        }
    }

    // --- Temperatura ----------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: SystemStats.tempCpu >= 0
        Head {
            title: "Temperatura"
            value: Math.round(SystemStats.tempCpu) + "°C"
            valueColor: root.level(SystemStats.tempCpu, 75, 88)
        }
        Flow {
            Layout.fillWidth: true
            spacing: 14
            Sub { visible: SystemStats.tempGpu >= 0; text: "GPU  " + Math.round(SystemStats.tempGpu) + "°" }
            Sub { visible: SystemStats.tempDisk >= 0; text: "Disco  " + Math.round(SystemStats.tempDisk) + "°" }
            Sub { visible: SystemStats.fan >= 0; text: "Ventilador  " + SystemStats.fan + " rpm" }
        }
    }

    // --- Red ------------------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Head {
            title: "Red"
            value: "↓ " + SystemStats.rate(SystemStats.netDown) + "B/s    ↑ " + SystemStats.rate(SystemStats.netUp) + "B/s"
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 34
            // Misma escala para bajada y subida.
            readonly property real scale100k: Math.max(100000, ...SystemStats.downHistory, ...SystemStats.upHistory)
            Spark { anchors.fill: parent; values: SystemStats.downHistory; max: parent.scale100k }
            Spark { anchors.fill: parent; values: SystemStats.upHistory; max: parent.scale100k; color: Theme.warn }
        }
    }

    // --- Disco y energia ------------------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: SystemStats.diskSize > 0
        Head {
            title: "Disco"
            value: SystemStats.gib(SystemStats.diskUsed) + " / " + SystemStats.gib(SystemStats.diskSize)
            valueColor: root.level(SystemStats.diskUsed / Math.max(1, SystemStats.diskSize), 0.85, 0.95)
        }
        Bar { frac: SystemStats.diskUsed / Math.max(1, SystemStats.diskSize) }
        Sub { text: "Lectura  " + SystemStats.rate(SystemStats.diskRead) + "B/s   ·   Escritura  " + SystemStats.rate(SystemStats.diskWrite) + "B/s" }
    }
    Head {
        visible: SystemStats.power >= 0
        title: "Consumo (bateria)"
        value: SystemStats.power.toFixed(1) + " W"
    }

    // --- Procesos -------------------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        visible: SystemStats.topCpu.length > 0

        component ProcList: ColumnLayout {
            property string title
            property var rows: []
            property bool byMem: false
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 3
            UiLabel {
                text: parent.title
                color: Theme.textDim
                font.pixelSize: Theme.fontSize - 2
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }
            Repeater {
                model: parent.rows
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    UiLabel {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSize - 1
                    }
                    UiLabel {
                        text: parent.parent.byMem ? SystemStats.mem(modelData.mem) : Math.round(modelData.cpu) + " %"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
        ProcList { title: "Mas CPU"; rows: SystemStats.topCpu }
        ProcList { title: "Mas memoria"; rows: SystemStats.topMem; byMem: true }
    }
}
