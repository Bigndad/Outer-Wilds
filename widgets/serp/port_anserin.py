#!/usr/bin/env python3
"""Bring Anserin's widget faces onto the Outer Wilds orbit layer.

Usage (from anywhere):
    python3 ~/.config/quickshell/outerwilds/widgets/serp/port_anserin.py /path/to/Anserin [--dry-run]

What it does (safe to re-run; it never touches the Anserin checkout):
  1. copies the faces Anserin has that your Serpantinum port does not
     (5 clocks, 3 image frames, text, user card, GitHub heatmap) into serp/faces/
  2. copies the few reusables they need into serp/shim/ and adds the missing
     singleton members (colours, DateTime.time/dateBadge, SystemInfo user/avatar, i18n strings ...)
  3. writes one wrapper per face (serp/Anserin*.qml) and registers them in serp/qmldir
  4. adds them to the settings app catalog (data/WidgetConfig.qml) and puts a few on planets
     (widgets/WidgetLayer.qml baseDefs). Every edit is anchored; if an anchor is missing it prints the
     snippet instead of guessing. Originals are saved once as <file>.pre-anserin.

Not ported on purpose: Anserin's YoutubeFace (it moves a real Hyprland PiP window, which cannot follow an
orbiting card) and the bar / panels / lock screen / bubble / duck.
"""
import json, pathlib, re, shutil, sys

args = [a for a in sys.argv[1:] if not a.startswith("--")]
DRY = "--dry-run" in sys.argv
if not args:
    sys.exit(__doc__)
repo = pathlib.Path(args[0]).expanduser()
qs = repo / "src" / "quickshell"
assets = repo / "src" / "assets"
here = pathlib.Path(__file__).resolve().parent          # .../widgets/serp
root = here.parent.parent                                # the outerwilds config dir
if not (qs / "widgets" / "faces").is_dir():
    sys.exit(f"{repo} does not look like an Anserin checkout (no src/quickshell/widgets/faces)")

changed = []
def write(path, text):
    if DRY:
        changed.append(f"(dry) {path.relative_to(root)}")
        return
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    changed.append(str(path.relative_to(root)))

def backup(path):
    bak = path.with_name(path.name + ".pre-anserin")
    if path.exists() and not bak.exists() and not DRY:
        shutil.copy2(path, bak)

# ------------------------------------------------------------------ 1. faces
# src (under src/quickshell/widgets/faces) -> name in serp/faces
FACES = {
    "clock/ClockFaceDigital.qml": "ClockFaceDigital.qml",
    "clock/ClockFaceLockscreen.qml": "ClockFaceLockscreen.qml",
    "clock/ClockFaceMaterial.qml": "ClockFaceMaterial.qml",
    "clock/ClockFaceMinimal.qml": "ClockFaceMinimal.qml",
    "clock/ClockFaceStretched.qml": "ClockFaceStretched.qml",
    "image/ImageFaceRect.qml": "ImageFaceRect.qml",
    "image/ImageFaceRound.qml": "ImageFaceRound.qml",
    "image/ImageFaceRounded.qml": "ImageFaceRounded.qml",
    "text/TextFace.qml": "TextFace.qml",
    "user/UserFace.qml": "UserFace.qml",
    "github/GithubFace.qml": "GithubFace.qml",
}
# reusables -> serp/shim
REUSABLES = {
    "display/MaterialDigitGrid.qml": "MaterialDigitGrid.qml",
    "display/ImageBox.qml": "ImageBox.qml",
    "inputs/NumberSelector.qml": "NumberSelector.qml",
}
KEEP_QS = {"UserFace.qml", "GithubFace.qml", "NumberSelector.qml"}   # these really use Quickshell / Quickshell.Io

