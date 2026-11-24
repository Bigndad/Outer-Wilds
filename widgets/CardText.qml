import QtQuick

// A Text that never spills out of its card. Give it `ui` (the card's size multiplier) and `px` (the size in px at ui = 1);
// with `maxW` set it shrinks to fit that width (down to `minShrink` of its size) and then elides with "...".
// Without `maxW` it is a plain one-line label. Colour defaults to the card's cream; pass `color:` for others.
//
//   CardText { ui: w.ui; px: 14; bold: true; maxW: w.innerW; text: "..." }
Text {
    id: t

    property real ui: 1.0
    property real px: 12
    property real maxW: 0            // 0 = no width limit
    property real minShrink: 0.6
    property bool bold: false
    property real tracking: 0        // letter spacing at ui = 1

    readonly property real wantPx: Math.max(7, Math.round(px * ui))

    color: "#E6D5B8"
    font.family: "monospace"
    font.pixelSize: wantPx
    font.bold: bold
    font.letterSpacing: tracking * ui
    maximumLineCount: 1
    wrapMode: Text.NoWrap
    elide: Text.ElideRight
    fontSizeMode: maxW > 0 ? Text.HorizontalFit : Text.FixedSize
    minimumPixelSize: Math.max(6, Math.round(wantPx * minShrink))
    width: maxW > 0 ? maxW : implicitWidth
}
