pragma Singleton
import QtQuick
import ".."

// =====================================================================
//  MapData: the ONE place the Map View (ship log map) gets its state and its page entries from.
//  Plain QtObject, NO Quickshell import, so it also loads under plain `qml` on Mint.
//
//  Layers (same split as RumorData / SignalscopeData):
//    * state      open, pageOpen, selectedId, entryId, zoomTarget, rumorMode ...   (the view only reads / writes these)
//    * catalog    the planets on the map: where they sit, how they are tinted
//    * providers  one per planet: entriesFor() = the list (structure only, cheap), describe() = text / picture of one
//                 entry (live values), actionFor() / runAction() = the button under the picture
//    * mock data  apps and window titles. Live: call setApps() / setWindows() from a live-only file (sketch at the bottom).
//
//  IDLE COST: no Timer, nothing runs while the map is closed. Providers are only evaluated by the open view.
// =====================================================================
QtObject {
    id: root

    property bool mock: true

    // ---------------- OPEN / CLOSE (single source of truth) ----------------
    property bool open: false
    property string toggleKey: "N"          // window shortcut (MapHost.qml). Free keys only: never W A S D Space Shift Ctrl Esc (rig),
                                            // L (Rumor Map), Q Left Right Up Down P , . M (Signalscope)
    function toggle() { open = !open; }
    function show()   { open = true; }
    function hide()   { open = false; }

    // ---------------- VIEW STATE ----------------
    property bool pageOpen: false           // false = the grid, true = the planet page
    property string selectedId: "timber_hearth"
    property string entryId: ""             // selected entry on the planet page ("" = the first one)
    property real zoomTarget: 1.0           // 1 = in-game close view (selected planet centred), 0 = whole system at once
    property bool rumorMode: false          // the Rumor Map is up on top of this map (the map is hidden, not closed)
    property bool returning: false          // "Back to Map" was pressed (instead of closing the Rumor Map for good)

    // Planets whose action button works. Everything else shows it dimmed ("READ-ONLY") until its real adapter exists.
    // When an adapter lands, add the id here.
    property var interactiveIds: ({ ember_twin: true, ash_twin: true, dark_bramble: true })

    // Planet pictures for the map. false = flat placeholder discs. true = load map_icons/<planet id>.png (transparent
    // render, any size), e.g. map_icons/timber_hearth.png; a planet whose file is missing keeps its placeholder disc.
    property bool useIcons: false
    readonly property url iconDir: Qt.resolvedUrl("map_icons/")

    signal launchRequested(string appId, string name)           // Dark Bramble action (live: launch the app, see bottom)
    signal pinRequested(string statId, string label)            // Brittle Hollow / Hollow's Lantern action (live: pin to the HUD)
    signal rumorFocusRequested(string notificationId)           // Interloper action (live: focus that card in the Rumor Map)

    property var pendingTune: null          // { id, planet } while the map closes after "Tune Signalscope"

    onOpenChanged: {
        if (!open) {
            pageOpen = false;
            if (rumorMode) { rumorMode = false; returning = false; RumorData.hide(); }
            if (pendingTune) {
                const t = pendingTune;
                pendingTune = null;
                SignalscopeData.dispatch("equip");
                SignalscopeData.lastId = t.id;          // Left / Right channel cycling continues from here
                SignalscopeData.alignRequested(t.planet);
            }
        }
    }

    // ---------------- CATALOG ----------------
    // x / y: position on the map in "column" units (1 = one column apart). d: diameter in the same units.
    // moons sit under their parent. fill / ring: placeholder disc colours (the real planet looks live in the rig).
    readonly property var catalog: [
        { id: "sun",             name: "The Sun",          role: "Clock / Loop",          x: -0.25, y: 0.0, d: 2.00, fill: "#E2531F", ring: "#FF9A4A", moonOf: "" },
        { id: "sun_station",     name: "Sun Station",      role: "System Power",          x: 1.05, y: 0.0, d: 0.20, fill: "#BDB6A4", ring: "#E6D5B8", moonOf: "" },
        { id: "ember_twin",      name: "Ember Twin",       role: "Audio / Media",         x: 2.05, y: 0.0, d: 0.42, fill: "#D8512C", ring: "#F2A08A", moonOf: "" },
        { id: "ash_twin",        name: "Ash Twin",         role: "Timer / Sand",          x: 2.05, y: 0.52, d: 0.42, fill: "#BFA27A", ring: "#E3CBA0", moonOf: "ember_twin" },
        { id: "timber_hearth",   name: "Timber Hearth",    role: "Workspaces",            x: 3.10, y: 0.0, d: 0.44, fill: "#3F7D5A", ring: "#6FA8E8", moonOf: "" },
        { id: "attlerock",       name: "Attlerock",        role: "Quick Notes",           x: 3.10, y: 0.50, d: 0.15, fill: "#8E8D98", ring: "#C9C8D2", moonOf: "timber_hearth" },
        { id: "brittle_hollow",  name: "Brittle Hollow",   role: "Memory / Disk",         x: 4.15, y: 0.0, d: 0.50, fill: "#6A5FA8", ring: "#B3A9E6", moonOf: "" },
        { id: "hollows_lantern", name: "Hollow's Lantern", role: "CPU Temp",              x: 4.15, y: 0.52, d: 0.14, fill: "#8A4A22", ring: "#E88B50", moonOf: "brittle_hollow" },
        { id: "giants_deep",     name: "Giant's Deep",     role: "Network / Tray",        x: 5.20, y: 0.0, d: 0.58, fill: "#1E8A68", ring: "#6FEAC8", moonOf: "" },
        { id: "dark_bramble",    name: "Dark Bramble",     role: "App Launcher",          x: 6.25, y: 0.0, d: 0.52, fill: "#3A5A3C", ring: "#8BBF7A", moonOf: "" },
        { id: "interloper",      name: "The Interloper",   role: "Notifications / Shots", x: 7.30, y: 0.0, d: 0.22, fill: "#9FDCF2", ring: "#E0FFFF", moonOf: "" },
        { id: "quantum_moon",    name: "Quantum Moon",     role: "Quantum Satellite",     x: 8.35, y: 0.0, d: 0.17, fill: "#8B849C", ring: "#D1C7BD", moonOf: "" }
    ]

    function body(id) {
        for (let i = 0; i < catalog.length; i++) if (catalog[i].id === id) return catalog[i];
        return null;
    }
    function hasMoon(id) {
        for (let i = 0; i < catalog.length; i++) if (catalog[i].moonOf === id) return true;
        return false;
    }
    function nameOf(id) { const b = body(id); return b ? b.name : id; }

    function initials(s) {
        const w = String(s || "").replace(/[^A-Za-z0-9 ]+/g, " ").trim().split(/\s+/);
        if (w.length === 0 || w[0] === "") return "?";
        return (w.length === 1 ? w[0].substring(0, 2) : w[0][0] + w[1][0]).toUpperCase();
    }

    // ---------------- NAVIGATION ----------------
    // dir: "left" | "right" | "up" | "down". Returns the neighbouring planet id, or the same id when there is none.
    function neighbor(id, dir) {
        const c = body(id);
        if (!c) return id;
        let best = null, bestScore = 1e9;
        for (let i = 0; i < catalog.length; i++) {
            const b = catalog[i];
            if (b.id === id) continue;
            const dx = b.x - c.x, dy = b.y - c.y;
            let score = -1;
            if (dir === "left" && dx < -0.01)       score = -dx * 10 + Math.abs(dy);
            else if (dir === "right" && dx > 0.01)  score = dx * 10 + Math.abs(dy);
            else if (dir === "up" && Math.abs(dx) < 0.01 && dy < -0.01)   score = -dy;
            else if (dir === "down" && Math.abs(dx) < 0.01 && dy > 0.01)  score = dy;
            if (score >= 0 && score < bestScore) { best = b; bestScore = score; }
        }
        return best ? best.id : id;
    }
    function select(id) {
        if (!body(id) || id === selectedId) return;
        selectedId = id;
        entryId = "";
    }
    function move(dir) { select(neighbor(selectedId, dir)); }
    function openPage()  { pageOpen = true; }
    function closePage() { pageOpen = false; }
    function zoomBy(step) { zoomTarget = Math.max(0, Math.min(1, zoomTarget + step)); }

    // ---------------- RUMOR MODE <-> MAP ----------------
    function enterRumor() {
        if (!open || rumorMode) return;
        rumorMode = true;
        RumorData.show();
    }
    function backToMap() {
        if (!rumorMode) return;
        returning = true;
        RumorData.hide();
    }

    // ---------------- DATA THAT HAS NO SOURCE YET (MOCK) ----------------
    // [{ id, name, comment, category, icon }]  icon = file:// url or "" (monogram). Live: setApps().
    property var apps: []
    function setApps(list) { apps = list; }
    // windows per workspace id: { "1": ["Firefox - page title", ...] }. Live: setWindows().
    property var windowsByWs: ({})
    function setWindows(map) { windowsByWs = map; }

    readonly property var _mockWinPool: ["Firefox - Quickshell docs", "Kitty - ~/.config/quickshell", "Files - Downloads", "Discord - #general",
                                         "VS Code - CameraRig.qml", "Spotify", "OBS Studio", "Steam - Library"]
    function windowsOf(wsId, count) {
        const real = windowsByWs[String(wsId)];
        if (real) return real;
        const out = [];
        for (let i = 0; i < count; i++) out.push(_mockWinPool[(wsId * 3 + i) % _mockWinPool.length]);
        return out;
    }

    Component.onCompleted: {
        if (!mock) return;
        apps = [
            { id: "firefox",      name: "Firefox",       comment: "Browse the web.",                       category: "Internet" },
            { id: "discord",      name: "Discord",       comment: "Voice and text chat.",                  category: "Internet" },
            { id: "kitty",        name: "Kitty",         comment: "A fast, GPU-accelerated terminal.",     category: "Development" },
            { id: "code",         name: "Visual Studio Code", comment: "Edit code.",                       category: "Development" },
            { id: "godot",        name: "Godot Engine",  comment: "Make 2D and 3D games.",                 category: "Development" },
            { id: "spotify",      name: "Spotify",       comment: "Stream music.",                         category: "Media" },
            { id: "mpv",          name: "mpv",           comment: "Play videos and audio files.",          category: "Media" },
            { id: "obs",          name: "OBS Studio",    comment: "Record and stream video.",              category: "Media" },
            { id: "steam",        name: "Steam",         comment: "Your game library.",                    category: "Games" },
            { id: "gimp",         name: "GIMP",          comment: "Edit images.",                          category: "Graphics" },
            { id: "blender",      name: "Blender",       comment: "Model, animate and render in 3D.",      category: "Graphics" },
            { id: "thunar",       name: "Files",         comment: "Browse the file system.",               category: "System" },
            { id: "settings",     name: "Settings",      comment: "Change how the system behaves.",        category: "System" }
        ];
    }

    // ---------------- PROVIDERS ----------------
    // Which planets have something to show. Cheap on purpose (reads lengths only, never live numbers).
    // Planets that return false are drawn as outlines; they fill in as soon as this turns true.
    function hasData(id) {
        switch (id) {
        case "sun":             return true;
        case "ember_twin":
        case "ash_twin":        return SignalscopeData.channels.length > 0;
        case "timber_hearth":   return WidgetData.workspaces.length > 0;
        case "attlerock":       return String(WidgetData.notesText || "").trim() !== "";
        case "brittle_hollow":
        case "hollows_lantern": return mock;            // live: true once the sysinfo adapter exists
        case "dark_bramble":    return apps.length > 0;
        case "interloper":      return RumorData.notifications.length > 0;
        default:                return false;           // Sun Station, Giant's Deep, Quantum Moon: no provider yet
        }
    }
    function entryCount(id) { return entriesFor(id).length; }

    // The list on the planet page, STRUCTURE ONLY (no per-second numbers, so the list does not rebuild every tick):
    // [{ eid, group, title }] in display order, entries of one group next to each other.
    function entriesFor(id) {
        const out = [];
        switch (id) {
        case "ember_twin":
        case "ash_twin": {
            // Both twins list every audio player; the Signalscope puts each one on its own planet.
            const chs = SignalscopeData.channels;
            for (let pass = 0; pass < 2; pass++)
                for (let i = 0; i < chs.length; i++)
                    if ((pass === 0) === !!chs[i].playing)
                        out.push({ eid: chs[i].id, group: pass === 0 ? "Playing" : "Paused", title: chs[i].name });
            break;
        }
        case "dark_bramble": {
            const cats = [];
            for (let i = 0; i < apps.length; i++) if (cats.indexOf(apps[i].category) < 0) cats.push(apps[i].category);
            cats.sort();
            for (let c = 0; c < cats.length; c++) {
                const inCat = apps.filter(a => a.category === cats[c]).sort((a, b) => a.name.localeCompare(b.name));
                for (let i = 0; i < inCat.length; i++) out.push({ eid: inCat[i].id, group: cats[c], title: inCat[i].name });
            }
            break;
        }
        case "timber_hearth": {
            const ws = WidgetData.workspaces;
            for (let i = 0; i < ws.length; i++)
                out.push({ eid: "ws" + ws[i].id, group: "Workspaces",
                           title: "Workspace " + ws[i].id + (ws[i].id === WidgetData.activeWorkspace ? "  (here)" : "") });
            break;
        }
        case "interloper": {
            const ns = RumorData.notifications.slice().sort((a, b) => b.time - a.time).slice(0, 14);
            const apps2 = [];
            for (let i = 0; i < ns.length; i++) if (apps2.indexOf(ns[i].app) < 0) apps2.push(ns[i].app);   // newest app first
            for (let a = 0; a < apps2.length; a++)
                for (let i = 0; i < ns.length; i++)
                    if (ns[i].app === apps2[a]) out.push({ eid: ns[i].id, group: apps2[a], title: ns[i].summary !== "" ? ns[i].summary : "(no title)" });
            break;
        }
        case "brittle_hollow":
            if (!mock) break;
            out.push({ eid: "mem:ram",  group: "Memory", title: "RAM" });
            out.push({ eid: "mem:swap", group: "Memory", title: "Swap" });
            out.push({ eid: "disk:/",          group: "Disk", title: "/  (system)" });
            out.push({ eid: "disk:/home",      group: "Disk", title: "/home" });
            out.push({ eid: "disk:/mnt/games", group: "Disk", title: "/mnt/games" });
            break;
        case "hollows_lantern":
            if (!mock) break;
            out.push({ eid: "temp:pkg",  group: "Temperatures", title: "CPU package" });
            for (let i = 0; i < 4; i++) out.push({ eid: "temp:c" + i, group: "Temperatures", title: "Core " + i });
            out.push({ eid: "temp:gpu",  group: "Temperatures", title: "GPU" });
            out.push({ eid: "temp:nvme", group: "Temperatures", title: "NVMe drive" });
            out.push({ eid: "load:cpu",  group: "Load", title: "CPU load" });
            break;
        case "attlerock": {
            const lines = String(WidgetData.notesText || "").split("\n");
            for (let i = 0; i < lines.length; i++) {
                const t = lines[i].trim();
                if (t === "") continue;
                out.push({ eid: "n" + i, group: "Notes", title: t.length > 40 ? t.substring(0, 39) + "..." : t });
            }
            break;
        }
        case "sun": {
            out.push({ eid: "local", group: "Clock", title: "Local time" });
            const z = WidgetData.worldZones;
            for (let i = 0; i < z.length; i++) out.push({ eid: "z" + i, group: "Clock", title: z[i].label });
            out.push({ eid: "uptime", group: "System", title: "Uptime" });
            break;
        }
        default: break;
        }
        return out;
    }

    // Text and picture of one entry: { text: [paragraphs], image: url or "", glyph: "AB" }.
    // Evaluated by the page's description binding only, so live values update there without touching the list.
    function describe(id, eid) {
        const none = { text: [], image: "", glyph: "?" };
        switch (id) {
        case "ember_twin":
        case "ash_twin": {
            const ch = SignalscopeData.channelById(eid);
            if (!ch) return none;
            const t = [];
            t.push("Track: " + (ch.title !== "" ? ch.title : "nothing queued"));
            if (ch.artist !== "") t.push("Artist: " + ch.artist);
            t.push((ch.playing ? "Playing" : "Paused") + ", volume " + Math.round(ch.volume * 100) + "%" + (ch.muted ? " (muted)" : "")
                   + ". Its signal comes from " + nameOf(ch.planet) + ".");
            return { text: t, image: ch.art || "", glyph: initials(ch.name) };
        }
        case "dark_bramble": {
            const a = apps.find(x => x.id === eid);
            if (!a) return none;
            return { text: [a.comment, "Category: " + a.category], image: a.icon || "", glyph: initials(a.name) };
        }
        case "timber_hearth": {
            const n = parseInt(String(eid).substring(2));
            const w = WidgetData.workspaces.find(x => x.id === n);
            if (!w) return none;
            const names = windowsOf(n, w.windows);
            const t = ["Workspace " + n + ": " + (w.windows === 0 ? "no windows." : w.windows + (w.windows === 1 ? " window." : " windows."))
                       + (n === WidgetData.activeWorkspace ? " You are here." : "")];
            for (let i = 0; i < names.length; i++) t.push(names[i]);
            return { text: t, image: "", glyph: String(n) };
        }
        case "interloper": {
            const n = RumorData.notifications.find(x => x.id === eid);
            if (!n) return none;
            return { text: [n.body !== "" ? n.body : "(no message text)", n.app + ", " + RumorData.formatTime(n.time)],
                     image: n.image || "", glyph: initials(n.app) };
        }
        case "brittle_hollow": return _memDisk(eid);
        case "hollows_lantern": return _sensors(eid);
        case "attlerock": {
            const lines = String(WidgetData.notesText || "").split("\n");
            const i = parseInt(String(eid).substring(1));
            return { text: [i < lines.length ? lines[i].trim() : ""], image: "", glyph: "N" };
        }
        case "sun": {
            if (eid === "local") return { text: [Qt.formatDateTime(WidgetData.now, "HH:mm:ss"), Qt.formatDateTime(WidgetData.now, "dddd d MMMM yyyy")], image: "", glyph: "SU" };
            if (eid === "uptime") return { text: [WidgetData.formatUptime(WidgetData.uptimeSeconds)], image: "", glyph: "UP" };
            const z = WidgetData.worldZones[parseInt(String(eid).substring(1))];
            if (!z) return none;
            return { text: [WidgetData.zoneTime(z.offsetMin) + "  " + z.label], image: "", glyph: z.label.substring(0, 2) };
        }
        default: return none;
        }
    }

    // The button under the picture. null = this planet has no action at all (the button is hidden).
    // { label, enabled }: enabled is false for planets that are read-only for now (the button shows dimmed).
    function actionFor(id, eid) {
        let label = "";
        switch (id) {
        case "ember_twin":
        case "ash_twin":        label = "Tune Signalscope"; if (!SignalscopeData.channelById(eid)) return null; break;
        case "dark_bramble":    label = "Launch App"; break;
        case "interloper":      label = "Open In Rumor Map"; break;
        case "brittle_hollow":
        case "hollows_lantern": label = "Pin To HUD"; break;
        default: return null;
        }
        return { label: label, enabled: interactiveIds[id] === true };
    }

    function runAction(id, eid) {
        const act = actionFor(id, eid);
        if (!act || !act.enabled || eid === "") return;
        switch (id) {
        case "ember_twin":
        case "ash_twin": {
            const ch = SignalscopeData.channelById(eid);
            if (!ch) return;
            pendingTune = { id: ch.id, planet: ch.planet };
            open = false;                       // onOpenChanged equips the scope and aims it
            break;
        }
        case "dark_bramble": {
            const a = apps.find(x => x.id === eid);
            if (!a) return;
            launchRequested(a.id, a.name);
            if (mock) console.log("[MapData] mock: would launch '" + a.name + "' (" + a.id + ")");
            open = false;                       // like the game: acting on an entry puts you back in the world
            break;
        }
        case "interloper":
            rumorFocusRequested(eid);
            enterRumor();
            break;
        case "brittle_hollow":
        case "hollows_lantern": {
            const e = entriesFor(id).find(x => x.eid === eid);
            pinRequested(eid, e ? e.title : eid);
            if (mock) console.log("[MapData] mock: would pin '" + (e ? e.title : eid) + "' to the HUD");
            break;
        }
        default: break;
        }
    }

    // ---------------- MOCK SYSTEM NUMBERS (live values come from HudData, the rest is made up) ----------------
    function _bar(f) {
        const n = 20, k = Math.round(Math.max(0, Math.min(1, f)) * n);
        let s = "";
        for (let i = 0; i < n; i++) s += i < k ? "#" : ".";
        return "[" + s + "]";
    }
    function _memDisk(eid) {
        let used = 0, total = 1, label = "", unit = "GB";
        if (eid === "mem:ram")           { total = 16; used = HudData.ram * 16; label = "RAM"; }
        else if (eid === "mem:swap")     { total = 8;  used = 1.2; label = "Swap"; }
        else if (eid === "disk:/")       { total = 238;  used = 145; label = "Disk /"; }
        else if (eid === "disk:/home")   { total = 931;  used = 400; label = "Disk /home"; }
        else if (eid === "disk:/mnt/games") { total = 1863; used = 1341; label = "Disk /mnt/games"; }
        else return { text: [], image: "", glyph: "?" };
        const f = used / total;
        return { text: [label + ": " + used.toFixed(used < 10 ? 1 : 0) + " of " + total + " " + unit + " in use (" + Math.round(f * 100) + "%).", _bar(f)],
                 image: "", glyph: eid.indexOf("mem") === 0 ? "RAM" : "DSK" };
    }
    function _sensors(eid) {
        const pkg = 38 + HudData.cpu * 42;
        let t = [], g = "TMP";
        if (eid === "temp:pkg")       t = ["CPU package: " + pkg.toFixed(0) + " C."];
        else if (eid.indexOf("temp:c") === 0 && eid !== "temp:cpu") {
            const i = parseInt(eid.substring(6));
            t = ["Core " + i + ": " + (pkg + (i % 2 ? -2 : 1) * (1 + i * 0.4)).toFixed(0) + " C."];
        }
        else if (eid === "temp:gpu")  t = ["GPU: " + (44 + HudData.cpu * 18).toFixed(0) + " C."];
        else if (eid === "temp:nvme") t = ["NVMe drive: 41 C."];
        else if (eid === "load:cpu")  { t = ["CPU load: " + Math.round(HudData.cpu * 100) + "%.", _bar(HudData.cpu)]; g = "CPU"; }
        else return { text: [], image: "", glyph: "?" };
        return { text: t, image: "", glyph: g };
    }

    // ---------------- GO LIVE (sketch, untested) ----------------
    // A live-only file that ONLY shell.qml loads (like SignalscopeMpris.qml); it sets MapData.mock = false and feeds:
    //   apps:     import Quickshell; DesktopEntries.applications.values -> setApps(list.map(e => ({ id: e.id, name: e.name,
    //             comment: e.comment, category: (e.categories[0] || "Other"), icon: "file://" + Quickshell.iconPath(e.icon, true) })))
    //   launch:   Connections { target: MapData; function onLaunchRequested(appId) { DesktopEntries.byId(appId).execute(); } }
    //   windows:  Hyprland.toplevels -> setWindows({ "<workspace id>": ["<class> - <title>", ...] })
    //   pins:     Connections { target: MapData; function onPinRequested(statId, label) { ... HudData pin API ... } }
    //   Brittle Hollow / Hollow's Lantern: their entriesFor() / describe() branches above are mock-only; replace them with
    //   readings from /proc/meminfo, statvfs and /sys/class/hwmon, then add the ids to `interactiveIds`.
}
