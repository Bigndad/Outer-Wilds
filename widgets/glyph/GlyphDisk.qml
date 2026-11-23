import QtQuick
import "../.."
import "."

// Disk ring: the first mount from Sensors.disks (usually /). Red at 90%.
GlyphRingStat {
    readonly property var d: Sensors.disks.length > 0 ? Sensors.disks[0] : null
    warnAt: 0.9
    f: d && d.totalGb > 0 ? d.usedGb / d.totalGb : 0
    value: d ? String(Math.round(f * 100)) : "--"
    label: d ? "disk " + d.mount : "disk"
}
