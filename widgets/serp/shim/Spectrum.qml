pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Real audio spectrum for the music faces, from `cava` (pacman -S cava). Same API as Serpantinum's
// Spectrum singleton (which needs his own `serpantinum-audio` binary). cava only runs while a face
// has registered as a consumer AND something is playing, so it costs nothing otherwise.
Item {
    id: root

    property int barCount: 64
    readonly property var emptyLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return Object.freeze(arr);
    }
    property var barLevels: emptyLevels
    property int activeConsumers: 0
    property bool isPlaying: MprisController.isPlaying
    property bool isDecaying: false
    property bool isRestarting: false
    property int crashes: 0
    property bool processEnabled: activeConsumers > 0 && (isPlaying || isDecaying) && !isRestarting

    readonly property string cfgPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ow-cava.conf"
    readonly property string cfgText: [
        "[general]", "bars = " + barCount, "framerate = 60",
        "[input]", "method = pulse", "source = auto",
        "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii",
        "ascii_max_range = 1000", "bar_delimiter = 59", "frame_delimiter = 10",
        "[smoothing]", "noise_reduction = 70"
    ].join("\n")

    function registerConsumer() { activeConsumers++; }
    function unregisterConsumer() { activeConsumers = Math.max(0, activeConsumers - 1); }
    function resetBars() { barLevels = emptyLevels; }

    onIsPlayingChanged: {
        if (isPlaying) { isDecaying = false; decayTimer.stop(); }
        else if (activeConsumers > 0) { isDecaying = true; decayTimer.restart(); }
        else resetBars();
    }
    onActiveConsumersChanged: { if (activeConsumers === 0) { isDecaying = false; decayTimer.stop(); } }
    onProcessEnabledChanged: { if (!processEnabled) { if (!isRestarting) crashes = 0; resetBars(); } }

    Timer { id: decayTimer; interval: 1200; onTriggered: root.isDecaying = false }
    Timer { id: restartTimer; interval: 500; onTriggered: root.isRestarting = false }

    Process {
        id: cava
        running: root.processEnabled
        command: ["sh", "-c", 'printf "%s\\n" "$1" > "$2"; exec cava -p "$2"', "sh", root.cfgText, root.cfgPath]
        onExited: {
            if (root.processEnabled && root.crashes < 5) {
                root.crashes++;
                root.isRestarting = true;
                restartTimer.restart();
            }
        }
        stdout: SplitParser {
            onRead: data => {
                if (!root.processEnabled) return;
                const parts = data.split(";");
                if (parts.length < root.barCount) return;
                const levels = new Array(root.barCount);
                for (let i = 0; i < root.barCount; i++) levels[i] = Math.min(1, (parseInt(parts[i]) || 0) / 1000);
                root.crashes = 0;
                root.barLevels = levels;
            }
        }
    }
}
