pragma Singleton
import QtQuick
import "../.."

// Nothing-style palette with live WidgetConfig overrides (no Quickshell import, loads on Mint too).
QtObject {
    readonly property color bg:   "#000000"
    readonly property color s1:   WidgetConfig.glyphBg !== "" ? WidgetConfig.glyphBg : "#0E0E0E"
    readonly property color s2:   WidgetConfig.glyphBorder !== "" ? WidgetConfig.glyphBorder : "#1A1A1A"
    readonly property color s3:   WidgetConfig.glyphOff !== "" ? WidgetConfig.glyphOff : "#2A2A2A"
    readonly property color mute: "#4A4A4A"
    readonly property color grey: "#8C8C8C"
    readonly property color fg:   WidgetConfig.glyphFg !== "" ? WidgetConfig.glyphFg : "#F2F2F2"
    readonly property color red:  WidgetConfig.glyphAccent !== "" ? WidgetConfig.glyphAccent : "#D71921"
    readonly property string mono: WidgetConfig.glyphFont !== "" ? WidgetConfig.glyphFont : "monospace"
}
