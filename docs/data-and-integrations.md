# Data and integrations

Everything the widgets and overlays show comes from singletons. Each has a **mock** mode (fake data, so the scene works on a
machine without the real sources) and a **live** mode. `SystemExtras` switches the mocks off at start-up (`HudData.mock = false`,
`WidgetData.mock = false`, `MapData.mock = false`, `RumorData.mock = false`), so on your PC everything below is live.
Check at any time: `qs -c outerwilds ipc call system status`.

| Data | Source | Writer | Cost / notes |
|---|---|---|---|
| CPU %, RAM %, swap, GPU %, VRAM, temps (CPU, GPU, NVMe) | `/proc/stat`, `/proc/meminfo`, `/sys/class/hwmon/*`, amdgpu `gpu_busy_percent`, VRAM files | `Sensors` (one shell `Process`, every 2 s) | disks every 30 s and when the Map View opens |
| Apps | Quickshell `DesktopEntries` | `SystemLive` → `MapData.setApps` | launch = the real desktop entry |
| Workspaces, window titles | `hyprctl -j workspaces/clients/activeworkspace`, refreshed on Hyprland events (150 ms debounce) | `SystemLive` → `WidgetData`, `MapData.setWindows` | read-only: never changes workspace |
| Uptime | `cat /proc/uptime` every 10 s | `SystemLive` → `WidgetData.uptimeSeconds` | |
| HUD arcs | yellow = CPU, cyan = RAM, orange "boost" = **GPU load** (a desktop has no battery) | `SystemExtras` bindings from `Sensors` | |
| HUD audio globe and Glyph Matrix | `cava` raw output, 8 bands | `SystemExtras` | runs only while audio plays **and** the scene is visible; no `cava` → globe idle |
| Audio channels | MPRIS players over D-Bus | `SignalscopeMpris` → `SignalscopeData` | poll every 400 ms while the scope is out, 2.5 s otherwise |
| Notifications | `busctl --user monitor` on `org.freedesktop.Notifications` (**eavesdrop only**) | `SystemExtras` → `RumorData` | history in `~/.local/share/ow-shell/shiplog.json`; "open app" launches the desktop entry; dismiss only removes the card here |
| Notes | `~/.local/share/ow-shell/notes.txt` | `SystemExtras` ↔ `WidgetData.notesText` | |
| Weather | Open-Meteo (free, no key), polled every 15 min by the weather widgets | the widget | |
| Scene visibility | Hyprland events + `hyprctl -j monitors/workspaces` | `NoctaliaBridge` | |

## Map View provider model

`MapData` has one provider per **feature** (clock, workspaces, audio, apps, notes, rumors, memory/disk, sensors). A planet's page
shows the features of the **widgets that currently sit on it** (`featuresOf`), so moving a Workspaces widget to another planet moves
the workspace list with it. `entriesFor()` returns the structure (cheap), `describe()` the live text/picture of one entry,
`actionFor()`/`runAction()` the button under the picture. Defaults: twins = audio players (they tune the Signalscope), Dark Bramble =
apps (launch), Timber Hearth = workspaces/windows, Interloper = notifications (open in the Rumor Map), Brittle Hollow / Hollow's
Lantern = disk, memory, sensors, Attlerock = notes.

## Noctalia v5: what works and what cannot

* Noctalia v5 is a **native** shell: controlled with `noctalia msg <command>`, Luau plugins, TOML config. It is **not** Quickshell, and
  the older v4 docs (QML plugins, `qs -c noctalia-shell ipc ...`) do **not** apply.
* Its panels and desktop widgets are separate Wayland surfaces. They **cannot** be moved onto or orbit planets. The scene can only
  observe them (`NoctaliaBridge`) and fly the camera to a planet; native equivalents have to be rebuilt as widgets here.
* Layer names seen: `noctalia-wallpaper` (background), `noctalia-desktop-widget-*` and `outerwilds-solar-system` (bottom),
  `noctalia-bar-default`, `noctalia-panel`, `noctalia-attached-panel` (top), `noctalia-dock` (overlay).
  Launcher and clipboard use `noctalia-panel`; control center, session and wallpaper use `noctalia-attached-panel`.
  Only one Noctalia panel exists at a time, so `noctalia msg status` → `activePanelId` is reliable. The Control Centre *tab* is not exposed.
* Only one process may own the notification service, and Noctalia owns it. **Never run a second notification server.**
* Noctalia's own desktop widgets sit on the Bottom layer and are hidden under the scene; disable them in Noctalia's config if needed.
* `widgets/NoctaliaPlugin.qml` and `kind: "noctalia"` defs were written for v4 QML plugins and are not useful on v5.
* Official Noctalia plugins are Luau + `plugin.toml`; they cannot be loaded into the scene. Build native widgets instead.

## Third-party widget sources

| Family | Folder | Origin | Licence | How it is brought in |
|---|---|---|---|---|
| Launcher | `launcher/` | ilyamiro hypr-comp `applauncher.qml` | AGPL-3.0 | patched: apps from `DesktopEntries`; `Scaler` / `MatugenColors` are our stand-ins |
| Serpantinum + Anserin | `widgets/serp/` | ilyamiro/serpantinum, lukpednoi/Anserin | AGPL-3.0 | `port*.py` scripts re-generate wrappers (`Anserin*.qml`), `shim/` replaces the singletons they expect, `panels/` holds the big windows |
| Lucid | `widgets/lucid/` | Sn3akyy1/lucid | MIT | `port.py` + `shim/` (Theme, Units, UPower, Cava, ... stand-ins) |
| Glyph | `widgets/glyph/` | design language of Nebelung-cloud/glyph-rice | GPL-3.0 | QML written fresh for this project |

Do not hand-edit generated wrappers if a `port*.py` script produces them: change the script, or the edit is lost on the next port.
