import QtQuick
import Quickshell.Services.UPower
import "."

// Battery ring (UPower). Red under 15% while not charging. A desktop PC has no battery: shows "--".
GlyphRingStat {
    readonly property var bat: UPower.displayDevice
    readonly property bool has: !!bat && bat.ready && bat.isLaptopBattery
    readonly property bool charging: has && bat.state === UPowerDeviceState.Charging
    warnAt: 2                                  // never "full = red"; low is handled below
    f: has ? bat.percentage : 0
    value: has ? String(Math.round(bat.percentage * 100)) : "--"
    label: !has ? "no battery" : charging ? "charging" : "battery"
    tone: has && !charging && bat.percentage < 0.15 ? GlyphTheme.red : GlyphTheme.fg
}
