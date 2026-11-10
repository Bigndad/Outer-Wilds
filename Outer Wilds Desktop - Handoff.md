# Outer Wilds Desktop: Handoff

Written 1 November 2026 so the project can be continued by another assistant or by the owner. It is self-contained: paste it into a new chat and attach the files listed in section 8.

## 1. What this is

An Outer Wilds themed interactive desktop for Hyprland, built with Quickshell (Qt6 QML). A 3D solar system (shaders, Keplerian orbits, a 22-minute loop that ends in a supernova) is the desktop background. Widgets orbit the planets, and overlays (Map View, Rumor Map, Signalscope, HUD) sit on top. Noctalia (bar and panels) runs alongside it and we integrate with it.

## 2. Environment

- CachyOS, Hyprland configured in Lua (`~/.config/hypr/hyprland.lua` plus `hyprland/` modules; read these before writing any keybind). Ryzen 5 5600, RX 6600, one monitor (HDMI-A-1, 1920x1080). Desktop PC, so no battery.
- Noctalia is **v5**: a native shell (not Quickshell), controlled with `noctalia msg <command>`, Luau plugins, TOML config. Docs: https://docs.noctalia.dev/v5/ . The older v4 docs (QML plugins, `qs -c noctalia-shell ipc ...`) do NOT apply.
- `qs` is the noctalia-qs build of Quickshell. It warns that it was built against Qt 6.11.2 while the system has Qt 6.12.0. The package should be rebuilt with the AUR helper; crashes are possible until then.
- Config folder: `~/.config/quickshell/outerwilds` (entry point `shell.qml`).
- Run: `qs -c outerwilds`. Stop: `qs kill -c outerwilds`. Logs: `qs -c outerwilds log`.
- IPC examples: `qs -c outerwilds ipc call launcher toggle`, `qs -c outerwilds ipc call bridge fly dark_bramble`.
- Backups: `~/outerwilds-pre-reorg.tar.gz` (before the folder reorganisation) and `~/outerwilds-archive` (old backup folders, plus pre-patch copies of `CameraRig.qml` and `shell.qml`).

## 3. Folder layout and the rule that bites

- `core/CameraRig.qml`: 3D engine, input, `bodyMeta`, `flyTo()`.
- `planets/PlanetShader.qml`, `shaders/` (`*.frag`, compiled `*.qsb`, `build.sh`).
- `hud/SatelliteHUD.qml` and `hud_assets/`.
- `widgets/`: `WidgetLayer`, `WidgetSlot`, `WidgetCard`, and all `*Widget.qml` files, `BlankWidget`, `NoctaliaPlugin`.
- `map/`, `rumor/`, `signalscope/`: the overlays.
- `data/`: singletons `HudData`, `WidgetData`, `RumorData`, `SignalscopeData`, `MapData`, `SignalscopeMpris`, `NoctaliaBridge`. All still MOCK data except the last two.
- `launcher/`: `AppLauncher`, `LauncherWindow`, `Scaler`, `MatugenColors`.
- `dev/`: `test_mint.qml`, `main.qml` and the Quickshell stubs for testing on another machine (path-dependent; may need adjusting).

**The rule:** every QML file used by type name from another file must have a line in the root `qmldir`: `Name 1.0 folder/Name.qml`, or `singleton Name 1.0 folder/Name.qml`. On this Qt, unlisted sibling files are NOT found and give 'X is not a type'. Files in subfolders start with `import ".."` to see that registry. Files loaded by path through a `Loader` `source:` need no entry. Shader paths are relative to the QML file (for example `../shaders/planet.frag.qsb`). `vignette.frag.qsb` has no `.frag` source.

## 4. Architecture

