# Guide for AI assistants working on this project

Read this before changing anything. The owner uses Gemini and Claude on this project, usually from chat, often away from the PC.

## Environment facts

* Owner's machine: CachyOS, Hyprland (configured in **Lua**: `~/.config/hypr/hyprland.lua` + `hyprland/` modules + `outerwilds.lua`),
  Ryzen 5 5600, RX 6600, one monitor (HDMI-A-1, 1920×1080). Read the existing binds before writing any new one.
* Config folder = this repo: `~/.config/quickshell/outerwilds`. Run `qs -c outerwilds`, stop `qs kill -c outerwilds`, logs `qs -c outerwilds log`.
* `qs` is the noctalia-qs fork of Quickshell, and may lag upstream. Noctalia is **v5** (native, `noctalia msg`), not QML.
* A second machine (Linux Mint laptop, i3) is used for testing: plain `qml --rhi opengl dev/test_mint.qml`, **without** Quickshell.
  So logic singletons must not import `Quickshell` (see [architecture.md](architecture.md)).
* Code written in chat is usually **not** run against the real Quickshell before delivery. Say plainly what you could not test.

## Hard rules

1. **Registry**: any QML type used by name from another file needs a line in the root `qmldir`. Widgets loaded by path do not.
2. **Logic vs IO**: state/rules in plain singletons (no `Quickshell` import); processes/files/D-Bus/Hyprland in scopes.
3. **Widgets**: root is `WidgetCard`; every pixel value × `w.ui`; no `Quickshell` import; no timers under 1 s; read data from singletons.
   Full contract: [../WIDGETS.md](../WIDGETS.md).
4. **Never run a second notification server**; eavesdrop on the bus only.
5. **Never put the scene on layer Top.** It stays Bottom.
6. **Shaders**: never name a variable `gl`/`gl_*`; rebuild `.qsb` with `shaders/build.sh`; validate (see [rendering.md](rendering.md)).
7. **Do not touch finished work** unless asked:
   * planets are done and must stay pixel-identical: Dark Bramble, Timber Hearth, Attlerock, Hollow's Lantern, Ember Twin, Ash Twin
     and all other bodies (the aura on every planet is applied and intended);
   * the double-click teleport bug is left alone **on purpose** (Alt+click is the fly-in);
   * the loop stays frozen while interacting past 1288 s;
   * the Noctalia bridge, launcher, Map View, Rumor Map and Signalscope behaviours listed in [usage.md](usage.md) are accepted.
8. **No fixed keys**: every key is an action in `data/Keybinds.qml`; never hard-code a `Shortcut` sequence elsewhere.
9. **Limits**: do not add clamps to orbit/size/speed unless something breaks without them (NaN, size ≤ 0, negative radius are the
   known breakers).
10. **Optimisations must not cost visuals.** Be upfront if something gets heavier.
11. Do not edit generated files (`widgets/serp/Anserin*.qml`, `widgets/lucid/*` wrappers) by hand if a `port*.py` produces them.

## How the owner wants work delivered

* **Small patches, not re-uploads.** Token cost matters: prefer `git apply`-able patches (or scripts that patch/regenerate files in
  place) over full file dumps, and ask only for the specific files you need. Patch history is in the root `ow_*.patch` files.
  Check the patch applies to a clean clone **plus the earlier patches** before handing it over.
* For shaders: full drop-in `bake.frag` / `planet.frag` (and `PlanetShader.qml` only if changed) plus a before/after/in-game
  comparison PNG; name the tweak knobs; say if the shader got heavier; the owner rebuilds the `.qsb` and tests on the PC.
* State plainly what is untested, what still looks wrong, and exact commands to run (`ow restart`, `ow rescan`, ...).
* Keep answers concise. The owner is new to GitHub: explain git steps when they matter
  (`git status` saying "up to date" means in sync with the *last commit*, not necessarily with the working folder).
* In handoffs the owner wants complete drop-in files (or a patch) and a plain statement of what could not be tested.

## Safe working method

1. Read the page for the area ([file-map.md](file-map.md) tells you which file).
2. Make the smallest change that works; keep style (4-space indent, comments that explain *why*).
3. Syntax-check QML if you can (`qmllint` from Qt/PySide6 catches syntax errors even without Quickshell).
4. Test pure logic headlessly where possible: singletons without `Quickshell` import can be loaded in a tiny QML test (see how
   the widget-config logic was tested: a `qmldir` with the singleton + a test item calling its functions under
   `QT_QPA_PLATFORM=offscreen`).
5. Build the patch, apply it on a fresh clone, re-lint.
6. Tell the owner the commands and the risks.

## Common tasks, fastest route

| Task | Do |
|---|---|
| New widget | `ow new-widget name`, edit `Main.qml` + `widget.json`; see WIDGETS.md |
| Widget options | `settings: [...]` in `widget.json` (or the built-in's `builtinCatalog` entry) + `cfg.key` in the widget; the Clock is the worked example |
| New planet job / label | `bodyMeta` role string in `CameraRig.qml`; place widgets there via the Control Centre |
| New key | action in `Keybinds.qml` + handling in `KeyHost.qml`; add an IPC function in `HyprIpc.qml` if it must work without focus |
| New IPC call | `IpcHandler { target: "..."; function x(): void {...} }` in an IO scope that is instantiated in `shell.qml` |
| New big panel | copy `widgets/serp/panels/NetworkWindow.qml` (window + `open` + IPC), register the type in `qmldir`, instantiate in `shell.qml` |
| New data source | write it as an IO scope that fills a logic singleton; add the type to `qmldir` and an instance to `shell.qml`; keep a mock fallback |

## Known unknowns (verify in the log before building on them)

* Some Quickshell API names were used from memory in early files (`DesktopEntry.noDisplay`, `execString`, `execute()`,
  `DesktopEntries.applications.values`). If the app list is empty, look for undefined-property warnings.
* The `qs` build warns about a Qt version mismatch; unexplained crashes may be that, not the code.
* The idle frame cap and drop-in widget system were added after the last full on-PC test of the scene.
