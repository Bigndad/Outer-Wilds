# File map

Repo root = the config folder `~/.config/quickshell/outerwilds` (the repo *is* that folder).

## Root

| File | Purpose |
|---|---|
| `shell.qml` | entry point. Creates the data/IO scopes, the panel windows and one scene window per screen |
| `qmldir` | **the registry**: every type used by name from another file must be listed here (see the rule below) |
| `widgets.json` | your saved widget/key/UI settings (only differences from the defaults) |
| `WIDGETS.md` | how to write a widget (AI-friendly) |
| `.gitignore` | keeps backups, `__pycache__` and `widgets-backups/` out of git; old backups live outside the repo in `~/outerwilds-backups/` |
| `bin/ow` | helper command: `start stop restart status log doctor rescan new-widget` |

## The registry rule (the one that bites)

On this Qt, a QML file in the same folder is **not** found by name unless it is listed in the root `qmldir`:

```
Name 1.0 folder/Name.qml
singleton Name 1.0 folder/Name.qml
```

Files in subfolders start with `import ".."` (or `"../.."`, `"../../.."` for deeper ones) to see the registry.
Files loaded **by path** through a `Loader { source: ... }` (all widgets) need no entry. Missing entry = "X is not a type".

## Folders

| Folder | Contents |
|---|---|
| `core/` | `CameraRig.qml` (3D engine, input, bodies, loop, `flyTo`), `KeyHost.qml` (key table → shortcuts), `HyprIpc.qml` (IPC for Hyprland binds) |
| `planets/` | `PlanetShader.qml`: one planet = baked texture + live sphere shader + name label |
| `shaders/` | `bake.frag` (procedural surface maps), `planet.frag` (sphere shading), `sandcolumn.frag`, `hud_globe.frag`, `hud_sprite.frag`, compiled `*.qsb`, `build.sh`. `vignette.frag.qsb` has no `.frag` source |
| `data/` | all shared state and IO (below) |
| `widgets/` | the widget system and built-in widgets (below) |
| `settings/` | `SettingsPanel.qml` (Control Centre UI), `SettingsWindow.qml` |
| `map/` | `MapView`, `MapHost`, `MapNode`, `MapButton`, `MapReturnChip` (Map View) |
| `rumor/` | `RumorMap`, `RumorMapView` (notification graph) |
| `signalscope/` | `Signalscope.qml` overlay |
| `hud/` | `SatelliteHUD.qml` and `hud_assets/` (real game HUD PNGs) |
| `launcher/` | `AppLauncher` (ilyamiro's 3D app sphere, patched), `LauncherWindow`, `Scaler`, `MatugenColors` (stand-ins for his helpers) |
| `dev/` | `main.qml`, `test_mint.qml`, Quickshell stubs for testing on a machine without Quickshell |

## `data/`

| File | Kind | What |
|---|---|---|
| `WidgetConfig.qml` | logic singleton | catalog, defaults registry, overrides, extras, option values (`cfg`), all edit functions |
| `WidgetConfigStore.qml` | IO scope | reads/writes `widgets.json`; scans `widgets/user/*/widget.json`; IPC `widgets rescan` |
| `WidgetData.qml` | logic singleton | `now`, uptime, workspaces, notes text, world zones, formatting helpers |
| `Keybinds.qml` | logic singleton | the single table of every key action (ids, defaults, contexts) |
| `HudData.qml` | singleton | CPU / RAM / boost arcs and audio bands for the HUD |
| `MapData.qml` | logic singleton | Map View state, planet catalog, per-feature providers |
| `RumorData.qml` | logic singleton | notification history, links, pins, filters |
| `SignalscopeData.qml` | logic singleton | scope state, channels, key names, `dispatch(cmd)` |
| `SignalscopeMpris.qml` | IO scope | MPRIS players → channels; IPC `signalscope ...` |
| `Sensors.qml` | singleton | one poller: CPU, RAM, swap, GPU, VRAM, temps, disks |
| `SystemLive.qml` | IO scope | apps (DesktopEntries), workspaces/windows (`hyprctl`), uptime |
| `SystemExtras.qml` | IO scope | switches the mocks off: HUD, sensors, notifications (D-Bus), notes, cava; IPC `system status` |
| `NoctaliaBridge.qml` | singleton | observes Hyprland + Noctalia; scene visibility; fly-to requests; IPC `bridge fly` |

## `widgets/`

| Item | What |
|---|---|
| `WidgetLayer.qml` | **the default table** `baseDefs` (id, host planet, source, size, orbit) and the slot repeater |
| `WidgetSlot.qml` | one live widget: orbit maths, fade, occlusion, sizing from camera distance, `Loader`, `cfg` push |
| `WidgetCard.qml` | base type of every widget: card frame, brackets, title, `ui` scale, palette |
| `*Widget.qml`, `ScreentimeCard`, `WallpaperCard` | built-in Outer Wilds widgets (clock, loop, uptime, date/world, workspaces, notes, rumor, map, launcher, signalscope, weather, blank) |
| `lucid/` | widgets ported from Lucid (clock, calendar, weather, battery, visualiser) with a `shim/` of the Noctalia pieces they expect |
| `serp/` | widgets ported from Serpantinum/Anserin: `SerpCard`, `faces/`, `shim/`, `panels/` (big wallpaper, screentime, network, process windows), `port*.py` re-port scripts |
| `glyph/` | Nothing-style dot-matrix widgets written for this project |
| `user/<name>/` | **your drop-in widgets**: `Main.qml` + `widget.json` (see `WIDGETS.md`) |
| `NoctaliaPlugin.qml` | host for old v4 QML plugins; **not useful for Noctalia v5** |

## Where to change what

| I want to... | Edit |
|---|---|
| add a widget | a new folder in `widgets/user/` (`ow new-widget <name>`); nothing else |
| change a built-in widget's default planet/orbit | its entry in `WidgetLayer.baseDefs` (or use the Control Centre) |
| give a built-in widget options | `settings: [...]` in its `WidgetConfig.builtinCatalog` entry + `cfg.<key>` in the widget |
| change a planet's look | `shaders/bake.frag` / `planet.frag`, then `shaders/build.sh` ([rendering.md](rendering.md)) |
| change a planet's role label | `bodyMeta` in `core/CameraRig.qml` |
| add/rename a key | `data/Keybinds.qml` (`actions`), then handle it in `core/KeyHost.qml` |
| map a Noctalia panel to a planet | `panelPlanets` in `data/NoctaliaBridge.qml` |
| add a new type used by name | a line in the root `qmldir` |
