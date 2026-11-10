pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Real MPRIS player state for the music faces (same API as Serpantinum's MprisController).
// Album art comes straight from the player's own art URL (Serpantinum runs a 300-line shell script
// for covers + colour extraction; that is skipped, the faces fall back to the theme colours).
Singleton {
    id: root

    readonly property var _playerWatch: {
        let players = Mpris.players.values;
        let states = [];
        for (let i = 0; i < players.length; i++) {
            states.push(players[i].isPlaying);
            states.push(players[i].canControl);
            states.push(players[i].busName);
        }
        return states;
    }

    property string lastPlayingBus: ""

    readonly property MprisPlayer activePlayer: {
        let _ = _playerWatch;
        try {
            let players = Mpris.players.values.filter(p => p).sort((a, b) => (a.busName || "").localeCompare(b.busName || ""));
            let playing = players.find(p => p.isPlaying);
            if (playing) return playing;
            let last = root.lastPlayingBus !== "" ? players.find(p => p.busName === root.lastPlayingBus) : null;
            if (last) return last;
            let loaded = players.find(p => p.playbackState !== MprisPlaybackState.Stopped && p.trackTitle !== "");
            if (loaded) return loaded;
            let controllable = players.find(p => p.canControl);
            if (controllable) return controllable;
            return players.length > 0 ? players[0] : null;
        } catch (e) {
            return null;
        }
    }

    readonly property string activePlayerId: activePlayer ? (activePlayer.busName || activePlayer.identity || "") : ""
    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool isPlaying: { try { return activePlayer ? activePlayer.isPlaying === true : false; } catch (e) { return false; } }
    readonly property string trackTitle: { try { return activePlayer ? String(activePlayer.trackTitle || "") : ""; } catch (e) { return ""; } }
    readonly property string trackArtist: { try { return activePlayer ? String(activePlayer.trackArtist || "") : ""; } catch (e) { return ""; } }

    readonly property string currentArtUrl: {
        if (!activePlayer) return "";
        if (activePlayer.trackArtUrl && activePlayer.trackArtUrl !== "") return String(activePlayer.trackArtUrl);
        let m = activePlayer.metadata;
        if (m) {
            if (m["mpris:artUrl"]) return String(m["mpris:artUrl"]);
            if (m["artUrl"]) return String(m["artUrl"]);
        }
        return "";
    }

    property real livePosition: activePlayer ? activePlayer.position : 0
    readonly property string artUrl: currentArtUrl

    // colour extraction is skipped: empty = the faces use the theme palette
    readonly property string primaryColor: ""
    readonly property string dominantColor: ""
    readonly property string backgroundColor: ""
    readonly property string grad: ""
    readonly property string textColor: "#E6D5B8"
    readonly property string deviceIcon: "󰓃"
    readonly property string deviceName: "Speaker"
    function queueFetch() {}
    function forceArtRefresh() {}

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.isPlaying) lastPlayingBus = activePlayer.busName || "";
        if (activePlayer) livePosition = activePlayer.position;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasActivePlayer && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() { if (root.activePlayer) root.livePosition = root.activePlayer.position; }
        function onPostTrackChanged() { if (root.activePlayer) root.livePosition = root.activePlayer.position; }
    }
}
