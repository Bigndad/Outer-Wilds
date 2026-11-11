#!/usr/bin/env python3
"""Port ilyamiro's wallpaper picker (and the screentime panel) into serp/panels.
Usage: python3 port_panels.py /path/to/serpantinum      (the checkout is never modified)
Run AFTER port.py, port_music.py and port_more.py. Safe to run repeatedly."""
import json, pathlib, re, shutil, sys

repo = pathlib.Path(sys.argv[1]); qs = repo / "src" / "quickshell"
here = pathlib.Path(__file__).resolve().parent
shim, panels, scripts = here / "shim", here / "panels", here / "scripts"
for d in (shim, panels, scripts): d.mkdir(exist_ok=True)
problems = []
REL_IMPORT = re.compile(r'^\s*import "(\.\./)+[\w/]*"\s*$')

def clean(text, shimpath):
    text = "\n".join(l for l in text.splitlines() if not REL_IMPORT.match(l)) + "\n"
    return text.replace("import QtQuick\n", f'import QtQuick\nimport "{shimpath}"\n', 1) if shimpath else text

def must_replace(text, old, new, what):
    if old not in text: problems.append(f"patch not applied ({what}): upstream changed?"); return text
    return text.replace(old, new)

def append_missing(path, lines):
    cur = path.read_text() if path.exists() else ""
    have = {l.split()[-3] for l in cur.splitlines() if len(l.split()) >= 3 and not l.startswith("#")}
    add = [l for l in lines if l.split()[-3] not in have]
    if add: path.write_text(cur.rstrip("\n") + "\n" + "\n".join(add) + "\n")
    return add

# ============================== WALLPAPER ==============================
t = clean((qs / "wallpaper/WallpaperPicker.qml").read_text(), "../shim")
t = must_replace(t, '["serpantinum-core", "monitors"]', '["hyprctl", "-j", "monitors"]', "monitor list")
t = must_replace(t, '''            "serpantinum-core",
            "wallpaper",
            "index",''', '''            "python3",
            Caching.serpantinumDir + "/scripts/wp_index.py",''', "indexer")
# the picker refers to a host window by id (masterWindow); make it a property the host sets
t = must_replace(t, "    id: window\n", "    id: window\n    property var masterWindow: null\n", "masterWindow")
t = t.replace('readonly property string scriptDir: Caching.serpantinumDir + "/scripts/wallpaper"',
              'readonly property string scriptDir: Caching.serpantinumDir + "/scripts/wallpaper"')
(panels / "WallpaperPicker.qml").write_text(t)
sd = scripts / "wallpaper"; sd.mkdir(exist_ok=True)
for f in (repo / "src/scripts/wallpaper").iterdir():
    shutil.copy(f, sd / f.name); (sd / f.name).chmod(0o755)

COPY = {"reusables/buttons/CanvasIconButton.qml": "CanvasIconButton.qml",
        "reusables/inputs/Input.qml": "Input.qml", "reusables/inputs/Switch.qml": "Switch.qml"}
for src, dst in COPY.items():
    (shim / dst).write_text(clean((qs / src).read_text(), None))

