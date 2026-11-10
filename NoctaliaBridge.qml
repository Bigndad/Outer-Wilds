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
