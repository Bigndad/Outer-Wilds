pragma Singleton
import QtQuick

// =====================================================================
//  WidgetConfig: the ONE place that decides which widgets exist, which planet
//  each one orbits, and how big / fast / far / tilted it is.
//
//   * WidgetLayer.baseDefs (widgets/WidgetLayer.qml) stays the DEFAULT table and registers itself here.
//   * The settings panel edits `overrides` (and adds / removes `extras`); nothing else writes them.
//   * WidgetLayer asks liveDefs() for the merged, enabled list and follows `revision`.
//   * Saving: this file never touches the disk. It emits saveRequested(text) (debounced) and
//     WidgetConfigStore.qml (the only file that imports Quickshell.Io) writes widgets.json.
//
//  No Quickshell import on purpose, so this loads in plain `qml` on the Mint laptop too.
// =====================================================================
QtObject {
    id: root

    // ---------------- what the panel can offer ----------------
    readonly property var planets: [
        { id: "sun",             name: "The Sun" },
        { id: "sun_station",     name: "Sun Station" },
        { id: "ash_twin",        name: "Ash Twin" },
        { id: "ember_twin",      name: "Ember Twin" },
        { id: "timber_hearth",   name: "Timber Hearth" },
        { id: "attlerock",       name: "Attlerock" },
        { id: "brittle_hollow",  name: "Brittle Hollow" },
        { id: "hollows_lantern", name: "Hollow's Lantern" },
        { id: "giants_deep",     name: "Giant's Deep" },
        { id: "dark_bramble",    name: "Dark Bramble" },
        { id: "interloper",      name: "The Interloper" },
        { id: "quantum_moon",    name: "Quantum Moon" }
    ]

    // Every widget file that can be placed. `source` is relative to widgets/ (same as WidgetLayer defs).
    // designW = the file's width in px at ui = 1 (used to keep the on-screen size sensible when a slot's widget type is swapped).
    // title   = card title override for widgets that take one (blank = the widget's own).
    readonly property var catalog: [
        { source: "ClockWidget.qml",             name: "Clock",                 group: "Time",    designW: 300 },
        { source: "LoopWidget.qml",              name: "Loop timer",            group: "Time",    designW: 276 },
        { source: "UptimeWidget.qml",            name: "Uptime",                group: "Time",    designW: 236 },
        { source: "DateWorldWidget.qml",         name: "Date / world clocks",   group: "Time",    designW: 276 },
        { source: "serp/SunClock.qml",           name: "Dial clock (ilyamiro)", group: "Time",    designW: 220 },
        { source: "WorkspacesWidget.qml",        name: "Workspaces",            group: "System",  designW: 300 },
        { source: "NotesWidget.qml",             name: "Notes",                 group: "System",  designW: 280 },
        { source: "RumorWidget.qml",             name: "Ship log (rumors)",     group: "System",  designW: 250 },
        { source: "SignalscopeWidget.qml",       name: "Signalscope",           group: "System",  designW: 250 },
        { source: "serp/AshTwinBattery.qml",     name: "Battery (round)",       group: "System",  designW: 220, title: "BATTERY" },
        { source: "serp/EmberTwinBattery.qml",   name: "Battery (small)",       group: "System",  designW: 160, title: "BATTERY" },
        { source: "WeatherWidget.qml",           name: "Weather",               group: "Weather", designW: 280, title: "WEATHER" },
        { source: "serp/GiantsDeepWeather.qml",  name: "Weather (full)",        group: "Weather", designW: 360, title: "WEATHER" },
        { source: "serp/EmberTwinMusic.qml",     name: "Music player",          group: "Music",   designW: 340 },
        { source: "serp/EmberTwinLyrics.qml",    name: "Music + lyrics",        group: "Music",   designW: 340 },
        { source: "serp/DarkBrambleVisualiser.qml", name: "Visualiser",         group: "Music",   designW: 360, title: "VISUALISER" },
        { source: "serp/DarkBrambleDisc.qml",    name: "Disc player",           group: "Music",   designW: 210 },
        { source: "serp/DarkBrambleLyrics.qml",  name: "Lyrics",                group: "Music",   designW: 340 },
        { source: "BlankWidget.qml",             name: "Blank placeholder",     group: "Other",   designW: 240 }
    ]

    // ---------------- state ----------------
    property var defaults: []        // registered by WidgetLayer (its baseDefs)
    property var extras: []          // widgets added from the panel (complete defs, ids "x1", "x2", ...)
    property var overrides: ({})     // id -> { host, enabled, size, speed, k, tilt, node, show, source }
    property real globalSpeed: 1.0   // multiplies every orbit (WidgetLayer.speedScale)
    property string previewId: ""    // the widget being edited: shown even if its planet is not in focus
    property bool panelOpen: false   // the settings panel window (SettingsWindow) follows this; the map's "Edit Widgets" button sets it
    property int revision: 0         // bumped on EVERY change (WidgetLayer / panel follow this)
    property bool loaded: false

    signal saveRequested(string text)

    property string _lastText: ""
    property bool _quiet: false
    property Timer _saveTimer: Timer {
        interval: 350
        onTriggered: {
            const t = root.serialize();
            root._lastText = t;
            root.saveRequested(t);
        }
    }

    // ---------------- helpers ----------------
    function _clone(o) { return JSON.parse(JSON.stringify(o)); }

    function catalogEntry(source) {
        for (let i = 0; i < catalog.length; i++) if (catalog[i].source === source) return catalog[i];
        return null;
    }

    function planetName(id) {
        for (let i = 0; i < planets.length; i++) if (planets[i].id === id) return planets[i].name;
        return id;
    }

    function widgetName(def) {
        const c = catalogEntry(def.source);
        if (def.source === "BlankWidget.qml" && def.title) return def.title;
        return c ? c.name : def.source;
    }

    function _bump(save) {
        revision++;
        if (save && !_quiet) _saveTimer.restart();
    }

    // ---------------- merge ----------------
    // base def + this id's overrides -> the def the slot actually uses (a fresh object each call).
    function _resolveOne(base, ov, isExtra) {
        const d = _clone(base);
        d.baseHost = base.host;
        d.baseSource = base.source;
        d._extra = isExtra === true;
        d._base = { host: base.host, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt, node: base.orbit.node || 0,
                    show: base.show, source: base.source };
        d.enabled = true;
        d.size = 1;
        if (!ov) return d;

        if (ov.host !== undefined) d.host = ov.host;
        if (ov.enabled !== undefined) d.enabled = ov.enabled;
        if (ov.show !== undefined) d.show = ov.show;
        if (ov.speed !== undefined) d.orbit.speed = ov.speed;
        if (ov.k !== undefined) d.orbit.k = ov.k;
        if (ov.tilt !== undefined) d.orbit.tilt = ov.tilt;
        if (ov.node !== undefined) d.orbit.node = ov.node;

        if (ov.source !== undefined && ov.source !== base.source) {
            // another widget type in the same slot: its own title, and a width that keeps the on-screen size similar
            const oldC = catalogEntry(base.source), newC = catalogEntry(ov.source);
            d.source = ov.source;
            if (newC && newC.title !== undefined) d.title = newC.title; else delete d.title;
            if (oldC && newC && oldC.designW > 0 && d.worldW !== undefined) d.worldW = d.worldW * newC.designW / oldC.designW;
        }

        if (ov.size !== undefined && ov.size > 0) {
            // uniform scale: the width AND both clamps, otherwise the clamp would cancel the change at most zoom levels
            const m = ov.size;
            if (d.worldW !== undefined) d.worldW *= m;
            if (d.worldWk !== undefined) d.worldWk *= m;
            d.minUi = (d.minUi !== undefined ? d.minUi : 0.4) * m;
            d.maxUi = (d.maxUi !== undefined ? d.maxUi : 1.5) * m;
        }
        d.size = (ov.size !== undefined && ov.size > 0) ? ov.size : 1;
        return d;
    }

    function _baseList() {
        const out = [];
        for (let i = 0; i < defaults.length; i++) out.push({ def: defaults[i], extra: false });
        for (let j = 0; j < extras.length; j++) out.push({ def: extras[j], extra: true });
        return out;
    }

    // all widgets, including disabled ones (the panel lists these)
    function entries() {
        revision;   // binding dependency
        const list = _baseList(), out = [];
        for (let i = 0; i < list.length; i++) out.push(_resolveOne(list[i].def, overrides[list[i].def.id], list[i].extra));
        return out;
    }

    // enabled widgets only (the layer builds slots for these)
    function liveDefs() {
        const all = entries(), out = [];
        for (let i = 0; i < all.length; i++) if (all[i].enabled !== false) out.push(all[i]);
        return out;
    }

    // one widget, resolved on its own (cheap: the panel rows call this)
    function entry(id) {
        revision;   // binding dependency
        const list = _baseList();
        for (let i = 0; i < list.length; i++)
            if (list[i].def.id === id) return _resolveOne(list[i].def, overrides[id], list[i].extra);
        return null;
    }

    function registerDefaults(defs) {
        if (JSON.stringify(defs) === JSON.stringify(defaults)) return;
        defaults = _clone(defs);
        _bump(false);
    }

    // ---------------- edits (all called by the panel) ----------------
    function _baseFor(id) {
        for (let i = 0; i < defaults.length; i++) if (defaults[i].id === id) return defaults[i];
        for (let j = 0; j < extras.length; j++) if (extras[j].id === id) return extras[j];
        return null;
    }

    function _same(a, b) { return typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 1e-6 : a === b; }

    // field: host | enabled | size | speed | k | tilt | node | show | source
    function setField(id, field, value) {
        const base = _baseFor(id);
        if (!base) return;
        const baseVal = { host: base.host, enabled: true, size: 1, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt,
                          node: base.orbit.node || 0, show: base.show, source: base.source }[field];
        const o = _clone(overrides);
        if (!o[id]) o[id] = {};
        if (_same(value, baseVal)) delete o[id][field]; else o[id][field] = value;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function setGlobalSpeed(v) { globalSpeed = v; _bump(true); }

    function resetWidget(id) {
        if (!overrides[id]) return;
        const o = _clone(overrides);
        delete o[id];
        overrides = o;
        _bump(true);
    }

    function resetAll() {
        overrides = ({});
        extras = [];
        globalSpeed = 1.0;
        previewId = "";
        _bump(true);
    }

    // new widget from the catalog; returns its id
    function addWidget(source, host) {
        const c = catalogEntry(source);
        let n = 1;
        const taken = {};
        for (let i = 0; i < extras.length; i++) taken[extras[i].id] = true;
        while (taken["x" + n]) n++;
        const id = "x" + n;
        // spread new widgets over different planes so they do not sit on top of each other
        const seed = (n * 2.399963) % (Math.PI * 2);
        const def = {
            id: id, host: host, source: source, show: "focus",
            worldWk: 1.25, minUi: 0.5, maxUi: 1.4,
            orbit: { k: 2.0, add: 40, tilt: Math.sin(seed * 1.7) * 0.9, node: seed % 3.0, phase: seed, speed: 0.2 }
        };
        if (c && c.title !== undefined) def.title = c.title;
        const e = extras.slice();
        e.push(def);
        extras = e;
        previewId = id;
        _bump(true);
        return id;
    }

    function removeWidget(id) {
        const e = [];
        for (let i = 0; i < extras.length; i++) if (extras[i].id !== id) e.push(extras[i]);
        if (e.length === extras.length) return;   // only widgets added from the panel can be deleted; defaults are disabled instead
        extras = e;
        const o = _clone(overrides);
        delete o[id];
        overrides = o;
        if (previewId === id) previewId = "";
        _bump(true);
    }

    // ---------------- persistence ----------------
    function serialize() {
        return JSON.stringify({ version: 1, globalSpeed: globalSpeed, overrides: overrides, extras: extras }, null, 2);
    }

    // called by WidgetConfigStore after reading widgets.json ("" = no file yet)
    function load(text) {
        if (text === _lastText && loaded) return;     // our own write coming back through the file watcher
        _lastText = text;
        let obj = null;
        try { obj = text && text.trim() !== "" ? JSON.parse(text) : null; } catch (e) { console.warn("widgets.json is not valid JSON, ignoring it: " + e); }
        _quiet = true;
        overrides = (obj && obj.overrides && typeof obj.overrides === "object") ? obj.overrides : ({});
        extras = (obj && Array.isArray(obj.extras)) ? obj.extras : [];
        globalSpeed = (obj && typeof obj.globalSpeed === "number") ? obj.globalSpeed : 1.0;
        loaded = true;
        _bump(false);
        _quiet = false;
    }
}
