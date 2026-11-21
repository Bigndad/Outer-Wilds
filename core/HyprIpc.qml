import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Global-bind targets for Hyprland (binds live in ~/.config/hypr/outerwilds.lua):
//   qs -c outerwilds ipc call map toggle|show|hide
//   qs -c outerwilds ipc call rumor toggle|show|hide
//   qs -c outerwilds ipc call scene status          (prints what the bridge sees; handy for debugging)
// The overlays still pause the rig themselves (MapHost / RumorMap watch MapData.open / RumorData.open).
// These work without keyboard focus, unlike the in-scene N / L / Q shortcuts.
// (HYPR-COMPAT)
Scope {
    id: root

    IpcHandler {
        target: "map"
        // same rules as the N shortcut in MapHost: inside Rumor Mode it means "Back to Map",
        // and a Rumor Map opened on its own is left alone
        function toggle(): void {
            if (RumorData.open && !MapData.rumorMode) return;
            if (MapData.rumorMode) MapData.backToMap(); else MapData.toggle();
        }
        function show(): void { if (!MapData.open) toggle(); }
        function hide(): void { if (MapData.open) toggle(); }
    }

    IpcHandler {
        target: "rumor"
        function toggle(): void { RumorData.toggle(); }
        function show(): void { if (!RumorData.open) RumorData.toggle(); }
        function hide(): void { if (RumorData.open) RumorData.toggle(); }
    }

    IpcHandler {
        target: "scene"
        function status(): string {
            return JSON.stringify({
                desktopVisible: NoctaliaBridge.desktopVisible,
                windowsOnSceneWorkspace: NoctaliaBridge.lastWindows,
                lastPanel: NoctaliaBridge.lastPanel,
                skipPattern: NoctaliaBridge.skipPattern,
                map: MapData.open,
                rumor: RumorData.open,
                scope: SignalscopeData.equipped
            });
        }
    }

    // the signalscope key submap (outerwilds.lua) must never outlive the scope, or its arrow / P / M keys stay hijacked
    Connections {
        target: SignalscopeData
        function onEquippedChanged() {
            if (!SignalscopeData.equipped)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
        }
    }
}
