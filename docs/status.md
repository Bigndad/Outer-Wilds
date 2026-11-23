# Status and roadmap

Last updated: 23 November 2026. (Update this page when something changes; it is the first thing a new contributor reads after the README.)

## Done

* **Scene**: Keplerian orbits, camera and flight (classic and drift), 22-minute loop with supernova and reset, debug speed slider,
  stars/orbits/dust canvas, aura on every planet.
* **Planets**: all twelve bodies have final shaders and baked textures (Sun, Sun Station, Ash/Ember Twin, Timber Hearth, Attlerock,
  Brittle Hollow, Hollow's Lantern, Giant's Deep, Dark Bramble, Interloper, Quantum Moon).
* **Overlays**: HUD (real game assets; CPU/RAM/GPU arcs, audio globe, thrust indicator), Map View, Rumor Map (toasts, actions, urgency,
  search/filter), Signalscope (per-planet brackets, lock circle, media keys, MPRIS channels).
* **Noctalia bridge**: panels fly the camera to a planet; launcher replaced by ilyamiro's 3D launcher.
* **Widgets**: orbiting widget system, Control Centre (add/remove/restore, planet, size, speed, distance, axis, visibility, key),
  free keybinds, hideable loop panel, shrink-when-far, widget families (Outer Wilds, Serpantinum/Anserin, Lucid, Glyph) and the big
  panels (wallpaper switcher, screentime, network manager, process monitor).
* **Live data**: sensors, apps, workspaces, uptime, notifications, notes, cava bands (mock fallbacks remain for off-PC testing).
* **Scene window covers the whole output; idle frame cap** (30 fps idle, full rate when moving).
* **Drop-in widgets**, widget options (`cfg`), `ow new-widget`, `ow rescan`, and this wiki.

## Known issues / left on purpose

* Double-click teleport is unreliable; `Alt`+click is the fly-in. Left alone by decision.
* Only the **Clock** widget has options so far; the schema is ready for the others.
* Planet `role` strings in `bodyMeta` were placeholders; the owner has set some jobs (Timber Hearth = workspaces, Dark Bramble =
  launcher, Attlerock = notes, Brittle Hollow = weather and memory/disk, twins = audio/battery, Interloper = notifications) and may
  still change others.
* Noctalia's panels cannot be moved into the scene (see [data-and-integrations.md](data-and-integrations.md)); the Control Center
  *tab* is not visible to the bridge.
* Dismissing a card in the Rumor Map does not dismiss it in Noctalia (Noctalia owns the notification daemon).
* The scene gets heaviest when one planet fills the screen.
* Root contains backups (`*.bak`, `*.pre-*`, `.hypr-compat-backup-*`) and patch files; harmless, can be cleaned up.

## Ideas, in no fixed order

* Options for more widgets (weather units and location, battery, visualiser colours, calendar start day, music faces).
* A dedicated Scout (screenshot "photos" into the Map View picture panel; screenshot tools do not run in the background).
* The owner's own 3D Signalscope mesh and real planet textures for the Map View pictures.
* An escape-hatch Hyprland bind (`qs kill -c outerwilds`) if not already bound.
* Optional per-planet themes (the shared theme is Outer Wilds styled).
* More Anserin/Serpantinum/Glyph widgets; each is a manifest or `port*.py` entry.
* A real data adapter for anything still on mock when running off the PC.

## History

The git patches applied so far are (when kept) in the repo root: `ow_control_centre`, `ow_qol`, `ow_apps_map`, `ow_keys_live`, `ow_keys_free`,
`ow_system`, `ow_widgets`, `ow_scroll`, `ow_fixes`, `ow_hotfix`, then `ow_fullscreen_perf` and `ow_widget_system`.
