# Architecture

## The big picture

```
Hyprland (compositor)
 ├─ Noctalia v5 (separate native process): wallpaper, bar, launcher/clipboard/control-center panels, notification daemon
 └─ qs -c outerwilds (this project, one Quickshell process)
      ├─ scene window  (layer Bottom, one per monitor)  ── CameraRig ── planets, orbits, camera, loop
      │                                                     ├─ WidgetLayer ── WidgetSlot × N ── widget files
      │                                                     ├─ SatelliteHUD, Signalscope, MapHost, RumorMap (in-scene overlays)
      │                                                     └─ KeyHost (turns the key table into shortcuts)
      ├─ panel windows (Overlay): LauncherWindow, SettingsWindow, Screentime/Bubble/Network/Wallpaper windows
      ├─ data/IO scopes (no visuals): SystemLive, SystemExtras, SignalscopeMpris, WidgetConfigStore, HyprIpc
      └─ singletons (shared state): see below
```

## Windows and layers

* `shell.qml` is the entry point (`ShellRoot`). It creates one `PanelWindow` per screen, on layer **Bottom**, anchored to all four
  edges with `exclusionMode: Ignore` so it covers the whole monitor (the bar still draws on top because it is on the Top layer).
  Namespace: `outerwilds-solar-system`.
* Bottom = above Noctalia's wallpaper, below app windows. **Never use layer Top for the scene**: it once covered the whole system.
* The scene is only seen on an **empty workspace**. `NoctaliaBridge.desktopVisible` is true when some scene monitor's active workspace
  has 0 windows and no fullscreen window; `CameraRig.active` follows it. When false: the frame loop, widget layer, cava and
  other per-frame work stop.
* Monitors whose name matches `^HEADLESS` (the streaming output) never get a scene (`NoctaliaBridge.skipPattern`).
* Panels (launcher, settings, screentime, network, wallpaper, processes) are separate Overlay windows, each with an IPC handler
  (`toggle` / `show` / `hide`). The Map View, Rumor Map, Signalscope and HUD live **inside** the scene.

## The three kinds of QML files

1. **Visual items**: `CameraRig`, `PlanetShader`, widgets, overlays.
2. **Logic singletons** (`pragma Singleton`, plain `QtObject`, **no `Quickshell` import**): `WidgetConfig`, `Keybinds`, `MapData`,
   `RumorData`, `SignalscopeData`, `WidgetData`. They hold state and rules. Keeping them Quickshell-free means the scene also runs in
   plain `qml` on a laptop without Quickshell (see `dev/`).
3. **IO scopes** (import `Quickshell` / `Quickshell.Io`, no visuals): `WidgetConfigStore`, `SystemLive`, `SystemExtras`,
   `SignalscopeMpris`, `HyprIpc`, plus the singletons `Sensors`, `NoctaliaBridge`. They run processes / read files / listen to
   Hyprland and write results into the logic singletons.

This split is the main design rule: **logic and data in plain singletons, side effects in scopes.**

## The frame loop (core/CameraRig.qml)

One `FrameAnimation` drives everything while `active`:

1. throttle (idle frame-rate cap, see [rendering.md](rendering.md));
2. advance `loopTime` (frozen while interacting after 1288 s), update Keplerian orbits (`updateOrbits`);
3. camera: auto-orient toward a targeted planet, key thrust / drift physics, or anchor on the orbit shell of a locked planet;
4. project every body to screen (`projectedMap`: position, radius, light direction, z-order) and rebuild hit boxes;
5. repaint the background `Canvas` (stars, orbit lines, dust) **only if** the camera or a highlight changed;
6. emit `frameUpdated()`, which the widget slots use to reposition.

Planets are `PlanetShader` items in a `Repeater` over `bodyKeys`; they read `projectedMap` through bindings.

## The widget pipeline

