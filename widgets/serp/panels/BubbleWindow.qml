import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shim"
import "../../.."

// Full-screen overlay hosting Anserin's Bubble Monitor (BubbleMonitor.qml).
//   toggle:  qs -c outerwilds ipc call bubble toggle      (bind a key to this)
// The monitor only reads the system (bubble/bubble-feed.py, needs python-psutil) while this is open.
// Esc or the X closes it.
Scope {
    id: root
    property bool open: false

    IpcHandler {
        target: "bubble"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    PanelWindow {
        visible: root.open
        color: "#55000000"      // see-through: your solar system shows behind the bubbles
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-bubble"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        Loader {
            anchors.fill: parent
            active: root.open
            source: "BubbleMonitor.qml"
            onLoaded: {
                item.hosted = true;
                item.active = true;
                item.closeRequested.connect(function () { root.open = false; });
            }
        }

        Rectangle {
            z: 100
            anchors { left: parent.left; top: parent.top; margins: 14 }
            width: 38; height: 38; radius: 19
            color: closeMa.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
            Text { anchors.centerIn: parent; text: "\u2715"; color: "#E8DFC8"; font.pixelSize: 16 }
            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
        }
    }
}
