import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shim"
import "../../.."

// Full-screen overlay hosting Anserin's network manager (NetworkPopup.qml): Ethernet, Wi-Fi and Bluetooth.
//   toggle:  qs -c outerwilds ipc call network toggle      (bind a key to this)
// Esc, the X, or a click outside the panel closes it (Esc first cancels a Wi-Fi password prompt).
// Keyboard focus is OnDemand (not Exclusive) so the overlay can never lock you out of typing a close command.
Scope {
    id: root
    property bool open: false
    property bool built: false          // the popup is only created the first time it opens
    onOpenChanged: if (open) built = true

    IpcHandler {
        target: "network"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    PanelWindow {
        visible: root.open
        color: "#66000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-network"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.open = false }

        // the popup consumes Esc itself, so it is handled here: first cancel a Wi-Fi password prompt, then close
        Shortcut {
            sequence: "Escape"
            enabled: root.open
            onActivated: {
                const p = pop.item;
                if (p && p.pendingWifiId !== "") { p.pendingWifiId = ""; p.pendingWifiSsid = ""; }
                else root.open = false;
            }
        }

        Rectangle {
            z: 100
            anchors { right: parent.right; top: parent.top; margins: 14 }
            width: 38; height: 38; radius: 19
            color: closeMa.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
            Text { anchors.centerIn: parent; text: "\u2715"; color: "#E8DFC8"; font.pixelSize: 16 }
            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
        }

        Item {
            id: holder
            width: 720; height: 600          // the popup's own size; scaled up to fill most of the screen
            anchors.centerIn: parent
            scale: Math.max(0.6, Math.min(1.6, (parent.height - 80) / 600, (parent.width - 80) / 720))
            MouseArea { anchors.fill: parent }       // clicks inside do not close

            Loader {
                id: pop
                anchors.fill: parent
                active: root.built
                source: "NetworkPopup.qml"
                onLoaded: item.visible = Qt.binding(function () { return root.open; })
            }
        }
    }
}
