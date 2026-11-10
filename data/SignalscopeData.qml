pragma Singleton
import QtQuick
import ".."

// =====================================================================
//  SignalscopeData: the ONE place the signalscope gets its state from.
//  Plain QtObject, NO Quickshell import, so it also loads under plain `qml` on Mint.
//
//  Model: every audio player is a CHANNEL ("signal"). Every channel sits on a planet
//  (planetPool order, or pinned by name in `pins`). The view (Signalscope.qml) writes
//  aimedId / lockedId every frame; every keybind / widget / IPC call goes through dispatch().
//
//  MOCK today (4 fake channels). Live: SignalscopeMpris.qml (shell.qml only) sets mock=false,
//  installs itself as `backend` and feeds the real players in through setChannels().
// =====================================================================
QtObject {
    id: root

    // ---------------- PUBLIC SURFACE ----------------
    property bool equipped: false               // scope is up
    property var channels: []                   // [{ id, identity, name, planet, title, artist, art, playing, volume, muted }]
    property string aimedId: ""                 // channel inside the aiming cone (written by the view)
    property string lockedId: ""                // channel dead centre (written by the view); media keys act on this one
    property string lastId: ""                  // last channel that was locked / selected (channel cycling starts here)
    signal alignRequested(string planetId)      // view turns the camera to this planet

    // ---------------- TUNING KNOBS ----------------
    property bool mediaNeedsLock: true          // true: mute / play / volume only work while locked on a channel
    property real metersPerUnit: 10.0           // world units -> the "27037m" readout
    // channel -> planet. Pool order = order players first appear. Edit freely (planet ids = CameraRig.bodyMeta keys).
    property var planetPool: ["ember_twin", "ash_twin", "brittle_hollow", "hollows_lantern",
                              "giants_deep", "dark_bramble", "interloper", "attlerock"]
    // pin a player to a planet by its lowercase name, e.g. ({ "spotify": "ember_twin", "firefox": "brittle_hollow" })
    property var pins: ({})
    // key map (Qt Shortcut sequences). Never W A S D Space Shift Ctrl Esc (rig) or L (rumor map).
    property var keys: ({
        toggle:    "Q",
        chanPrev:  "Left",
        chanNext:  "Right",
        playPause: "P",
        trackPrev: ",",
        trackNext: ".",
        mute:      "M",
        volUp:     "Up",
        volDown:   "Down"
    })

    // ---------------- LIVE HOOKS ----------------
    property bool mock: true
    property bool useHudBands: false            // live: waveform follows HudData's cava bands
    // live adapter: object with togglePlay(id) next(id) previous(id) setMuted(id, bool) setVolume(id, 0..1)
    property var backend: null

    // ---------------- LOOKUPS ----------------
    function channelIndex(id) {
        for (let i = 0; i < channels.length; i++) if (channels[i].id === id) return i;
        return -1;
    }
    function channelById(id) {
        const i = channelIndex(id);
        return i < 0 ? null : channels[i];
    }
    readonly property var lockedChannel: channelById(lockedId)
    readonly property var aimedChannel: channelById(aimedId)

    // ---------------- COMMANDS (keys, widget, IPC all end up here) ----------------
    // toggle | equip | unequip | chan-next | chan-prev | playpause | mute | vol-up | vol-down | track-next | track-prev
    function dispatch(cmd) {
        if (cmd === "toggle")  { equipped = !equipped; return; }
        if (cmd === "equip")   { equipped = true; return; }
        if (cmd === "unequip") { equipped = false; return; }
        if (!equipped) return;
        if (cmd === "chan-next") { cycle(1); return; }
        if (cmd === "chan-prev") { cycle(-1); return; }

        const id = lockedId !== "" ? lockedId : (mediaNeedsLock ? "" : (aimedId !== "" ? aimedId : lastId));
        const ch = channelById(id);
        if (!ch) return;
        if (cmd === "playpause")  { if (backend) backend.togglePlay(id); else _patch(id, { playing: !ch.playing }); }
        else if (cmd === "mute")  { if (backend) backend.setMuted(id, !ch.muted); else _patch(id, { muted: !ch.muted }); }
        else if (cmd === "vol-up" || cmd === "vol-down") {
            const v = Math.max(0, Math.min(1, ch.volume + (cmd === "vol-up" ? 0.05 : -0.05)));
            if (backend) backend.setVolume(id, v); else _patch(id, { volume: v, muted: false });
        }
        else if (cmd === "track-next") { if (backend) backend.next(id); else _patch(id, { title: _mockTitle() }); }
        else if (cmd === "track-prev") { if (backend) backend.previous(id); else _patch(id, { title: _mockTitle() }); }
    }

    function cycle(dir) {
        const n = channels.length;
        if (n === 0) return;
        const base = channelIndex(aimedId !== "" ? aimedId : lastId);
        const i = base < 0 ? (dir > 0 ? 0 : n - 1) : (base + dir + n) % n;
        lastId = channels[i].id;
        alignRequested(channels[i].planet);
    }

    onEquippedChanged: { if (!equipped) { aimedId = ""; lockedId = ""; } }

    // ---------------- CHANNEL FEED ----------------
    property var _assigned: ({})                // channel id -> planet (kept, so channels never jump planets)
    property string _json: ""

    function _planetFor(ch) {
        const pin = pins[String(ch.identity || "").toLowerCase()];
        if (pin) return pin;
        if (_assigned[ch.id]) return _assigned[ch.id];
        const used = {};
        for (const k in _assigned) used[_assigned[k]] = true;
        for (const k in pins) used[pins[k]] = true;
        for (let i = 0; i < planetPool.length; i++) {
            if (!used[planetPool[i]]) { _assigned[ch.id] = planetPool[i]; return planetPool[i]; }
        }
        return "";
    }

    // list: [{ id, identity, name, title, artist, art, playing, volume, muted }]  (planet is assigned here; art = cover url or "")
    function setChannels(list) {
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const c = list[i];
            const pl = _planetFor(c);
            if (pl === "") continue;                // more players than planets: the extras are simply not on the scope
            out.push({
                id: c.id, identity: c.identity || "", name: c.name || "UNKNOWN", planet: pl,
                title: c.title || "", artist: c.artist || "", art: c.art || "",
                playing: !!c.playing, volume: c.volume === undefined ? 1 : c.volume, muted: !!c.muted
            });
        }
        const s = JSON.stringify(out);
        if (s === _json) return;
        _json = s;
        channels = out;
        if (lastId !== "" && channelIndex(lastId) < 0) lastId = "";
    }

    function _patch(id, fields) {
        const out = [];
        for (let i = 0; i < channels.length; i++) {
            const c = channels[i];
            if (c.id !== id) { out.push(c); continue; }
            const n = {};
            for (const k in c) n[k] = c[k];
            for (const k in fields) n[k] = fields[k];
            out.push(n);
        }
        _json = JSON.stringify(out);
        channels = out;
    }

    // ---------------- MOCK ----------------
    property int _mockN: 0
    function _mockTitle() { _mockN++; return "Mock Track " + (_mockN + 4); }

    Component.onCompleted: {
        if (!mock) return;
        setChannels([
            { id: "m1", identity: "owv",   name: "OUTER WILDS VENTURES", title: "Mock Track 1", artist: "Mock Artist A", playing: true,  volume: 0.8, muted: false },
            { id: "m2", identity: "trav",  name: "TRAVELER",             title: "Mock Track 2", artist: "Mock Artist B", playing: true,  volume: 0.6, muted: false },
            { id: "m3", identity: "dist",  name: "DISTRESS BEACON",      title: "Mock Track 3", artist: "Mock Artist C", playing: false, volume: 1.0, muted: false },
            { id: "m4", identity: "quant", name: "QUANTUM FLUCTUATIONS", title: "Mock Track 4", artist: "Mock Artist D", playing: true,  volume: 0.9, muted: true  }
        ]);
    }
}
