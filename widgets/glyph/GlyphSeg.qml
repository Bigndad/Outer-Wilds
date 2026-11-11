import QtQuick
import "."

// row (or column) of n dot segments, a fraction f lit from the start
Item {
    id: root
    property int n: 24
    property real f: 0
    property bool vertical: false
    property color on: GlyphTheme.fg
    property color off: GlyphTheme.s3
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))
    readonly property real pitch: (vertical ? height : width) / n
    readonly property real dot: Math.min(pitch * 0.72, vertical ? width : height)

    Repeater {
        model: root.n
        Rectangle {
            required property int index
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            x: root.vertical ? (root.width - width) / 2 : index * root.pitch + (root.pitch - width) / 2
            y: root.vertical ? root.height - (index + 1) * root.pitch + (root.pitch - height) / 2
                             : (root.height - height) / 2
            color: index < root.lit ? root.on : root.off
        }
    }
}
