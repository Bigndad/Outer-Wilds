import QtQuick
import ".."

// Outer Wilds styled panel. Every built-in widget is a WidgetCard.
// `ui` is the size multiplier the slot sets (quantised), so text stays crisp at any zoom.
Item {
    id: card

    property real ui: 1.0
    property var rig: null              // the CameraRig (set by the slot)
    property string title: ""
    property real designW: 280          // size in px at ui = 1
    property real designH: 140
    default property alias content: body.data

    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property color cDim: "#8A7F66"
    readonly property color cBg: "#E007080C"
    property var cardStyle: ({})        // per-widget overrides pushed by WidgetSlot
    readonly property string effTitle: (cardStyle && cardStyle.title) ? cardStyle.title : title
    readonly property bool effBrackets: (cardStyle && cardStyle.brackets !== undefined) ? cardStyle.brackets : WidgetConfig.widgetBrackets
    property color accent: (cardStyle && cardStyle.accent) ? cardStyle.accent : WidgetConfig.widgetAccent

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)

    Rectangle {
        anchors.fill: parent
        radius: ((card.cardStyle && card.cardStyle.radius >= 0) ? card.cardStyle.radius : WidgetConfig.widgetRadius) * card.ui
        color: (card.cardStyle && card.cardStyle.bg) ? card.cardStyle.bg : card.cBg
        border.color: (card.cardStyle && card.cardStyle.border) ? card.cardStyle.border : "#55D4AF37"
        border.width: Math.max(1, Math.round(card.ui))
    }

    component Bracket: Item {
        visible: card.effBrackets
        property bool atRight: false
        property bool atBottom: false
        width: 11 * card.ui
        height: 11 * card.ui
        x: atRight ? card.width - width : 0
        y: atBottom ? card.height - height : 0
        Rectangle {
            width: parent.width
            height: Math.max(1, Math.round(card.ui * 1.5))
            y: atBottom ? parent.height - height : 0
            color: card.accent
        }
        Rectangle {
            height: parent.height
            width: Math.max(1, Math.round(card.ui * 1.5))
            x: atRight ? parent.width - width : 0
            color: card.accent
        }
    }
    Bracket { }
    Bracket { atRight: true }
    Bracket { atBottom: true }
    Bracket { atRight: true; atBottom: true }

    Text {
        visible: card.effTitle !== ""
        x: 14 * card.ui
        y: 9 * card.ui
        text: card.effTitle
        color: card.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(8, Math.round(11 * card.ui))
        font.letterSpacing: 2 * card.ui
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 12 * card.ui
        anchors.topMargin: card.effTitle !== "" ? 30 * card.ui : 12 * card.ui
    }
}
