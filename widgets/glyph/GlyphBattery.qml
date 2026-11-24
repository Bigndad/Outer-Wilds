import QtQuick
import Quickshell.Services.UPower
import "."

// Battery ring (UPower). Red under cfg.lowAt (default 15%) while not charging.
GlyphRingStat {
    readonly property var bat: UPower.displayDevice
    readonly property bool has: !!bat && bat.ready && bat.isLaptopBattery
    readonly property bool charging: has && bat.state === UPowerDeviceState.Charging
    readonly property real lowFrac: (cfg.lowAt !== undefined ? Number(cfg.lowAt) : 15) / 100
    useWarnCfg: false
    warnAt: 2
    f: has ? bat.percentage : 0
    value: has ? String(Math.round(bat.percentage * 100)) : "--"
    label: !has ? "no battery" : charging ? "charging" : "battery"
    tone: has && !charging && bat.percentage < lowFrac ? warnTone : normalTone
}
