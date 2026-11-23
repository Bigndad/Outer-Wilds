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
    readonly property var builtinCatalog: [
        { source: "ClockWidget.qml",             name: "Clock",                 group: "Outer Wilds",    designW: 300,
          settings: [
              { key: "hour24",       type: "toggle", label: "24-hour clock",  default: true },
              { key: "showSeconds",  type: "toggle", label: "Show seconds",   default: true },
              { key: "showDate",     type: "toggle", label: "Show date",      default: true },
              { key: "dateFormat",   type: "text",   label: "Date format",    default: "dddd, d MMMM yyyy" },
              { key: "timeColor",    type: "color",  label: "Time colour",    default: "#E6D5B8" },
              { key: "secondsColor", type: "color",  label: "Seconds colour", default: "#D4AF37" },
              { key: "font",         type: "font",   label: "Font",           default: "monospace" }
          ] },
        { source: "LoopWidget.qml",              name: "Loop timer",            group: "Outer Wilds",    designW: 276 },
        { source: "UptimeWidget.qml",            name: "Uptime",                group: "Outer Wilds",    designW: 236 },
        { source: "DateWorldWidget.qml",         name: "Date / world clocks",   group: "Outer Wilds",    designW: 276 },
        { source: "WorkspacesWidget.qml",        name: "Workspaces",            group: "Outer Wilds",  designW: 300 },
        { source: "NotesWidget.qml",             name: "Notes",                 group: "Outer Wilds",  designW: 280 },
        { source: "RumorWidget.qml",             name: "Ship log (rumors)",     group: "Outer Wilds",  designW: 250 },
        { source: "MapWidget.qml",               name: "Map (small)",           group: "Outer Wilds",  designW: 250 },
        { source: "AppLauncherWidget.qml",       name: "App launcher (small)",  group: "Outer Wilds",  designW: 250 },
        { source: "SignalscopeWidget.qml",       name: "Signalscope",           group: "Outer Wilds",  designW: 250 },
        { source: "WeatherWidget.qml",           name: "Weather",               group: "Outer Wilds", designW: 280, title: "WEATHER" },
        { source: "BlankWidget.qml",             name: "Blank placeholder",     group: "Outer Wilds",   designW: 240 },
        { source: "WallpaperCard.qml",           name: "Wallpaper switcher",    group: "Outer Wilds",   designW: 260, title: "WALLPAPER" },
        { source: "ScreentimeCard.qml",          name: "Screen time",           group: "Outer Wilds",   designW: 260, title: "SCREEN TIME" },
        { source: "serp/SunClock.qml",           name: "Dial clock", group: "Serpantinum",    designW: 220 },
        { source: "serp/AshTwinBattery.qml",     name: "Battery (round)",       group: "Serpantinum",  designW: 220, title: "BATTERY" },
        { source: "serp/EmberTwinBattery.qml",   name: "Battery (small)",       group: "Serpantinum",  designW: 160, title: "BATTERY" },
        { source: "serp/GiantsDeepWeather.qml",  name: "Weather (full)",        group: "Serpantinum", designW: 360, title: "WEATHER" },
        { source: "serp/EmberTwinMusic.qml",     name: "Music player",          group: "Serpantinum",   designW: 340 },
        { source: "serp/EmberTwinLyrics.qml",    name: "Music + lyrics",        group: "Serpantinum",   designW: 340 },
        { source: "serp/DarkBrambleVisualiser.qml", name: "Visualiser",         group: "Serpantinum",   designW: 360, title: "VISUALISER" },
        { source: "serp/DarkBrambleDisc.qml",    name: "Disc player",           group: "Serpantinum",   designW: 210 },
        { source: "serp/DarkBrambleLyrics.qml",  name: "Lyrics",                group: "Serpantinum",   designW: 340 },
        { source: "serp/SunStationCpu.qml",      name: "CPU",                   group: "Serpantinum",   designW: 200, title: "CPU" },
        { source: "serp/BrittleHollowRam.qml",   name: "RAM",                   group: "Serpantinum",   designW: 220, title: "RAM" },
        { source: "serp/BrittleHollowDisk.qml",  name: "Disk",                  group: "Serpantinum",   designW: 220, title: "DISK" },
        { source: "serp/HollowsLanternTemp.qml", name: "Temperature",           group: "Serpantinum",   designW: 200, title: "TEMP" },
        { source: "serp/AshTwinTimer.qml",       name: "Focus timer (Pomodoro)", group: "Serpantinum",  designW: 240, title: "FOCUS" },
        { source: "serp/GiantsDeepTimer.qml",    name: "Timer",                 group: "Serpantinum",   designW: 240, title: "TIMER" },
        { source: "serp/GiantsDeepStopwatch.qml", name: "Stopwatch",            group: "Serpantinum",   designW: 240, title: "STOPWATCH" },
        { source: "serp/QuantumMoonWeather.qml", name: "Weather (round)",       group: "Serpantinum",   designW: 220, title: "WEATHER" },
        { source: "glyph/GlyphMatrix.qml", name: "Glyph Matrix (spectrum)", group: "Glyph", designW: 220 },
        { source: "glyph/GlyphClock.qml", name: "Glyph clock", group: "Glyph", designW: 280 },
        { source: "glyph/GlyphCal.qml", name: "Glyph calendar", group: "Glyph", designW: 320 },
        { source: "glyph/GlyphFocus.qml", name: "Glyph focus timer", group: "Glyph", designW: 240 },
        { source: "glyph/GlyphCpu.qml", name: "Glyph CPU ring", group: "Glyph", designW: 200 },
        { source: "glyph/GlyphRam.qml", name: "Glyph RAM ring", group: "Glyph", designW: 200 },
        { source: "glyph/GlyphGpu.qml", name: "Glyph GPU ring", group: "Glyph", designW: 200 },
        { source: "glyph/GlyphSystem.qml", name: "Glyph system", group: "Glyph", designW: 440 },
        { source: "lucid/SunClock.qml", name: "Dial clock", group: "Lucid", designW: 220 },
        { source: "lucid/BrittleHollowCalendar.qml", name: "Calendar", group: "Lucid", designW: 340 },
        { source: "lucid/GiantsDeepWeather.qml", name: "Weather", group: "Lucid", designW: 300 },
        { source: "lucid/EmberTwinBattery.qml", name: "Battery (small)", group: "Lucid", designW: 170 },
        { source: "lucid/AshTwinBattery.qml", name: "Battery (round)", group: "Lucid", designW: 260 },
        { source: "lucid/DarkBrambleVisualiser.qml", name: "Visualiser", group: "Lucid", designW: 360 },
        { source: "serp/AnserinClockDigital.qml", name: "Digital clock (Anserin)", group: "Time", designW: 250 },
        { source: "serp/AnserinClockMaterial.qml", name: "Material clock (Anserin)", group: "Time", designW: 220 },
        { source: "serp/AnserinClockMinimal.qml", name: "Minimal clock (Anserin)", group: "Time", designW: 250 },
        { source: "serp/AnserinClockLockscreen.qml", name: "Lock-screen clock (Anserin)", group: "Time", designW: 300 },
        { source: "serp/AnserinClockStretched.qml", name: "Stretched clock (Anserin)", group: "Time", designW: 420 },
        { source: "serp/AnserinUser.qml", name: "User card (Anserin)", group: "Other", designW: 260, title: "USER" },
        { source: "serp/AnserinGithub.qml", name: "GitHub contributions", group: "Other", designW: 540, title: "GITHUB" },
        { source: "serp/AnserinImageRounded.qml", name: "Picture, rounded", group: "Other", designW: 300 },
        { source: "serp/AnserinImageRect.qml", name: "Picture, square corners", group: "Other", designW: 300 },
        { source: "serp/AnserinImageRound.qml", name: "Picture, round", group: "Other", designW: 200 },
        { source: "serp/AnserinText.qml", name: "Text", group: "Other", designW: 320 },
        { source: "serp/AnserinNetworkCard.qml", name: "Network (small)", group: "Other", designW: 240, title: "NETWORK" },
        { source: "serp/AnserinBubbleCard.qml", name: "Processes (small)", group: "Other", designW: 240, title: "PROCESSES" }
    ]

    // Drop-in widgets: every widgets/user/<name>/widget.json found by WidgetConfigStore (see WIDGETS.md).
    // Same entry shape as builtinCatalog, plus `default` (size / orbit / show) and `settings` (the schema the panel draws).
    property var userCatalog: []
    property var catalog: builtinCatalog.concat(userCatalog)
    function setUserCatalog(list) { userCatalog = list; _bump(false); }

    // ---------------- state ----------------
    property var defaults: []        // registered by WidgetLayer (its baseDefs)
    property var extras: []          // widgets added from the panel (complete defs, ids "x1", "x2", ...)
    property var overrides: ({})     // id -> { host, enabled, size, speed, k, tilt, node, show, source }
    property real globalSpeed: 1.0   // multiplies every orbit (WidgetLayer.speedScale)
    property string previewId: ""    // the widget being edited: shown even if its planet is not in focus
    property bool panelOpen: false   // the settings panel window (SettingsWindow) follows this; the map's "Edit Widgets" button sets it
    property int revision: 0         // bumped on EVERY change (WidgetLayer / panel follow this)
    property bool loaded: false
    property var keyOverrides: ({})          // action id -> key sequence (Keybinds.qml); only the CHANGED keys are stored
    property bool showLoopPanel: true        // the bottom-right LOOP / SPEED panel (CameraRig)
    property bool shrinkFar: true            // widgets get much smaller when the planet is far away (WidgetSlot)
    property int bakeW: 1024                 // planet bake texture width: 512, 1024, or 2048 (PlanetShader)
    property bool showHud: true              // SatelliteHUD overlay (CameraRig)
    property bool showOrbits: true           // orbital path lines (CameraRig)
    property bool showLabels: true           // planet name / distance labels (PlanetShader)
    property bool showReticles: true         // hover and lock reticles (CameraRig)
    property int fpsIdle: 30                 // idle frame cap: 15, 30, 60, or 0 = off (CameraRig)
    property real hudOpacity: 1.0            // SatelliteHUD opacity (0.1..1.0)
    property real hudScale: 1.0              // SatelliteHUD scale (0.5..1.5)
    property real orbitOpacity: 1.0          // orbit path opacity (0.1..1.0)
    property real orbitWidth: 1.2            // orbit line thickness in px (0.5..4.0)
    property real labelSize: 1.0             // planet label font multiplier (0.6..2.0)
    property real labelDist: 1500            // max distance to show unselected labels
    property real reticleOpacity: 1.0        // hover/lock reticle opacity (0.1..1.0)
    property real reticleWidth: 1.0          // reticle stroke multiplier (0.5..3.0)
    property real loopPanelOpacity: 1.0      // bottom-right loop panel opacity (0.2..1.0)
    property real loopPanelScale: 1.0        // bottom-right loop panel scale (0.6..1.5)
    property string focusPlanet: ""          // the planet the camera is targeting / locked on ("" = none); set by KeyHost
    property string panelTab: "widgets"      // settings panel tab: widgets | keys | options
    property bool capturingKeys: false       // the panel is recording a key: HyprIpc parks Hyprland's own binds so Super+... reaches it

    signal saveRequested(string text)
    signal launcherRequested()               // the small app-launcher widget was clicked: LauncherWindow opens the big one

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
    // the widget's option values: schema defaults, then this id's saved overrides (a widget reads them as `cfg.key`)
    function _cfgFor(source, ov) {
        const c = catalogEntry(source), cfg = {};
        const sch = c && Array.isArray(c.settings) ? c.settings : [];
        for (let i = 0; i < sch.length; i++) cfg[sch[i].key] = sch[i].default;
        if (ov && ov.settings) for (const k in ov.settings) cfg[k] = ov.settings[k];
        return cfg;
    }
    function _resolveOne(base, ov, isExtra) {
        const d = _resolveCore(base, ov, isExtra);
        d.cfg = _cfgFor(d.source, ov);
        return d;
    }
    function _resolveCore(base, ov, isExtra) {
        const d = _clone(base);
        d.baseHost = base.host;
        d.baseSource = base.source;
        d._extra = isExtra === true;
        d._base = { host: base.host, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt, node: base.orbit.node || 0,
                    show: base.show, source: base.source };
        d.enabled = true;
        d.removed = false;
        d.size = 1;
        if (!ov) return d;

        if (ov.host !== undefined) d.host = ov.host;
        if (ov.enabled !== undefined) d.enabled = ov.enabled;
        if (ov.removed !== undefined) d.removed = ov.removed;
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

    // all widgets that are still ON a planet, including switched-off ones (the panel lists these); removed ones are not here
    function entries() {
        revision;   // binding dependency
        const list = _baseList(), out = [];
        for (let i = 0; i < list.length; i++) {
            const e = _resolveOne(list[i].def, overrides[list[i].def.id], list[i].extra);
            if (!e.removed) out.push(e);
        }
        return out;
    }

    // default widgets that were removed from their planet (the picker offers them for restoring)
    function removedEntries() {
        revision;
        const out = [];
        for (let i = 0; i < defaults.length; i++) {
            const e = _resolveOne(defaults[i], overrides[defaults[i].id], false);
            if (e.removed) out.push(e);
        }
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

    // field: host | enabled | removed | size | speed | k | tilt | node | show | source
    function setField(id, field, value) {
        const base = _baseFor(id);
        if (!base) return;
        // the only things refused are the ones that break the scene: NaN/Infinity, a size <= 0, a negative orbit radius
        if (typeof value === "number") {
            if (!isFinite(value)) return;
            if (field === "size" && !(value > 0)) return;
            if (field === "k" && value < 0) value = 0;
        }
        const baseVal = { host: base.host, enabled: true, removed: false, size: 1, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt,
                          node: base.orbit.node || 0, show: base.show, source: base.source }[field];
        const o = _clone(overrides);
        if (!o[id]) o[id] = {};
        if (_same(value, baseVal)) delete o[id][field]; else o[id][field] = value;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function setGlobalSpeed(v) { if (!isFinite(v) || v < 0) return; globalSpeed = v; _bump(true); }

    // one widget option (schema key) -> saved under overrides[id].settings; a value equal to the default is dropped
    function setSetting(id, key, value) {
        const base = _baseFor(id);
        if (!base) return;
        const src = (overrides[id] && overrides[id].source !== undefined) ? overrides[id].source : base.source;
        const c = catalogEntry(src);
        let def;
        if (c && Array.isArray(c.settings)) for (let i = 0; i < c.settings.length; i++) if (c.settings[i].key === key) def = c.settings[i].default;
        const o = _clone(overrides);
        if (!o[id]) o[id] = {};
        const st = o[id].settings ? o[id].settings : {};
        if (JSON.stringify(value) === JSON.stringify(def)) delete st[key]; else st[key] = value;
        if (Object.keys(st).length === 0) delete o[id].settings; else o[id].settings = st;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

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
        if (c && c.default && typeof c.default === "object") {      // a drop-in widget's own defaults (host is always the one asked for)
            const m = c.default;
            for (const k of ["show", "worldW", "worldWk", "minUi", "maxUi"]) if (m[k] !== undefined) def[k] = m[k];
            if (m.worldW !== undefined && m.worldWk === undefined) delete def.worldWk;
            if (m.orbit) for (const k in m.orbit) def.orbit[k] = m.orbit[k];
        }
        const e = extras.slice();
        e.push(def);
        extras = e;
        previewId = id;
        _bump(true);
        return id;
    }

    // Takes a widget OFF its planet for good (it is not just switched off).
    //  * a widget added from the panel is deleted;
    //  * a default widget is marked `removed`: gone from the planet and the list, but still offered by the picker
    //    ("restore" with its original planet / orbit), because the picker lists the whole catalog.
    function removeWidget(id) {
        let isExtra = false;
        for (let i = 0; i < extras.length; i++) if (extras[i].id === id) isExtra = true;
        const o = _clone(overrides);
        if (isExtra) {
            const e = [];
            for (let i = 0; i < extras.length; i++) if (extras[i].id !== id) e.push(extras[i]);
            extras = e;
            delete o[id];
        } else {
            if (!_baseFor(id)) return;
            o[id] = { removed: true };          // other edits are dropped: restoring brings back the original
        }
        overrides = o;
        if (previewId === id) previewId = "";
        _bump(true);
    }

    function restoreWidget(id) {
        if (!overrides[id] || !overrides[id].removed) return;
        const o = _clone(overrides);
        delete o[id];
        overrides = o;
        previewId = id;
        _bump(true);
    }

    // removes every switched-off widget from its planet; returns how many
    function removeDisabled() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) if (all[i].enabled === false) { removeWidget(all[i].id); n++; }
        return n;
    }

    // removes EVERY widget from its planet (the picker still lists them all; "RESET ALL WIDGETS" brings the defaults back); returns how many
    function removeAll() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) { removeWidget(all[i].id); n++; }
        return n;
    }

    function disabledCount() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) if (all[i].enabled === false) n++;
        return n;
    }

    // the planet an enabled widget of this file sits on ("" = none); used to open the launcher / map "where the widget is"
    function planetOfSource(source) {
        const all = entries();
        for (let i = 0; i < all.length; i++) if (all[i].source === source && all[i].enabled !== false) return all[i].host;
        return "";
    }

    // ---------------- keys / options ----------------
    function setKey(action, seq) {
        const o = _clone(keyOverrides);
        o[action] = seq;
        keyOverrides = o;
        _bump(true);
    }
    function resetKey(action) {
        if (keyOverrides[action] === undefined) return;
        const o = _clone(keyOverrides);
        delete o[action];
        keyOverrides = o;
        _bump(true);
    }
    function resetKeys() { keyOverrides = ({}); _bump(true); }
    function setShrinkFar(v) { if (shrinkFar === v) return; shrinkFar = v; _bump(true); }
    function setShowLoopPanel(v) { if (showLoopPanel === v) return; showLoopPanel = v; _bump(true); }
    function setBakeW(v) { const n = Number(v); if (n !== 512 && n !== 1024 && n !== 2048) return; if (bakeW === n) return; bakeW = n; _bump(true); }
    function setShowHud(v) { if (showHud === v) return; showHud = v; _bump(true); }
    function setShowOrbits(v) { if (showOrbits === v) return; showOrbits = v; _bump(true); }
    function setShowLabels(v) { if (showLabels === v) return; showLabels = v; _bump(true); }
    function setShowReticles(v) { if (showReticles === v) return; showReticles = v; _bump(true); }
    function setFpsIdle(v) { const n = Number(v); if (n !== 0 && n !== 15 && n !== 30 && n !== 60) return; if (fpsIdle === n) return; fpsIdle = n; _bump(true); }
    function setHudOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || hudOpacity === n) return; hudOpacity = n; _bump(true); }
    function setHudScale(v) { const n = Math.max(0.5, Math.min(1.5, Number(v))); if (!isFinite(n) || hudScale === n) return; hudScale = n; _bump(true); }
    function setOrbitOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || orbitOpacity === n) return; orbitOpacity = n; _bump(true); }
    function setOrbitWidth(v) { const n = Math.max(0.4, Math.min(4.0, Number(v))); if (!isFinite(n) || orbitWidth === n) return; orbitWidth = n; _bump(true); }
    function setLabelSize(v) { const n = Math.max(0.6, Math.min(2.0, Number(v))); if (!isFinite(n) || labelSize === n) return; labelSize = n; _bump(true); }
    function setLabelDist(v) { const n = Math.max(400, Math.min(8000, Number(v))); if (!isFinite(n) || labelDist === n) return; labelDist = n; _bump(true); }
    function setReticleOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || reticleOpacity === n) return; reticleOpacity = n; _bump(true); }
    function setReticleWidth(v) { const n = Math.max(0.5, Math.min(3.0, Number(v))); if (!isFinite(n) || reticleWidth === n) return; reticleWidth = n; _bump(true); }
    function setLoopPanelOpacity(v) { const n = Math.max(0.2, Math.min(1.0, Number(v))); if (!isFinite(n) || loopPanelOpacity === n) return; loopPanelOpacity = n; _bump(true); }
    function setLoopPanelScale(v) { const n = Math.max(0.6, Math.min(1.5, Number(v))); if (!isFinite(n) || loopPanelScale === n) return; loopPanelScale = n; _bump(true); }

    // ---------------- persistence ----------------
    function serialize() {
        return JSON.stringify({ version: 1, globalSpeed: globalSpeed, overrides: overrides, extras: extras,
                                keys: keyOverrides, ui: { loopPanel: showLoopPanel, shrinkFar: shrinkFar, bakeW: bakeW, hud: showHud, orbits: showOrbits, labels: showLabels, reticles: showReticles, fpsIdle: fpsIdle, hudOpacity: hudOpacity, hudScale: hudScale, orbitOpacity: orbitOpacity, orbitWidth: orbitWidth, labelSize: labelSize, labelDist: labelDist, reticleOpacity: reticleOpacity, reticleWidth: reticleWidth, loopPanelOpacity: loopPanelOpacity, loopPanelScale: loopPanelScale } }, null, 2);
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
        keyOverrides = (obj && obj.keys && typeof obj.keys === "object") ? obj.keys : ({});
        showLoopPanel = !(obj && obj.ui && obj.ui.loopPanel === false);
        shrinkFar = !(obj && obj.ui && obj.ui.shrinkFar === false);
        const bw = obj && obj.ui ? Number(obj.ui.bakeW) : 1024;
        bakeW = (bw === 512 || bw === 1024 || bw === 2048) ? bw : 1024;
        showHud = !(obj && obj.ui && obj.ui.hud === false);
        showOrbits = !(obj && obj.ui && obj.ui.orbits === false);
        showLabels = !(obj && obj.ui && obj.ui.labels === false);
        showReticles = !(obj && obj.ui && obj.ui.reticles === false);
        const fi = obj && obj.ui && obj.ui.fpsIdle !== undefined ? Number(obj.ui.fpsIdle) : 30;
        fpsIdle = (fi === 0 || fi === 15 || fi === 30 || fi === 60) ? fi : 30;
        const u = (obj && obj.ui) ? obj.ui : {};
        hudOpacity = typeof u.hudOpacity === 'number' ? u.hudOpacity : 1.0;
        hudScale = typeof u.hudScale === 'number' ? u.hudScale : 1.0;
        orbitOpacity = typeof u.orbitOpacity === 'number' ? u.orbitOpacity : 1.0;
        orbitWidth = typeof u.orbitWidth === 'number' ? u.orbitWidth : 1.2;
        labelSize = typeof u.labelSize === 'number' ? u.labelSize : 1.0;
        labelDist = typeof u.labelDist === 'number' ? u.labelDist : 1500;
        reticleOpacity = typeof u.reticleOpacity === 'number' ? u.reticleOpacity : 1.0;
        reticleWidth = typeof u.reticleWidth === 'number' ? u.reticleWidth : 1.0;
        loopPanelOpacity = typeof u.loopPanelOpacity === 'number' ? u.loopPanelOpacity : 1.0;
        loopPanelScale = typeof u.loopPanelScale === 'number' ? u.loopPanelScale : 1.0;
        loaded = true;
        _bump(false);
        _quiet = false;
    }
}
