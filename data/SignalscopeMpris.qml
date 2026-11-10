import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."

// =====================================================================
//  LIVE adapter for the signalscope (shell.qml only; never loaded by the Mint test, it needs Quickshell).
//  Every MPRIS player (Spotify, Firefox, mpv, ...) becomes a channel; SignalscopeData assigns the planets.
//  Put ONE in shell.qml next to the Variants:   SignalscopeMpris { }
//
//  UNTESTED (written away from the PC): check the MprisPlayer property names against your Quickshell version
//  (identity, dbusName, trackTitle, trackArtist, isPlaying, volume, volumeSupported, canTogglePlaying,
//  canGoNext, canGoPrevious, togglePlaying(), next(), previous()).
//
//  Mute = volume 0 / restore, so it only works for players that expose MPRIS volume (Spotify, mpv and most
//  browsers do). The waveform follows HudData's cava bands = overall system output, not one player.
//
//  Hyprland keybinds that work without keyboard focus (config dir = ~/.config/quickshell/outerwilds):
//    bind = SUPER, Q, exec, qs -c outerwilds ipc call signalscope toggle
//    bind = SUPER, right, exec, qs -c outerwilds ipc call signalscope next
//    ...same for prev, playpause, mute, nexttrack, prevtrack
// =====================================================================
Scope {
    id: root

    property var _prevVol: ({})

    function _list() {
        const v = Mpris.players ? Mpris.players.values : null;
        return v ? v : [];
    }
    function _id(p, i) { return p.dbusName ? String(p.dbusName) : (String(p.identity) + "#" + i); }
    function _find(id) {
        const ps = _list();
        for (let i = 0; i < ps.length; i++) if (_id(ps[i], i) === id) return ps[i];
        return null;
    }

    function publish() {
        const ps = _list();
        const out = [];
        for (let i = 0; i < ps.length; i++) {
            const p = ps[i];
            const vs = !!p.volumeSupported;
            out.push({
                id: _id(p, i),
                identity: String(p.identity || "").toLowerCase(),
                name: String(p.identity || "UNKNOWN").toUpperCase(),
                title: String(p.trackTitle || ""),
                artist: String(p.trackArtist || ""),
                playing: !!p.isPlaying,
                volume: vs ? p.volume : 1,
                muted: vs && p.volume < 0.001
            });
        }
        SignalscopeData.setChannels(out);
    }

    // ---- backend interface used by SignalscopeData.dispatch ----
    function togglePlay(id)  { const p = _find(id); if (p && p.canTogglePlaying) p.togglePlaying(); publish(); }
    function next(id)        { const p = _find(id); if (p && p.canGoNext) p.next(); }
    function previous(id)    { const p = _find(id); if (p && p.canGoPrevious) p.previous(); }
    function setVolume(id, v) { const p = _find(id); if (p && p.volumeSupported) p.volume = v; publish(); }
    function setMuted(id, m) {
        const p = _find(id);
        if (!p || !p.volumeSupported) return;
        if (m) { _prevVol[id] = p.volume > 0.001 ? p.volume : (_prevVol[id] || 1); p.volume = 0; }
        else p.volume = _prevVol[id] || 1;
        publish();
    }

    Component.onCompleted: {
        SignalscopeData.mock = false;
        SignalscopeData.useHudBands = true;
        SignalscopeData.backend = root;
        publish();
    }

    // players come and go, so poll: fast while the scope is up, lazy otherwise
    Timer {
        interval: SignalscopeData.equipped ? 400 : 2500
        running: true
        repeat: true
        onTriggered: root.publish()
    }

    IpcHandler {
        target: "signalscope"
        function toggle(): void    { SignalscopeData.dispatch("toggle"); }
        function equip(): void     { SignalscopeData.dispatch("equip"); }
        function unequip(): void   { SignalscopeData.dispatch("unequip"); }
        function next(): void      { SignalscopeData.dispatch("chan-next"); }
        function prev(): void      { SignalscopeData.dispatch("chan-prev"); }
        function playpause(): void { SignalscopeData.dispatch("playpause"); }
        function mute(): void      { SignalscopeData.dispatch("mute"); }
        function volup(): void     { SignalscopeData.dispatch("vol-up"); }
        function voldown(): void   { SignalscopeData.dispatch("vol-down"); }
        function nexttrack(): void { SignalscopeData.dispatch("track-next"); }
        function prevtrack(): void { SignalscopeData.dispatch("track-prev"); }
    }
}
