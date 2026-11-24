import QtQuick
import "../.."
import "."

// Dot-matrix time, date underneath, and a 60-dot seconds strip.
GlyphCard {
    id: w
    designW: 280
    designH: 160

    readonly property var d: WidgetData.now
    readonly property int sec: d.getSeconds()
    readonly property color digCol: (cfg.dotColor && cfg.dotColor !== "") ? cfg.dotColor : GlyphTheme.fg
    readonly property color colCol: (cfg.colonColor && cfg.colonColor !== "") ? cfg.colonColor : GlyphTheme.red

    GlyphLabel { visible: w.cfg.showDate !== false; x: 24; y: 18; text: Qt.formatDate(w.d, "dddd") }
    GlyphLabel { visible: w.cfg.showDate !== false; anchors { right: parent.right; rightMargin: 24 } y: 18; text: Qt.formatDate(w.d, "d MMM yyyy") }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: w.cfg.showDate !== false ? 46 : 36
        spacing: 9
        GlyphDots { text: Qt.formatTime(w.d, w.cfg.hour24 === false ? "hh" : "HH"); cell: 9; on: w.digCol }
        GlyphDots { text: ":"; cell: 9; showOff: false; on: w.colCol; opacity: (w.cfg.blinkColon === true && w.sec % 2 === 1) ? 0.15 : 1.0 }
        GlyphDots { text: Qt.formatTime(w.d, "mm"); cell: 9; on: w.digCol }
    }
    GlyphSeg {
        visible: w.cfg.showSecondsBar !== false
        x: 24
        y: 126
        width: parent.width - 48
        height: 6
        n: 60
        f: w.sec / 59
        on: w.digCol
    }
}
