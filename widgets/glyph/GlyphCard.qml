import QtQuick
import "."

// Same contract as WidgetCard / SerpCard: designW x designH at ui = 1, `ui` and `rig` set by the slot.
// Everything inside is laid out in plain design pixels; the stage is scaled by ui (vector shapes stay crisp).
Item {
    id: card

    property real ui: 1.0
    property var rig: null
    property string title: ""
    property real designW: 220
    property real designH: 220
    property bool round: false
    readonly property bool wantsHold: false
    property var cardStyle: ({})
    property var cfg: ({ bgOpacity: 1.0, borderWidth: 1, contentScale: 1.0, showBrackets: false })
    default property alias content: inner.data

    readonly property color effAccent: (cardStyle && cardStyle.accent) ? cardStyle.accent : ((cardStyle && cardStyle.globalAccent) ? cardStyle.globalAccent : "#D4AF37")
    readonly property bool effBrackets: cfg.showBrackets === true && (!cardStyle || cardStyle.brackets !== false)

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
            radius: (card.cardStyle && card.cardStyle.radius >= 0) ? card.cardStyle.radius : (card.round ? Math.min(width, height) / 2 : 28)
            color: (card.cardStyle && card.cardStyle.bg) ? card.cardStyle.bg : GlyphTheme.s1
            opacity: card.cfg.bgOpacity !== undefined ? card.cfg.bgOpacity : 1.0
            border.width: card.cfg.borderWidth !== undefined ? card.cfg.borderWidth : 1
            border.color: (card.cardStyle && card.cardStyle.border) ? card.cardStyle.border : GlyphTheme.s2
        }

        Item {
            id: inner
            anchors.fill: parent
            scale: card.cfg.contentScale !== undefined ? card.cfg.contentScale : 1.0
            transformOrigin: Item.Center
        }
    }

    component Bracket: Item {
        property bool atRight: false
        property bool atBottom: false
        visible: card.effBrackets
        width: 11 * card.ui
        height: 11 * card.ui
        x: atRight ? card.width - width : 0
        y: atBottom ? card.height - height : 0
        Rectangle { width: parent.width; height: Math.max(1, Math.round(card.ui * 1.5)); y: atBottom ? parent.height - height : 0; color: card.effAccent }
        Rectangle { height: parent.height; width: Math.max(1, Math.round(card.ui * 1.5)); x: atRight ? parent.width - width : 0; color: card.effAccent }
    }
    Bracket { }
    Bracket { atRight: true }
    Bracket { atBottom: true }
    Bracket { atRight: true; atBottom: true }
}
