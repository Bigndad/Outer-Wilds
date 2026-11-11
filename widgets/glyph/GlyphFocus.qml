import QtQuick
import "../.."
import "."

// Focus timer on an LED ring. The ring drains while it runs and turns red (the one live thing);
// click the digits to start / pause, -5 / +5 change the length while it is not running, RESET refills.
// At zero it blinks red for a few seconds. (Pure QML timer, no notification is sent.)
GlyphCard {
    id: w
    designW: 240
    designH: 240
    round: true

    property int total: 25 * 60
    property int remain: 25 * 60
    property bool running: false
    property bool done: false
    property real endAt: 0
    property bool blink: false

    function startPause() {
        if (running) { running = false; return; }
        if (remain <= 0) remain = total;
        done = false;
        endAt = Date.now() + remain * 1000;
        running = true;
    }
    function reset() { running = false; done = false; remain = total; }
    function bump(min) {
        if (running) return;
        total = Math.max(60, Math.min(180 * 60, total + min * 60));
        remain = total;
        done = false;
    }
    function mmss(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    Timer {
        interval: 250
        running: w.running
        repeat: true
        onTriggered: {
            w.remain = Math.max(0, Math.ceil((w.endAt - Date.now()) / 1000));
            if (w.remain <= 0) { w.running = false; w.done = true; blinkT.count = 0; blinkT.start(); }
        }
    }
    Timer {
        id: blinkT
        property int count: 0
        interval: 450
        repeat: true
        onTriggered: { w.blink = !w.blink; if (++count >= 12) { stop(); w.blink = false; w.done = false; } }
    }

    readonly property color tone: (running || (done && blink)) ? GlyphTheme.red : GlyphTheme.fg

    GlyphRing {
        anchors.fill: parent
        anchors.margins: 14
        n: 60
        dot: 6
        f: w.total > 0 ? w.remain / w.total : 0
        on: w.tone
    }

    Column {
        anchors.centerIn: parent
        spacing: 14
        GlyphLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.running ? "focus" : (w.remain < w.total ? "paused" : "focus \u00B7 " + Math.round(w.total / 60) + " min")
        }
        GlyphDots {
            id: digits
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.mmss(w.remain)
            cell: 6.5
            on: w.tone
            MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: w.startPause() }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Repeater {
                model: [ { t: "\u2212 5", a: "m" }, { t: w.running ? "PAUSE" : "START", a: "s" }, { t: "+ 5", a: "p" } ]
                Text {
                    required property var modelData
                    text: modelData.t
                    color: modelData.a === "s" ? GlyphTheme.fg : GlyphTheme.grey
                    font.family: GlyphTheme.mono
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -8
                        onClicked: modelData.a === "m" ? w.bump(-5) : modelData.a === "p" ? w.bump(5) : w.startPause()
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !w.running && w.remain !== w.total
            text: "RESET"
            color: GlyphTheme.mute
            font.family: GlyphTheme.mono
            font.pixelSize: 10
            font.letterSpacing: 1.2
            MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: w.reset() }
        }
    }
}
