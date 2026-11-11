import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shim"
import "../../.."

// Overlay hosting the screen-time panel, plus the tracker that feeds it.
//   toggle:  qs -c outerwilds ipc call screentime toggle
// The tracker (scripts/screentime.py track) counts the focused Hyprland window once a second into
// ~/.local/state/outerwilds/screentime/. Only one tracker runs at a time.
Scope {
    id: root
    property bool open: false

    onOpenChanged: if (open) NoctaliaBridge.planetRequested("sun_station", "screentime")

    IpcHandler {
        target: "screentime"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    Process {
        running: true
        command: ["python3", Caching.serpantinumDir + "/scripts/screentime.py", "track"]
    }

    PanelWindow {
        visible: root.open
        color: "#66000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-screentime"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.open = false }
        Shortcut { sequence: "Escape"; enabled: root.open; onActivated: root.open = false }

        Rectangle {
            width: Math.min(parent.width - 80, 1040)
            height: Math.min(parent.height - 80, 760)
            anchors.centerIn: parent
            radius: 16
            color: "#F0080A0F"
            border.color: "#55D4AF37"
            border.width: 1

            MouseArea { anchors.fill: parent }          // clicks inside do not close
            Loader {
                anchors.fill: parent
                active: root.open
                source: "ScreentimePanel.qml"
            }
        }
    }
}
