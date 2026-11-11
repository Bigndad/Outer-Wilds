import QtQuick
import "."

// Same contract as WidgetCard / SerpCard: designW x designH at ui = 1, `ui` and `rig` set by the slot.
// Everything inside is laid out in plain design pixels; the stage is scaled by ui (vector shapes stay crisp).
Item {
    id: card

    property real ui: 1.0
    property var rig: null
    property string title: ""            // accepted from the slot, deliberately not drawn (cards label themselves)
    property real designW: 220
    property real designH: 220
    property bool round: false
    readonly property bool wantsHold: false
    default property alias content: stage.data

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)

    Item {
        id: stage
        width: card.designW
        height: card.designH
        scale: card.ui
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            radius: card.round ? Math.min(width, height) / 2 : 28
            color: GlyphTheme.s1
            border.width: 1
            border.color: GlyphTheme.s2
        }
    }
}
