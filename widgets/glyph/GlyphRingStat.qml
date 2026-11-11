import QtQuick
import "."

// Round LED-ring gauge: ring lit by f, dot-matrix number in the middle, caption under it.
// Turns red at `warnAt` (the one red thing). Subclasses only set f / value / label.
GlyphCard {
    id: w
    designW: 200
    designH: 200
    round: true

    property real f: 0
    property string value: "0"
    property string label: ""
    property real warnAt: 0.85
    readonly property color tone: f >= warnAt ? GlyphTheme.red : GlyphTheme.fg

    GlyphRing {
        anchors.fill: parent
        anchors.margins: 12
        n: 44
        dot: 7
        f: w.f
        on: w.tone
    }
    Column {
        anchors.centerIn: parent
        spacing: 12
        GlyphDots {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.value
            cell: w.value.length >= 3 ? 6 : 8
            on: w.tone
        }
        GlyphLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.label
        }
    }
}
