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
    visible: false
}
