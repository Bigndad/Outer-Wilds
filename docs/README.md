# Outer Wilds Desktop: Wiki

An interactive Outer Wilds themed desktop for Hyprland, built with Quickshell (Qt 6 / QML).
The desktop background is a live 3D solar system (shader-rendered planets, orbits, a 22-minute loop that ends in a supernova).
Widgets orbit the planets, and full-screen overlays (Map View, Rumor Map, Signalscope, HUD, settings) sit on top.
Noctalia (bar and panels) runs alongside it.

> This wiki is written for **both humans and AI assistants**. If you are an AI, read [ai-guide.md](ai-guide.md) first: it lists the
> rules that, if broken, produce "X is not a type" errors, blank scenes or broken planets.

## Pages

| Page | Read it when you want to... |
|---|---|
| [architecture.md](architecture.md) | understand how the pieces fit: process, windows, layers, data flow, the widget pipeline |
| [file-map.md](file-map.md) | find which file does what, and how a file gets registered |
| [usage.md](usage.md) | run it, control it: `ow` command, IPC calls, keys, mouse, Hyprland binds, files it writes |
| [rendering.md](rendering.md) | touch planets, shaders, the camera, the loop, or performance |
| [data-and-integrations.md](data-and-integrations.md) | see where each number comes from (sensors, notifications, audio) and what Noctalia can and cannot do |
| [../WIDGETS.md](../WIDGETS.md) | add a widget or give it options (written to be pasted into an AI) |
| [ai-guide.md](ai-guide.md) | work on the project as an AI: rules, delivery format, what is finished and must not change |
| [troubleshooting.md](troubleshooting.md) | fix an error or a "nothing shows" situation |
| [status.md](status.md) | know what is done, known bugs and the open ideas |

## 60-second tour

1. `qs -c outerwilds` (or `ow start`) starts the shell. One full-screen window per monitor sits on the **Bottom** layer: above the
   wallpaper, below every app. So the scene is only visible on an **empty workspace**; opening a window hides it and pauses all work.
2. Click a planet to centre it, double-click to lock and orbit it, scroll to zoom, WASD to fly.
3. Widgets (clock, weather, workspaces, music, notes...) orbit their planets. Each planet has a job (Timber Hearth = workspaces,
   Dark Bramble = app launcher, ...). `E` opens the widget control centre where you move, resize, add, remove and configure them.
4. `N` opens the Map View (ship-log style map), `L` the Rumor Map (notification graph), `Q` the Signalscope (audio channels per planet).
5. Everything is configurable without editing code: widgets, orbits, keys and options are saved in `widgets.json`.

## Vocabulary

| Term | Meaning |
|---|---|
| **scene** | the full-screen 3D solar system (`core/CameraRig.qml`) |
| **rig** | the `CameraRig` item; owns camera, input, bodies and the loop clock |
| **body** | a sun/planet/moon, identified by an id like `timber_hearth` (list in [rendering.md](rendering.md)) |
| **host** | the planet a widget orbits |
| **slot** | one live widget instance (`WidgetSlot`) |
| **def** | the table entry describing a slot: id, host, source file, size, orbit |
| **catalog** | every widget file that can be placed (built-in list in `WidgetConfig`, plus drop-in folders) |
| **cfg** | a widget's saved option values, read in the widget as `cfg.<key>` |
| **registry** | the root `qmldir`: the list of QML types other files may use by name |
| **loop** | the 22-minute cycle: the Sun swells, goes supernova, resets |
| **Signalscope / Map View / Rumor Map** | the in-game-inspired overlays |
| **Noctalia** | the separate bar/panel shell running alongside (v5, native, not QML) |

## Credits and licences

Fan project; Outer Wilds belongs to Mobius Digital / Annapurna Interactive. The repository is AGPL-3.0.
It builds on ilyamiro's Serpantinum/hypr-comp (AGPL-3.0), the Anserin fork, Sn3akyy1's Lucid (MIT) and the design language of
Nebelung-cloud's glyph-rice (GPL-3.0). Per-family notes are in `widgets/serp/NOTICE.md`, `widgets/lucid/NOTICE.md`,
`widgets/glyph/NOTICE.md`. If you share this config, keep it AGPL-compatible.
