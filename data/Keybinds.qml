pragma Singleton
import QtQuick
import ".."

// =====================================================================
//  Keybinds: the ONE list of every key in the shell.
//   * `actions`   keys you can rebind (the Control Centre's KEYS tab edits them).
//   * `reference` only the mouse; NO keyboard key is fixed any more (flying, map and rumor-map keys are actions too).
//   * Changed keys live in WidgetConfig.keyOverrides (saved in widgets.json under "keys"); everything else
//     uses `def` below. KeyHost.qml turns them into the real Shortcuts and into MapData / RumorData /
//     SignalscopeData key settings.
//   * Only the keys that differ from the default are stored, so changing a default here updates everyone
//     who never touched that key.
//  No Quickshell import (loads in plain `qml` on the Mint laptop too).
// =====================================================================
QtObject {
    id: root

    readonly property string gAnywhere: "In the scene"
    readonly property string gFlight: "Flying"
    readonly property string gScope: "Signalscope (while equipped)"
    readonly property string gOverlay: "Map View + Rumor Map"
    readonly property string gMap: "Map View"
    readonly property string gRumor: "Rumor Map"

    // ctx = where the key is live; two actions clash only if they can be live together:
    //   all (always) / scene (flying, signalscope) / overlay (map or rumor map open) / map / rumor
    // kind = "shortcut": a window Shortcut, so it needs a real key (Ctrl+A is fine, Ctrl alone is not)
    //        "key":      read from the key events, so a lone modifier (Ctrl, Shift, Super) can be the key
    // scopeKey = the name SignalscopeData.keys uses for it
    readonly property var actions: [
        { id: "map",       group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Map View",             hint: "open / close the ship-log map",     def: "N" },
        { id: "rumor",     group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Rumor Map",            hint: "open / close the notification map", def: "L" },
        { id: "edit",      group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Widget control",       hint: "open / close this panel (also works inside the map)", def: "E" },
        { id: "keys",      group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Key list",             hint: "open this panel on the KEYS tab",   def: "F1" },
        { id: "hud",       group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Loop / speed panel",   hint: "show / hide the bottom-right box",  def: "H" },
        { id: "launcher",  group: gAnywhere, ctx: "all",   kind: "shortcut", label: "App launcher",         hint: "open the big launcher (no key yet)", def: "" },
        { id: "perf",      group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Performance preset",   hint: "cycle Quality / Balanced / Performance (no key yet)", def: "" },
        { id: "diag",      group: gAnywhere, ctx: "all",   kind: "shortcut", label: "FPS / CPU readout",    hint: "show / hide the diagnostics box (no key yet)", def: "" },
        { id: "layout",    group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Next widget layout",   hint: "switch to the next saved layout preset (no key yet)", def: "" },
        { id: "scope",     group: gAnywhere, ctx: "all",   kind: "shortcut", label: "Signalscope",          hint: "equip / stow",                      def: "Q", scopeKey: "toggle" },

        { id: "fwd",       group: gFlight,   ctx: "scene", kind: "key",      label: "Forward",              hint: "zoom in while locked on a planet",  def: "W" },
        { id: "back",      group: gFlight,   ctx: "scene", kind: "key",      label: "Back",                 hint: "zoom out while locked",             def: "S" },
        { id: "left",      group: gFlight,   ctx: "scene", kind: "key",      label: "Left",                 hint: "turn while locked",                 def: "A" },
        { id: "right",     group: gFlight,   ctx: "scene", kind: "key",      label: "Right",                hint: "turn while locked",                 def: "D" },
        { id: "up",        group: gFlight,   ctx: "scene", kind: "key",      label: "Up",                   hint: "",                                  def: "Space" },
        { id: "down",      group: gFlight,   ctx: "scene", kind: "key",      label: "Down",                 hint: "",                                  def: "Shift" },
        { id: "drift",     group: gFlight,   ctx: "scene", kind: "key",      label: "Drift on / off",       hint: "a lone Ctrl toggles on release, so Ctrl+A combos leave it alone", def: "Ctrl" },
        { id: "release",   group: gFlight,   ctx: "scene", kind: "key",      label: "Let go of the planet", hint: "",                                  def: "Esc" },

        { id: "chanPrev",  group: gScope,    ctx: "scene", kind: "shortcut", label: "Previous channel",     hint: "",                                  def: "Left",  scopeKey: "chanPrev" },
        { id: "chanNext",  group: gScope,    ctx: "scene", kind: "shortcut", label: "Next channel",         hint: "",                                  def: "Right", scopeKey: "chanNext" },
        { id: "playPause", group: gScope,    ctx: "scene", kind: "shortcut", label: "Play / pause",         hint: "",                                  def: "P",     scopeKey: "playPause" },
        { id: "trackPrev", group: gScope,    ctx: "scene", kind: "shortcut", label: "Previous track",       hint: "",                                  def: ",",     scopeKey: "trackPrev" },
        { id: "trackNext", group: gScope,    ctx: "scene", kind: "shortcut", label: "Next track",           hint: "",                                  def: ".",     scopeKey: "trackNext" },
        { id: "mute",      group: gScope,    ctx: "scene", kind: "shortcut", label: "Mute",                 hint: "",                                  def: "M",     scopeKey: "mute" },
        { id: "volUp",     group: gScope,    ctx: "scene", kind: "shortcut", label: "Volume up",            hint: "",                                  def: "Up",    scopeKey: "volUp" },
        { id: "volDown",   group: gScope,    ctx: "scene", kind: "shortcut", label: "Volume down",          hint: "",                                  def: "Down",  scopeKey: "volDown" },

        { id: "navUp",     group: gOverlay,  ctx: "overlay", kind: "key",    label: "Move up",              hint: "",                                  def: "Up" },
        { id: "navDown",   group: gOverlay,  ctx: "overlay", kind: "key",    label: "Move down",            hint: "",                                  def: "Down" },
        { id: "navLeft",   group: gOverlay,  ctx: "overlay", kind: "key",    label: "Move left",            hint: "",                                  def: "Left" },
        { id: "navRight",  group: gOverlay,  ctx: "overlay", kind: "key",    label: "Move right",           hint: "",                                  def: "Right" },
        { id: "select",    group: gOverlay,  ctx: "overlay", kind: "key",    label: "Open / confirm",       hint: "planet page, action button, explore", def: "Return" },
        { id: "backKey",   group: gOverlay,  ctx: "overlay", kind: "key",    label: "Back / close",         hint: "",                                  def: "Esc" },
        { id: "zoomIn",    group: gOverlay,  ctx: "overlay", kind: "key",    label: "Zoom in",              hint: "",                                  def: "=" },
        { id: "zoomOut",   group: gOverlay,  ctx: "overlay", kind: "key",    label: "Zoom out",             hint: "",                                  def: "-" },


        { id: "search",    group: gRumor,    ctx: "rumor", kind: "key",      label: "Search",               hint: "",                                  def: "/" },
        { id: "unread",    group: gRumor,    ctx: "rumor", kind: "key",      label: "Unread only",          hint: "",                                  def: "U" },
        { id: "openApp",   group: gRumor,    ctx: "rumor", kind: "key",      label: "Open the app",         hint: "",                                  def: "O" },
        { id: "pin",       group: gRumor,    ctx: "rumor", kind: "key",      label: "Pin",                  hint: "",                                  def: "P" },
        { id: "dismiss",   group: gRumor,    ctx: "rumor", kind: "key",      label: "Dismiss",              hint: "",                                  def: "X" },
        { id: "fit",       group: gRumor,    ctx: "rumor", kind: "key",      label: "Fit everything",       hint: "",                                  def: "Home" }
    ]

    // read-only: the mouse
    readonly property var reference: [
        { group: "Mouse (fixed)", rows: [
            ["Click",             "centre on a planet"],
            ["Double-click",      "lock and orbit (Alt+click = fly in)"],
            ["Scroll",            "zoom / thrust"] ] }
    ]

    // widget file -> the action its "KEY" row in the widget editor sets (only widgets that have a key worth setting)
    readonly property var byWidget: ({
        "AppLauncherWidget.qml": "launcher",
        "MapWidget.qml": "map",
        "RumorWidget.qml": "rumor",
        "SignalscopeWidget.qml": "scope"
    })
    function forWidget(source) { return byWidget[source] !== undefined ? byWidget[source] : ""; }

    // the held-down flying actions (CameraRig keeps them down until the key goes up)
    readonly property var holdIds: ["fwd", "back", "left", "right", "up", "down"]

    // ---------------- lookups ----------------
    function _find(id) {
        for (let i = 0; i < actions.length; i++) if (actions[i].id === id) return actions[i];
        return null;
    }
    function defOf(id) { const a = _find(id); return a ? a.def : ""; }
    function labelOf(id) { const a = _find(id); return a ? a.label : id; }
    function isCustom(id) { return WidgetConfig.keyOverrides[id] !== undefined; }

    // the key an action uses right now (reads keyOverrides, so bindings follow changes)
    function seq(id) {
        const o = WidgetConfig.keyOverrides;
        if (o && o[id] !== undefined) return o[id];
        return defOf(id);
    }

    // object in SignalscopeData.keys format: { toggle, chanPrev, ... }
    function scopeKeys() {
        const out = {};
        for (let i = 0; i < actions.length; i++)
            if (actions[i].scopeKey !== undefined) out[actions[i].scopeKey] = seq(actions[i].id);
        return out;
    }

    function _ctxClash(a, b) {
        if (a === "all" || b === "all" || a === b) return true;
        const ov = { overlay: true, map: true, rumor: true };
        return (a === "overlay" && ov[b] === true) || (b === "overlay" && ov[a] === true);
    }

    // action id that already uses `s` where it can be live at the same time as `id` (other than `id`), or ""
    function owner(s, id) {
        const want = String(s).toLowerCase();
        if (want === "") return "";                 // "no key" is never a conflict
        const me = _find(id);
        for (let i = 0; i < actions.length; i++) {
            const a = actions[i];
            if (a.id === id) continue;
            if (me && !_ctxClash(me.ctx, a.ctx)) continue;
            if (String(seq(a.id)).toLowerCase() === want) return a.id;
        }
        return "";
    }

    // ---------------- display ----------------
    function pretty(s) {
        if (String(s) === "") return "—";
        const map = { "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Meta": "Super", "Esc": "Esc" };
        const parts = String(s).split("+");
        for (let i = 0; i < parts.length; i++) if (map[parts[i]] !== undefined) parts[i] = map[parts[i]];
        return parts.join(" + ");
    }

    // ---------------- key events ----------------
    readonly property var _special: ({
        [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up", [Qt.Key_Down]: "Down",
        [Qt.Key_Comma]: ",", [Qt.Key_Period]: ".", [Qt.Key_Slash]: "/", [Qt.Key_Semicolon]: ";",
        [Qt.Key_Apostrophe]: "'", [Qt.Key_BracketLeft]: "[", [Qt.Key_BracketRight]: "]",
        [Qt.Key_Minus]: "-", [Qt.Key_Underscore]: "-", [Qt.Key_Equal]: "=", [Qt.Key_Plus]: "=",
        [Qt.Key_Backslash]: "\\", [Qt.Key_QuoteLeft]: "`",
        [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "PgUp", [Qt.Key_PageDown]: "PgDown",
        [Qt.Key_Insert]: "Ins", [Qt.Key_Delete]: "Del", [Qt.Key_Space]: "Space", [Qt.Key_Escape]: "Esc",
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab", [Qt.Key_Backspace]: "Backspace"
    })
    readonly property var _modKey: ({ Ctrl: Qt.Key_Control, Shift: Qt.Key_Shift, Alt: Qt.Key_Alt, Meta: Qt.Key_Meta })

    function isLone(s) { return _modKey[String(s)] !== undefined; }

    // name of the modifier a modifier key press stands for ("" for any other key)
    function loneOf(ev) {
        const k = ev.key;
        if (k === Qt.Key_Control) return "Ctrl";
        if (k === Qt.Key_Shift) return "Shift";
        if (k === Qt.Key_Alt || k === Qt.Key_AltGr) return "Alt";
        if (k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) return "Meta";
        return "";
    }

    function _nameOf(k) {
        let name = _special[k];
        if (name !== undefined) return name;
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12) return "F" + (k - Qt.Key_F1 + 1);
        return "";
    }

    // { key, ctrl, alt, shift, meta } of a key event ("+" and "_" are typed with Shift: that Shift is not counted)
    function _evParts(ev) {
        const k = ev.key;
        const shifted = (k === Qt.Key_Plus || k === Qt.Key_Underscore);
        return {
            key: _nameOf(k),
            ctrl: (ev.modifiers & Qt.ControlModifier) !== 0,
            alt: (ev.modifiers & Qt.AltModifier) !== 0,
            shift: ((ev.modifiers & Qt.ShiftModifier) !== 0) && !shifted,
            meta: (ev.modifiers & Qt.MetaModifier) !== 0
        };
    }

    // KeyEvent -> Qt Shortcut sequence, or "" for a modifier on its own / a key we cannot express
    function fromEvent(ev) {
        if (loneOf(ev) !== "") return "";
        const p = _evParts(ev);
        if (p.key === "") return "";
        let mods = "";
        if (p.ctrl) mods += "Ctrl+";
        if (p.alt) mods += "Alt+";
        if (p.shift) mods += "Shift+";
        if (p.meta) mods += "Meta+";
        return mods + p.key;
    }

    function _parseSeq(s) {
        s = String(s);
        if (s === "") return null;
        if (isLone(s)) return { lone: s };
        const parts = s.split("+");
        const key = parts.pop();
        return { key: key, ctrl: parts.indexOf("Ctrl") >= 0, alt: parts.indexOf("Alt") >= 0, shift: parts.indexOf("Shift") >= 0, meta: parts.indexOf("Meta") >= 0 };
    }

    // modifiers that may be held on top of a flying key: the ones that are themselves flying keys (Shift = down ...)
    function _freeMods() {
        const f = { ctrl: false, alt: false, shift: false, meta: false };
        const ids = holdIds.concat(["drift"]);
        for (let i = 0; i < ids.length; i++) {
            const q = String(seq(ids[i]));
            if (q === "Ctrl") f.ctrl = true; else if (q === "Alt") f.alt = true; else if (q === "Shift") f.shift = true; else if (q === "Meta") f.meta = true;
        }
        return f;
    }

    function _matchSeq(sq, ev, loose) {
        const b = _parseSeq(sq);
        if (!b) return false;
        if (b.lone !== undefined) return ev.key === _modKey[b.lone] || (b.lone === "Alt" && ev.key === Qt.Key_AltGr) || (b.lone === "Meta" && (ev.key === Qt.Key_Super_L || ev.key === Qt.Key_Super_R));
        if (loneOf(ev) !== "") return false;
        const p = _evParts(ev);
        if (p.key === "" || p.key !== b.key) return false;
        if ((b.ctrl && !p.ctrl) || (b.alt && !p.alt) || (b.shift && !p.shift) || (b.meta && !p.meta)) return false;
        const f = loose ? _freeMods() : { ctrl: false, alt: false, shift: false, meta: false };
        if (p.ctrl && !b.ctrl && !f.ctrl) return false;
        if (p.alt && !b.alt && !f.alt) return false;
        if (p.shift && !b.shift && !f.shift) return false;
        if (p.meta && !b.meta && !f.meta) return false;
        return true;
    }

    // does this key event press that action's key?
    function matches(id, ev) { return _matchSeq(seq(id), ev, false); }

    // which held-down flying action does this key event press ("" = none); lenient about the other flying modifiers held
    function holdAction(ev) {
        for (let i = 0; i < holdIds.length; i++) if (_matchSeq(seq(holdIds[i]), ev, true)) return holdIds[i];
        return "";
    }

    // "" = fine, otherwise the reason this key cannot be used
    function check(id, s) {
        if (s === "") return "That key cannot be used.";
        const a = _find(id);
        if (a && a.kind === "shortcut" && isLone(s)) return "This one needs a key with it, like " + pretty(s) + " + A.";
        const o = owner(s, id);
        if (o !== "") return "Already used by " + labelOf(o) + ".";
        return "";
    }

    // take the key off an action (an action whose default is "no key" simply goes back to default)
    function unbind(id) {
        if (defOf(id) === "") WidgetConfig.resetKey(id); else WidgetConfig.setKey(id, "");
    }

    // returns "" on success, else the reason
    function assign(id, s) {
        const why = check(id, s);
        if (why !== "") return why;
        if (s === defOf(id)) WidgetConfig.resetKey(id); else WidgetConfig.setKey(id, s);
        return "";
    }
}
