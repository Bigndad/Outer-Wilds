import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // live audio players -> signalscope channels (also registers `qs ipc call signalscope ...`)
    SignalscopeMpris { }

    LauncherWindow { }

    // widget settings: widgets.json <-> WidgetConfig, and the panel (qs -c outerwilds ipc call settings toggle)
    WidgetConfigStore { }
    SettingsWindow { }
    ScreentimeWindow { }
    WallpaperWindow { }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            property var modelData
            screen: modelData

            // Starts on Top for Stage 1 testing; we switch to Background in Stage 5
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "outerwilds-solar-system"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"

            CameraRig {
                anchors.fill: parent
            }
        }
    }
}