- `shell.qml`: a ShellRoot with `SignalscopeMpris`, `LauncherWindow`, and one fullscreen PanelWindow per screen on layer **Bottom** (above Noctalia's wallpaper, below app windows) containing `CameraRig`. Bottom means the scene is only visible on an empty workspace. (Layer Top once covered the whole system and locked the user out; do not use it.)
- `CameraRig`: Keplerian orbits, the 22-minute loop, `bodyMeta` (planet ids: sun, sun\_station, ash\_twin, ember\_twin, timber\_hearth, attlerock, brittle\_hollow, hollows\_lantern, giants\_deep, dark\_bramble, interloper, quantum\_moon). The `role` strings in `bodyMeta` are placeholders; the owner has not decided roles. `flyTo(id)` flies to and locks a planet. `active` is meant to pause all per-frame work (stage 5, not wired yet).
- `WidgetLayer.defs`: one table entry per orbiting widget: `id`, `host` (planet id), `source` (file), `show` (`always` or `focus`), `worldW`/`worldWk`, `minUi`/`maxUi`, `orbit {k, add, tilt, node, phase, speed}`. The placeholders use `BlankWidget.qml`. Edit `defs` only.
- Built widgets: Sun (clock, loop, uptime, calendar), Timber Hearth (workspaces, signalscope), Attlerock (notes), Interloper (Ship Log / Rumor).
- **NoctaliaBridge** (`data/NoctaliaBridge.qml`): listens to Hyprland `openlayer` events for namespaces `noctalia-panel` and `noctalia-attached-panel`, then runs `noctalia msg status` (gives `activePanelId`) and `hyprctl -j activeworkspace` (gives `windows`). If the workspace is empty it emits `planetRequested(planet, panel)` and CameraRig flies there. The `panelPlanets` table (editable) is: launcher to dark\_bramble, session to sun\_station, clipboard to attlerock, wallpaper to quantum\_moon, control-center to giants\_deep. Noctalia's panel still opens normally; only the camera moves. With `replaceLauncher: true` it also closes Noctalia's launcher (`noctalia msg panel-close launcher`) and emits `launcherRequested`.
- **LauncherWindow**: an Overlay-layer PanelWindow with exclusive keyboard focus hosting `AppLauncher`. This is ilyamiro's `applauncher.qml` (a 3D sphere of app icons), patched: apps come from Quickshell `DesktopEntries` (his `app_fetcher.py` is not available), closing emits `closeRequested()`. `Scaler` and `MatugenColors` are our stand-ins (`MatugenColors` uses an Outer Wilds palette). They are registered globally, so other ilyamiro widgets can reuse them.

## 5. Done

- Planet shaders, textures, camera, loop, supernova, HUD, Map View, Rumor Map, Signalscope, orbiting widget system (mock data).
- Folder reorganisation with the registry `qmldir`.
- Layer fix (Bottom), the NoctaliaBridge camera fly-to (confirmed working via `ipc call bridge fly`), and the ilyamiro launcher (works; opening it from Noctalia shows only ours).

## 6. Left to do, in suggested order

**A. Launcher: resolved.** The owner confirmed that opening the launcher from Noctalia shows only ilyamiro's launcher; Noctalia's own is closed by NoctaliaBridge. Optional polish: bind the launcher key to `qs -c outerwilds ipc call launcher toggle` (read how existing binds are written in the Hyprland Lua config first) so the keyboard path never touches Noctalia's launcher.

**B. Add a keybind escape hatch** running `qs kill -c outerwilds`.

**C. `data/Sensors.qml` singleton** (one poller for everything): a single 2 s Timer reading `/proc/meminfo`, `/proc/stat` (CPU deltas), `/sys/class/drm/card*/device/gpu_busy_percent`, `mem_info_vram_used` and `mem_info_vram_total`, and temperatures from hwmon (find the right ones with `grep -l k10temp /sys/class/hwmon/*/name` for the CPU and the amdgpu hwmon under the card's `device/hwmon/`). Use `FileView` or a Process from `Quickshell.Io`. Pause it when `rig.active` is false. Noctalia's bar already shows RAM and GPU, but we cannot share its polling (separate process); reading sysfs is cheap, and the shaders cost far more than sensors.

**D. Replace mock data** in `data/*.qml`, easiest first: workspaces (`Quickshell.Hyprland`), clock and uptime (`/proc/uptime`), MPRIS (`SignalscopeMpris` already exists), apps (`DesktopEntries`), then sensors. The HUD battery gauge makes no sense on a desktop: map it to GPU load or hide it.

**E. Roles and widgets for the 18 placeholder slots** (ids in `WidgetLayer.defs`: ss\_a, at\_a, at\_b, et\_a, et\_b, bh\_a/b/c, hl\_a, gd\_a/b/c, db\_a/b/c, in\_b, qm\_a). The owner has NOT chosen roles. Suggestions I made (not decided): Sun Station = CPU/GPU load and temps, Ash Twin = network and a focus timer, Ember Twin = disk and quick toggles, Brittle Hollow = processes, trash, clipboard, Hollow's Lantern = brightness, Giant's Deep = music, volume, Dark Bramble = connections, logs, updates, Interloper = notification history, Quantum Moon = screenshot launcher. **Decided: the weather widget goes on Brittle Hollow.** Weather source suggestion: Open-Meteo (free, no key), e.g. `curl -s 'https://api.open-meteo.com/v1/forecast?latitude=19.08&longitude=72.88&current=temperature_2m,weather_code,wind_speed_10m'` (Mumbai) every \~15 minutes through a Process. How to build a widget: copy `BlankWidget.qml` / follow `ClockWidget.qml` and `WidgetCard`, change that entry's `source` in `defs`, register nothing (widgets load by path).

**F. Noctalia integration limits and options.**

- Noctalia's panels and desktop widgets are separate Wayland surfaces drawn by Noctalia; they cannot be moved onto or made to orbit planets. We can only fly the camera to a planet and show native equivalents.
- Noctalia's own desktop widgets (clock, weather, media\_player, audio\_visualizer, fancy\_audio\_visualizer) sit on the Bottom layer and are currently hidden under our scene. The plan is to rebuild what is wanted natively, then disable them in Noctalia's config. Visualizers need an audio spectrum (for example `cava` raw output through a Process); mind the CPU cost.
- Control Center tab is NOT visible: `noctalia msg status` only reports `activePanelId` (all Control Center opens go to one planet for now). Options: set `open_near_click_control_center = true` in Noctalia's config so the panel position follows the click and map x to the bar widget; or check the Noctalia `[hooks]` events list for something panel-related.
- Notifications: only one process may own the notification service, and Noctalia owns it. Never run a second server. v5 docs showed DND and clear commands but no history readout; fallback is watching the session bus: `dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'"` through a Process.
- Official Noctalia plugins (for example `notes`) are Luau scripts with `plugin.toml`; they cannot be loaded into our QML scene. Build native equivalents. `NoctaliaPlugin.qml` and the `kind: "noctalia"` entry in `WidgetLayer` were built for old v4 QML plugins and are not useful for v5.

**G. Stage 5 optimisation (important for GPU use).** Wire `CameraRig.active`: set it false when the workspace has windows or a fullscreen window. Source: Hyprland `rawEvent` names `openwindow`, `closewindow`, `movewindow`, `workspace`, `fullscreen`, then read `hyprctl -j activeworkspace` (`windows`, `hasfullscreen`). The scene is only visible on an empty workspace anyway. NoctaliaBridge already runs that command and is a good place for it.

**H. More ilyamiro widgets.** His shell is serpantinum (https://github.com/ilyamiro/serpantinum, AGPL-3.0; fine for personal use, anything shared must also be AGPL). Only the launcher is done. His other files (`notifications.qml`, `moon.qml`, `Stars.qml` in hypr-comp) assume his own singletons; adapt them.

**I. Smaller items.** Map View and Rumor Map real data adapters; the owner's own 3D scope mesh and planet textures (to be sent); the Scout screenshot launcher idea; rebuild `noctalia-qs`; check the `dev/` Mint test path.

## 7. Gotchas learned

- Registry rule in section 3 (it caused two separate 'is not a type' errors).
- Quickshell API names used from memory and not yet confirmed against the running build: `DesktopEntry.noDisplay`, `execString`, `execute()`, `DesktopEntries.applications.values`. If the app sphere is empty, check the log for undefined properties.
- Code was only tested in plain Qt 6.4 with stub modules, never against the real Quickshell or Qt 6.12. Treat every new file as untested until the log is clean.
- `qs` here is the noctalia-qs fork; features may lag upstream Quickshell.
- Hyprland layer names seen: `noctalia-wallpaper` (background), `noctalia-desktop-widget-*` and `outerwilds-solar-system` (bottom), `noctalia-bar-default`, `noctalia-panel`, `noctalia-attached-panel` (top), `noctalia-dock` (overlay). Launcher and clipboard use `noctalia-panel`; control center, session and wallpaper use `noctalia-attached-panel`.
- Only one Noctalia panel exists at a time (same surface reused), so `activePanelId` is reliable.

## 8. How to continue in a new chat

Paste this document, then attach or paste: `shell.qml`, `qmldir`, `core/CameraRig.qml`, `widgets/WidgetLayer.qml`, `data/NoctaliaBridge.qml`, the specific data file being replaced, and the output of `qs -c outerwilds log`. Ask the assistant to make small changes, to give exact commands, and to always add new types to `qmldir`. When an error appears, send the first ERROR lines of the log; they name the file and line.
