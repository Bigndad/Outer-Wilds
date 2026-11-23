import QtQuick
import "."

// A little dot cat (drawn here, not the glyph-rice gif): blinks now and then, wags its tail while you hover, red nose.
GlyphCard {
    id: w
    designW: 220
    designH: 220

    readonly property var head: [
        "..##.......##..", ".####.....####.", ".#############.", ".#############.", ".##..#####..##.",
        ".##..#####..##.", ".#############.", "..####RRR####..", "...#########...", "..###########..",
        ".#############.", ".####.###.####.", ".####.###.####."]
    readonly property var headBlink: [
        "..##.......##..", ".####.....####.", ".#############.", ".#############.", ".#############.",
        ".##..#####..##.", ".#############.", "..####RRR####..", "...#########...", "..###########..",
        ".#############.", ".####.###.####.", ".####.###.####."]
    property bool blink: false
    property bool wag: false
    readonly property var tailUp:   ["..", "..", "..", "..", "..", "..", "..", ".#", "##", "#.", "#.", "#.", "##"]
    readonly property var tailFlat: ["..", "..", "..", "..", "..", "..", "..", "..", "..", "..", ".#", "##", "##"]
    readonly property var rows: {
        const h = blink ? headBlink : head, t = wag ? tailFlat : tailUp, out = [];
        for (let i = 0; i < h.length; i++) out.push(h[i] + t[i]);
        return out;
    }

    Timer {
        interval: 3200; running: true; repeat: true
        onTriggered: { w.blink = true; off.restart(); }
    }
    Timer { id: off; interval: 160; onTriggered: w.blink = false }
    Timer { interval: 420; running: ma.containsMouse; repeat: true; onTriggered: w.wag = !w.wag; onRunningChanged: if (!running) w.wag = false }

    GlyphBitmap {
        anchors.centerIn: parent
        rows: w.rows
        cell: 11
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { w.blink = true; off.restart(); } }
}
