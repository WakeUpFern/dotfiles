pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "RailLogic.js" as RailLogic

PanelWindow {
    id: line
    readonly property real u: Theme.unit(screen)
    readonly property var notes: Notices.live.values
    readonly property var note: notes.length > 0 ? notes[notes.length - 1] : null
    property bool earlier: false
    property bool calendar: false
    property bool layouts: false
    // The earlier sheet's text column fits the widest kept notice, capped; it is measured while
    // the sheet is closed and held while it is open, so forgetting a row never remaps it wider/narrower.
    readonly property real pastGap: 18 * u
    readonly property real pastTime: Theme.wide("00:00")
    readonly property real pastCap: Math.min(Theme.wide("M".repeat(60)), width * 0.6 - 44 * u - pastTime - 2 * pastGap - Theme.wide("×"))
    readonly property real pastWant: Math.min(pastCap, Math.max(0, ...Notices.history.slice(0, 10).map(p => Theme.wide(pastText(p)))))
    property real pastWidth: 0
    onPastWantChanged: if (!earlier) pastWidth = pastWant
    onEarlierChanged: if (!earlier) pastWidth = pastWant
    Component.onCompleted: pastWidth = pastWant
    function pastText(p): string {
        return (p.app + ": " + p.summary + (p.body ? " — " + p.body : "")).replace(/\s+/g, " ");
    }
    Connections {
        target: ShellState
        function onMissedWanted(onScreen) {
            if (onScreen === line.screen)
                line.earlier = true;
        }
    }
    onNoteChanged: {
        if (note)
            arrive.restart();
    }
    property date month: new Date()
    anchors {
        left: true
        right: true
        bottom: true
    }
    implicitHeight: 60 * u
    color: "transparent"
    WlrLayershell.namespace: "folio"
    WlrLayershell.layer: WlrLayer.Bottom
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    Timer {
        readonly property int wait: !line.note || line.note.urgency === NotificationUrgency.Critical ? 0 : (line.note.expireTimeout < 0 ? 8000 : line.note.expireTimeout)
        interval: Math.max(1, wait)
        running: wait > 0 && !noteHover.hovered
        onTriggered: {
            if (line.screen !== Quickshell.screens[0])
                return;
            if (!line.note.transient)
                Notices.missed++;
            line.note.expire();
        }
    }

    component Plate: Rectangle {
        required property Item around
        visible: around.visible
        x: around.x - 14 * line.u
        y: around.y - 10 * line.u
        width: around.width + 28 * line.u
        height: around.height + 20 * line.u
        color: Theme.bg
    }
    Plate {
        around: where
    }
    Plate {
        around: arrived
    }
    Plate {
        around: standing
    }
    Row {
        id: where
        x: 36 * line.u
        anchors.verticalCenter: parent.verticalCenter
        spacing: 38 * line.u
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            text: Theme.who.latitude ? Theme.who.latitude + "   " + Theme.who.longitude : ""
        }
        Small {
            screen: line.screen
            lit: false
            visible: text.length > 0
            text: Theme.who.place || ""
        }
        Small {
            screen: line.screen
            lit: false
            link: true
            text: Qt.locale("C").toString(clock.date, "ddd d MMM")
            onPressed: time.pressed(null)
        }
        Small {
            id: time
            screen: line.screen
            link: true
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            onPressed: {
                line.month = new Date();
                line.layouts = false;
                line.calendar = !line.calendar;
            }
        }
        Small {
            id: layoutWord
            screen: line.screen
            visible: Keyboard.names.length > 0
            link: true
            lit: line.layouts
            text: Keyboard.activeCode
            onPressed: {
                line.calendar = false;
                line.layouts = !line.layouts;
            }
        }
    }

    Row {
        id: arrived
        visible: line.note !== null
        transform: Translate {
            id: writing
        }
        ParallelAnimation {
            id: arrive
            NumberAnimation {
                target: arrived
                property: "opacity"
                from: 0
                to: 1
                duration: 260
            }
            NumberAnimation {
                target: writing
                property: "x"
                from: 40 * line.u
                to: 0
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 22 * line.u
        HoverHandler {
            id: noteHover
        }
        Small {
            screen: line.screen
            color: Theme.signal
            text: "↳"
        }
        Small {
            screen: line.screen
            width: Math.min(implicitWidth, line.width * 0.4)
            elide: Text.ElideRight
            text: line.note ? (line.note.appName || "notice") + ": " + line.note.summary + (line.note.body ? " — " + line.note.body.replace(/\s+/g, " ") : "") : ""
        }
        Repeater {
            model: line.note ? line.note.actions : []
            Small {
                required property var modelData
                screen: line.screen
                link: true
                text: modelData.text
                onPressed: {
                    modelData.invoke();
                    if (line.note && !line.note.resident)
                        line.note.dismiss();
                }
            }
        }
        Small {
            screen: line.screen
            link: true
            lit: false
            text: line.notes.length > 1 ? "later (+" + (line.notes.length - 1) + ")" : "later"
            onPressed: line.note.dismiss()
        }
    }
    Row {
        id: standing
        visible: line.note === null
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 260
            }
        }
        anchors {
            right: parent.right
            rightMargin: 36 * line.u
            verticalCenter: parent.verticalCenter
        }
        spacing: 38 * line.u
        Small {
            screen: line.screen
            visible: Notices.history.length > 0
            link: true
            lit: Notices.missed > 0
            text: Notices.missed > 0 ? Notices.missed + " missed" : "earlier"
            onPressed: line.earlier = !line.earlier
        }
        Row {
            spacing: 12 * line.u
            Small {
                screen: line.screen
                link: true
                lit: Notices.quiet
                text: "quiet"
                onPressed: Notices.quiet = !Notices.quiet
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 40 * line.u
                height: 20 * line.u
                radius: height / 2
                color: "transparent"
                border {
                    width: 1
                    color: Theme.fg
                }
                Rectangle {
                    x: Notices.quiet ? parent.width - width - 4 * line.u : 4 * line.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * line.u
                    height: width
                    radius: width / 2
                    color: Notices.quiet ? Theme.signal : Theme.fg
                    Behavior on x {
                        NumberAnimation {
                            duration: 140
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8 * line.u
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notices.quiet = !Notices.quiet
                }
            }
        }
    }

    Sheet {
        id: almanac
        readonly property int firstDay: Qt.locale().firstDayOfWeek % 7
        readonly property real cell: 3 * Theme.small(line.screen)
        anchor.window: line
        anchor.rect.x: Math.round(36 * line.u)
        anchor.rect.y: Math.round(-implicitHeight - 6 * line.u)
        open: line.calendar
        pad: 22 * line.u
        onDismissed: line.calendar = false
        Column {
            spacing: 12 * line.u
            Row {
                spacing: 24 * line.u
                Small {
                    screen: line.screen
                    link: true
                    width: almanac.cell * 5
                    text: Qt.formatDate(line.month, "MMMM yyyy")
                    onPressed: line.month = new Date()
                }
                Small {
                    screen: line.screen
                    link: true
                    text: "←"
                    onPressed: line.month = new Date(line.month.getFullYear(), line.month.getMonth() - 1, 1)
                }
                Small {
                    screen: line.screen
                    link: true
                    text: "→"
                    onPressed: line.month = new Date(line.month.getFullYear(), line.month.getMonth() + 1, 1)
                }
            }
            Row {
                Repeater {
                    model: 8
                    Small {
                        required property int index
                        screen: line.screen
                        lit: false
                        width: almanac.cell
                        horizontalAlignment: Text.AlignRight
                        text: index === 0 ? "wk" : Qt.locale("C").dayName((almanac.firstDay + index - 1) % 7, Locale.ShortFormat).slice(0, 2)
                    }
                }
            }
            Column {
                spacing: 6 * line.u
                Repeater {
                    model: RailLogic.monthWeeks(line.month.getFullYear(), line.month.getMonth(), almanac.firstDay, clock.date)
                    Row {
                        id: week
                        required property var modelData
                        Small {
                            screen: line.screen
                            lit: false
                            opacity: 0.6
                            width: almanac.cell
                            horizontalAlignment: Text.AlignRight
                            text: week.modelData.week
                        }
                        Repeater {
                            model: week.modelData.days
                            Item {
                                id: day
                                required property var modelData
                                width: almanac.cell
                                height: number.height
                                Rectangle {
                                    visible: day.modelData.today
                                    anchors.right: parent.right
                                    anchors.rightMargin: -5 * line.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: number.implicitWidth + 10 * line.u
                                    height: parent.height + 6 * line.u
                                    color: Theme.fg
                                }
                                Small {
                                    id: number
                                    screen: line.screen
                                    width: parent.width
                                    horizontalAlignment: Text.AlignRight
                                    color: day.modelData.today ? Theme.bg : (day.modelData.inMonth ? Theme.fg : Theme.faint)
                                    text: day.modelData.day
                                }
                            }
                        }
                    }
                }
            }
            Small {
                screen: line.screen
                lit: false
                text: Qt.formatDateTime(clock.date, "dddd d MMMM") + " · week " + RailLogic.isoWeek(clock.date)
            }
        }
    }

    Sheet {
        id: tongues
        anchor.window: line
        anchor.rect.x: Math.round(Math.max(0, where.x + layoutWord.x - 22 * line.u))
        anchor.rect.y: Math.round(-implicitHeight - 6 * line.u)
        open: line.layouts
        pad: 22 * line.u
        onDismissed: line.layouts = false
        Column {
            spacing: 12 * line.u
            Repeater {
                model: Keyboard.names
                Row {
                    id: choice
                    required property string modelData
                    required property int index
                    readonly property bool current: index === Keyboard.active
                    spacing: 18 * line.u
                    Small {
                        screen: line.screen
                        opacity: choice.current ? 1 : 0
                        text: "→"
                    }
                    Small {
                        screen: line.screen
                        lit: choice.current
                        text: Keyboard.code(choice.modelData)
                    }
                    Small {
                        screen: line.screen
                        link: true
                        lit: choice.current
                        text: choice.modelData
                        onPressed: {
                            Keyboard.choose(choice.index);
                            line.layouts = false;
                        }
                    }
                }
            }
        }
    }

    Sheet {
        anchor.window: line
        anchor.rect.x: Math.round(line.width - implicitWidth - 36 * line.u)
        anchor.rect.y: Math.round(-implicitHeight - 6 * line.u)
        open: line.earlier
        pad: 22 * line.u
        onOpenChanged: {
            if (open)
                Notices.missed = 0;
        }
        onDismissed: line.earlier = false
        Column {
            spacing: 12 * line.u
            Repeater {
                model: Notices.history.slice(0, 10)
                Row {
                    id: past
                    required property var modelData
                    required property int index
                    spacing: 18 * line.u
                    Small {
                        screen: line.screen
                        lit: false
                        width: line.pastTime
                        text: Qt.formatDateTime(new Date(past.modelData.time), "HH:mm")
                    }
                    Small {
                        screen: line.screen
                        color: past.modelData.critical ? Theme.signal : Theme.fg
                        width: line.pastWidth
                        elide: Text.ElideRight
                        text: line.pastText(past.modelData)
                    }
                    Small {
                        screen: line.screen
                        link: true
                        lit: false
                        text: "×"
                        onPressed: Notices.forget(past.index)
                    }
                }
            }
            Small {
                screen: line.screen
                link: true
                lit: false
                text: "forget all"
                onPressed: {
                    Notices.clear();
                    line.earlier = false;
                }
            }
        }
    }
}
