import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// =====================================================================
//  SystemExtras: the last mock -> live step. ONE of these in shell.qml (after SystemLive { }).
//  SystemLive already feeds apps, workspaces, window titles and uptime; this file feeds the rest and switches the mock flags off:
//    * HUD            CPU and RAM arcs from Sensors; the orange "boost" arc = GPU load (a desktop has no battery);
//                     globe audio bands from `cava` (only while something plays and the scene is visible; no cava = globe stays idle)
//    * Map View       Brittle Hollow / Hollow's Lantern read Sensors (RAM, swap, real mounts, CPU / GPU / NVMe temps, loads)
//    * Rumor Map      notifications, read from the session bus with `busctl --user monitor` (eavesdrop only: Noctalia keeps owning
//                     the notification service). Saved to ~/.local/share/ow-shell/shiplog.json so history, read and pins survive restarts.
//                     "Open app" launches the desktop entry. Dismiss only removes the card here (the daemon is Noctalia's).
//    * Notes          ~/.local/share/ow-shell/notes.txt (loaded at start, saved 0.8 s after the last edit)
//  Check everything with:  qs -c outerwilds ipc call system status
// =====================================================================
Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string dataDir: home + "/.local/share/ow-shell"
    readonly property string notesPath: dataDir + "/notes.txt"
    readonly property string logPath: dataDir + "/shiplog.json"

    property bool cavaOk: true
    property bool busOk: false
    property int seenNotifications: 0
    property bool _notesReady: false
    property bool _logReady: false
    property string _lastKey: ""
    property real _lastKeyAt: 0
    property int _seq: 0

    Component.onCompleted: {
        // ---- switch the mocks off ----
        HudData.mock = false;
        HudData.audioActive = false;
        WidgetData.mock = false;
        MapData.mock = false;
        MapData.sysLive = true;
        RumorData.clear();                 // drop the mock history before the real one is loaded
        RumorData.mock = false;
        RumorData._loading = false;
        notesLoad.running = true;
        logLoad.running = true;
        busProc.running = true;
    }

    // ---------------- HUD ----------------
    Binding { target: HudData; property: "cpu";     value: Math.min(1, Sensors.cpuPercent / 100); when: !HudData.mock }
    Binding { target: HudData; property: "ram";     value: Math.min(1, Sensors.ramPercent / 100); when: !HudData.mock }
    Binding { target: HudData; property: "battery"; value: Math.min(1, Sensors.gpuPercent / 100); when: !HudData.mock }
    Binding {
        target: HudData; property: "audioActive"; when: !HudData.mock
        value: { const c = SignalscopeData.channels; for (let i = 0; i < c.length; i++) if (c[i].playing) return true; return false; }
    }
    onCavaOkChanged: if (!cavaOk) console.warn("SystemExtras: cava not found or failed; the HUD globe stays idle (install `cava` for live bands)");

    Process {
        id: cava
        running: !HudData.mock && HudData.audioActive && NoctaliaBridge.desktopVisible && root.cavaOk
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 3; mkdir -p \"$HOME/.cache/ow-shell\"; " +
            "printf '[general]\\nbars = 8\\nframerate = 30\\n[input]\\nsource = auto\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' > \"$HOME/.cache/ow-shell/cava.conf\"; " +
            "exec cava -p \"$HOME/.cache/ow-shell/cava.conf\""]
        stdout: SplitParser {
            onRead: data => {
                const p = String(data).split(";");
                if (p.length < 8) return;
                const b = [];
                for (let i = 0; i < 8; i++) b.push(Math.max(0, Math.min(1, (parseFloat(p[i]) || 0) / 100)));
                HudData.setBands(b);
            }
        }
        onExited: (code, status) => {
            HudData.setBands([0, 0, 0, 0, 0, 0, 0, 0]);
            if (code === 3 || code === 127) root.cavaOk = false;
        }
    }

    // ---------------- Map View ----------------
    Connections {
        target: MapData
        function onOpenChanged() { if (MapData.open) Sensors.refreshDisks(); }
    }

    // ---------------- notes ----------------
    Process {
        id: notesLoad
        command: ["sh", "-c", "cat \"" + root.notesPath + "\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (String(text) !== "" && WidgetData.notesText === "") WidgetData.notesText = String(text);
                root._notesReady = true;
            }
        }
    }
    Connections {
        target: WidgetData
        function onNotesTextChanged() { if (root._notesReady) notesSave.restart(); }
    }
    Timer { id: notesSave; interval: 800; repeat: false; onTriggered: root.writeFile(root.notesPath, String(WidgetData.notesText)) }

    Process { id: writer }
    Process { id: writer2 }
    function writeFile(path, text) {
        const w = (path === root.notesPath) ? writer : writer2;
        w.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "sh", path, text];
        w.running = false;
        w.running = true;
    }

    // ---------------- ship log persistence ----------------
    Process {
        id: logLoad
        command: ["sh", "-c", "cat \"" + root.logPath + "\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (String(text).trim() !== "") {
                        const d = JSON.parse(text);
                        const r = ({}), p = ({});
                        (d.read || []).forEach(k => r[k] = true);
                        (d.pinned || []).forEach(k => p[k] = true);
                        const loaded = (d.notifications || []).map(n => {
                            if (!n.image) n.image = root._resolveImage("", "", n.appId, n.app);
                            return n;
                        });
                        const have = RumorData.notifications;      // anything that arrived while loading
                        RumorData.notifications = loaded.concat(have);
                        RumorData.readIds = r;
                        RumorData.pinnedIds = p;
                    }
                } catch (e) { console.warn("SystemExtras: shiplog.json unreadable: " + e); }
                root._logReady = true;
            }
        }
    }
    function _saveLog() {
        const ns = RumorData.notifications.slice(-120).map(n => ({
            id: n.id, app: n.app, appId: n.appId, summary: n.summary, body: String(n.body || "").substring(0, 300),
            time: n.time, thread: n.thread, urgency: n.urgency, image: n.image || ""
        }));
        writeFile(root.logPath, JSON.stringify({ notifications: ns, read: Object.keys(RumorData.readIds), pinned: Object.keys(RumorData.pinnedIds) }));
    }
    Timer { id: logSave; interval: 1500; repeat: false; onTriggered: root._saveLog() }
    Connections {
        target: RumorData
        function onNotificationsChanged() { if (root._logReady) logSave.restart(); }
        function onReadIdsChanged()       { if (root._logReady) logSave.restart(); }
        function onPinnedIdsChanged()     { if (root._logReady) logSave.restart(); }
        function onOpenRequested(n) {
            const script = Qt.resolvedUrl("open_notif.py").toString().replace(/^file:\/\//, "");
            Quickshell.execDetached(["python3", script, String(n.appId || ""), String(n.app || ""), String(n.image || "")]);
            RumorData.hide();
        }
    }

    // ---------------- notifications (eavesdrop on the session bus) ----------------
    function _icon(name) {
        const n = String(name || "").trim();
        if (n === "") return "";
        if (n.indexOf("file://") === 0 || n.indexOf("image://") === 0 || n.indexOf("qrc:") === 0) return n;
        if (n.indexOf("/") === 0) return "file://" + n;
        try {
            const resolved = Quickshell.iconPath(n, true);
            if (resolved && String(resolved) !== "") return String(resolved);
        } catch (err) {}
        return "image://icon/" + n;
    }
    function _resolveImage(imgHint, appIcon, appId, appName) {
        const fromHint = _icon(imgHint);
        if (fromHint !== "") return fromHint;
        const fromIcon = _icon(appIcon);
        if (fromIcon !== "") return fromIcon;
        let e = null;
        try {
            if (appId) e = DesktopEntries.byId(appId);
            if (!e && appName && DesktopEntries.heuristicLookup) e = DesktopEntries.heuristicLookup(appName);
        } catch (err) { e = null; }
        if (e && e.icon) return _icon(e.icon);
        return "";
    }
    function _hint(h, key) {
        if (!h) return undefined;
        let v;
        if (Array.isArray(h)) {
            for (let i = 0; i < h.length; i++) {
                const e = h[i];
                if (Array.isArray(e) && e[0] === key) { v = e[1]; break; }
                if (e && e.key === key) { v = e.value; break; }
            }
        } else v = h[key];
        return (v !== null && typeof v === "object" && v.data !== undefined) ? v.data : v;
    }
    // one line of `data/notify_monitor.py` -> a RumorData record, or null
    function parseNotify(line, nowMs) {
        let m;
        try { m = JSON.parse(line); } catch (e) { return null; }
        if (!m || typeof m !== "object") return null;
        const appName = String(m.app || "Unknown");
        const summary = String(m.summary || "");
        const body = String(m.body || "");
        if (summary === "" && body === "") return null;
        const key = appName + "|" + summary + "|" + body;
        if (key === root._lastKey && nowMs - root._lastKeyAt < 2000) return null;
        root._lastKey = key; root._lastKeyAt = nowMs;
        const appId = String(m.appId || "");
        root._seq++;
        return {
            id: "d" + nowMs + "-" + root._seq,
            app: appName,
            appId: appId,
            summary: summary,
            body: body,
            time: nowMs,
            thread: summary,
            urgency: String(m.urgency || "normal"),
            image: _resolveImage(m.image || "", m.appIcon || "", appId, appName)
        };
    }

    Process {
        id: busProc
        command: ["python3", "-u", Qt.resolvedUrl("notify_monitor.py").toString().replace(/^file:\/\//, "")]
        stdout: SplitParser {
            onRead: line => {
                root.busOk = true;
                const rec = root.parseNotify(line, Date.now());
                if (rec) { root.seenNotifications++; RumorData.push(rec); }
            }
        }
        onExited: busRestart.restart()
    }
    Timer { id: busRestart; interval: 3000; repeat: false; onTriggered: busProc.running = true }

    // ---------------- diagnostics ----------------
    IpcHandler {
        target: "system"
        function status(): string {
            return JSON.stringify({
                sensors: { cpu: Sensors.cpuPercent, ram: Sensors.ramPercent, gpu: Sensors.gpuPercent, cpuTemp: Sensors.cpuTempC,
                           gpuTemp: Sensors.gpuTempC, nvmeTemp: Sensors.nvmeTempC, disks: Sensors.disks.length },
                sceneVisible: NoctaliaBridge.desktopVisible,
                hud: { mock: HudData.mock, audioActive: HudData.audioActive, cava: root.cavaOk },
                notifications: { busSeen: root.busOk, newSinceStart: root.seenNotifications, stored: RumorData.notifications.length },
                notesChars: String(WidgetData.notesText).length,
                dataDir: root.dataDir
            });
        }
        function refresh(): void { Sensors.refreshDisks(); }
    }
}
