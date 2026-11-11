#!/usr/bin/env python3
"""Port the remaining Serpantinum faces (CPU / RAM / disk / temp usage, timers, compact weather) into serp/.
Usage: python3 port_more.py /path/to/serpantinum      (the checkout is never modified)
Run it AFTER port.py and port_music.py (port.py rewrites shim/I18n.qml). Safe to run repeatedly."""
import json, pathlib, re, sys

repo = pathlib.Path(sys.argv[1])
qs = repo / "src" / "quickshell"
here = pathlib.Path(__file__).resolve().parent
faces, shim = here / "faces", here / "shim"
faces.mkdir(exist_ok=True); shim.mkdir(exist_ok=True)
problems = []

FACES = {   # face name -> upstream folder under widgets/faces
    "UsageFaceBase": "usage", "UsageFaceCircleBase": "usage",
    "CpuFace": "usage", "CpuFaceCircle": "usage", "RamFace": "usage", "RamFaceCircle": "usage",
    "DiskFace": "usage", "DiskFaceCircle": "usage", "TempFace": "usage", "TempFaceCircle": "usage",
    "TimerFace": "timer", "TimerFacePomodoro": "timer", "TimerFaceStopwatch": "timer", "TimerFaceTimer": "timer",
    "WeatherFaceCompact": "weather",
}
FOCUS = ["FocusPanel", "FocusPomodoroPanel", "FocusStopwatchPanel", "FocusTimeCard", "FocusTimerControls", "FocusTimerPanel"]
SHIM_TYPES = [
    "singleton SysData 1.0 SysData.qml", "singleton FocusTimer 1.0 FocusTimer.qml",
    "singleton TimerState 1.0 TimerState.qml", "singleton DesktopMenuController 1.0 DesktopMenuController.qml",
    "SystemUsageCard 1.0 SystemUsageCard.qml", "TimeSelector 1.0 TimeSelector.qml",
] + [f"{n} 1.0 {n}.qml" for n in FOCUS]
SERP_TYPES = ["SunStationCpu", "HollowsLanternTemp", "BrittleHollowRam", "BrittleHollowDisk",
              "AshTwinTimer", "GiantsDeepTimer", "GiantsDeepStopwatch", "QuantumMoonWeather"]

REL_IMPORT = re.compile(r'^\s*import "(\.\./)+[\w/]*"\s*$')

def clean(text, add_shim):
    text = "\n".join(l for l in text.splitlines() if not REL_IMPORT.match(l)) + "\n"
    if add_shim:
        text = text.replace("import QtQuick\n", 'import QtQuick\nimport "../shim"\n', 1)
    return text

def find(rel):
    p = qs / rel
    if p.exists(): return p
    hits = sorted(qs.rglob(pathlib.Path(rel).name))
    return hits[0] if hits else None

# ---- faces ----
for name, sub in FACES.items():
    src = find(f"widgets/faces/{sub}/{name}.qml")
    if src is None: problems.append(f"{name}.qml not found upstream"); continue
    (faces / f"{name}.qml").write_text(clean(src.read_text(), True))

# ---- shim components copied from upstream ----
src = find("reusables/display/SystemUsageCard.qml")
if src: (shim / "SystemUsageCard.qml").write_text(clean(src.read_text(), False))
else: problems.append("SystemUsageCard.qml not found upstream")
src = find("reusables/inputs/TimeSelector.qml")
if src: (shim / "TimeSelector.qml").write_text(clean(src.read_text(), False))
else: problems.append("TimeSelector.qml not found upstream")
for n in FOCUS:
    src = find(f"reusables/display/focustimer/{n}.qml")
    if src: (shim / f"{n}.qml").write_text(clean(src.read_text(), False))
    else: problems.append(f"{n}.qml not found upstream")

# FocusTimer: same logic, but notifications go through notify-send and state lives in our own runtime dir
src = find("singletons/system/FocusTimer.qml")
if src:
    t = clean(src.read_text(), False)
    t = t.replace('((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/serpantinum/focustime")',
                  '((Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/outerwilds/focustime")')
    t = t.replace('notifyProc.command = ["serpantinum-core", "notify", "--app", I18n.t("quickactions.timer.notification.app_name"), "--icon", icon, "--", title, message];',
                  'notifyProc.command = ["notify-send", "-a", I18n.t("quickactions.timer.notification.app_name"), "-i", icon, title, message];')
    if "serpantinum-core" in t: problems.append("shim/FocusTimer.qml still calls serpantinum-core (upstream changed?)")
    if "Quickshell.Io" in t and "mkdir" not in t:
        # the state file needs its folder to exist
        t = t.replace("    FileView {\n        id: stateFile",
                      '    Process { running: true; command: ["mkdir", "-p", root.getStorageDir()] }\n\n    FileView {\n        id: stateFile', 1)
    (shim / "FocusTimer.qml").write_text(t)
