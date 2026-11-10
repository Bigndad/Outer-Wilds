#!/usr/bin/env bash
# Self-contained installer for NoctaliaBridge (includes the bridge file itself).
# Installs the singleton, registers it in qmldir, and adds flyTo() + a Connections block to core/CameraRig.qml.
# Safe to re-run: re-running also refreshes NoctaliaBridge.qml to this version.
set -euo pipefail
CFG="${OW_DIR:-$HOME/.config/quickshell/outerwilds}"
ARCH="${OW_ARCHIVE:-$HOME/outerwilds-archive}"
mkdir -p "$ARCH" "$CFG/data"

cat > "$CFG/data/NoctaliaBridge.qml" <<'QMLEOF'
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// When a Noctalia panel opens while you are looking at the wallpaper (no window on the
// current workspace), ask the solar system to fly to that panel's planet.
//
//   Hyprland "openlayer" event  ->  one shell call that prints
//     `noctalia msg status`            (which panel is it?   -> activePanelId)
//     `hyprctl -j activeworkspace`     (is the desktop empty? -> windows)
//   ->  planetRequested(planetId, panelId)   (CameraRig listens and flies there)
//
// Noctalia's own panel still opens normally on top; we only move the camera.
Singleton {
    id: root

    signal planetRequested(string planetId, string panelId)
    signal launcherRequested()

    // true: opening Noctalia's launcher from the bar closes it and opens ilyamiro's launcher instead
    property bool replaceLauncher: true

    // true: react only on an empty workspace. false: react even with windows open.
    property bool onlyWhenEmpty: true

    // Noctalia panel id -> planet id (ids as in CameraRig.bodyMeta). Edit freely.
    readonly property var panelPlanets: ({
        "launcher":       "dark_bramble",   // App Launcher
        "session":        "sun_station",    // System Power
        "clipboard":      "attlerock",      // Quick Notes
        "wallpaper":      "quantum_moon",
        "control-center": "giants_deep"     // all tabs for now: status does not report the tab
    })

    // layer names Noctalia uses for panels (from `hyprctl layers`)
    readonly property var layerNames: ["noctalia-panel", "noctalia-attached-panel"]

    // last probe result, handy for debugging: qs -c outerwilds log
    property string lastPanel: ""
    property int lastWindows: -1

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openlayer" && root.layerNames.indexOf(event.data) !== -1)
                probe.running = true;
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "noctalia msg status; echo @@@; hyprctl -j activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: root.handle(text)
        }
    }

    function handle(out) {
        const parts = out.split("@@@");
        const panel = ((parts[0] || "").match(/"activePanelId"\s*:\s*"([^"]*)"/) || [])[1] || "";
        const wins = parseInt(((parts[1] || "").match(/"windows"\s*:\s*(\d+)/) || [])[1]);
        root.lastPanel = panel;
        root.lastWindows = isNaN(wins) ? -1 : wins;
        console.log("[NoctaliaBridge] panel=" + panel + " windows=" + root.lastWindows);

        if (panel === "") return;
        if (panel === "launcher" && root.replaceLauncher) {
            Quickshell.execDetached(["noctalia", "msg", "panel-close", "launcher"]);
            root.launcherRequested();
            return;
        }
        if (root.onlyWhenEmpty && root.lastWindows !== 0) return;   // unknown (-1) also skips
        const planet = root.panelPlanets[panel];
        if (planet) root.planetRequested(planet, panel);
    }

    // test the camera without Noctalia:  qs -c outerwilds ipc call bridge fly dark_bramble
    IpcHandler {
        target: "bridge"
        function fly(planetId: string): void { root.planetRequested(planetId, "ipc"); }
    }
}
QMLEOF

grep -q NoctaliaBridge "$CFG/qmldir" || \
  echo "singleton NoctaliaBridge 1.0 data/NoctaliaBridge.qml" >> "$CFG/qmldir"

python3 - "$CFG/core/CameraRig.qml" "$ARCH" <<'PY'
import sys, shutil, pathlib
p = pathlib.Path(sys.argv[1]); arch = pathlib.Path(sys.argv[2])
t = p.read_text()
if "NoctaliaBridge" in t:
    print("CameraRig already patched"); sys.exit(0)
anchor = "    function flyInAt(mx, my) { return mouseArea.engageAt(mx, my); }\n"
if anchor not in t:
    sys.exit("anchor line (flyInAt) not found in CameraRig.qml - not patched")
shutil.copy(p, arch / "CameraRig.qml.pre-bridge")
add = anchor + """
    // fly to a planet and lock on (same as double-clicking it); used by NoctaliaBridge
    function flyTo(planetId) { mouseArea.engageAutopilot(planetId); }
    Connections {
        target: NoctaliaBridge
        function onPlanetRequested(planetId, panelId) { root.flyTo(planetId); }
    }
"""
p.write_text(t.replace(anchor, add, 1))
print("CameraRig patched (backup in " + str(arch) + ")")
PY
echo "restart:  qs kill -c outerwilds; qs -c outerwilds"
echo "test:     qs -c outerwilds ipc call bridge fly dark_bramble"
