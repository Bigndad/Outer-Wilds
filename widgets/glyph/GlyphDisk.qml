import QtQuick
import "../.."
import "."

// Disk ring: selects mount from Sensors.disks by cfg.diskIndex (default 0).
GlyphRingStat {
    readonly property int idx: Math.max(0, Math.min(Math.max(0, Sensors.disks.length - 1), Math.round(cfg.diskIndex || 0)))
    readonly property var d: Sensors.disks.length > 0 ? Sensors.disks[idx] : null
    warnAt: 0.9
    f: d && d.totalGb > 0 ? d.usedGb / d.totalGb : 0
    value: d ? String(Math.round(f * 100)) : "--"
    label: d ? "disk " + d.mount : "disk"
}
