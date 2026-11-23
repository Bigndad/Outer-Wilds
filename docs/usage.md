# Usage

## Requirements

* Hyprland, and `qs` (Quickshell; on CachyOS the `noctalia-qs` build). `qs` may warn about a Qt version mismatch: rebuild the package if you see crashes.
* Noctalia v5 (optional but expected): `noctalia msg ...` is used for panel state.
* Tools used at runtime: `hyprctl`, `busctl` (notifications), `cava` (HUD audio bands; without it the globe stays idle), `gtk-launch`.
* `ow doctor` checks all of them and prints the layer surface, sensors and shell status.

## The `ow` command (`bin/ow`)

| Command | Does |
|---|---|
| `ow start` / `stop` / `restart` | run `qs -c outerwilds` detached / kill it / both |
| `ow status` | `ipc call system status` (sensors, scene visibility, notifications, notes) |
| `ow log` | `qs -c outerwilds log` (first ERROR lines name file and line) |
| `ow doctor` | dependency and environment check |
| `ow rescan` | re-read `widgets/user/*/widget.json` without restarting |
| `ow new-widget <name>` | scaffold `widgets/user/<name>/` (Main.qml + widget.json) |

## IPC (`qs -c outerwilds ipc call <target> <function> [arg]`)

These work without keyboard focus, so they are what Hyprland binds should call.

| Target | Functions |
|---|---|
| `map` | `toggle` `show` `hide` (inside Rumor Mode, `toggle` = back to the map) |
| `rumor` | `toggle` `show` `hide` |
| `hud` | `toggle` `show` `hide` (the bottom-right loop/speed panel) |
| `keys` | `toggle` `show` `hide` (Control Centre on the KEYS tab) |
| `settings` | `toggle` `show` `hide` (Control Centre) |
| `launcher` | `toggle` `show` `hide` (big app launcher) |
| `signalscope` | `toggle` `equip` `unequip` `next` `prev` `playpause` `mute` `volup` `voldown` `nexttrack` `prevtrack` |
| `screentime`, `bubble`, `network`, `wallpaper` | `toggle` `show` `hide` (big panels) |
| `bridge` | `fly <planetId>` (fly the camera to a planet and lock on) |
| `scene` | `status` (what the bridge sees: desktopVisible, windows, last panel, overlays) |
| `system` | `status`, `refresh` (re-read disks) |
| `widgets` | `rescan` |

Example: `qs -c outerwilds ipc call bridge fly dark_bramble`.

## Keys and mouse

**No keyboard key is fixed**: every key below is a rebindable action (Control Centre → KEYS; `Super+A`, `Ctrl+Shift+X`, a lone
`Ctrl` for drift all work). Defaults, from `data/Keybinds.qml`:

| Group | Defaults |
|---|---|
| In the scene | `N` Map View · `L` Rumor Map · `E` widget control · `F1` key list · `H` loop/speed panel · `Q` Signalscope · launcher: no key |
| Flying | `W/S` forward/back (zoom while locked) · `A/D` turn · `Space` up · `Shift` down · `Ctrl` toggles drift · `Esc` let go of the planet |
| Signalscope (while equipped) | `←/→` channel · `P` play/pause · `,` `.` track · `M` mute · `↑/↓` volume |
| Map View + Rumor Map | arrows move · `Return` open/confirm · `Esc` back/close · `=` `-` zoom |
| Map View | `R` Rumor Mode |
| Rumor Map | `/` search · `U` unread only · `O` open app · `P` pin · `X` dismiss · `Home` fit all |
| Mouse (fixed) | click = centre on a planet · double-click = lock and orbit · `Alt`+click = fly in · scroll = zoom/thrust |

Window shortcuts only fire while the scene has keyboard focus. For keys that must always work, bind the IPC calls in Hyprland.

## Hyprland binds

The project expects a bind file `~/.config/hypr/outerwilds.lua` (your Hyprland config is Lua) that calls the IPC above.
Three **submaps** are used: `ow_capture` (empty; the Control Centre switches to it while it records a key so Hyprland binds do not
swallow combos), `reset` (the normal map, restored afterwards; a 20 s failsafe always restores it) and the Signalscope key submap
(restored automatically when the scope is stowed). Read your existing binds before adding new ones.
An escape hatch should always exist: a bind running `qs kill -c outerwilds`.

## Control Centre (`E`, or `ipc call settings toggle`)

Tabs: **widgets**, **keys**, **options**.

* Widgets: search, expand a widget to change **widget type, planet, size, orbit speed, orbit distance, visibility (near planet /
  always), orbit axis (tilt and turn), key (for launcher/map/rumor/scope widgets)** and its **options**; `RESET`, `REMOVE`,
  `SHOW PLANET`. `+ ADD` lists the whole catalog (removed widgets stay offered); new widgets go on the planet you are focused on.
* Every orbit number has a slider **and a typed box**; typed values are never clamped (only NaN, size ≤ 0 and negative radius are refused).
* `ALL ORBITS` multiplies every orbit speed. `REMOVE ALL` / `RESET ALL WIDGETS` exist with confirmation.
* Keys: rebind any action; conflicts are only flagged between actions that can be live at the same time.
* Options: show/hide the loop panel, shrink-when-far.

## Files it writes

| Path | What |
|---|---|
| `~/.config/quickshell/outerwilds/widgets.json` | widget/key/UI settings; edit by hand and the scene follows. Delete to return to defaults |
| `~/.local/share/ow-shell/notes.txt` | the Notes widget text (saved 0.8 s after the last edit) |
| `~/.local/share/ow-shell/shiplog.json` | notification history, read state and pins |

The core shell writes nothing else (sensors are read-only). The ported Serpantinum panels (screentime, wallpaper, network) may keep data of their own: check `widgets/serp/panels/` if you need to know.
