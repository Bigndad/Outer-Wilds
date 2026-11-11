import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// Widget control panel as a slide-in strip on the right edge, ABOVE every window (Overlay layer).
// The rest of the screen stays free, so the solar system behind it (on an empty workspace) previews every change live.
// Open state lives in WidgetConfig.panelOpen, so the map's "Edit Widgets" button, the IPC calls and the X all share it.
//   toggle:  qs -c outerwilds ipc call settings toggle        (also: show / hide)
// Esc or the X closes it. Needs keyboard focus only for Esc (OnDemand: it takes focus when clicked).
Scope {
    id: root

    IpcHandler {
        target: "settings"
        function toggle(): void { WidgetConfig.panelOpen = !WidgetConfig.panelOpen; }
        function show(): void { WidgetConfig.panelOpen = true; }
        function hide(): void { WidgetConfig.panelOpen = false; }
    }

    Connections {
        target: WidgetConfig
        function onPanelOpenChanged() { if (!WidgetConfig.panelOpen) WidgetConfig.previewId = ""; }
    }

    PanelWindow {
        visible: WidgetConfig.panelOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-settings"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; right: true }
        implicitWidth: 480

        SettingsPanel {
            anchors.fill: parent
            onCloseRequested: WidgetConfig.panelOpen = false
            onFlyRequested: (planetId) => { if (planetId !== "") NoctaliaBridge.planetRequested(planetId, "settings"); }
        }
    }
}
