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

    // ---- HYPR-COMPAT: only monitors whose name does NOT match skipPattern show the scene (the headless /
    // streaming output must not render a second solar system). desktopVisible = some scene monitor is
    // looking at an empty workspace with no fullscreen window.
    property string skipPattern: "^HEADLESS"
    function isSceneScreen(name) { return !(new RegExp(root.skipPattern)).test(name || ""); }

    // `hyprctl -j monitors` text + `hyprctl -j workspaces` text -> { visible, windows } or null when unreadable
    function sceneState(monText, wsText) {
        let mons, wss;
        try { mons = JSON.parse(monText); wss = JSON.parse(wsText); } catch (e) { return null; }
        if (!Array.isArray(mons) || !Array.isArray(wss)) return null;
        let anyEmpty = false, shownWins = -1;
        for (const m of mons) {
            if (!root.isSceneScreen(m.name)) continue;
            const id = m.activeWorkspace ? m.activeWorkspace.id : undefined;
            const ws = wss.find(w => w.id === id);
            const wins = ws ? (ws.windows | 0) : 0;
            const fs = ws ? !!ws.hasfullscreen : false;
            if (shownWins < 0 || m.focused) shownWins = wins;
            if (wins === 0 && !fs) anyEmpty = true;
        }
        if (shownWins < 0) return null;
        return { visible: anyEmpty, windows: shownWins };
    }
    function applyState(st) {
        if (!st) return;
        root.lastWindows = st.windows;
        root.desktopVisible = st.visible;
    }

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
        command: ["sh", "-c", "hyprctl -j monitors; echo @@@; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.split("@@@");
                root.applyState(root.sceneState(p[0] || "", p[1] || ""));
            }
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "noctalia msg status; echo @@@; hyprctl -j monitors; echo @@@; hyprctl -j workspaces"]
        stdout: StdioCollector {
            onStreamFinished: root.handle(text)
        }
    }

    function handle(out) {
        const parts = out.split("@@@");
        const panel = ((parts[0] || "").match(/"activePanelId"\s*:\s*"([^"]*)"/) || [])[1] || "";
        root.lastPanel = panel;
        root.applyState(root.sceneState(parts[1] || "", parts[2] || ""));

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
