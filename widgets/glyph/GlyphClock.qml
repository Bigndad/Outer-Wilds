import QtQuick
import "../.."
import "."

// Dot-matrix time, date underneath, and a 60-dot seconds strip. The colon is the one red thing.
GlyphCard {
    id: w
    designW: 280
    designH: 160

    readonly property var d: WidgetData.now
    readonly property int sec: d.getSeconds()

    GlyphLabel { x: 24; y: 18; text: Qt.formatDate(w.d, "dddd") }
    GlyphLabel { anchors { right: parent.right; rightMargin: 24 } y: 18; text: Qt.formatDate(w.d, "d MMM yyyy") }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46
        spacing: 9
        GlyphDots { text: Qt.formatTime(w.d, "HH"); cell: 9 }
        GlyphDots { text: ":"; cell: 9; showOff: false; on: GlyphTheme.red }
        GlyphDots { text: Qt.formatTime(w.d, "mm"); cell: 9 }
    }
    GlyphSeg {
        x: 24
        y: 126
        width: parent.width - 48
        height: 6
        n: 60
        f: w.sec / 59
    }
}