# small source fixes: Anserin's DateTime hands out zero-padded strings, ours has ints
FIXES = {
    "ClockFaceStretched.qml": [
        ('(DateTime.hour + ":" + DateTime.minute).split("")',
         '(String(DateTime.hour).padStart(2, "0") + ":" + String(DateTime.minute).padStart(2, "0")).split("")'),
    ],
    "ClockFaceDigital.qml": [
        ("text: DateTime.hour\n", 'text: String(DateTime.hour).padStart(2, "0")\n'),
        ("text: DateTime.minute\n", 'text: String(DateTime.minute).padStart(2, "0")\n'),
    ],
}

def clean(text, name, inshim):
    keep = name in KEEP_QS
    out = []
    for line in text.splitlines():
        if re.match(r'\s*import Quickshell\.(Wayland|Hyprland|Services)', line):
            continue
        if re.match(r'\s*import Quickshell', line) and not keep:
            continue
        if re.match(r'\s*import "(\.\./)+(reusables)?"\s*$', line):
            continue
        out.append(line)
    text = "\n".join(out) + "\n"
    if not inshim:
        text = text.replace("import QtQuick\n", 'import QtQuick\nimport "../shim"\n', 1)
    for a, b in FIXES.get(name, []):
        if a not in text:
            sys.exit(f"{name}: expected text not found, Anserin changed? -> {a!r}")
        text = text.replace(a, b)
    if not keep:
        assert "Quickshell" not in text, f"{name}: Quickshell reference left over"
    return text

for src, dst in FACES.items():
    write(here / "faces" / dst, clean((qs / "widgets" / "faces" / src).read_text(), dst, False))
for src, dst in REUSABLES.items():
    write(here / "shim" / dst, clean((qs / "reusables" / src).read_text(), dst, True))

# WallpaperMedia: ours is image/gif only (the original needs QtMultimedia for video)
write(here / "shim" / "WallpaperMedia.qml", '''import QtQuick
import QtQuick.Window

// Same interface as Anserin's WallpaperMedia (path, active, crop, ready, failed, painted size),
// pictures and gifs only (no QtMultimedia needed).
Item {
    id: root
    property string path: ""
    property bool active: visible
    property bool crop: true
    readonly property url mediaUrl: {
        if (!path) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    readonly property bool isGif: /\\.gif$/i.test(path)
    readonly property bool failed: loader.item ? loader.item.status === Image.Error : false
    readonly property bool ready: loader.item ? loader.item.status === Image.Ready : false
    readonly property real paintedWidth: loader.item ? loader.item.paintedWidth : 0
    readonly property real paintedHeight: loader.item ? loader.item.paintedHeight : 0

    Loader {
        id: loader
        anchors.fill: parent
        active: root.active && root.path !== ""
        sourceComponent: root.isGif ? gifC : imgC
    }
    Component {
        id: imgC
        Image {
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
            cache: false
            mipmap: true
        }
    }
    Component {
        id: gifC
        AnimatedImage {
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: root.active
        }
    }
}
''')

# ------------------------------------------------------------------ 2. shim members
MARK = "// added by port_anserin.py"

def add_members(fname, members, names, imports=()):
    """Insert `members` before the last closing brace of a shim singleton, skipping ones that exist."""
    p = here / "shim" / fname
    t = p.read_text()
    if MARK in t:
        return
    need = [m for n, m in zip(names, members) if not re.search(r'\b' + re.escape(n) + r'\b\s*:', t)
            and not re.search(r'property\s+\w+\s+' + re.escape(n) + r'\b', t)]
    if not need:
        return
    backup(p)
    for imp in imports:
        if imp not in t:
            t = t.replace("import QtQuick\n", "import QtQuick\n" + imp + "\n", 1)
    i = t.rstrip().rfind("}")
    t = t[:i].rstrip() + "\n\n    " + MARK + "\n    " + "\n    ".join(need) + "\n}\n"
    write(p, t)

