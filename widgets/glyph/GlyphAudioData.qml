pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Default output volume through wpctl (PipeWire). Polled every 2 s while the scene is visible.
Singleton {
    id: root
    property real vol: 0
    property bool muted: false
    property bool ok: false

    function setVol(v) {
        v = Math.max(0, Math.min(1, v));
        root.vol = v;
        setProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)];
        setProc.running = true;
    }
    function toggleMute() {
        root.muted = !root.muted;
        muteProc.running = true;
    }

    Timer {
        interval: 2000
        running: NoctaliaBridge.desktopVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!setProc.running) getProc.running = true
    }
    Process {
        id: getProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = String(text).match(/Volume:\s*([0-9.]+)/);
                if (m) { root.vol = parseFloat(m[1]); root.ok = true; }
                root.muted = String(text).indexOf("MUTED") >= 0;
            }
        }
    }
    Process { id: setProc }
    Process { id: muteProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
}
