import QtQuick
import "."

// Volume ring (default output, wpctl). Wheel = volume, click = mute (the ring turns red while muted).
GlyphRingStat {
    id: w
    warnAt: 2
    f: GlyphAudioData.muted ? 0 : GlyphAudioData.vol
    value: GlyphAudioData.ok ? String(Math.round(GlyphAudioData.vol * 100)) : "--"
    label: GlyphAudioData.muted ? "muted" : "volume"
    tone: GlyphAudioData.muted ? GlyphTheme.red : GlyphTheme.fg

    MouseArea {
        anchors.fill: parent
        onClicked: GlyphAudioData.toggleMute()
        onWheel: wheel => GlyphAudioData.setVol(GlyphAudioData.vol + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
