pragma Singleton
import QtQuick

// Outer Wilds palette for the ported Lucid widgets. Every colour lives in the
// first block so a planet-specific palette can replace it later.
QtObject {
    // ---- palette (edit here) ----
    readonly property color bg: "#e00a0c12"
    readonly property color surfaceHighest: "#2a2a33"
    readonly property color text: "#ead9b4"
    readonly property color subtext: "#b5a783"
    readonly property color subtextDim: "#7d7358"
    readonly property color accent: "#e8b54a"
    readonly property color fgAccent: "#1a1408"
    readonly property color primary: "#e8b54a"
    readonly property color fgPrimary: "#1a1408"
    readonly property color primaryContainer: "#3b2f14"
    readonly property color fgPrimaryContainer: "#f3e3ba"
    readonly property color secondary: "#7fb7c9"
    readonly property color fgSecondary: "#0c1e24"
    readonly property color secondaryContainer: "#16313a"
    readonly property color fgSecondaryContainer: "#cfe8f0"
    readonly property color tertiary: "#e5834a"
    readonly property color fgTertiary: "#1f0e03"
    readonly property color tertiaryContainer: "#40240f"
    readonly property color fgTertiaryContainer: "#ffd9be"
    readonly property color cTertiary: "#e5834a"
    readonly property color error: "#e5604a"
    readonly property color fgError: "#2a0a04"

    // ---- constants the widgets read ----
    readonly property bool isLight: false
    readonly property real blurAmount: 0
    readonly property real radiusXl: 8
    readonly property real uiScale: 1
    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.12
    readonly property string fontFamily: "sans-serif"

    readonly property int durQuick: 120
    readonly property int durShort: 200
    readonly property int durMedium: 400
    readonly property int durFastEffects: 150
    readonly property int durSlowEffects: 800
    readonly property int durFastSpatial: 350
    readonly property int durDefaultSpatial: 500
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var easeStandard: [0.2, 0, 0, 1, 1, 1]

    // The host scales each card as a whole, so a dp is just a pixel here.
    function dp(x) { return x; }
    function rad(x) { return Math.min(x, 12); }
    function withBlur(c) { return c; }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    function toneOf(c) { return c.hslLightness; }
    function atTone(c, t) { return Qt.hsla(c.hslHue, c.hslSaturation, t, c.a); }
}
