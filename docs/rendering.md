# Rendering, camera, loop, performance

## Bodies

Static data is in `bodyMeta` in `core/CameraRig.qml` (name, role label, colours, `bType`, `isSun`). Positions come from `bodyCoords`,
updated each frame by `updateOrbits`.

| id | name | bType | note |
|---|---|---|---|
| `sun` | The Sun | 0 | corona; radius follows the loop |
| `sun_station` | Sun Station | 1 | no baked texture |
| `ash_twin` / `ember_twin` | Ash / Ember Twin | 2 / 3 | sand moves between them over the loop (`sandcolumn.frag`) |
| `timber_hearth` | Timber Hearth | 4 | forest, white mountains, craters |
| `attlerock` | Attlerock | 5 | |
| `brittle_hollow` | Brittle Hollow | 6 | |
| `hollows_lantern` | Hollow's Lantern | 7 | volcanoes |
| `giants_deep` | Giant's Deep | 8 | |
| `dark_bramble` | Dark Bramble | 9 | vine core with light inside |
| `interloper` | The Interloper | 10 | comet tail |
| `quantum_moon` | Quantum Moon | 11 | hops between hosts; angle derived from loop time |

The `role` strings are labels for the planet's *job* (e.g. Timber Hearth = Workspaces). Widgets are not forced to match; the roles
are just defaults and display text.

## How a planet is drawn (`planets/PlanetShader.qml`)

1. **Bake once** (bodies with `bType` 2–10): `shaders/bake.frag` renders the planet's surface (terrain, clouds, craters, lava,
   vines...) into a 1024×512 equirectangular `RGBA16F` texture through a `ShaderEffectSource` with `live: false` and one
   `scheduleUpdate()`. It is **not** re-rendered per frame.
2. **Shade every frame**: `shaders/planet.frag` draws the sphere on a quad of `screenRadius × quadMultiplier` pixels (room for
   corona, tails, mountains, aura), sampling the baked texture and applying lighting from `lightDir` (view-space direction to the Sun),
   atmosphere, aura, the locked/target highlight, and the loop state (`shaderParams`: loopTime, sunProgress, swellRatio, locked).
3. Uniforms per planet: `baseColor`, `accentColor`, `lightDir`, `params`, `bakeInfo`, `camAngles`, `bakeTex`.
4. The label (name, and `ROLE:` when locked or sun) is a `Column` next to the sphere.

Cost scales with the quad's pixel area, so zooming in on one planet is the most expensive state.

## Changing shaders (rules that came from experience)

* Edit `shaders/*.frag`, then run `shaders/build.sh` (uses `qsb --qt6`). Commit the `.qsb` files: the shell loads those, not the `.frag`.
* Shader paths in QML are relative to the QML file (`../shaders/planet.frag.qsb`).
* **Never name a GLSL variable `gl` or `gl_*`.**
* Before delivering a shader change: compile with `glslangValidator`; convert with `spirv-cross` to GLSL 150 and 330 and compile
  both; pixel-diff every *other* body against the previous build (a change to one planet must not alter the others).
* Finished planets (see [ai-guide.md](ai-guide.md)) must stay pixel-identical.

## The 22-minute loop

`loopTime` runs 0 → 1320 s then resets (`timeScale` multiplies it; the debug speed slider in the bottom-right panel sets it).

| loopTime | Event |
|---|---|
| 0 – 1280 s | the Sun swells: radius `280 + progress³·⁵ × 400` |
| 1280 – 1290 s | collapse to radius 28 |
| 1290 – 1320 s | supernova: a ring expands to 8500 units; alpha fades 1305 → 1320 s |

While you are interacting after 1288 s, the loop is frozen so the supernova cannot catch you mid-action.

## Camera and input

* Camera: `camX/Y/Z`, `camYaw/Pitch`. Single click targets a planet (camera turns to it); double-click locks it (camera sits on a
  spherical shell, `lockDist`, and you orbit with the turn keys / drag). `Alt`+click or `flyTo(id)` autopilots in.
* Free flight: thrust 1800 (300 in drift mode). Classic mode damps to a stop; **drift** mode keeps velocity, with gentle resistance
  near the Sun/deep space that does not stop active travel.
* Held keys are tracked in `actDown` (action → bool). Input comes from `KeyHost` and the key handlers in `CameraRig`.
* Known bug left on purpose: double-click teleport is flaky; `Alt`+click is the dependable fly-in.

## Performance presets (Control Centre > OPTIONS > Rendering & performance)

`WidgetConfig.perfMode` = quality | balanced | performance | custom. A preset only sets four knobs (`fpsIdle`, `bakeW`, `sensorMs`,
`planetScale`); touching a knob by hand makes the mode `custom`. Consumers read the `eff*` properties (`effFpsIdle`, `effBakeW`,
`effSensorMs`, `effPlanetScale`, `effHudMs`), which switch to the Performance values while "Performance preset while on battery" is on
and the battery is discharging (`Sensors` polls `/sys/class/power_supply/BAT*/status` every 30 s, only when that option is on).

| | idle fps | bake | sensors | big-planet render scale |
|---|---|---|---|---|
| quality (= old defaults, pixel-identical) | 30 | 1024 | 2 s | 100% |
| balanced | 20 | 1024 | 3 s | 85% |
| performance | 15 | 512 | 5 s | 60% |

Render scale < 100% draws a planet quad wider than 240 px into a smaller `layer` texture (rounded to 32 px) and stretches it.
At 100% the layer is off. Control: `ow perf set|cycle|diag|status` (IPC target `perf`), keys `perf` / `diag` on the KEYS tab.
The diagnostics box (top right) shows scene frames per second (frames the scene actually worked on), the cap, and system CPU / GPU.

## Performance model

* Nothing runs when the scene is hidden: `active = NoctaliaBridge.desktopVisible`.
* The background `Canvas` repaints only when the camera or highlight changed; the supernova canvas only during the supernova.
* **Idle frame-rate cap**: `CameraRig.fpsIdle` (default 30). When nothing is moving (no keys, no drag, camera settled, Signalscope
  not out, time scale ≤ 4×) skipped frames change nothing, so Qt renders nothing. Any input or camera motion returns to the full
  display rate. `fpsIdle: 0` turns the cap off.
* Baked textures are generated once; only the sphere shader runs per frame.
* Sensors: one poller, 2 s; disks every 30 s; the Map View has no timers while closed.
* Widgets should not run timers faster than 1 s (`WidgetData.now` ticks every second).
* Remaining heavy case: one planet filling the screen (large quad, long fragment shader). Any fix there is a visual trade-off.
