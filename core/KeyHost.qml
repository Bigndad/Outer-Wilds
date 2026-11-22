import QtQuick
import QtQml
import "../"

// Turns the Keybinds table into the real keys. Lives inside the scene (CameraRig), next to MapHost / RumorMap, so these are
// ordinary window Shortcuts like N / L / Q always were (they need the scene to have keyboard focus; for focus-free keys use the IPC calls).
//   * map / rumor / scope keys are handed to the existing owners (MapData.toggleKey, RumorData.toggleKey, SignalscopeData.keys);
//     their own Shortcuts then follow automatically.
//   * edit / keys / hud are handled here.
// No Quickshell import (CameraRig also runs in plain `qml`).
Item {
    id: host
    visible: false
    width: 0; height: 0

    property var rig: null

    // the planet being targeted / locked on: new widgets are added there (Control Centre)
    Binding { target: WidgetConfig;    property: "focusPlanet"; value: host.rig ? host.rig.activeFocusId : "" }
    Binding { target: MapData;         property: "toggleKey"; value: Keybinds.seq("map") }
    Binding { target: RumorData;       property: "toggleKey"; value: Keybinds.seq("rumor") }
    Binding { target: SignalscopeData; property: "keys";      value: Keybinds.scopeKeys() }

    // the overlays handle their own keys while they are up (the map's E = edit widgets); never type-trigger while a text field is active
    readonly property bool free: !MapData.open && !RumorData.open && !RumorData.typing

    Shortcut {
        sequence: Keybinds.seq("edit")
        enabled: host.free
        autoRepeat: false
        onActivated: WidgetConfig.panelOpen = !WidgetConfig.panelOpen
    }
    Shortcut {
        sequence: Keybinds.seq("keys")
        enabled: !RumorData.typing
        autoRepeat: false
        onActivated: {
            if (WidgetConfig.panelOpen && WidgetConfig.panelTab === "keys") { WidgetConfig.panelOpen = false; return; }
            WidgetConfig.panelTab = "keys";
            WidgetConfig.panelOpen = true;
        }
    }
    Shortcut {
        sequence: Keybinds.seq("launcher")
        enabled: host.free && Keybinds.seq("launcher") !== ""
        autoRepeat: false
        onActivated: WidgetConfig.launcherRequested()
    }
    Shortcut {
        sequence: Keybinds.seq("hud")
        enabled: host.free
        autoRepeat: false
        onActivated: WidgetConfig.setShowLoopPanel(!WidgetConfig.showLoopPanel)
    }
}
