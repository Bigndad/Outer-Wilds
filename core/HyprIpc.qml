import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// Global-bind targets for Hyprland (binds live in ~/.config/hypr/outerwilds.lua):
//   qs -c outerwilds ipc call map toggle|show|hide
//   qs -c outerwilds ipc call rumor toggle|show|hide
//   qs -c outerwilds ipc call perf set|cycle|diag|status      qs -c outerwilds ipc call layout next|load|list
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

    // qs -c outerwilds ipc call hud toggle|show|hide        (the bottom-right loop / speed panel)
    IpcHandler {
        target: "hud"
        function toggle(): void { WidgetConfig.setShowLoopPanel(!WidgetConfig.showLoopPanel); }
        function show(): void { WidgetConfig.setShowLoopPanel(true); }
        function hide(): void { WidgetConfig.setShowLoopPanel(false); }
    }

    // qs -c outerwilds ipc call keys toggle|show|hide        (the Control Centre on its KEYS tab)
    IpcHandler {
        target: "keys"
        function show(): void { WidgetConfig.panelTab = "keys"; WidgetConfig.panelOpen = true; }
        function hide(): void { WidgetConfig.panelOpen = false; }
        function toggle(): void {
            if (WidgetConfig.panelOpen && WidgetConfig.panelTab === "keys") WidgetConfig.panelOpen = false;
            else { WidgetConfig.panelTab = "keys"; WidgetConfig.panelOpen = true; }
        }
    }

    // qs -c outerwilds ipc call perf set quality|balanced|performance   |   perf cycle   |   perf diag   |   perf status
    IpcHandler {
        target: "perf"
        function set(mode: string): string { WidgetConfig.setPerfMode(mode); return WidgetConfig.perfMode; }
        function cycle(): string { return WidgetConfig.cyclePerfMode(); }
        function diag(): void { WidgetConfig.setShowDiag(!WidgetConfig.showDiag); }
        function status(): string { return WidgetConfig.effMode + (WidgetConfig.perfMode === "custom" ? " (custom)" : ""); }
    }

    // qs -c outerwilds ipc call layout next   |   layout load <name>   |   layout list      (the saved widget layout presets)
    IpcHandler {
        target: "layout"
        function next(): string { return WidgetConfig.nextPreset(); }
        function load(name: string): bool { return WidgetConfig.loadPreset(name); }
        function list(): string { return WidgetConfig.presetNames().join(", "); }
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

    // While the Control Centre records a key, Hyprland's own binds would swallow combos like Super+A before the panel sees them.
    // So recording switches Hyprland to an (empty) submap, ow_capture, where no bind is active, and back to "reset" afterwards.
    // The timer is a failsafe: whatever happens, the binds come back within 20 s.
    Connections {
        target: WidgetConfig
        function onCapturingKeysChanged() {
            if (WidgetConfig.capturingKeys) {
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"ow_capture\")"]);
                captureFailsafe.restart();
            } else {
                captureFailsafe.stop();
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
            }
        }
    }
    Timer {
        id: captureFailsafe
        interval: 20000
        repeat: false
        onTriggered: WidgetConfig.capturingKeys = false
    }
    Component.onDestruction: if (WidgetConfig.capturingKeys) Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"])

    // the signalscope key submap (outerwilds.lua) must never outlive the scope, or its arrow / P / M keys stay hijacked
    Connections {
        target: SignalscopeData
        function onEquippedChanged() {
            if (!SignalscopeData.equipped)
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]);
        }
    }
}
