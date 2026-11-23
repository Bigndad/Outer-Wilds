pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    signal planetRequested(string planetId, string panelId)
    signal launcherRequested()

    property bool replaceLauncher: true
    property bool onlyWhenEmpty: true

    // True only when the active workspace has 0 tiled/floating windows and no fullscreen window
    property bool desktopVisible: true

    readonly property var panelPlanets: ({
        "launcher":       "dark_bramble",
        "session":        "sun_station",
        "clipboard":      "attlerock",
        "wallpaper":      "quantum_moon",
        "control-center": "giants_deep"
    })

    readonly property var layerNames: ["noctalia-panel", "noctalia-attached-panel"]
    readonly property var wsEvents: [
        "workspace", "focusedmon", "openwindow", "closewindow",
        "movewindow", "fullscreen", "changefloatingmode"
    ]

    property string lastPanel: ""
    property int lastWindows: 0

    Component.onCompleted: wsProbe.running = true

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openlayer" && root.layerNames.indexOf(event.data) !== -1) {
                probe.running = true;
            } else if (root.wsEvents.indexOf(event.name) !== -1) {
                wsDebounce.restart();
            }
        }
    }

    Timer {
        id: wsDebounce
        interval: 60
        repeat: false
        onTriggered: wsProbe.running = true
    }

    Process {
        id: wsProbe
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wins = parseInt((text.match(/"windows"\s*:\s*(\d+)/) || [])[1]);
                const fs = /"hasfullscreen"\s*:\s*true/.test(text);
                if (!isNaN(wins)) {
                    root.lastWindows = wins;
                    root.desktopVisible = (wins === 0 && !fs);
                }
            }
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
        const fs = /"hasfullscreen"\s*:\s*true/.test(parts[1] || "");
        root.lastPanel = panel;
        if (!isNaN(wins)) {
            root.lastWindows = wins;
            root.desktopVisible = (wins === 0 && !fs);
        }

        if (panel === "") return;
        if (panel === "launcher" && root.replaceLauncher) {
            Quickshell.execDetached(["noctalia", "msg", "panel-close", "launcher"]);
            root.launcherRequested();
            return;
        }
        if (root.onlyWhenEmpty && root.lastWindows !== 0) return;
        const planet = root.panelPlanets[panel];
        if (planet) root.planetRequested(planet, panel);
    }

    IpcHandler {
        target: "bridge"
        function fly(planetId: string): void { root.planetRequested(planetId, "ipc"); }
    }
}
