import QtQuick
import Quickshell

PopupWindow {
    id: sheet
    property real pad: 18
    property bool open: false
    signal dismissed
    default property alias contents: inside.data
    // A popup that is resized while mapped stops repainting (the compositor keeps
    // stretching its last buffer), so the size is held while open and a change in
    // content is shown by remapping the popup at the new size instead.
    readonly property int fitWidth: Math.ceil(inside.childrenRect.width + 2 * pad)
    readonly property int fitHeight: Math.ceil(inside.childrenRect.height + 2 * pad)
    property bool held: false
    property bool remapping: false
    property int heldWidth: 0
    property int heldHeight: 0
    implicitWidth: held ? heldWidth : fitWidth
    implicitHeight: held ? heldHeight : fitHeight
    visible: open && !remapping
    onFitWidthChanged: refit.restart()
    onFitHeightChanged: refit.restart()
    onVisibleChanged: {
        if (visible) {
            heldWidth = fitWidth;
            heldHeight = fitHeight;
            held = true;
        } else if (!remapping) {
            held = false;
            dismissed();
        }
    }
    Timer {
        id: refit
        interval: 0
        onTriggered: {
            if (!sheet.visible || (sheet.fitWidth === sheet.heldWidth && sheet.fitHeight === sheet.heldHeight))
                return;
            sheet.remapping = true;
            sheet.heldWidth = sheet.fitWidth;
            sheet.heldHeight = sheet.fitHeight;
            reshow.restart();
        }
    }
    Timer {
        id: reshow
        interval: 0
        onTriggered: sheet.remapping = false
    }
    color: Theme.bg
    grabFocus: true
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border {
            width: 1
            color: Theme.fg
        }
    }
    Item {
        id: inside
        x: sheet.pad
        y: sheet.pad
        opacity: sheet.visible || sheet.remapping ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }
        }
    }
}