else:
    problems.append("FocusTimer.qml not found upstream")

# ---- hand-written shims ----
(shim / "TimerState.qml").write_text("""pragma Singleton
import QtQuick

// Upstream shows running timers in its bar; here nothing reads it, FocusTimer just writes to it.
QtObject { property var entries: [] }
""")
(shim / "DesktopMenuController.qml").write_text("""pragma Singleton
import QtQuick

// Upstream's right-click desktop menu does not exist here.
QtObject { readonly property bool isVisible: false }
""")
(shim / "SysData.qml").write_text("""pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../.."

// Serpantinum's SysData, fed by the config's own Sensors singleton (CPU, RAM, CPU temperature).
// Disk usage of / comes from `df`, polled only while a face is visible.
Singleton {
    id: root

    readonly property int cpu: Sensors.cpuPercent
    readonly property int ramPercent: Sensors.ramPercent
    readonly property real ramGb: Sensors.ramUsedGb
    readonly property int temp: Math.round(Sensors.cpuTempC)
    property real netRx: 0
    property real netTx: 0
    property int diskPercent: 0
    property real diskGb: 0.0
    property real diskTotalGb: 0.0

    property int subscribers: 0
    function subscribe() { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    Timer {
        interval: 30000
        running: root.subscribers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -B1 --output=used,size / | tail -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\\s+/);
                const used = parseFloat(p[0]) || 0, total = parseFloat(p[1]) || 0;
                if (total > 0) {
                    root.diskGb = used / 1073741824;
                    root.diskTotalGb = total / 1073741824;
                    root.diskPercent = Math.round(used / total * 100);
                }
            }
        }
    }
}
""")

# faces/ needs its own registry for the base types (siblings are not found without one)
(faces / "qmldir").write_text("UsageFaceBase 1.0 UsageFaceBase.qml\nUsageFaceCircleBase 1.0 UsageFaceCircleBase.qml\nTimerFace 1.0 TimerFace.qml\n")

# the hand-made GlassFill stand-in must carry the properties SystemUsageCard / TimeSelector set
gf = shim / "GlassFill.qml"
if gf.exists() and "property bool allowed" not in gf.read_text():
    gt = gf.read_text()
    gt = gt.replace("    property real tintAmount: 0\n", "    property real tintAmount: 0\n    property bool allowed: true\n    readonly property bool active: false\n    property real frost: 0\n    property real rim: 0\n    property real saturation: 1.0\n    property real thickness: -1\n    property real tintStrength: 0.5\n    property bool forceClear: false\n    property bool forceOpaque: false\n    property int nestLevel: 0\n    property real topLeftRadius: radius\n    property real topRightRadius: radius\n    property real bottomLeftRadius: radius\n    property real bottomRightRadius: radius\n", 1)
    gf.write_text(gt)

wb = shim / "WallpaperBlur.qml"
if wb.exists() and "standalone" not in wb.read_text():
    wb.write_text("import QtQuick\n// Serpantinum blurs the wallpaper behind its cards; here it is a no-op placeholder.\nItem {\n    property real radius: 0\n    property bool standalone: false\n    property bool surfaceEnabled: false\n}\n")

# ---- qmldir lines ----
def append_missing(path, lines):
    cur = path.read_text() if path.exists() else ""
    have = {l.split()[-3] for l in cur.splitlines() if len(l.split()) >= 3 and not l.startswith("#")}
    add = [l for l in lines if l.split()[-3] not in have]
    if add: path.write_text(cur.rstrip("\n") + "\n" + "\n".join(add) + "\n")
    return add
a1 = append_missing(shim / "qmldir", SHIM_TYPES)
a2 = append_missing(here / "qmldir", [f"{n} 1.0 {n}.qml" for n in SERP_TYPES])

