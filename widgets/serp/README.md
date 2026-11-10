# Serpantinum faces on the Outer Wilds orbit layer

## Install
1. Copy this `serp/` folder into `widgets/` (next to `WidgetSlot.qml`). It has its own `qmldir`, so no root registry edit is needed.
2. Replace `widgets/WidgetLayer.qml` with the one provided (or apply the six def changes by hand, below).
3. Needs the Mesa/GL stack you already run; shaders are the prebuilt `.qsb` files from Serpantinum (in `assets/shaders`).

## Defs changed in WidgetLayer.qml
| id | planet | source |
|---|---|---|
| sun_dial (new) | Sun | serp/SunClock.qml (Lumen dial clock) |
| gd_a | Giant's Deep | serp/GiantsDeepWeather.qml (full weather card) |
| et_a | Ember Twin | serp/EmberTwinBattery.qml (wavy ring) |
| at_a | Ash Twin | serp/AshTwinBattery.qml (fluid-fill bar) |
| db_a | Dark Bramble | serp/DarkBrambleVisualiser.qml (continuous wave) |

No calendar: Serpantinum has no desktop calendar widget (its calendar is a 1,000-line popup).

## Changing things
- Other faces: edit the wrapper's `face:` line. Included: ClockFaceMaterialLumen / MaterialAnalog / Analog, WeatherFaceRound / Full,
  BatteryFace / BatteryFaceCircle, VisualizerFace (bars) / VisualizerFaceContinuous.
- Face options: `faceProps: ({ sineWave: false })` in the wrapper. Size: `designW` / `designH`.
- Colours: `shim/ThemeBackend.qml` (Outer Wilds palette in Serpantinum's token names; `mauve` is the main accent).

## Mock data and where it goes real
- shim/Weather.qml (fixed Mumbai sample), shim/Cava.qml (fake spectrum), shim/UPower.qml (fake laptop battery 72%), shim/DateTime.qml and Location.qml.
- Real battery: delete the three `UPower*` lines from `shim/qmldir` and add `import Quickshell.Services.UPower` to the two battery faces.
  A desktop PC has no battery, so the real faces will show "--".

## Known limits
- Serpantinum blurs the wallpaper behind its cards; `WallpaperBlur` is a no-op here.
- Weather icons are Nerd Font glyphs; the font is bundled and loaded by ThemeBackend.
- `python3 port.py /path/to/serpantinum` rebuilds faces/ and shim copies from a fresh checkout.
