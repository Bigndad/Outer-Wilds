import QtQuick
import "."

// A little dot cat: blinks, wags its tail while hovered (or always), coloured nose.
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
        interval: Math.max(800, Math.round((Number(w.cfg.blinkSec) || 3.2) * 1000))
        running: true; repeat: true
        onTriggered: { w.blink = true; off.restart(); }
    }
    Timer { id: off; interval: 160; onTriggered: w.blink = false }
    Timer {
        interval: 420
        running: ma.containsMouse || w.cfg.alwaysWag === true
        repeat: true
        onTriggered: w.wag = !w.wag
        onRunningChanged: if (!running) w.wag = false
    }

    GlyphBitmap {
        anchors.centerIn: parent
        rows: w.rows
        cell: 11
        on: (w.cfg.catColor && w.cfg.catColor !== "") ? w.cfg.catColor : GlyphTheme.fg
        red: (w.cfg.noseColor && w.cfg.noseColor !== "") ? w.cfg.noseColor : GlyphTheme.red
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: { w.blink = true; off.restart(); } }
}