add_members("ThemeBackend.qml", [
    'readonly property color secondaryContainer: "#3a3324"',
    'readonly property color onSecondaryContainer: "#ead9b4"',
    'readonly property color onSurface: "#ead9b4"',
    'readonly property color primaryContainer: "#5a4515"',
    'readonly property color surfaceVariant: "#2a2c36"',
    'readonly property real glassElementOpacity: 0.92',
    'property var availableFontPaths: ({})',
], ["secondaryContainer", "onSecondaryContainer", "onSurface", "primaryContainer", "surfaceVariant",
    "glassElementOpacity", "availableFontPaths"])

add_members("DateTime.qml", [
    'readonly property string time: Qt.formatDateTime(now, "hh:mm")',
    'readonly property string dateBadge: now.toLocaleDateString(Qt.locale("en"), "d MMM").toUpperCase()',
], ["time", "dateBadge"])

# SystemInfo: real user name; avatar from ~/.config/outerwilds/settings.json {"avatarPath": "..."}
si = here / "shim" / "SystemInfo.qml"
if MARK not in si.read_text():
    backup(si)
    write(si, '''pragma Singleton
import QtQuick
import Quickshell

QtObject {
    property bool isDesktop: false
    ''' + MARK + '''
    property string username: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    // set "avatarPath" in ~/.config/outerwilds/settings.json to show a picture on the user card
    property string avatarPath: (Config.rawSettings && Config.rawSettings.avatarPath) ? String(Config.rawSettings.avatarPath) : ""
}
''')

add_members("Caching.qml", [
    'readonly property string anserinDir: serpantinumDir   // user card runs <anserinDir>/scripts/...',
], ["anserinDir"])
add_members("Sounds.qml", [
    'function playUntilStopped(name, volume, loop) { return -1 }',
    'function stopSfx(handle) {}',
], ["playUntilStopped", "stopSfx"])

