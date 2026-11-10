import QtQuick
import "shim"

// Hosts one ported Lucid widget inside an orbit slot. Same contract as WidgetCard:
// designW/designH are pixels at ui = 1, the slot sets `ui` and `rig`.
// The Lucid body is laid out at design size and the whole thing is scaled by ui.
Item {
    id: card

    property real ui: 1.0
    property var rig: null
    property string title: ""
    property real designW: 280
    property real designH: 140
    readonly property bool wantsHold: false

    // what to load
    property string wtype: "clock"          // clock | calendar | weather | battery | visualiser
    property string wvariant: ""
    property var options: ({})              // overrides on top of Widgets.defaults(wtype)

    // ---- the host contract Lucid's WidgetBody reads ----
    readonly property string uid: "ow-" + card.wtype + "-" + card.wvariant + "-" + card.objectName
    readonly property bool hovered: hover.hovered
    readonly property bool preview: false
    readonly property bool born: false
    readonly property bool resizing: false
    readonly property bool onThisScreen: true
    readonly property real bodyRadius: 8
    readonly property real zoom: 1
    readonly property var board: null
    property var localOpts: ({})

    function opt(key) {
        if (card.localOpts[key] !== undefined) return card.localOpts[key];
        if (card.options[key] !== undefined) return card.options[key];
        return Widgets.defaults(card.wtype)[key];
    }
    function setOpt(key, value) {
        var o = Object.assign({}, card.localOpts);
        o[key] = value;
        card.localOpts = o;     // session only, not persisted
    }
    function setOpts(changes) {
        card.localOpts = Object.assign({}, card.localOpts, changes);
    }

    readonly property var sources: ({
        "clock": "ClockWidget.qml", "calendar": "CalendarWidget.qml", "weather": "WeatherWidget.qml",
        "battery": "BatteryWidget.qml", "visualiser": "VisualiserWidget.qml"
    })
    readonly property var body: loader.item
    readonly property bool bare: body ? body.bare : false
    readonly property bool gone: body ? body.hidden : false

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)
    visible: !gone
    opacity: gone ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 250 } }

    HoverHandler { id: hover }

    // Outer Wilds panel, skipped for bare variants that draw straight on the scene
    Rectangle {
        visible: !card.bare
        anchors.fill: parent
        radius: 6 * card.ui
        color: card.body ? card.body.fill : Theme.bg
        border.color: "#55D4AF37"
        border.width: Math.max(1, Math.round(card.ui))
    }
    component Bracket: Item {
        property bool atRight: false
        property bool atBottom: false
        visible: !card.bare
        width: 11 * card.ui
        height: 11 * card.ui
        x: atRight ? card.width - width : 0
        y: atBottom ? card.height - height : 0
        Rectangle {
            width: parent.width
            height: Math.max(1, Math.round(card.ui * 1.5))
            y: atBottom ? parent.height - height : 0
            color: "#D4AF37"
        }
        Rectangle {
            height: parent.height
            width: Math.max(1, Math.round(card.ui * 1.5))
            x: atRight ? parent.width - width : 0
            color: "#D4AF37"
        }
    }
    Bracket { }
    Bracket { atRight: true }
    Bracket { atBottom: true }
    Bracket { atRight: true; atBottom: true }

    Item {
        id: stage
        width: card.designW
        height: card.designH
        scale: card.ui
        transformOrigin: Item.TopLeft
        clip: !card.bare

        Loader {
            id: loader
            anchors.fill: parent
            source: card.sources[card.wtype] || ""
            onLoaded: item.host = card
        }
    }
}