# ---- English strings for every I18n key the new files use ----
used_files = [faces / f"{n}.qml" for n in FACES] + [shim / f"{n}.qml" for n in FOCUS + ["SystemUsageCard", "FocusTimer", "TimeSelector"]]
keys = sorted({k for f in used_files if f.exists() for k in re.findall(r'I18n\.t\("([^"]+)"', f.read_text())})
en = json.loads((repo / "src/assets/languages/en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."): cur = cur[p]
    return cur
found = {}
for k in keys:
    try: found[k] = dig(k)
    except (KeyError, TypeError): problems.append(f"I18n key not in en.json: {k} (the face will show the raw key)")
i18n = shim / "I18n.qml"
txt = i18n.read_text()
m = re.search(r'readonly property var strings: \((\{.*?\})\)\n', txt, re.S)
if m:
    d = json.loads(m.group(1)); d.update(found)
    i18n.write_text(txt[:m.start(1)] + json.dumps(d, indent=8) + txt[m.end(1):])
else:
    problems.append("could not find the strings map in shim/I18n.qml (run port.py then port_music.py first)")

# ---- self-check ----
all_src = "\n".join(f.read_text() for f in used_files if f.exists())
theme = (shim / "ThemeBackend.qml").read_text()
miss = sorted(p for p in set(re.findall(r'\bThemeBackend\.(\w+)', all_src)) if not re.search(rf'\b{p}\b', theme))
TOKENS = {"red": "#e5604a", "overlay0": "#5E5444", "overlay1": "#7A6E5A", "overlay2": "#968A74", "pink": "#C98F86",
          "sapphire": "#6FA3B0", "teal": "#6FA89A", "peach": "#D9945B", "yellow": "#E3B958", "green": "#8FB070",
          "blue": "#7B9CC4", "surface2": "#4A4234", "subtext1": "#CDBFA6", "subtext0": "#B0A28A", "mantle": "#080a0f"}
add = [p for p in miss if p in TOKENS]
if add and theme.rstrip().endswith("}"):
    cut = theme.rstrip().rfind("}")
    (shim / "ThemeBackend.qml").write_text(theme[:cut] + "\n    // added by port_more.py\n" +
        "".join(f'    property color {p}: "{TOKENS[p]}"\n' for p in add) + theme[cut:])
    print("added to shim/ThemeBackend.qml:", ", ".join(add)); miss = [p for p in miss if p not in add]
if miss: problems.append(f"shim/ThemeBackend.qml lacks: {', '.join(miss)}")
scaler = (shim / "Scaler.qml").read_text()
for p in sorted(set(re.findall(r'\bScaler\.(\w+)', all_src))):
    if not re.search(rf'\b{p}\b', scaler): problems.append(f"shim/Scaler.qml lacks {p}")
for p in sorted(set(re.findall(r'\bSysData\.(\w+)', all_src))):
    if not re.search(rf'\b{p}\b', (shim / "SysData.qml").read_text()): problems.append(f"shim/SysData.qml lacks {p}")
for p in sorted(set(re.findall(r'\bWeather\.(\w+)', (faces / "WeatherFaceCompact.qml").read_text() if (faces / "WeatherFaceCompact.qml").exists() else ""))):
    if not re.search(rf'\b{p}\b', (shim / "Weather.qml").read_text()): problems.append(f"shim/Weather.qml lacks {p}")
shim_files = {p.stem for p in shim.glob("*.qml")} | {p.stem for p in faces.glob("*.qml")}
qtish = set("""Item Rectangle Text Row Column Image Timer Connections MultiEffect NumberAnimation SpringAnimation ColorAnimation
Repeater RowLayout ColumnLayout Shape ShapePath Behavior MouseArea ShaderEffect ShaderEffectSource Canvas Flickable Loader Process
StdioCollector FileView Scale Rotation Translate Gradient GradientStop PropertyAnimation SequentialAnimation ParallelAnimation
PathLine PathArc PathAngleArc LinearGradient FontLoader Component QtObject Singleton Window Instantiator ListModel ListElement
Layout AnimatedImage PauseAnimation PropertyAction TapHandler WheelHandler HoverHandler DragHandler PointHandler Binding
SplitParser Shortcut GridLayout GridView ListView TextInput TextEdit Flow Grid Clip Item State Transition PropertyChanges
RegularExpressionValidator TimerSegment AnchorChanges StateGroup OpacityAnimator RotationAnimator ScaleAnimator XAnimator YAnimator UniformAnimator""".split())
for t in sorted(set(re.findall(r'(?m)^\s*(?:\w+:\s*)?([A-Z]\w+)\s*\{', all_src)) - qtish - shim_files):
    problems.append(f"type '{t}' is used but not provided in shim/ or faces/")
if not (here / "assets/shaders").exists(): problems.append("assets/shaders missing (run port.py)")

print(f"faces: {len(FACES)} | focus panels: {len(FOCUS)} | I18n keys: {len(found)} | qmldir lines added: {len(a1) + len(a2)}")
if problems:
    print("\nCHECK THESE:"); [print(" -", p) for p in problems]
else:
    print("self-check clean")
