import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// Fullscreen overlay hosting ilyamiro's app launcher (AppLauncher.qml).
//   toggle:  qs -c outerwilds ipc call launcher toggle     (bind your launcher key to this)
//   also opened by NoctaliaBridge when the Noctalia launcher is opened from the bar.
Scope {
    id: root
    property bool open: false

    onOpenChanged: if (open) NoctaliaBridge.planetRequested("dark_bramble", "launcher")

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    Connections {
        target: NoctaliaBridge
        function onLauncherRequested() { root.open = true; }
    }

    PanelWindow {
        visible: root.open
        color: "#B307080C"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        Loader {
            anchors.fill: parent
            active: root.open
            sourceComponent: AppLauncher {
                onCloseRequested: root.open = false
            }
        }
    }
}
