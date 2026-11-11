import QtQuick
import "../.."
import "."

// Glyph Matrix: the audio spectrum on a round 15x15 dot grid (like the back of a Nothing Phone).
// Bass in the middle column, treble at the edges, columns grow up and down from the middle row.
// Silence = all dots unlit. The centre dot is the one red thing while audio is playing.
// Reads HudData's 8 bands (bandsA/bandsB), so it follows whatever feeds HudData (cava, mock...).
GlyphCard {
    id: w
    designW: 220
    designH: 220
    round: true

    readonly property real pitch: 12
    readonly property real dotD: 9
    readonly property var bands: [HudData.bandsA.x, HudData.bandsA.y, HudData.bandsA.z, HudData.bandsA.w,
                                  HudData.bandsB.x, HudData.bandsB.y, HudData.bandsB.z, HudData.bandsB.w]

    Item {
        x: (w.designW - 15 * w.pitch) / 2
        y: (w.designH - 15 * w.pitch) / 2
        width: 15 * w.pitch
        height: 15 * w.pitch

        Repeater {
            model: 15
            Item {
                id: col
                required property int index
                readonly property int cx: index - 7
                readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx))   // half height inside the circle
                readonly property real v: w.bands[Math.abs(cx)] ?? 0
                readonly property int lit: Math.round(Math.max(0, Math.min(1, v)) * (half + 1))
                x: index * w.pitch
                width: w.pitch
                height: 15 * w.pitch

                Repeater {
                    model: 15
                    Rectangle {
                        required property int index
                        readonly property int cy: index - 7
                        readonly property bool inside: Math.abs(cy) <= col.half
                        readonly property bool isOn: inside && Math.abs(cy) < col.lit
                        readonly property bool heart: col.cx === 0 && cy === 0
                        visible: inside
                        width: w.dotD
                        height: w.dotD
                        radius: w.dotD / 2
                        x: (w.pitch - w.dotD) / 2
                        y: index * w.pitch + (w.pitch - w.dotD) / 2
                        color: heart && HudData.audioActive ? GlyphTheme.red : isOn ? GlyphTheme.fg : GlyphTheme.s3
                    }
                }
            }
        }
    }
}
