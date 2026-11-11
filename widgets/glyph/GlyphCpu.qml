import QtQuick
import "../.."
import "."

GlyphRingStat {
    f: Sensors.cpuPercent / 100
    value: String(Sensors.cpuPercent)
    label: "cpu %"
}
