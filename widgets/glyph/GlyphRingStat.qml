import QtQuick
import "."

// Round LED-ring gauge: ring lit by f, dot-matrix number in the middle, caption under it.
GlyphCard {
    id: w
    designW: 200
    designH: 200
    round: true

    property real f: 0
    property string value: "0"
    property string label: ""
    property real warnAt: 0.85
    property bool useWarnCfg: true
    readonly property real effWarnAt: (useWarnCfg && cfg.warnAt !== undefined) ? (Number(cfg.warnAt) / 100) : warnAt
    readonly property color normalTone: (cfg.ringColor && cfg.ringColor !== "") ? cfg.ringColor : GlyphTheme.fg
    readonly property color warnTone: (cfg.warnColor && cfg.warnColor !== "") ? cfg.warnColor : GlyphTheme.red
    property color tone: f >= effWarnAt ? warnTone : normalTone

    GlyphRing {
        anchors.fill: parent
        anchors.margins: 12
        n: Math.max(8, Math.round(w.cfg.ringDots || 44))
        dot: w.cfg.dotSize || 7
        f: w.f
        on: w.tone
    }
    Column {
        anchors.centerIn: parent
        spacing: 12
        GlyphDots {
            anchors.horizontalCenter: parent.horizontalCenter
            text: w.value
            cell: w.value.length >= 3 ? 6 : 8
            on: w.tone
        }
        GlyphLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (w.cfg.customLabel && w.cfg.customLabel !== "") ? w.cfg.customLabel : w.label
        }
    }
}
