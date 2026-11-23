import QtQuick
import "."

// Dot bitmap from rows of equal length: "#" lit, "R" red, "." unlit (hidden unless showOff).
Item {
    id: root
    property var rows: []
    property real cell: 8
    property real dot: cell * 0.72
    property color on: GlyphTheme.fg
    property color off: GlyphTheme.s3
    property bool showOff: false
    readonly property int cols: rows.length > 0 ? rows[0].length : 0
    width: cols * cell
    height: rows.length * cell

    Repeater {
        model: root.rows.length * root.cols
        Rectangle {
            required property int index
            readonly property string ch: (root.rows[Math.floor(index / root.cols)] || "")[index % root.cols] || "."
            visible: ch !== "." || root.showOff
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            x: (index % root.cols) * root.cell + (root.cell - root.dot) / 2
            y: Math.floor(index / root.cols) * root.cell + (root.cell - root.dot) / 2
            color: ch === "R" ? GlyphTheme.red : ch === "#" ? root.on : root.off
        }
    }
}
