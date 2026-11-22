import QtQuick
// Serpantinum blurs the wallpaper behind its cards; here it's a no-op placeholder.
Item {
    property real radius: 0
    property bool standalone: false
    property bool surfaceEnabled: false
    readonly property bool active: false   // added by port_anserin_panels.py
}
