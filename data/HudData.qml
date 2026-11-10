pragma Singleton
import QtQuick
import Quickshell
import ".."

// =====================================================================
//  HudData: the ONE place the HUD gets its numbers from.
//  The HUD only reads the "public surface" below. Today everything is
//  MOCK data. To go live: set `mock: false` and fill the properties
//  from real sources (sketch at the bottom of this file).
// =====================================================================
Singleton {
    id: root

    // ---------------- PUBLIC SURFACE (read by SatelliteHUD) ----------------
    property real cpu: 0.0              // 0..1   -> yellow arc
    property real ram: 0.0              // 0..1   -> cyan arc
    property real battery: 1.0          // 0..1   -> orange boost arc
    property bool audioActive: false    // false  -> globe stops spinning, bands decay to 0
    property vector4d bandsA: Qt.vector4d(0, 0, 0, 0)   // audio bands 0..3 (bass -> mid), each 0..1
    property vector4d bandsB: Qt.vector4d(0, 0, 0, 0)   // audio bands 4..7 (mid -> treble)

    // Helper for a real audio source: setBands([8 floats in 0..1])
    function setBands(b) {
        bandsA = Qt.vector4d(b[0], b[1], b[2], b[3]);
        bandsB = Qt.vector4d(b[4], b[5], b[6], b[7]);
    }

    // ---------------- MOCK ----------------
    property bool mock: true
    property real _sec: 0.0
    property real _audioT: 0.0

    // slow system-stat drift, 1 Hz
    Timer {
        interval: 1000
        repeat: true
        running: root.mock
        triggeredOnStart: true
        onTriggered: {
            root._sec += 1.0;
            const t = root._sec;
            root.cpu = Math.max(0.03, Math.min(0.97, 0.28 + 0.22 * Math.sin(t / 7.0) + 0.10 * Math.sin(t * 1.9)));
            root.ram = Math.max(0.05, Math.min(0.97, 0.58 + 0.06 * Math.sin(t / 31.0) + 0.02 * Math.sin(t * 0.7)));
            root.battery = Math.max(0.05, Math.min(1.0, 0.80 + 0.18 * Math.sin(t / 60.0)));
        }
    }

    // fake music: 24 s playing, 6 s silence, repeating
    Timer {
        id: audioSwitch
        interval: 24000
        repeat: true
        running: root.mock
        onTriggered: {
            root.audioActive = !root.audioActive;
            interval = root.audioActive ? 24000 : 6000;
            if (!root.audioActive) root.setBands([0, 0, 0, 0, 0, 0, 0, 0]);
        }
    }
    Component.onCompleted: if (mock) audioActive = true

    // 30 Hz band synthesis; only runs while "audio" is active
    Timer {
        interval: 33
        repeat: true
        running: root.mock && root.audioActive
        onTriggered: {
            root._audioT += 0.033;
            const t = root._audioT;
            const beat = 0.65 + 0.35 * Math.pow(Math.max(0.0, Math.sin(t * 7.0)), 3.0);
            const b = [];
            for (let i = 0; i < 8; i++) {
                const wob = 0.5 + 0.5 * Math.sin(t * (1.7 + 0.55 * i) + i * 1.3);
                b.push(Math.min(1.0, Math.pow(wob, 1.5) * (1.0 - 0.06 * i) * beat * 1.15));
            }
            root.setBands(b);
        }
    }

    // ---------------- REAL DATA (untested sketch; wire up when at the PC) ----------------
    // 1. Set `mock: false` above and delete/disable the three Timers.
    // 2. CPU/RAM: poll every 1-2 s, never faster:
    //      FileView { path: "/proc/meminfo" }  -> ram = 1 - MemAvailable / MemTotal
    //      FileView { path: "/proc/stat" }     -> cpu = delta(busy) / delta(total) between polls
    //    (call reload() from a 1500 ms Timer, parse in onLoaded)
    // 3. Battery: FileView { path: "/sys/class/power_supply/BAT0/capacity" } -> battery = value / 100
    //    A desktop has no BAT*. Either keep the arc on mock, or feed it something else
    //    (e.g. GPU busy: /sys/class/drm/card*/device/gpu_busy_percent on amdgpu).
    // 4. Audio: Process { command: ["cava", "-p", "<cava raw config, 8 bars, ascii>"]
    //      stdout: SplitParser { onRead: line => root.setBands(parse(line)) } }
    //    Set audioActive from the player state (playerctl / Mpris) so cava only runs while playing.
}
