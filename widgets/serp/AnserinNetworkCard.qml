import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Small network card (port_anserin_panels.py). Click opens Anserin's network manager:
//   qs -c outerwilds ipc call network toggle
WidgetCard {
    id: w
    title: "NETWORK"
    designW: 240
    designH: 110

    property bool up: false
    property string kind: ""
    property string conn: ""
    property string iface: ""
    property real rxRate: 0
    property real txRate: 0
    property var prev: null

    function rate(b) {
        if (b < 1024) return Math.round(b) + " B/s";
        if (b < 1048576) return Math.round(b / 1024) + " KB/s";
        return (b / 1048576).toFixed(1) + " MB/s";
    }
    // nmcli -t escapes ':' and '\' with a backslash
    function splitT(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }
    function parse(txt) {
        const parts = txt.split("\n---\n");
        let best = null;
        for (const raw of (parts[0] || "").split("\n")) {
            if (!raw) continue;
            const f = splitT(raw);
            if (f.length >= 4 && f[1] === "connected" && (f[0] === "wifi" || f[0] === "ethernet")) { best = f; break; }
        }
        if (!best) { w.up = false; w.conn = ""; w.kind = ""; w.iface = ""; w.rxRate = 0; w.txRate = 0; w.prev = null; return; }
        w.up = true; w.kind = best[0]; w.conn = best[2]; w.iface = best[3];
        for (const line of (parts[1] || "").split("\n")) {
            const tk = line.trim().replace(":", " ").split(/\s+/);
            if (tk[0] !== w.iface || tk.length < 10) continue;
            const now = Date.now(), rx = Number(tk[1]), tx = Number(tk[9]);
            if (w.prev && w.prev.iface === w.iface && now > w.prev.t) {
                const dt = (now - w.prev.t) / 1000;
                w.rxRate = Math.max(0, (rx - w.prev.rx) / dt);
                w.txRate = Math.max(0, (tx - w.prev.tx) / dt);
            }
            w.prev = { iface: w.iface, t: now, rx: rx, tx: tx };
        }
    }

    Process {
        id: proc
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE,CONNECTION,DEVICE device 2>/dev/null; echo ---; cat /proc/net/dev"]
        stdout: StdioCollector { onStreamFinished: w.parse(text) }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

    Rectangle {
        id: dot
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 6 * w.ui
        width: 9 * w.ui; height: width; radius: width / 2
        color: w.up ? w.cGold : w.cDim
    }
    Text {
        anchors.left: dot.right
        anchors.leftMargin: 8 * w.ui
        anchors.right: parent.right
        anchors.verticalCenter: dot.verticalCenter
        text: w.up ? w.conn : "OFFLINE"
        elide: Text.ElideRight
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.round(15 * w.ui)
    }
    Text {
        id: sub
        anchors.top: dot.bottom
        anchors.topMargin: 8 * w.ui
        anchors.left: parent.left
        text: w.up ? (w.kind === "wifi" ? "WI-FI" : "ETHERNET") + "  " + w.iface : "NO CONNECTION"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(11 * w.ui)
    }
    Row {
        visible: w.up
        anchors.top: sub.bottom
        anchors.topMargin: 10 * w.ui
        anchors.left: parent.left
        spacing: 16 * w.ui
        Text { text: "\u2193 " + w.rate(w.rxRate); color: w.cCream; font.family: "monospace"; font.pixelSize: Math.round(12 * w.ui) }
        Text { text: "\u2191 " + w.rate(w.txRate); color: w.cDim; font.family: "monospace"; font.pixelSize: Math.round(12 * w.ui) }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "network", "toggle"])
    }
}