(shim / "Sounds.qml").write_text("""pragma Singleton
import QtQuick

// Upstream plays UI sounds; here every call is a no-op.
QtObject { function playSfx(name, volume) {} }
""")
(shim / "Caching.qml").write_text("""pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Cache / runtime folders in Serpantinum's API, rooted in our own config's names.
Singleton {
    id: root
    // folder that contains assets/ and scripts/ (the parent of shim/)
    readonly property string serpantinumDir: Qt.resolvedUrl("..").toString().replace("file://", "").replace(/\\/+$/, "")
    readonly property string qsDir: serpantinumDir
    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string cacheRoot: (Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/outerwilds"
    readonly property string runRoot: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/outerwilds"
    readonly property string stateRoot: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/outerwilds"
    readonly property string runDir: runRoot
    readonly property string logDir: runRoot + "/log"
    function getCacheDir(name) { return name ? cacheRoot + "/" + name : cacheRoot; }
    function getRunDir(name) { return name ? runRoot + "/" + name : runRoot; }
    function getStateDir(name) { return name ? stateRoot + "/" + name : stateRoot; }

    Process {
        running: true
        command: ["mkdir", "-p", root.cacheRoot + "/wallpaper", root.runRoot + "/wallpaper", root.runRoot + "/focustime",
                  root.runRoot + "/music", root.runRoot + "/log", root.stateRoot + "/focustime"]
    }
}
""")
(shim / "Config.qml").write_text("""pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Serpantinum's settings store. Optional overrides live in ~/.config/outerwilds/settings.json, e.g.
//   { "wallpaperDir": "/home/you/Pictures/Wallpapers" }
Singleton {
    id: root
    property var rawSettings: ({})
    signal settingsLoaded()
    function getSetting(key, fallback) {
        const v = rawSettings ? rawSettings[key] : undefined;
        return (v === undefined || v === null) ? fallback : v;
    }
    FileView {
        path: (Quickshell.env("HOME") || "") + "/.config/outerwilds/settings.json"
        printErrors: false
        onLoaded: {
            try { root.rawSettings = JSON.parse(text()); } catch (e) { root.rawSettings = ({}); }
            root.settingsLoaded();
        }
    }
}
""")
(shim / "Wallpaper.qml").write_text("""pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Serpantinum's wallpaper engine API, applied through Noctalia v5:  noctalia msg wallpaper-set [<output>] <path>
// (Noctalia draws the wallpaper; it re-themes from it when [theme].source = "wallpaper").
Singleton {
    id: root
    property var names: ({})        // output (or "all") -> file name currently set
    readonly property string cacheDir: Caching.getCacheDir("wallpaper")

    function getWallpaper(screenName) {
        return names[screenName] || names["all"] || "";
    }
    function getWallpaperPath(screenName) { return ""; }
    function setPlayback(screenName, state) {}
    function clearWallpaper(screenName) {}
    function shuffle(screenName, transition) { runner.exec(["noctalia", "msg", "wallpaper-random"]); }

    function setWallpaper(screenName, path, transition) {
        const base = String(path).split("/").pop();
        const n = Object.assign({}, names);
        n[screenName] = base;
        if (screenName === "all") { for (const k in n) if (k !== "all") n[k] = base; }
        names = n;
        const cmd = screenName === "all" ? ["noctalia", "msg", "wallpaper-set", path]
                                         : ["noctalia", "msg", "wallpaper-set", screenName, path];
        runner.exec(cmd);
        // remember it for the picker (current_*_name, history.txt)
        const dir = cacheDir, nm = screenName === "all" ? "default" : screenName;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1"; printf %s "$2" > "$1/current_$3_name"; grep -vxF -- "$2" "$1/history.txt" 2>/dev/null > "$1/history.tmp"; printf "%s\\\\n" "$2" >> "$1/history.tmp"; mv "$1/history.tmp" "$1/history.txt"',
            "sh", dir, base, nm]);
    }

    QtObject {
        id: runner
        function exec(cmd) { Quickshell.execDetached(cmd); }
    }
}
""")

SHIM_TYPES = ["singleton Sounds 1.0 Sounds.qml", "singleton Caching 1.0 Caching.qml", "singleton Config 1.0 Config.qml",
              "singleton Wallpaper 1.0 Wallpaper.qml", "CanvasIconButton 1.0 CanvasIconButton.qml",
              "Input 1.0 Input.qml", "Switch 1.0 Switch.qml"]
q = shim / "qmldir"
lines = [l for l in q.read_text().splitlines() if not re.match(r'\s*singleton Caching\b', l)]   # replace the old Caching entry
q.write_text("\n".join(lines) + "\n")
a1 = append_missing(q, SHIM_TYPES)
pass

