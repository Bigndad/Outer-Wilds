import QtQuick
import "../.."
import "."

GlyphRingStat {
    f: Sensors.gpuPercent / 100
    value: String(Sensors.gpuPercent)
    label: "gpu %"
}
