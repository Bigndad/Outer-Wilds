# Lucid widgets on the Outer Wilds orbit layer

## Install
1. Copy this whole `lucid/` folder next to `WidgetSlot.qml` (so a def can say `source: "lucid/SunClock.qml"`).
2. Add the defs below to your widget list (WidgetData / wherever your defs live).
3. Reload: `qs -c outerwilds`. Mint test: your usual `qml --rhi opengl ...` works, nothing here imports Quickshell.

## Defs (orbit numbers are placeholders: copy `orbit` and `worldWk` from an existing def on the same planet)
```js
{ id: "sun-clock",        host: "sun",         source: "lucid/SunClock.qml",             orbit: { speed: 0.20, k: 1.9, add: 0, tilt: 0.15, node: 0 }, worldWk: 1.0 },
{ id: "brittle-cal",    host: "attlerock",   source: "lucid/BrittleHollowCalendar.qml",    orbit: { speed: 0.35, k: 2.4, add: 0, tilt: 0.5,  node: 1 }, worldWk: 3.0 },
{ id: "giants-weather",   host: "giants_deep", source: "lucid/GiantsDeepWeather.qml",    orbit: { speed: 0.25, k: 1.8, add: 0, tilt: 0.3,  node: 2 }, worldWk: 1.4 },
{ id: "ember-battery",    host: "ember_twin",  source: "lucid/EmberTwinBattery.qml",     orbit: { speed: 0.40, k: 2.2, add: 0, tilt: 0.4,  node: 3 }, worldWk: 1.6 },
{ id: "ash-devices",      host: "ash_twin",    source: "lucid/AshTwinBattery.qml",       orbit: { speed: 0.30, k: 2.3, add: 0, tilt: -0.4, node: 4 }, worldWk: 2.0 },
{ id: "bramble-visual",   host: "dark_bramble",source: "lucid/DarkBrambleVisualiser.qml",orbit: { speed: 0.22, k: 1.7, add: 0, tilt: 0.2,  node: 5 }, worldWk: 1.6 },
```
Only `dark_bramble` is a host id I have seen confirmed; check the others against `rig.bodyCoords` keys.

## Changing things
- Different variant: edit the wrapper file (`wvariant:`). Real ones: clock dial/digital/stack/analog/shape/oval/minimal/world/poster;
  calendar week/month/agenda/today; weather current/forecast/detail; battery ring/bar/detail/devices; visualiser bars/mirror/wave.
- Size: `designW` / `designH` in the wrapper (pixels at ui = 1).
- Colours: the first block of `shim/Theme.qml`.
- Options (seconds, 24h, density...): the `options:` object in the wrapper.

## Mock data, and where to make it real
- `shim/WeatherSource.qml` (fixed Mumbai sample), `shim/Agenda.qml` (sample events), `shim/Cava.qml` (fake spectrum),
  `shim/UPower.qml` (fake battery + phone/headset/mouse).
- Real battery: delete the three `UPower*` lines from `shim/qmldir`, then add `import Quickshell.Services.UPower` to `BatteryWidget.qml`.
  A desktop PC has no battery, so only peripherals would show.

## Known limits
- Shapes are drawn with plain QML (scalloped discs), not Lucid's exact Material shapes. Icons use Material Symbols if installed, otherwise a unicode stand-in.
- No day-picking in the month view; LinearProgress ignores the wavy options; world-clock zones use fixed offsets (no DST).
- Option changes made at runtime are not saved.
- Planet-specific themes are not done: all cards share `Theme.qml` for now.
