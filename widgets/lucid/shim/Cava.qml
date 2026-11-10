pragma Singleton
import QtQuick

// MOCK spectrum: a drifting fake, only ticking while some card has asked for bands.
// Swap `levels` for a real feed (Cava / your HUD's audio source) later.
QtObject {
    id: cava
    readonly property int maxBands: 64
    property bool active: true
    property var levels: []
    property var wants: ({})
    property real phase: 0
    property int count: 0

    function want(uid, n) {
        var w = wants; w[uid] = n; wants = w;
        recount();
    }
    function drop(uid) {
        if (!uid || wants[uid] === undefined) return;
        var w = wants; delete w[uid]; wants = w;
        recount();
    }
    function recount() {
        var m = 0;
        for (var k in wants) m = Math.max(m, wants[k]);
        count = m;
        if (m === 0) levels = [];
    }

    property Timer tick: Timer {
        interval: 40
        repeat: true
        running: cava.count > 0
        onTriggered: {
            cava.phase += 0.07;
            var out = [], n = cava.count;
            for (var i = 0; i < n; i++) {
                var x = i / Math.max(1, n - 1);
                var env = Math.pow(1 - x, 0.9) * 0.75 + 0.15;
                var v = 0.5 + 0.5 * Math.sin(cava.phase * 2.3 + x * 9.1) * Math.sin(cava.phase * 1.1 + x * 3.3);
                out.push(Math.max(0.02, Math.min(1, env * v)));
            }
            cava.levels = out;
        }
    }
}
