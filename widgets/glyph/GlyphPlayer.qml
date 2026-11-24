import QtQuick
import "../.."
import "."

// Now playing, from SignalscopeData.
GlyphCard {
    id: w
    designW: 340
    designH: 160

    readonly property var chans: SignalscopeData.channels
    readonly property var ch: {
        for (let i = 0; i < chans.length; i++) if (chans[i].playing) return chans[i];
        return SignalscopeData.channelById(SignalscopeData.lastId) || (chans.length > 0 ? chans[0] : null);
    }
    readonly property bool playing: !!ch && ch.playing
    readonly property color accCol: (cfg.accentColor && cfg.accentColor !== "") ? cfg.accentColor : GlyphTheme.red

    function act(cmd) {
        if (!ch) return;
        const b = SignalscopeData.backend;
        if (cmd === "pp") { if (b) b.togglePlay(ch.id); else SignalscopeData._patch(ch.id, { playing: !ch.playing }); }
        else if (cmd === "next" && b) b.next(ch.id);
        else if (cmd === "prev" && b) b.previous(ch.id);
    }

    Item {
        id: disc
        x: 22; y: 22; width: 116; height: 116
        property real turn: 0
        Timer {
            running: w.playing && w.cfg.spinDisc !== false
            interval: 50; repeat: true
            onTriggered: disc.turn = (disc.turn + (Number(w.cfg.spinSpeed) || 3)) % 360
        }
        GlyphRing { anchors.fill: parent; n: 36; dot: 6; f: 1; on: GlyphTheme.mute; rotation: disc.turn }
        GlyphRing { anchors.fill: parent; anchors.margins: 18; n: 24; dot: 5; f: 1; on: w.playing ? GlyphTheme.fg : GlyphTheme.mute; rotation: -disc.turn }
        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: w.playing ? w.accCol : GlyphTheme.s3 }
    }
    Column {
        x: 160; y: 26; width: w.designW - 160 - 20
        spacing: 4
        GlyphLabel { width: parent.width; elide: Text.ElideRight; text: w.ch ? w.ch.name : "silence" }
        Text {
            width: parent.width; elide: Text.ElideRight
            topPadding: 6
            text: w.ch && w.ch.title !== "" ? w.ch.title : "nothing on"
            color: GlyphTheme.fg; font.pixelSize: 19; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: w.ch ? w.ch.artist : ""
            color: GlyphTheme.grey; font.pixelSize: 13
        }
    }
    Row {
        visible: w.cfg.showControls !== false
        x: 160; y: 108
        spacing: 22
        Repeater {
            model: [{ t: "\u2039\u2039", c: "prev" }, { t: w.playing ? "II" : "\u25B6", c: "pp" }, { t: "\u203A\u203A", c: "next" }]
            Text {
                required property var modelData
                width: 34; height: 30
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: modelData.t
                color: modelData.c === "pp" ? GlyphTheme.fg : GlyphTheme.grey
                font.pixelSize: modelData.c === "pp" ? 18 : 22
                font.family: GlyphTheme.mono
                MouseArea { anchors.fill: parent; onClicked: w.act(parent.modelData.c) }
            }
        }
    }
}
