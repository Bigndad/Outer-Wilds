# Writing widgets for the Outer Wilds desktop

This file is written so you can paste it into an AI (Gemini, Claude...) and ask: *"make a widget that shows X"*.
Give it this file plus the one thing you want; it should hand back two files.

## 1. A widget is a folder with two files

```
widgets/user/<name>/Main.qml      the widget
widgets/user/<name>/widget.json   its name, default size/orbit, and its options
```

`ow new-widget <name>` creates both with a working example. After adding or editing a `widget.json`, run `ow rescan`
(edits to `Main.qml` need `ow restart`). Then open the settings panel, `+ ADD`, group **Custom**.
Nothing else needs editing: no registry, no qmldir, no catalog.

## 2. Main.qml rules

```qml
import QtQuick
import "../../.."                 // REQUIRED, exactly this path: WidgetCard, WidgetData, Sensors, ...

WidgetCard {
    id: w
    title: "CPU"                  // card title ("" = none)
    designW: 240                  // size in px at ui = 1
    designH: 110
    property var cfg: ({ unit: "%" })      // the options (section 4); defaults here must equal widget.json's

    Text {
        anchors.centerIn: parent
        text: Sensors.cpuPercent + w.cfg.unit
        color: w.cCream
        font.family: "monospace"
        font.pixelSize: Math.max(8, Math.round(28 * w.ui))
    }
}
```

* The root MUST be `WidgetCard`. Put children inside it.
* **Every size is multiplied by `w.ui`** (font sizes, margins, spacing, radii), and font sizes get a floor with `Math.max`.
  Never hard-code pixels: the widget is scaled as the camera moves. `w.ui` is 1.0 at design size.
* Palette: `w.cCream` (text), `w.cGold` (accent), `w.cDim` (secondary text), `w.cBg`. Monospace font by default.
* Do NOT import `Quickshell` in a widget (the scene is also tested in plain `qml`). Data comes from the singletons below.
* Do not run processes or timers faster than 1 s. Use `WidgetData.now` (updates each second) instead of your own clock Timer.
* `w.rig` is the camera rig (rarely needed).

## 3. Data you can read (singletons, available through `import "../../.."`)

| Name | Properties |
|---|---|
| `WidgetData` | `now` (Date, each second), `uptimeSeconds`, `workspaces` ([{id, windows}]), `activeWorkspace`, `notesText`; `formatUptime(sec)`, `switchWorkspace(id)` |
| `Sensors` | `cpuPercent`, `cpuTempC`, `ramPercent`, `ramUsedGb`, `ramTotalGb`, `gpuPercent`, `gpuTempC`, `vramPercent`, `swapUsedGb`, `nvmeTempC`, `disks` ([{mount, totalGb, usedGb}]) |
| `HudData` | `cpu`, `ram`, `battery` (0..1, mapped to GPU load on desktop), `audioActive`, `bandsA` / `bandsB` (audio bands) |

Finished examples to copy from: `widgets/ClockWidget.qml`, `widgets/UptimeWidget.qml`, `widgets/lucid/`, `widgets/serp/`.

## 4. widget.json

```json
{
  "name": "CPU meter",
  "group": "Custom",
  "designW": 240,
  "title": "CPU",
  "default": { "show": "focus", "worldW": 120, "orbit": { "k": 2.0, "add": 40, "speed": 0.2 } },
  "settings": [
    { "key": "unit", "type": "choice", "label": "Unit", "choices": ["%", " pct"], "default": "%" },
    { "key": "warn", "type": "number", "label": "Warn above", "min": 0, "max": 100, "step": 1, "unit": "%", "default": 80 }
  ]
}
```

* `designW` must equal the widget's `designW`. `title` is optional. `default` is optional: `show` is `"focus"` (fades in when the
  planet is near) or `"always"`; `worldW` is the card width in world units; `orbit` is `k` (x host radius), `add`, `tilt`, `node`,
  `phase` (radians), `speed` (rad/s, negative = other way).
* **Settings.** Each one is `{ key, type, label, default }`. The panel draws the control and saves the value; the widget reads it as
  `cfg.<key>`. Types:

| type | control | extra fields | value |
|---|---|---|---|
| `toggle` | switch | | true / false |
| `number` | slider + typed box (typing is never clamped) | `min`, `max`, `step`, `unit` | number |
| `text` | text box | | string |
| `choice` | buttons | `choices`: `["a","b"]` or `[{ "value": 1, "label": "One" }]` | the chosen value |
| `color` | text box + swatch | | `"#RRGGBB"` or `"#AARRGGBB"` |
| `font` | text box | | font family name |
| `file` | text box (path) | | string |

* Keep the `cfg` defaults in `Main.qml` identical to the `default` values here; they only show for the instant before the saved values arrive.
* Saved values live in `widgets.json` under `overrides.<id>.settings`; a value equal to the default is not stored.
* Built-in widgets use the same `settings: [...]` array inside their entry in `WidgetConfig.builtinCatalog`. The **Clock** entry
  plus `widgets/ClockWidget.qml` is a complete example with seven options.

## 5. Checklist before handing a widget back

1. `import "../../.."` is the second line. Root is `WidgetCard`. No `Quickshell` import.
2. Every pixel value uses `w.ui`.
3. `designW` in widget.json equals `designW` in Main.qml.
4. Each setting in widget.json has a matching `cfg.<key>` in Main.qml, with the same default.
5. widget.json is valid JSON (no comments, no trailing commas).
