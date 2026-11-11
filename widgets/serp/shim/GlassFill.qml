import QtQuick

// No-op stand-in for Serpantinum's liquid-glass backdrop fill (IconButton draws it only when
// ThemeBackend.liquidGlass is on, which it is not here). Keeps the property surface IconButton sets.
Item {
    property real radius: 0
    property real shadow: 0
    property real press: 0
    property real pulse: 0
    property color tintColor: "transparent"
    property real tintAmount: 0
    property bool allowed: true
    readonly property bool active: false
    property real frost: 0
    property real rim: 0
    property real saturation: 1.0
    property real thickness: -1
    property real tintStrength: 0.5
    property bool forceClear: false
    property bool forceOpaque: false
    property int nestLevel: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    visible: false
}
