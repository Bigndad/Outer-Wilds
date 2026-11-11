import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../.."

// Overlay hosting ilyamiro's wallpaper picker (WallpaperPicker.qml).
//   toggle:  qs -c outerwilds ipc call wallpaper toggle     (bind a key to this)
// Applying a wallpaper runs `noctalia msg wallpaper-set <output> <file>`. Esc or a click outside closes it.
Scope {
    id: root
    property bool open: false

    onOpenChanged: if (open) NoctaliaBridge.planetRequested("attlerock", "wallpaper")

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    PanelWindow {
        id: win
        visible: root.open
        color: "#66000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-wallpaper"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.open = false }
        Shortcut { sequence: "Escape"; enabled: root.open; onActivated: root.open = false }

        Loader {
            id: loader
            active: root.open
            width: parent.width
            height: 650
            anchors.verticalCenter: parent.verticalCenter
            source: "WallpaperPicker.qml"
            onLoaded: {
                item.masterWindow = win;
                item.width = Qt.binding(() => loader.width);
                item.height = Qt.binding(() => loader.height);
                item.visible = true;
            }
        }
    }
}
