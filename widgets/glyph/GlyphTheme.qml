pragma Singleton
import QtQuick

// Nothing-style palette: black, white dots, ONE red (the single live thing on a card).
// Plain QtObject on purpose (no Quickshell import) so it also loads in the Mint test.
QtObject {
    readonly property color bg:   "#000000"
    readonly property color s1:   "#0E0E0E"   // card
    readonly property color s2:   "#1A1A1A"   // card border, quiet tiles
    readonly property color s3:   "#2A2A2A"   // unlit dots
    readonly property color mute: "#4A4A4A"
    readonly property color grey: "#8C8C8C"   // labels
    readonly property color fg:   "#F2F2F2"   // lit dots, text
    readonly property color red:  "#D71921"
    readonly property string mono: "monospace"
}
