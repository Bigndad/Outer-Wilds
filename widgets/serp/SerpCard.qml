import QtQuick
import "shim"

// Hosts one Serpantinum face in an orbit slot. Same contract as WidgetCard
// (designW/designH at ui = 1, `ui` and `rig` set by the slot); the face is laid
// out at design size and the whole card is scaled by ui.
Item {
    id: card
    property real ui: 1.0
    property var rig: null
    property string title: ""
    property real designW: 220
    property real designH: 120
    readonly property bool wantsHold: false

    property string face: ""            // path relative to this file
    property var faceProps: ({})        // set on the face once loaded (e.g. { sineWave: false })
    property bool brackets: false       // gold corner brackets, for faces that draw their own card

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)

    Item {
        id: stage
        width: card.designW
        height: card.designH
        scale: card.ui
        transformOrigin: Item.TopLeft
        Loader {
            id: loader
            anchors.fill: parent
            source: card.face
            onLoaded: {
                for (var k in card.faceProps)
                    if (item[k] !== undefined) item[k] = card.faceProps[k];
            }
        }
    }

    component Bracket: Item {
        property bool atRight: false
        property bool atBottom: false
        visible: card.brackets
        width: 11 * card.ui
        height: 11 * card.ui
        x: atRight ? card.width - width : 0
        y: atBottom ? card.height - height : 0
        Rectangle { width: parent.width; height: Math.max(1, Math.round(card.ui * 1.5)); y: atBottom ? parent.height - height : 0; color: "#D4AF37" }
        Rectangle { height: parent.height; width: Math.max(1, Math.round(card.ui * 1.5)); x: atRight ? parent.width - width : 0; color: "#D4AF37" }
    }
    Bracket { }
    Bracket { atRight: true }
    Bracket { atBottom: true }
    Bracket { atRight: true; atBottom: true }
}