# i18n strings the new faces use, taken from Anserin's en.json
en = json.loads((assets / "languages" / "en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."):
        cur = cur[p]
    return cur
keys = set()
for dst in FACES.values():
    keys |= set(re.findall(r'I18n\.t\("([^"]+)"', (here / "faces" / dst).read_text() if not DRY else
                           (qs / "widgets" / "faces" / [s for s, d in FACES.items() if d == dst][0]).read_text()))
want = {}
for k in sorted(keys):
    try:
        v = dig(k)
        if isinstance(v, str): want[k] = v
    except (KeyError, TypeError):
        pass
for mkey, mv in en["weather"]["months"].items():
    want["weather.months." + mkey] = mv
want["widgets.types.user"] = en["widgets"]["types"]["user"]
i18n = here / "shim" / "I18n.qml"
txt = i18n.read_text()
m = re.search(r'(readonly property var strings: \()(\{.*?\n\s*\})(\)\n)', txt, re.S)
if not m:
    print("WARNING: could not find the strings map in shim/I18n.qml; add these keys by hand:\n", json.dumps(want, indent=2))
else:
    cur = json.loads(m.group(2))
    new = {k: v for k, v in want.items() if k not in cur}
    if new:
        backup(i18n)
        cur.update(new)
        write(i18n, txt[:m.start(2)] + json.dumps(cur, indent=8) + txt[m.end(2):])

# scripts the user card's hold-to-confirm buttons call (Anserin's own scripts are not ported)
scripts = {
    "lock.sh": "loginctl lock-session",
    "qs_manager.sh": "# the user card's name button asked Anserin to open its guide; nothing to do here\ntrue",
    "system/suspend.sh": "systemctl suspend",
    "system/reboot.sh": "systemctl reboot",
    "system/poweroff.sh": "systemctl poweroff",
}
for rel, body in scripts.items():
    write(here / "scripts" / rel, "#!/usr/bin/env bash\n" + body + "\n")
    if not DRY:
        (here / "scripts" / rel).chmod(0o755)

# shim/qmldir + faces/qmldir registrations
def add_qmldir(path, lines):
    t = path.read_text() if path.exists() else ""
    have = {l.split()[0] if not l.startswith("singleton") else l.split()[1] for l in t.splitlines() if l.strip() and not l.startswith("#")}
    add = [l for l in lines if (l.split()[1] if l.startswith("singleton") else l.split()[0]) not in have]
    if add:
        backup(path)
        write(path, t.rstrip("\n") + "\n" + "\n".join(add) + "\n")

add_qmldir(here / "shim" / "qmldir", [f"{n[:-4]} 1.0 {n}" for n in
           ("MaterialDigitGrid.qml", "ImageBox.qml", "NumberSelector.qml", "WallpaperMedia.qml")])
add_qmldir(here / "faces" / "qmldir", [f"{n[:-4]} 1.0 {n}" for n in FACES.values()])

# ------------------------------------------------------------------ 3. wrappers
# (type name, face, designW, designH, brackets, extra props, catalog name, group, title)
WRAPS = [
    ("AnserinClockDigital",    "ClockFaceDigital",    250, 120, False, "", "Digital clock (Anserin)",     "Time",  ""),
    ("AnserinClockMaterial",   "ClockFaceMaterial",   220, 220, False, "", "Material clock (Anserin)",    "Time",  ""),
    ("AnserinClockMinimal",    "ClockFaceMinimal",    250, 120, False, "", "Minimal clock (Anserin)",     "Time",  ""),
    ("AnserinClockLockscreen", "ClockFaceLockscreen", 300, 150, False, "", "Lock-screen clock (Anserin)", "Time",  ""),
    ("AnserinClockStretched",  "ClockFaceStretched",  420, 180, False, "", "Stretched clock (Anserin)",   "Time",  ""),
    ("AnserinUser",            "UserFace",            260, 140, True,  "", "User card (Anserin)",         "Other", "USER"),
    ("AnserinGithub",          "GithubFace",          540, 180, True,  "", "GitHub contributions",        "Other", "GITHUB"),
    ("AnserinImageRounded",    "ImageFaceRounded",    300, 200, False, "IMG", "Picture, rounded",         "Other", ""),
    ("AnserinImageRect",       "ImageFaceRect",       300, 200, False, "IMG", "Picture, square corners",  "Other", ""),
    ("AnserinImageRound",      "ImageFaceRound",      200, 200, False, "IMG", "Picture, round",           "Other", ""),
    ("AnserinText",            "TextFace",            320,  90, False, "TXT", "Text",                     "Other", ""),
]
for name, face, w, h, br, kind, *_ in WRAPS:
    if kind == "IMG":      # picture path: ~/.config/outerwilds/settings.json  { "imageWidgetPath": "/home/you/pic.png" }
        extra = '    faceProps: ({ imagePath: Config.getSetting("imageWidgetPath", "") })\n'
    elif kind == "TXT":    # text: settings.json { "textWidget": "OUTER WILDS" }
        extra = '    faceProps: ({ textContent: Config.getSetting("textWidget", "Outer Wilds") })\n'
    else:
        extra = ""
    write(here / f"{name}.qml", f'''import QtQuick
import "."
import "shim"

SerpCard {{
    face: "faces/{face}.qml"
    designW: {w}
    designH: {h}
    brackets: {"true" if br else "false"}
{extra}}}
''')
add_qmldir(here / "qmldir", [f"{n[0]} 1.0 {n[0]}.qml" for n in WRAPS])

# ------------------------------------------------------------------ 4. registry + planets
manual = []

cat = root / "data" / "WidgetConfig.qml"
if cat.exists():
    t = cat.read_text()
    if "serp/AnserinUser.qml" not in t:
        anchor = re.search(r'^(\s*)\{ source: "BlankWidget\.qml".*$', t, re.M)
        lines = []
        for name, face, w, h, br, kind, cname, group, title in WRAPS:
            tt = f', title: "{title}"' if title else ""
            lines.append(f'{anchor.group(1) if anchor else "        "}{{ source: "serp/{name}.qml", name: "{cname}", group: "{group}", designW: {w}{tt} }},')
        if anchor:
            backup(cat)
            write(cat, t[:anchor.start()] + "\n".join(lines) + "\n" + t[anchor.start():])
        else:
            manual.append(("data/WidgetConfig.qml  (add inside `catalog`)", "\n".join(lines)))
else:
    manual.append(("data/WidgetConfig.qml missing", ""))

# default placements (move any of them in the settings app)
DEFS = '''
        // ---- ANSERIN faces (port_anserin.py) ----
        { id: "an_sun_digital",  host: "sun", source: "serp/AnserinClockDigital.qml",  show: "focus", worldWk: 1.00, minUi: 0.50, maxUi: 1.4,
          orbit: { k: 1.95, add: 175, tilt:  0.55, node: 4.1, phase: 1.0, speed: -0.11 } },
        { id: "an_sun_material", host: "sun", source: "serp/AnserinClockMaterial.qml", show: "focus", worldWk: 0.90, minUi: 0.50, maxUi: 1.4,
          orbit: { k: 2.05, add: 185, tilt: -0.65, node: 5.0, phase: 4.6, speed:  0.09 } },
        { id: "an_th_github",    host: "timber_hearth", source: "serp/AnserinGithub.qml", title: "GITHUB", show: "focus", worldW: 140, minUi: 0.5, maxUi: 1.4,
          orbit: { k: 2.7, add: 40, tilt: 0.55, node: 2.4, phase: 5.0, speed: 0.18 } },
        { id: "an_att_user",     host: "attlerock", source: "serp/AnserinUser.qml", title: "USER", show: "focus", worldW: 60, minUi: 0.5, maxUi: 1.4,
          orbit: { k: 4.2, add: 40, tilt: -0.50, node: 2.4, phase: 2.2, speed: 0.22 } },
        { id: "an_hl_image",     host: "hollows_lantern", source: "serp/AnserinImageRounded.qml", show: "focus", worldW: 70, minUi: 0.5, maxUi: 1.3,
          orbit: { k: 3.0, add: 40, tilt: -0.40, node: 1.5, phase: 2.5, speed: -0.20 } },
'''
wl = root / "widgets" / "WidgetLayer.qml"
if wl.exists():
    t = wl.read_text()
    if 'id: "an_sun_digital"' not in t:
        a = re.search(r'^\s*// ---- PLACEHOLDERS', t, re.M)
        if a:
            backup(wl)
            write(wl, t[:a.start()] + DEFS.lstrip("\n") + "\n" + t[a.start():])
        else:
            manual.append(("widgets/WidgetLayer.qml  (paste into baseDefs, mind the commas)", DEFS))
else:
    manual.append(("widgets/WidgetLayer.qml missing", DEFS))

# notice
notice = here / "NOTICE.md"
n = notice.read_text() if notice.exists() else ""
if "Anserin" not in n:
    write(notice, n.rstrip() + '''

Anserin faces (faces/ClockFaceDigital, ClockFaceLockscreen, ClockFaceMaterial, ClockFaceMinimal, ClockFaceStretched,
ImageFace*, TextFace, UserFace, GithubFace and shim/MaterialDigitGrid, ImageBox, NumberSelector) are copies from
Anserin by lukpednoi (https://github.com/lukpednoi/Anserin, a Serpantinum fork), AGPL-3.0-or-later, with import lines
and a few zero-padding fixes changed. Their wrappers (Anserin*.qml), shim/WallpaperMedia.qml and scripts/ are new glue.
''')

print("\n".join(changed) if changed else "nothing to do (already ported)")
for where, snippet in manual:
    print(f"\n!! could not patch {where}. Paste this by hand:\n{snippet}")
print("\nDone. Restart with: qs -c outerwilds")
