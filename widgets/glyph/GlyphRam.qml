import QtQuick
import "../.."
import "."

GlyphRingStat {
    f: Sensors.ramPercent / 100
    value: String(Sensors.ramPercent)
    label: "ram %"
}
