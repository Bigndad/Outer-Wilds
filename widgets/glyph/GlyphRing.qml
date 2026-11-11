import QtQuick
import "."

// ring of n LED dots, fraction f lit clockwise from 12 o'clock
Item {
    id: root
    property int n: 44
    property real f: 1
    property real dot: 6
    property color on: GlyphTheme.fg
    property color off: GlyphTheme.s3
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    Repeater {
        model: root.n
        Rectangle {
            required property int index
            readonly property real a: index / root.n * 2 * Math.PI - Math.PI / 2
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            x: (root.width - root.dot) / 2 * (1 + Math.cos(a))
            y: (root.height - root.dot) / 2 * (1 + Math.sin(a))
            color: index < root.lit ? root.on : root.off
        }
    }
}
