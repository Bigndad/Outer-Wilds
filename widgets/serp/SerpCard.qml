import QtQuick
import "shim"

// Hosts one Serpantinum / Anserin face in an orbit slot. Same contract as WidgetCard
// (designW/designH at ui = 1, `ui` and `rig` set by the slot).
Item {
    id: card
    property real ui: 1.0
    property var rig: null
    property string title: ""
    property real designW: 220
    property real designH: 120
    readonly property bool wantsHold: false
    property var cardStyle: ({})
    property var cfg: ({ frameMode: "auto", bracketMode: "auto", borderWidth: 1, framePad: 0, contentScale: 1.0 })

    property string face: ""            // path relative to this file
    property var faceProps: ({})        // set on the face once loaded (e.g. { sineWave: false })
    property bool brackets: false       // gold corner brackets, for faces that draw their own card
    readonly property bool isRound: loader.item ? (loader.item.isRound === true) : false

    function applyCfgToFace() {
        const it = loader.item;
        if (!it || !card.cfg) return;
        if (it.cfg !== undefined) it.cfg = card.cfg;
        const skip = { frameMode: 1, bracketMode: 1, borderWidth: 1, framePad: 1, contentScale: 1 };
        for (const k in card.cfg) {
            if (skip[k]) continue;
            const v = card.cfg[k];
            if (k === "sineWaveMode") {
                if (it.sineWave !== undefined)
                    it.sineWave = (v === "on") ? true : (v === "off" ? false : (card.faceProps.sineWave !== undefined ? card.faceProps.sineWave : true));
                continue;
            }
            if (k === "continuousMode") {
                if (it.continuous !== undefined)
                    it.continuous = (v === "on") ? true : (v === "off" ? false : (card.faceProps.continuous !== undefined ? card.faceProps.continuous : false));
                continue;
            }
            if (it[k] !== undefined) it[k] = v;
        }
    }
    onCfgChanged: applyCfgToFace()

    readonly property bool hasCustomFrame: !!(cardStyle && ((cardStyle.bg && cardStyle.bg !== "") || (cardStyle.border && cardStyle.border !== "")))
    readonly property bool showFrame: cfg.frameMode === "card" ? true : (cfg.frameMode === "none" ? false : hasCustomFrame)
    readonly property bool showBrackets: cfg.bracketMode === "on" ? true : (cfg.bracketMode === "off" ? false : (card.brackets && (!cardStyle || cardStyle.brackets !== false)))
    readonly property color effAccent: (cardStyle && cardStyle.accent) ? cardStyle.accent : ((cardStyle && cardStyle.globalAccent) ? cardStyle.globalAccent : "#D4AF37")
    readonly property real effRadius: (cardStyle && cardStyle.radius >= 0) ? cardStyle.radius : ((cardStyle && cardStyle.globalRadius !== undefined) ? cardStyle.globalRadius : 6)

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)

    Rectangle {
        visible: card.showFrame
        anchors.fill: parent
        z: -1
        radius: card.effRadius * card.ui
        color: (card.cardStyle && card.cardStyle.bg) ? card.cardStyle.bg : "#E007080C"
        border.color: (card.cardStyle && card.cardStyle.border) ? card.cardStyle.border : "#55D4AF37"
        border.width: Math.max(0, Math.round((card.cfg.borderWidth !== undefined ? card.cfg.borderWidth : 1) * card.ui))
    }

    Item {
        id: stage
        width: card.designW
        height: card.designH
        scale: card.ui
        transformOrigin: Item.TopLeft
        Loader {
            id: loader
            anchors.fill: parent
            anchors.margins: card.cfg.framePad || 0
            scale: card.cfg.contentScale !== undefined ? card.cfg.contentScale : 1.0
            transformOrigin: Item.Center
            source: card.face
            onLoaded: {
                for (var k in card.faceProps)
                    if (item[k] !== undefined) item[k] = card.faceProps[k];
                card.applyCfgToFace();
            }
        }
    }

    component Bracket: Item {
        property bool atRight: false
        property bool atBottom: false
        visible: card.showBrackets
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