```
WidgetLayer.baseDefs (default table)          widgets/user/<name>/widget.json (drop-ins)
        │ registerDefaults()                            │ WidgetConfigStore.rescan() → setUserCatalog()
        ▼                                               ▼
              WidgetConfig  (singleton)  ◄── widgets.json (overrides, extras, keys, ui) via WidgetConfigStore
        │  liveDefs(): defaults + extras, merged with overrides, + cfg (option values)
        ▼
   WidgetLayer.refresh() → defById / slotIds → Repeater → WidgetSlot (one per widget)
        │  orbit maths, presence/occlusion, size from camera distance, Loader(source)
        ▼
   widget file (WidgetCard root) ◄─ cfg pushed in live (slot.pushCfg)
```

* The **settings panel** (`settings/SettingsPanel.qml`) only edits `WidgetConfig` through functions (`setField`, `setSetting`,
  `addWidget`, `removeWidget`, `restoreWidget`, `resetWidget`, ...). Every change bumps `revision`, which makes the layer rebuild the
  def objects (slots update in place, nothing is recreated unless the widget list itself changes) and schedules a debounced save.
* `WidgetConfigStore` is the only file that reads/writes `widgets.json`. It watches the file, so hand edits show up live.
* Defaults are never copied into `widgets.json`: only the **differences** are stored (an override equal to the default is deleted).
* `widgets.json` shape: `{ version, globalSpeed, overrides: { <id>: { host, enabled, removed, size, speed, k, tilt, node, show,
  source, settings } }, extras: [ full defs of widgets added from the panel, ids x1, x2... ], keys: { <action>: "<sequence>" },
  ui: { loopPanel, shrinkFar } }`.
* A slot's orbit: radius = `k × hostRadius + add`; `tilt` tilts the plane, `node` turns the plane about Y (different axes),
  `phase` start angle, `speed` rad/s (negative = other way, 0 = parked). `show: "focus"` fades the widget in when its planet is
  targeted/locked or you are close; `"always"` keeps it visible.

## The overlays

| Overlay | Files | Data | Purpose |
|---|---|---|---|
| Map View (`N`) | `map/*`, `data/MapData.qml` | `MapData` providers per feature | ship-log style map; planet pages follow the widgets on each planet |
| Rumor Map (`L`) | `rumor/*`, `data/RumorData.qml` | notifications | node graph of notification history |
| Signalscope (`Q`) | `signalscope/Signalscope.qml`, `data/SignalscopeData.qml`, `SignalscopeMpris.qml` | MPRIS players | each audio stream = a channel on a planet; brackets close as you aim |
| HUD | `hud/SatelliteHUD.qml`, `data/HudData.qml`, `hud/hud_assets/` | Sensors, cava | game HUD gauges, audio globe, thrust indicator |
| Control Centre (`E`) | `settings/*`, `data/WidgetConfig.qml` | `widgets.json` | widgets, keys, options |

Overlays pause the solar system by setting the rig inactive while they are open, and they do not leak input to the camera.
Map/Rumor/rumor-widget state is held in singletons; the views read them and render, so closing a view never loses state.

## Noctalia integration (what is and is not possible)

Noctalia v5 is a **separate native process**, not Quickshell. Its panels cannot be moved into the scene.
`data/NoctaliaBridge.qml` therefore only *observes*: it listens to Hyprland `openlayer` events for the namespaces `noctalia-panel`
and `noctalia-attached-panel`, runs `noctalia msg status` (gives `activePanelId`) and `hyprctl -j monitors/workspaces`, and, when the
workspace is empty, emits `planetRequested(planet, panel)`; the rig then flies the camera to that planet
(`panelPlanets`: launcher → dark_bramble, session → sun_station, clipboard → attlerock, wallpaper → quantum_moon,
control-center → giants_deep). With `replaceLauncher: true` it closes Noctalia's launcher and opens ours instead.
Details and limits: [data-and-integrations.md](data-and-integrations.md).
