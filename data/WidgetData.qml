pragma Singleton
import QtQuick
import Quickshell
import ".."

// =====================================================================
//  WidgetData: the ONE place the orbiting widgets get their data from.
//  Same idea as HudData: everything below is MOCK today. When you move to
//  the PC, keep the public surface and fill it from real sources (the
//  "go live" sketch is at the bottom). Widgets never talk to Hyprland or
//  the filesystem themselves.
// =====================================================================
Singleton {
    id: root

    property bool mock: true

    // ---------------- PUBLIC SURFACE ----------------
    property var now: new Date()                 // refreshed every second
    property real uptimeSeconds: 0               // system uptime
    property var workspaces: []                  // [{ id, windows }]
    property int activeWorkspace: 1
    property string notesText: ""                // scratchpad contents
    // World clock rows (fixed offsets, no DST): edit freely
    property var worldZones: [
        { label: "UTC",   offsetMin: 0 },
        { label: "TOKYO", offsetMin: 540 },
        { label: "DUBAI", offsetMin: 240 }
    ]

    function switchWorkspace(id) {
        activeWorkspace = id;
        // live: Hyprland.dispatch("workspace " + id)
    }

    function setNotes(text) {
        notesText = text;
        // live: debounce, then write to ~/.local/share/ow-shell/notes.txt with FileView
    }

    // ---------------- HELPERS (pure formatting) ----------------
    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    function formatUptime(sec) {
        let s = Math.floor(sec);
        let d = Math.floor(s / 86400);
        let h = Math.floor((s % 86400) / 3600);
        let m = Math.floor((s % 3600) / 60);
        let r = s % 60;
        return (d > 0 ? d + "d " : "") + pad2(h) + ":" + pad2(m) + ":" + pad2(r);
    }

    function formatMinSec(sec) {
        let s = Math.max(0, Math.floor(sec));
        return pad2(Math.floor(s / 60)) + ":" + pad2(s % 60);
    }

    function zoneTime(offsetMin) {
        let d = new Date(now.getTime() + offsetMin * 60000);
        return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes());
    }

    function isoWeek() {
        let d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        let dayNum = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }

    function dayOfYear() {
        let start = new Date(now.getFullYear(), 0, 0);
        return Math.floor((now - start) / 86400000);
    }

    // ---------------- MOCK ----------------
    Component.onCompleted: {
        if (!mock) return;
        let counts = [2, 1, 0, 3, 0, 1, 0, 0, 0, 0];
        let ws = [];
        for (let i = 1; i <= 10; i++) ws.push({ id: i, windows: counts[i - 1] });
        workspaces = ws;
        uptimeSeconds = 3 * 86400 + 4 * 3600 + 12 * 60 + 7;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = new Date();
            if (root.mock) root.uptimeSeconds += 1;
        }
    }

    // ---------------- GO LIVE (sketch) ----------------
    // uptime:      FileView { path: "/proc/uptime" } -> parseFloat(text().split(" ")[0]), refresh each second
    // workspaces:  import Quickshell.Hyprland -> Hyprland.workspaces / Hyprland.focusedWorkspace
    // notes:       FileView { path: ...; onTextChanged } + a debounced write



}
