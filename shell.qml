import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    // live audio players -> signalscope channels (also registers `qs ipc call signalscope ...`)
    SignalscopeMpris { }

    // live apps / launching / workspaces / uptime for the Map View and widgets (replaces their mock data)
    SystemLive { }

    // the last mock -> live step: HUD, sensors on the Map View, notifications, notes (qs -c outerwilds ipc call system status)
    SystemExtras { }

    LauncherWindow { }

    // widget settings: widgets.json <-> WidgetConfig, and the panel (qs -c outerwilds ipc call settings toggle)
    WidgetConfigStore { }
    SettingsWindow { }
    ScreentimeWindow { }
    BubbleWindow { }
    NetworkWindow { }
    WallpaperWindow { }

    // global-bind IPC for Hyprland: map, rumor, scene (HYPR-COMPAT)
    HyprIpc { }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: sceneWin
            readonly property bool sceneHere: NoctaliaBridge.isSceneScreen(modelData ? modelData.name : "")
            visible: sceneHere
            property var modelData
            screen: modelData

            // Starts on Top for Stage 1 testing; we switch to Background in Stage 5
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "outerwilds-solar-system"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // cover the whole output: ignore the bar's reserved strip (the bar still draws over the scene)
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            Loader {   // HYPR-COMPAT: no scene on the headless output
                anchors.fill: parent
                focus: true
                active: sceneWin.sceneHere
                sourceComponent: Component { CameraRig { anchors.fill: parent } }
            }
        }
    }
}