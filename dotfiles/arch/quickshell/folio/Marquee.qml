import QtQuick

// A Small that keeps the width it is given: text that fits stands still, text
// that does not runs past as a loop (text, gap, text again), pausing at the
// start of each pass and while the pointer rests on it.
Item {
    id: marquee
    property var screen
    property alias text: first.text
    property bool link: false
    property bool lit: true
    property real gap: 40
    property real speed: 36
    property int rest: 1800
    property real offset: 0
    readonly property real travel: first.implicitWidth + gap
    readonly property bool overflowing: first.implicitWidth > width + 0.5
    signal pressed(var event)
    signal wheeled(var event)
    implicitWidth: first.implicitWidth
    implicitHeight: first.implicitHeight
    baselineOffset: first.baselineOffset

    function reset(): void {
        if (run.running) {
            run.paused = false;
            run.stop();
        }
        offset = 0;
        if (overflowing && visible) {
            run.start();
            if (hover.containsMouse)
                run.paused = true;
        }
    }
    onTextChanged: reset()
    onOverflowingChanged: reset()
    onTravelChanged: reset()
    onVisibleChanged: reset()
    Component.onCompleted: reset()

    SequentialAnimation {
        id: run
        loops: Animation.Infinite
        PauseAnimation {
            duration: marquee.rest
        }
        NumberAnimation {
            target: marquee
            property: "offset"
            from: 0
            to: marquee.travel
            duration: Math.max(1, Math.round(marquee.travel / Math.max(1, marquee.speed) * 1000))
        }
    }
    Item {
        anchors.fill: parent
        clip: true
        Item {
            x: -Math.round(marquee.offset)
            width: marquee.travel + first.implicitWidth
            height: parent.height
            Small {
                id: first
                screen: marquee.screen
                lit: marquee.lit
            }
            Small {
                visible: marquee.overflowing
                x: marquee.travel
                screen: marquee.screen
                lit: marquee.lit
                text: first.text
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -2
        width: marquee.link && hover.containsMouse ? parent.width : 0
        height: 1
        color: first.color
        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        acceptedButtons: marquee.link ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
        cursorShape: marquee.link ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: {
            if (run.running)
                run.paused = containsMouse;
        }
        onClicked: event => marquee.pressed(event)
        onWheel: event => {
            if (marquee.link)
                marquee.wheeled(event);
            else
                event.accepted = false;
        }
    }
}
