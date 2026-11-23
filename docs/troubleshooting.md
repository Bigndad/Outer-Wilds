# Troubleshooting

First steps for anything: `ow doctor`, then `ow log` (the first `ERROR` lines name the file and line), then
`qs -c outerwilds ipc call scene status` and `... system status`.

| Symptom | Likely cause | Fix |
|---|---|---|
| `X is not a type` | type not in the root `qmldir` | add `Name 1.0 folder/Name.qml` (or `singleton ...`) |
| `SignalscopeMpris is not a type` (or any scope) at `shell.qml` | same | same |
| Scene invisible | a window is open on the workspace (by design), or `desktopVisible` is false | go to an empty workspace; `ipc call scene status`; check `skipPattern` |
| Scene invisible on an empty workspace | `qs` not running, or layer fighting | `hyprctl layers | grep outerwilds`; layer must be Bottom |
| Scene does not reach the screen edges | bar's reserved strip | `exclusionMode: ExclusionMode.Ignore` on the scene window (applied in `shell.qml`) |
| Keys do nothing | the scene lacks keyboard focus (window shortcuts) | click the scene, or bind the IPC call in Hyprland |
| A key combo cannot be bound | Hyprland swallows it | the Control Centre switches to the `ow_capture` submap while recording; if it hangs, the 20 s failsafe restores `reset` |
| Arrow/P/M keys stay hijacked | Signalscope key submap still active | stow the scope; the shell resets the submap on unequip |
| New drop-in widget not in `+ ADD` | not scanned or bad JSON | `ow rescan`; the log says which `widget.json` was skipped and why |
| Widget options do nothing | `cfg` not declared / key mismatch | `property var cfg` in `Main.qml`, same `key` as in `widget.json` |
| Widget tiny / huge | hard-coded pixels | multiply by `w.ui`; check `designW` |
| App sphere / Map "apps" empty | Quickshell API name mismatch | look for undefined-property warnings about `DesktopEntry` |
| HUD globe idle, no audio bands | `cava` missing or nothing playing | install `cava`; check `ipc call system status` → `hud.cava` |
| No notifications in the Rumor Map | `busctl` monitor not running | status → `notifications.busSeen`; it restarts itself after 3 s |
| Sensors read 0 | wrong hwmon/GPU path | `ow doctor` prints hwmon names and the GPU busy file |
| Planet looks wrong after a shader edit | `.qsb` not rebuilt | `shaders/build.sh`; check `qsb` path (`QSB=...`) |
| `qs` crashes randomly | Qt 6.11 / 6.12 mismatch in the `noctalia-qs` build | rebuild the package with your AUR helper |
| `widgets.json` ignored | invalid JSON | the log says so; fix or delete the file (defaults return) |
| Panel (`E`) text boxes do not take typing | panel lost keyboard focus | click inside the panel |
| Everything fine on PC but fails on the Mint laptop | a logic singleton imports `Quickshell` | keep logic singletons Quickshell-free ([architecture.md](architecture.md)) |

## Resetting

* One widget: Control Centre → RESET. All widgets: RESET ALL WIDGETS. Everything: delete `widgets.json`.
* Notification history: delete `~/.local/share/ow-shell/shiplog.json`. Notes: `notes.txt` in the same folder.
* Escape hatch if the shell misbehaves: `qs kill -c outerwilds` (bind it to a key).
