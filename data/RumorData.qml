pragma Singleton
import QtQuick
import ".."

// =====================================================================
//  RumorData: the ONE place the Rumor Map (ship log) gets its data from,
//  and the single switch that opens/closes it.
//  Same idea as WidgetData / HudData: everything below is MOCK today. When
//  you move to the PC, keep the public surface and feed `push()` from the
//  real notification source (the "go live" sketch is at the bottom).
//
//  IDLE COST: nothing in here runs on a timer. The graph layout is only
//  computed when the overlay asks for it (buildGraph), never while closed.
// =====================================================================
QtObject {
    id: root

    property bool mock: true
    property bool mockEmpty: false          // true = start with NO history (to see the first-open empty state)

    // ---------------- OPEN / CLOSE (single source of truth) ----------------
    // Everything that wants to show or hide the map just calls these:
    // the keybind, the Interloper widget, a Hyprland global shortcut, an IPC call.
    property bool open: false
    property string toggleKey: "L"          // window shortcut (RumorMap.qml); never W A S D Space Shift Ctrl Esc, those are the rig's
    function toggle() { open = !open; }
    function show()   { open = true; }
    function hide()   { open = false; }

    // ---------------- DATA ----------------
    // One entry per notification:
    //   { id, app, summary, body, time (ms since epoch), thread ("" = none) }
    property var notifications: []
    property var readIds: ({})              // { id: true }  (in memory today; live: persist, see bottom)
    property int maxNodes: 150              // the map only ever shows the newest N
    property int maxPerApp: 36              // ... and at most this many per app cluster
    property bool lockThreads: true         // a thread reply stays "locked" (???) until the message before it is read.
                                            // false = nothing is ever locked.
    property int agingHours: 24             // READ notifications older than this fade; 2+ of them per app gather into one
                                            // "N older" stack card (Enter spreads them out). Pinned and unread cards never age away.
    property var pinnedIds: ({})            // { id: true }  pinned cards always stay on the map
    property var expandedArchives: ({})     // { appName: true } while the map is open
    property bool typing: false             // set by the view while the search box has the keys (suspends the L shortcut)
    property bool _loading: true            // true while the mock fills itself, so it does not fire "arrived"

    signal arrived(var n)                   // a NEW notification came in (toast + widget flash listen to this)
    signal openRequested(var n)             // the user asked to open the app behind a card (go-live: launch it, see bottom)

    readonly property int unreadCount: {
        let c = 0;
        for (let i = 0; i < notifications.length; i++)
            if (!readIds[notifications[i].id]) c++;
        return c;
    }

    function push(n) {
        // the one entry point for new notifications (mock and live both use it)
        //   n.urgency: "low" | "normal" | "critical"   n.appId: desktop-entry id, used to open the app (optional)
        //   n.image: optional picture URL (sender avatar, thumbnail ...). file:// url, qrc, or image://... Cards without
        //            one keep the compact monogram layout; cards with one get the game-style picture card.
        for (let i = 0; i < notifications.length; i++)
            if (notifications[i].id === n.id) return;
        const rec = {
            id: n.id,
            app: n.app || "Unknown",
            appId: n.appId || "",
            summary: n.summary || "",
            body: n.body || "",
            time: n.time || Date.now(),
            thread: n.thread || "",
            urgency: n.urgency || "normal",
            image: n.image || ""
        };
        notifications = notifications.concat([rec]);
        if (!_loading) arrived(rec);
    }

    function clear() {
        notifications = [];
        readIds = ({});
        pinnedIds = ({});
    }

    // ---- actions on a card ----
    function togglePin(id) {
        let p = Object.assign({}, pinnedIds);
        if (p[id]) delete p[id]; else p[id] = true;
        pinnedIds = p;
    }
    function dismissMany(ids) {
        let drop = {};
        for (let i = 0; i < ids.length; i++) drop[ids[i]] = true;
        notifications = notifications.filter(n => !drop[n.id]);
        let r = Object.assign({}, readIds);
        let p = Object.assign({}, pinnedIds);
        for (let i = 0; i < ids.length; i++) { delete r[ids[i]]; delete p[ids[i]]; }
        readIds = r;
        pinnedIds = p;
        // go-live: also tell the notification daemon / your persisted history (see bottom)
    }
    function dismiss(id) { dismissMany([id]); }
    function openApp(id) {
        for (let i = 0; i < notifications.length; i++) {
            if (notifications[i].id === id) {
                markRead(id);
                openRequested(notifications[i]);
                if (mock) console.log("[RumorData] mock: would open the app for '" + notifications[i].app + "' (" + notifications[i].summary + ")");
                return;
            }
        }
    }
    function toggleArchive(app) {
        let e = Object.assign({}, expandedArchives);
        if (e[app]) delete e[app]; else e[app] = true;
        expandedArchives = e;
    }
    onOpenChanged: {
        if (!open) { expandedArchives = ({}); typing = false; }
    }

    // newest notification as one line (the Interloper widget scrolls it)
    readonly property string latestLine: {
        let best = null;
        for (let i = 0; i < notifications.length; i++)
            if (!best || notifications[i].time > best.time) best = notifications[i];
        if (!best) return "NO RUMORS YET";
        return best.app.toUpperCase() + "   " + best.summary + (best.body !== "" ? " - " + best.body : "");
    }

    function markRead(id) {
        if (readIds[id]) return;
        let r = Object.assign({}, readIds);
        r[id] = true;
        readIds = r;
    }

    // "unread" (new rumor) | "read" (explored) | "locked" (thread reply whose predecessor is unread)
    function stateOfNode(n) {
        if (n.archive) return "read";
        if (readIds[n.id]) return "read";
        if (lockThreads && n.threadParent !== "" && !readIds[n.threadParent]) return "locked";
        return "unread";
    }

    // ---------------- FORMATTING ----------------
    function formatTime(ms) {
        const d = new Date(ms);
        const now = new Date();
        const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (ms >= startToday) return Qt.formatDateTime(d, "HH:mm");
        if (ms >= startToday - 86400000) return "Yesterday " + Qt.formatDateTime(d, "HH:mm");
        return Qt.formatDateTime(d, "ddd d MMM HH:mm");
    }

    // ---------------- GRAPH (pure function of `notifications`) ----------------
    // Region colours (rgb) like the game's colour-coded regions. An app always gets the same one (name hash).
    readonly property var palette: [
        [232, 136, 58],     // orange
        [63, 191, 106],     // green
        [142, 91, 208],     // purple
        [59, 130, 224],     // blue
        [216, 84, 75],      // red
        [53, 183, 176]      // teal
    ]
    // Fixed cluster anchors (world units, y down) so existing clusters do not move when a new app shows up.
    readonly property var anchors: [
        [0, 0], [1000, -210], [-960, 180], [210, -960],
        [-200, 940], [1020, 800], [-1000, -800], [1960, -120]
    ]
    // The anchors are spread out in steps depending on the biggest cluster (so small histories stay compact and the
    // whole map fits on screen, while a long chat thread still gets room). Clusters only shift when it crosses a step.
    function spreadFor(maxCount) {
        if (maxCount <= 6) return 0.65;
        if (maxCount <= 12) return 0.85;
        if (maxCount <= 20) return 1.05;
        return 1.35;
    }
    readonly property real cardW: 132       // text card size in world units (the view multiplies by its ui scale)
    readonly property real cardH: 56
    readonly property real imgCardW: 104    // picture card (like the game's cards: title on top, picture below)
    readonly property real imgCardH: 100
    readonly property url assetDir: Qt.resolvedUrl("rumor_assets/")   // mock pictures live here

    function hashStr(s) {
        let h = 0;
        for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
        return h;
    }

    // Returns { nodes, links, clusters, byId, bounds }.
    //   node:    { id, app, summary, body, time, thread, x, y, w, h, rgb, threadParent, parent, linkKind,
    //              urgency, pinned, aged, archive, ids, count, sizeK, image }
    //   link:    { from, to, kind: "thread" | "app" }   (from = earlier, to = later)
    //   cluster: { app, rgb, x, y }   (label position)
    function buildGraph() {
        const now = Date.now();
        const agingMs = agingHours * 3600000;
        let list = notifications.slice().sort((a, b) => a.time - b.time);

        // retention: newest maxPerApp per app, newest maxNodes overall; pinned cards always stay
        let perApp = {};
        let kept = [];
        for (let i = list.length - 1; i >= 0; i--) {
            const n = list[i];
            perApp[n.app] = (perApp[n.app] || 0) + 1;
            if (pinnedIds[n.id] || perApp[n.app] <= maxPerApp) kept.push(n);
        }
        kept.reverse();
        let over = kept.length - maxNodes;
        if (over > 0) kept = kept.filter(n => {
            if (over > 0 && !pinnedIds[n.id]) { over--; return false; }
            return true;
        });

        // group by app in order of first appearance
        let apps = [];
        let appIdx = {};
        for (let i = 0; i < kept.length; i++) {
            const n = kept[i];
            if (appIdx[n.app] === undefined) { appIdx[n.app] = apps.length; apps.push({ name: n.app, items: [] }); }
            apps[appIdx[n.app]].items.push(n);
        }

        // aging: 2+ old READ cards of an app gather into one stack card (unless that app's stack was spread out)
        for (let k = 0; k < apps.length; k++) {
            const app = apps[k];
            const agedRead = app.items.filter(n => !pinnedIds[n.id] && now - n.time > agingMs && readIds[n.id]);
            if (!expandedArchives[app.name] && agedRead.length >= 2) {
                let drop = {};
                for (let i = 0; i < agedRead.length; i++) drop[agedRead[i].id] = true;
                const stack = {
                    id: "archive:" + app.name, archive: true, app: app.name, thread: "", urgency: "normal", appId: "", image: "",
                    ids: agedRead.map(n => n.id), count: agedRead.length, time: agedRead[agedRead.length - 1].time,
                    summary: agedRead.length + " older rumors",
                    body: "Read notifications older than " + agingHours + " hours are gathered here. Press Enter to spread them out."
                };
                app.items = [stack].concat(app.items.filter(n => !drop[n.id]));
            }
        }

        let maxCount = 1;
        for (let k = 0; k < apps.length; k++) maxCount = Math.max(maxCount, apps[k].items.length);
        const spread = spreadFor(maxCount);

        let nodes = [];
        let links = [];
        let clusters = [];
        let byId = {};
        const GA = 2.399963;                // golden angle

        for (let k = 0; k < apps.length; k++) {
            const app = apps[k];
            const rgb = palette[hashStr(app.name) % palette.length];
            let anchor;
            if (k < anchors.length) anchor = [anchors[k][0] * spread, anchors[k][1] * spread];
            else {
                const j = k - anchors.length;
                anchor = [Math.cos(j * 0.9) * (2000 + j * 130) * spread, Math.sin(j * 0.9) * (2000 + j * 130) * spread];
            }

            let lastInApp = null;
            let lastInThread = {};
            let mine = [];
            for (let i = 0; i < app.items.length; i++) {
                const src = app.items[i];
                let parent = null;
                let kind = "";
                let threadParent = "";
                if (!src.archive && src.thread !== "" && lastInThread[src.thread]) {
                    parent = lastInThread[src.thread];
                    kind = "thread";
                    threadParent = parent.id;
                } else if (lastInApp) {
                    parent = lastInApp;
                    kind = "app";
                }
                const phase = (hashStr(app.name) % 628) / 100.0;
                const r = 98 * Math.sqrt(i);
                const pinned = !!pinnedIds[src.id];
                const node = {
                    id: src.id, app: src.app, summary: src.summary, body: src.body,
                    time: src.time, thread: src.thread, rgb: rgb,
                    appId: src.appId || "",
                    urgency: src.urgency || "normal",
                    pinned: pinned,
                    aged: !src.archive && !pinned && (now - src.time > agingMs),
                    archive: !!src.archive,
                    image: src.image || "",
                    w: (src.image || "") !== "" ? imgCardW : cardW,
                    h: (src.image || "") !== "" ? imgCardH : cardH,
                    ids: src.ids || [],
                    count: src.count || 0,
                    sizeK: src.urgency === "critical" ? 1.15 : 1.0,
                    threadParent: threadParent,
                    parent: parent ? parent.id : "",
                    linkKind: kind,
                    x: anchor[0] + Math.cos(i * GA + phase) * r,
                    y: anchor[1] + Math.sin(i * GA + phase) * r * 0.78
                };
                mine.push(node);
                nodes.push(node);
                byId[node.id] = node;
                if (parent) links.push({ from: parent.id, to: node.id, kind: kind });
                lastInApp = node;
                if (!src.archive && src.thread !== "") lastInThread[src.thread] = node;
            }

            // push overlapping cards apart (deterministic, small N)
            for (let it = 0; it < 40; it++) {
                let moved = false;
                for (let a = 0; a < mine.length; a++) {
                    for (let b = a + 1; b < mine.length; b++) {
                        const sk = (mine[a].sizeK + mine[b].sizeK) / 2;
                        const dx = mine[b].x - mine[a].x;
                        const dy = mine[b].y - mine[a].y;
                        const ox = ((mine[a].w + mine[b].w) / 2 + 20) * sk - Math.abs(dx);
                        const oy = ((mine[a].h + mine[b].h) / 2 + 18) * sk - Math.abs(dy);
                        if (ox > 0 && oy > 0) {
                            moved = true;
                            if (ox < oy) {
                                const s = (dx >= 0 ? 1 : -1) * ox * 0.5;
                                mine[a].x -= s; mine[b].x += s;
                            } else {
                                const s = (dy >= 0 ? 1 : -1) * oy * 0.5;
                                mine[a].y -= s; mine[b].y += s;
                            }
                        }
                    }
                }
                if (!moved) break;
            }

            let minY = 1e9, sx = 0;
            for (let i = 0; i < mine.length; i++) { minY = Math.min(minY, mine[i].y - mine[i].h * mine[i].sizeK / 2); sx += mine[i].x; }
            clusters.push({ app: app.name, rgb: rgb, x: sx / mine.length, y: minY - 30 });
        }

        let b = { minX: 0, minY: 0, maxX: 0, maxY: 0 };
        if (nodes.length > 0) {
            b = { minX: 1e9, minY: 1e9, maxX: -1e9, maxY: -1e9 };
            for (let i = 0; i < nodes.length; i++) {
                b.minX = Math.min(b.minX, nodes[i].x - nodes[i].w / 2);
                b.maxX = Math.max(b.maxX, nodes[i].x + nodes[i].w / 2);
                b.minY = Math.min(b.minY, nodes[i].y - nodes[i].h / 2);
                b.maxY = Math.max(b.maxY, nodes[i].y + nodes[i].h / 2);
            }
            for (let i = 0; i < clusters.length; i++) b.minY = Math.min(b.minY, clusters[i].y - 12);
        }
        return { nodes: nodes, links: links, clusters: clusters, byId: byId, bounds: b };
    }

    // ---------------- MOCK ----------------
    Component.onCompleted: {
        if (!mock || mockEmpty) { _loading = false; return; }
        const now = Date.now();
        const m = 60000;
        let id = 0;
        function add(app, thread, minsAgo, summary, body, read, urgency, image) {
            id++;
            push({ id: "m" + id, app: app, thread: thread, time: now - minsAgo * m, summary: summary, body: body,
                   urgency: urgency || "normal", image: image ? assetDir + image : "" });
            if (read) markRead("m" + id);
        }

        add("Telegram", "Mum", 340, "Mum", "Did you eat lunch?", true, "normal", "mum.png");
        add("Telegram", "Mum", 335, "Mum", "Call me when you are free, nothing urgent.", true);
        add("Telegram", "Mum", 110, "Mum", "Also bring the charger when you come over.", false, "normal", "mum.png");
        add("Telegram", "Mum", 20, "Mum", "Are you coming for dinner on Sunday? I am planning the menu.", false, "normal", "mum.png");

        add("Telegram", "Dev group", 900, "Dev group", "Has anyone got Quickshell running on i3?", true, "normal", "devgroup.png");
        add("Telegram", "Dev group", 893, "Dev group", "It needs a Wayland compositor, i3 will not cut it.", true);
        add("Telegram", "Dev group", 600, "Dev group", "Use the mock-data trick: stub the module and run offscreen.", false);
        add("Telegram", "Dev group", 590, "Dev group", "Screenshots with grabToImage are good enough for layout checks.", false);
        add("Telegram", "Dev group", 45, "Dev group", "New wallpaper pack dropped in the shared folder.", false, "normal", "devgroup.png");

        add("Thunderbird", "", 1500, "Your order has shipped", "Parcel 4471-A left the warehouse. Estimated delivery: 3 days.", true);
        add("Thunderbird", "", 1400, "Invoice 2041 attached", "Please find the invoice for last month attached to this mail.", true);
        add("Thunderbird", "Project kickoff", 800, "Project kickoff", "Agenda for Thursday: scope, owners, first milestone.", true, "normal", "pm.png");
        add("Thunderbird", "Project kickoff", 700, "Re: Project kickoff", "Can we move it to 15:00? I have a clash in the morning.", false);
        add("Thunderbird", "Project kickoff", 300, "Re: Project kickoff", "15:00 works. I will send the updated invite.", false, "normal", "pm.png");
        add("Thunderbird", "", 120, "Weekly digest", "Eleven new posts in the communities you follow.", false);

        add("Firefox", "", 1000, "Download complete", "wallpaper-4k.png (3.2 MB) finished downloading.", true);
        add("Firefox", "", 520, "Download complete", "notes.pdf (410 KB) finished downloading.", false);
        add("Firefox", "", 60, "Download complete", "wallpaper-sunset.png (3.2 MB) finished downloading.", false, "normal", "wallpaper.png");

        add("Software Updates", "", 2000, "12 updates available", "Packages: firefox, mesa, linux-firmware and 9 more.", true);
        add("Software Updates", "", 1990, "Update finished", "All packages are up to date.", true);
        add("Software Updates", "", 250, "Kernel update ready", "A new kernel was installed. It will be used after the next reboot.", false);
        add("Software Updates", "", 249, "Reboot recommended", "Restart soon to finish applying updates.", false);

        add("Calendar", "", 1200, "Dentist tomorrow 10:00", "Reminder: appointment at 10:00, bring your insurance card.", true);
        add("Calendar", "", 200, "Stand-up in 10 minutes", "Daily stand-up starts at 10:30.", true);
        add("Calendar", "", 30, "Evening plans at 21:00", "You have an event today at 21:00.", false);

        add("System", "", 15, "Low disk space", "Only 4% is free on /home. Clean up soon to avoid failed writes.", false, "critical");
        add("System", "", 400, "Backup finished", "Nightly backup completed without errors.", true);

        togglePin("m11");                   // the invoice stays on the map even when old
        _loading = false;
    }

    // ---------------- GO LIVE (untested sketch; wire up when at the PC) ----------------
    // 0. Set `mock: false` above. Everything the map shows comes through push(); nothing else changes.
    //
    // 1. NOTIFICATION SOURCE. Only ONE program can own org.freedesktop.Notifications on the session bus.
    //    Noctalia most likely already owns it on your PC (check: `busctl --user status org.freedesktop.Notifications`).
    //    If Noctalia owns it, a second NotificationServer here will either fail or steal the name, so pick ONE of:
    //      a) read Noctalia's notification history if it keeps one on disk (look in ~/.cache/noctalia and
    //         ~/.local/state/noctalia), parse it with FileView and call push() per entry. Safest, no daemon change.
    //      b) eavesdrop only: Process { command: ["dbus-monitor", "--session",
    //         "interface='org.freedesktop.Notifications',member='Notify'"] ... } and parse the Notify lines.
    //      c) if the OW shell is a separate config that REPLACES Noctalia's daemon, use a NotificationServer:
    //
    //      import Quickshell.Services.Notifications
    //      NotificationServer {
    //          keepOnReload: true
    //          bodySupported: true
    //          onNotification: n => {
    //              n.tracked = true;    // keep the object alive; drop this if you only want history
    //              root.push({
    //                  id: "n" + n.id + "-" + Date.now(),
    //                  app: n.appName,
    //                  summary: n.summary,
    //                  body: n.body,
    //                  appId: n.desktopEntry,       // used by "open app" below
    //                  // picture: the sender avatar / thumbnail the app sent, else the app icon. Both are image URLs
    //                  // that a QML Image can load (image://icon/... , image://qsimage/... , file://...).
    //                  image: n.image !== "" ? n.image : (n.appIcon !== "" ? Quickshell.iconPath(n.appIcon, true) : ""),
    //                  urgency: n.urgency === NotificationUrgency.Critical ? "critical"
    //                         : (n.urgency === NotificationUrgency.Low ? "low" : "normal"),
    //                  // freedesktop notifications have no thread id. This guess groups chat messages by
    //                  // sender/chat name (title). Tweak per app, or leave "" to link by app only.
    //                  thread: n.summary
    //              });
    //          }
    //      }
    //
    // 2a. OPEN APP (the "O" action). RumorData only emits openRequested(n); launch from the shell, e.g. in shell.qml:
    //        Connections { target: RumorData
    //            function onOpenRequested(n) { if (n.appId !== "") Quickshell.execDetached(["gtk-launch", n.appId]); } }
    //    Dismissing a card only removes it from the map. To also close it in the daemon keep the live Notification object
    //    per id (a map id -> n) and call n.dismiss() from a Connections on a dismissed signal you add to dismissMany().
    //
    // 2. READ STATE across restarts: persist `readIds` (JSON.stringify(Object.keys(readIds))) to
    //    ~/.local/share/ow-shell/shiplog-read.json with a debounced FileView write, and load it in Component.onCompleted.
    //    Persist `pinnedIds` the same way.
    //    Also persist `notifications` the same way if your source does not keep history for you.
    //
    // 3. OPEN FROM OUTSIDE THE WINDOW. Plain QML key shortcuts only work while this window has keyboard focus,
    //    and a background-layer layer-shell surface never gets keys. Use one of these (both just call toggle()):
    //      import Quickshell.Hyprland
    //      GlobalShortcut { appid: "ow-shell"; name: "rumormap"; description: "Toggle the rumor map"; onPressed: root.toggle() }
    //        hyprland.conf:  bind = SUPER, N, global, ow-shell:rumormap
    //      import Quickshell.Io
    //      IpcHandler { target: "rumormap"; function toggle(): void { root.toggle(); } }
    //        shell:          qs ipc call rumormap toggle     (bind that to a key in hyprland.conf)
    //    While the map is open the shell window must be on the overlay layer with keyboard focus, bind in shell.qml:
    //        WlrLayershell.layer: RumorData.open ? WlrLayer.Overlay : <your normal layer>
    //        WlrLayershell.keyboardFocus: RumorData.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
}
