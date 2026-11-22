import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// =====================================================================
//  LIVE system data (shell.qml only; needs Quickshell). One of these in shell.qml: SystemLive { }
//  Replaces the MOCK values of three things, without touching the mock flags (the sensors / notifications stay mock):
//    * apps       DesktopEntries -> MapData.setApps(); the Map View's "Launch App" button runs the real app
//    * workspaces `hyprctl -j workspaces / clients / activeworkspace` -> WidgetData.workspaces, activeWorkspace and
//                 MapData.setWindows() (window titles on the workspace pages). Refreshed on Hyprland window / workspace events,
//                 and every time the Map View opens. Read-only: it never changes workspaces.
//    * uptime     `cat /proc/uptime` every 10 s -> WidgetData.uptimeSeconds
//  Everything it uses is already used elsewhere in this config (DesktopEntries + execute() in AppLauncher, the Hyprland raw events
//  and hyprctl probes in NoctaliaBridge).
//  UNTESTED against your Quickshell (written without it): if something is off, the log says "SystemLive: ...".
// =====================================================================
Scope {
    id: root

    property var _entries: ({})          // app id -> DesktopEntry (for launching)

    // ---------------- apps ----------------
    function _icon(name) {
        const n = String(name || "");
        if (n === "") return "";
        return n.startsWith("/") ? "file://" + n : "image://icon/" + n;
    }

    function loadApps() {
        const entries = DesktopEntries.applications.values;
        const list = [];
        const map = ({});
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay) continue;
            const id = String(e.id || e.name);
            list.push({
                id: id,
                name: String(e.name),
                comment: String(e.comment || ""),
                category: (e.categories && e.categories.length > 0) ? String(e.categories[0]) : "Other",
                icon: root._icon(e.icon)
            });
            map[id] = e;
        }
        root._entries = map;
        MapData.setApps(list);
    }

    Component.onCompleted: { loadApps(); probe.running = true; uptimeProbe.running = true; }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.loadApps(); }
    }

    Connections {
        target: MapData
        function onLaunchRequested(appId, name) {
            const e = root._entries[appId];
            if (e) e.execute();
            else console.warn("SystemLive: no desktop entry for '" + appId + "' (" + name + ")");
        }
        function onOpenChanged() { if (MapData.open) debounce.restart(); }     // fresh window titles when the map opens
    }

    // ---------------- workspaces + windows ----------------
    readonly property var wsEvents: ["workspace", "focusedmon", "openwindow", "closewindow", "movewindow"]

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.wsEvents.indexOf(event.name) !== -1) debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: 150
        repeat: false
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["sh", "-c", "hyprctl -j workspaces; echo @@@; hyprctl -j clients; echo @@@; hyprctl -j activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: root.applyHypr(text)
        }
    }

    function applyHypr(out) {
        const p = out.split("@@@");
        let ws = [], cl = [], act = null;
        try {
            ws = JSON.parse(p[0]);
            cl = JSON.parse(p[1]);
            act = JSON.parse(p[2]);
        } catch (e) {
            console.warn("SystemLive: hyprctl output was not JSON: " + e);
            return;
        }
        const wins = ({});
        for (let i = 0; i < cl.length; i++) {
            const c = cl[i];
            if (c.mapped === false) continue;
            const id = c.workspace ? c.workspace.id : 0;
            if (id <= 0) continue;                              // special workspaces (scratchpads) have negative ids
            if (!wins[id]) wins[id] = [];
            const cls = String(c.class || c.initialClass || "?");
            wins[id].push(c.title ? cls + " - " + c.title : cls);
        }
        let top = 10;
        for (let i = 0; i < ws.length; i++) if (ws[i].id > top) top = ws[i].id;
        const list = [];
        for (let id = 1; id <= top; id++) list.push({ id: id, windows: wins[id] ? wins[id].length : 0 });
        WidgetData.workspaces = list;
        if (act && act.id > 0) WidgetData.activeWorkspace = act.id;
        MapData.setWindows(wins);
    }

    // ---------------- uptime ----------------
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: uptimeProbe.running = true
    }
    Process {
        id: uptimeProbe
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(String(text).split(" ")[0]);
                if (!isNaN(v)) WidgetData.uptimeSeconds = v;
            }
        }
    }
}
