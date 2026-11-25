import QtQuick

// A measure that may grow but never shrinks while `open`: on opening it takes the current
// `want`, then only widens until closed. Closed, it simply follows `want`.
QtObject {
    id: hold
    required property real want
    required property bool open
    property real floor: 0
    readonly property real value: Math.max(floor, want)
    onWantChanged: if (open)
        floor = Math.max(floor, want)
    onOpenChanged: floor = open ? want : 0
}
