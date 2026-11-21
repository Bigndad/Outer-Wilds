pragma Singleton
import QtQuick

// Outer Wilds palette in Serpantinum's (catppuccin-style) token names.
// Edit this one block to retheme; planet-specific themes can come later.
QtObject {
    readonly property color base: "#0a0c12"
    readonly property color mantle: "#080a0f"
    readonly property color crust: "#06070b"
    readonly property color surface0: "#1d1f27"
    readonly property color surface1: "#2a2c36"
    readonly property color surface2: "#383b47"
    readonly property color text: "#ead9b4"
    readonly property color subtext0: "#b5a783"
    readonly property color subtext1: "#cdbd96"
    readonly property color mauve: "#e8b54a"     // main accent -> brass gold
    readonly property color primary: "#e8b54a"
    readonly property color yellow: "#e8b54a"
    readonly property color peach: "#e5834a"
    readonly property color green: "#8fbf7a"
    readonly property color teal: "#6fb7a8"
    readonly property color red: "#e5604a"
    readonly property color blue: "#7fb7c9"

    readonly property real elementOpacity: 0.92
    readonly property real borderRadius: 8
    readonly property real clampedBorderRadius: 8
    readonly property bool blurBackground: false
    readonly property bool liquidGlass: false
    readonly property var matugenColors: null
    readonly property string fontFamily: "sans-serif"
    readonly property string iconFont: nerd.name !== "" ? nerd.name : "Symbols Nerd Font Mono"

    property FontLoader nerd: FontLoader { source: Qt.resolvedUrl("../assets/fonts/SymbolsNerdFontMono-Regular.ttf") }

    // added by port_music.py (music faces need these tokens)
    property color overlay0: "#5E5444"
    property color overlay1: "#7A6E5A"
    property color overlay2: "#968A74"
    property color pink: "#C98F86"
    property color sapphire: "#6FA3B0"
}
