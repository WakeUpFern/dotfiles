import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// Panel multimedia del notch: lo que suena (caratula, titulo, artista), progreso con
// seek y controles. Teclado: Espacio pausa, <- -> adelantan/atrasan 5 s, N/P pista,
// S aleatorio, R repetir, Esc cierra.
FocusScope {
    id: root

    signal closeRequested()

    readonly property var p: MediaState.active
    readonly property bool has: p !== null

    focus: true
    Component.onCompleted: forceActiveFocus()

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    function seekTo(fraction) {
        if (!has || !p.canSeek || p.length <= 0) return;
        if (p.positionSupported) p.position = fraction * p.length;
        else p.seek(fraction * p.length - p.position);
    }
    function cycleLoop() {
        if (!has || !p.loopSupported) return;
        p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) closeRequested();
        else if (event.key === Qt.Key_Space) MediaState.togglePlaying();
        else if (event.key === Qt.Key_Right && has && p.canSeek) p.seek(5);
        else if (event.key === Qt.Key_Left && has && p.canSeek) p.seek(-5);
        else if (event.key === Qt.Key_N) MediaState.next();
        else if (event.key === Qt.Key_P) MediaState.previous();
        else if (event.key === Qt.Key_S && has && p.shuffleSupported) p.shuffle = !p.shuffle;
        else if (event.key === Qt.Key_R) cycleLoop();
        else return;
        event.accepted = true;
    }

    // La posicion no se actualiza sola: se consulta mientras suena y el panel esta abierto.
    Timer {
        interval: 400
        repeat: true
        running: root.has && root.p.isPlaying
        onTriggered: root.p.positionChanged()
    }

    component Glyph: Text {
        color: Theme.text
        font.family: "FontAwesome"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Boton circular con rebote al pulsar.
    component RoundButton: Rectangle {
        id: btn
        property string glyph
        property bool on: false              // resaltado (aleatorio/repetir activos)
        property bool enabledBtn: true
        property real glyphSize: 16
        signal clicked()
        radius: width / 2
        color: on ? Theme.accent : (area.containsMouse && enabledBtn ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
        opacity: enabledBtn ? 1 : 0.35
        scale: area.pressed ? 0.88 : 1
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Glyph { anchors.centerIn: parent; text: btn.glyph; color: btn.on ? "#0b1020" : Theme.text; font.pixelSize: btn.glyphSize }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (btn.enabledBtn) btn.clicked()
        }
    }

    // --- Vacio ----------------------------------------------------------------------
    Column {
        visible: !root.has
        anchors.centerIn: parent
        spacing: 12
        Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: ""; font.pixelSize: 40; color: Theme.textDim }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nada reproduciéndose"
            color: Theme.textDim
            font.family: Theme.fontSans
            font.pixelSize: Theme.fontSize + 2
        }
    }

    // --- Reproductor ------------------------------------------------------------------
    ColumnLayout {
        visible: root.has
        anchors.fill: parent
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            // Caratula
            Rectangle {
                Layout.preferredWidth: 132
                Layout.preferredHeight: 132
                radius: 22
                clip: true
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: Theme.border
                scale: root.has && root.p.isPlaying ? 1 : 0.94
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                Glyph { anchors.centerIn: parent; text: ""; font.pixelSize: 44; color: Theme.textDim; visible: art.status !== Image.Ready }
                Image {
                    id: art
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(264, 264)
                    source: root.has ? root.p.trackArtUrl : ""
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Text {
                    text: root.has ? root.p.identity : ""
                    color: Theme.accent
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize - 2
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.has && root.p.trackTitle !== "" ? root.p.trackTitle : "Sin título"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: text !== ""
                    text: root.has ? root.p.trackArtist : ""
                    color: Theme.text
                    opacity: 0.8
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize + 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: text !== ""
                    text: root.has ? root.p.trackAlbum : ""
                    color: Theme.textDim
                    font.family: Theme.fontSans
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Progreso
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: root.fmt(root.has ? root.p.position : 0)
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize - 1
                Layout.preferredWidth: 42
            }
            Slider {
                Layout.fillWidth: true
                value: root.has && root.p.length > 0 ? root.p.position / root.p.length : 0
                enabled: root.has && root.p.canSeek && root.p.length > 0
                opacity: enabled ? 1 : 0.5
                onMoved: v => root.seekTo(v)
            }
            Text {
                text: root.has && root.p.lengthSupported ? root.fmt(root.p.length) : "--:--"
                color: Theme.textDim
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSize - 1
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
            }
        }

        // Controles
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            RoundButton {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                glyph: ""
                on: root.has && root.p.shuffleSupported && root.p.shuffle
                enabledBtn: root.has && root.p.shuffleSupported
                onClicked: root.p.shuffle = !root.p.shuffle
            }
            RoundButton {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                glyph: ""; glyphSize: 18
                enabledBtn: root.has && root.p.canGoPrevious
                onClicked: MediaState.previous()
            }
            RoundButton {
                Layout.preferredWidth: 66; Layout.preferredHeight: 66
                glyph: root.has && root.p.isPlaying ? "" : ""; glyphSize: 24
                on: true
                enabledBtn: root.has && root.p.canTogglePlaying
                onClicked: MediaState.togglePlaying()
            }
            RoundButton {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                glyph: ""; glyphSize: 18
                enabledBtn: root.has && root.p.canGoNext
                onClicked: MediaState.next()
            }
            RoundButton {
                Layout.preferredWidth: 42; Layout.preferredHeight: 42
                glyph: ""
                on: root.has && root.p.loopSupported && root.p.loopState !== MprisLoopState.None
                enabledBtn: root.has && root.p.loopSupported
                onClicked: root.cycleLoop()
                Text {
                    visible: root.has && root.p.loopState === MprisLoopState.Track
                    anchors.centerIn: parent
                    text: "1"
                    color: "#0b1020"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                }
            }
        }

        // Selector de reproductor (solo si hay varios)
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: MediaState.players.length > 1
            spacing: 8
            Repeater {
                model: MediaState.players
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: root.has && modelData === root.p
                    height: 30
                    width: chipText.implicitWidth + 26
                    radius: 15
                    color: current ? Theme.accent : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: modelData.identity + (modelData.isPlaying ? "  ♪" : "")
                        color: parent.current ? "#0b1020" : Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontSize - 1
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: MediaState.preferred = modelData.identity
                    }
                }
            }
        }
    }
}
