import QtQuick
import "."

// Volume ring (default output, wpctl). Wheel = volume, click = mute.
GlyphRingStat {
    id: w
    useWarnCfg: false
    warnAt: 2
    f: GlyphAudioData.muted ? 0 : GlyphAudioData.vol
    value: GlyphAudioData.ok ? String(Math.round(GlyphAudioData.vol * 100)) : "--"
    label: GlyphAudioData.muted ? "muted" : "volume"
    tone: GlyphAudioData.muted ? warnTone : normalTone

    MouseArea {
        anchors.fill: parent
        onClicked: GlyphAudioData.toggleMute()
        onWheel: wheel => {
            const step = Math.max(0.01, (Number(w.cfg.stepPct) || 5) / 100);
            GlyphAudioData.setVol(GlyphAudioData.vol + (wheel.angleDelta.y > 0 ? step : -step));
        }
    }
}