# ---- I18n strings ----
en = json.loads((repo / "src/assets/languages/en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."): cur = cur[p]
    return cur
used_files = [panels / "WallpaperPicker.qml"] + [shim / n for n in COPY.values()]
keys = sorted({k for f in used_files for k in re.findall(r'I18n\.t\("([^"]+)"', f.read_text())})
found = {}
FALLBACK = {"wallpaper.filters.history": "History"}     # key the upstream picker uses but its en.json lacks
for k in keys:
    try: found[k] = dig(k)
    except (KeyError, TypeError):
        if k in FALLBACK: found[k] = FALLBACK[k]
        else: problems.append(f"I18n key not in en.json: {k}")
i18n = shim / "I18n.qml"; txt = i18n.read_text()
m = re.search(r'readonly property var strings: \((\{.*?\})\)\n', txt, re.S)
if m:
    d = json.loads(m.group(1)); d.update(found)
    i18n.write_text(txt[:m.start(1)] + json.dumps(d, indent=8) + txt[m.end(1):])
else: problems.append("could not find the strings map in shim/I18n.qml")

# ---- self-check ----
def check(files, label):
    src = "\n".join(f.read_text() for f in files)
    theme = (shim / "ThemeBackend.qml").read_text()
    miss = sorted(p for p in set(re.findall(r'\bThemeBackend\.(\w+)', src)) if not re.search(rf'\b{p}\b', theme))
    TOKENS = {"red": "#e5604a", "overlay0": "#5E5444", "overlay1": "#7A6E5A", "overlay2": "#968A74", "pink": "#C98F86",
              "sapphire": "#6FA3B0", "teal": "#6FA89A", "peach": "#D9945B", "yellow": "#E3B958", "green": "#8FB070",
              "blue": "#7B9CC4", "surface2": "#4A4234", "subtext1": "#CDBFA6", "subtext0": "#B0A28A", "mantle": "#080a0f",
              "lavender": "#A9A3C9", "maroon": "#B5645A", "flamingo": "#D8A89A", "rosewater": "#E3C7B5", "sky": "#7FB7C9"}
    add = [p for p in miss if p in TOKENS]
    if add:
        th = (shim / "ThemeBackend.qml").read_text(); cut = th.rstrip().rfind("}")
        (shim / "ThemeBackend.qml").write_text(th[:cut] + "\n    // added by port_panels.py\n" +
            "".join(f'    property color {p}: "{TOKENS[p]}"\n' for p in add) + th[cut:])
        miss = [p for p in miss if p not in TOKENS]
    if miss: problems.append(f"{label}: shim/ThemeBackend.qml lacks {', '.join(miss)}")
    for s in ("Config", "Wallpaper", "Caching", "Scaler", "Sounds", "DesktopMenuController", "SysData", "FocusTimer"):
        f = shim / f"{s}.qml"
        if not f.exists(): continue
        body = f.read_text()
        for p in sorted(set(re.findall(rf'\b{s}\.(\w+)', src))):
            if not re.search(rf'\b{p}\b', body): problems.append(f"{label}: shim/{s}.qml lacks {p}")
    shim_files = {p.stem for p in shim.glob("*.qml")} | {p.stem for p in (here / "faces").glob("*.qml")} | {f.stem for f in files} | {p.stem for p in (panels / "screentime").glob("*.qml")}
    qtish = set("""Item Rectangle Text Row Column Image Timer Connections MultiEffect NumberAnimation SpringAnimation ColorAnimation
Repeater RowLayout ColumnLayout Shape ShapePath Behavior MouseArea ShaderEffect ShaderEffectSource Canvas Flickable Loader Process
StdioCollector FileView Scale Rotation Translate Gradient GradientStop PropertyAnimation SequentialAnimation ParallelAnimation
PathLine PathArc PathAngleArc LinearGradient FontLoader Component QtObject Singleton Window Instantiator ListModel ListElement
Layout AnimatedImage PauseAnimation PropertyAction TapHandler WheelHandler HoverHandler DragHandler PointHandler Binding
SplitParser Shortcut GridLayout ListView GridView PathView Path TextInput TextEdit Flow Grid State Transition PropertyChanges
RegularExpressionValidator ScriptAction FolderListModel MediaPlayer VideoOutput AudioOutput FrameAnimation TextMetrics FocusScope
Popup ScrollBar ScrollView Drag DropArea OpacityMask DropShadow GaussianBlur FastBlur Colorize ColorOverlay RadialGradient
SystemClock Scope PanelWindow Variants PathAttribute PathPercent PathCubic PathQuad Matrix4x4 SmoothedAnimation""".split())
    for tname in sorted(set(re.findall(r'(?<![\w.])([A-Z]\w+)\s*\{', src)) - qtish - shim_files):
        problems.append(f"{label}: type '{tname}' is used but not provided")
check([panels / "WallpaperPicker.qml"] + [shim / n for n in COPY.values()], "wallpaper")


# ============================== SCREENTIME ==============================
wb = qs / "guide/wellbeing"; st = panels / "screentime"; st.mkdir(exist_ok=True)
KEEP = ["WellbeingState", "WellbeingHeader", "WellbeingStatsRow", "WellbeingMidRow", "WellbeingBottomPanel", "WellbeingDailyView",
        "WellbeingWeekView", "WellbeingWeekChart", "WellbeingWeekDetails", "WellbeingMetric"]   # no settings / limits / app picker
for n in KEEP:
    src_t = clean((wb / f"{n}.qml").read_text(), "../../shim")
    if n == "WellbeingState":
        src_t = must_replace(src_t, 'let cmd = ["serpantinum-core", "screentime", "stats", getIsoDate(tabRoot.activeDate)];',
                             'let cmd = ["python3", Caching.serpantinumDir + "/scripts/screentime.py", "stats", getIsoDate(tabRoot.activeDate)];', "stats command")
    if n == "WellbeingHeader":      # the gear opens a settings view that is not ported
        src_t = must_replace(src_t, 'buttonIcon: "\U000f0493"' if False else 'iconFontSize: rootObj.s(16)\n        accentColor: header.tab.isSettingsView',
                             'iconFontSize: rootObj.s(16)\n        visible: false\n        accentColor: header.tab.isSettingsView', "hide settings gear")
    (st / f"{n}.qml").write_text(src_t)
(st / "qmldir").write_text("".join(f"{n} 1.0 {n}.qml\n" for n in KEEP))

(shim / "GuideTab.qml").write_text("""import QtQuick

// Stand-in for Serpantinum's settings-window tab base: supplies rootObj (scaling + folders) and builds all stages at once.
Item {
    id: guideTabRoot
    property var rootObj: QtObject {
        function s(v) { return v; }
        property var appPaths: QtObject {
            function getRunDir(name) { return Caching.getRunDir(name); }
            function getStateDir(name) { return Caching.getStateDir(name); }
        }
        property int currentTab: 0
        property int currentSubTab: 0
        property var pendingHighlightItem: null
        property string highlightedSettingId: ""
        property int deferredBuilds: 0
    }
    property int tabIndex: 0
    property int subTabIndex: -1
    readonly property bool isCurrent: true
    property bool revealed: visible
    anchors.fill: parent
    property int deferredStages: 0
    property int deferredStage: deferredStages
    readonly property bool deferredBuilding: false
}
""")
cfg = shim / "Config.qml"; ct = cfg.read_text()
if "function setSetting" not in ct:
    cfg.write_text(ct.replace("    FileView {", """    function setSetting(key, value) {      // in memory only (the wellbeing limits UI is not ported)
        const n = Object.assign({}, rawSettings); n[key] = value; rawSettings = n;
    }
    FileView {""", 1))
a2 = append_missing(shim / "qmldir", ["GuideTab 1.0 GuideTab.qml"])

used_files = used_files + [st / f"{n}.qml" for n in KEEP]
keys = sorted({k for f in used_files for k in re.findall(r'I18n\.t\("([^"]+)"', f.read_text())})
found = {}
for k in keys:
    try: found[k] = dig(k)
    except (KeyError, TypeError):
        if k in FALLBACK: found[k] = FALLBACK[k]
        else: problems.append(f"I18n key not in en.json: {k}")
txt = i18n.read_text(); m = re.search(r'readonly property var strings: \((\{.*?\})\)\n', txt, re.S)
if m:
    d = json.loads(m.group(1)); d.update(found)
    i18n.write_text(txt[:m.start(1)] + json.dumps(d, indent=8) + txt[m.end(1):])
check([panels / "ScreentimePanel.qml"] + [st / f"{n}.qml" for n in KEEP], "screentime")
print(f"screentime ported | I18n keys now: {len(found)}")

print(f"wallpaper picker ported | I18n keys: {len(found)} | qmldir lines added: {len(a1)}")
print("\nCHECK THESE:" if problems else "self-check clean")
for p in problems: print(" -", p)
