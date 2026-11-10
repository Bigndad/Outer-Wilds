#!/usr/bin/env python3
"""Port the 4 Serpantinum music faces into serp/ (run it from, or copy it into, your serp/ folder).
Usage: python3 port_music.py /path/to/serpantinum      (the checkout is never modified)
Run it AFTER port.py if you ever re-run that (port.py rewrites shim/I18n.qml).
Safe to run repeatedly."""
import json, pathlib, re, sys

repo = pathlib.Path(sys.argv[1])
qs = repo / "src" / "quickshell"
here = pathlib.Path(__file__).resolve().parent
faces, shim = here / "faces", here / "shim"
faces.mkdir(exist_ok=True); shim.mkdir(exist_ok=True)

FACES = ["MusicFace", "MusicFaceRound", "MusicFaceLyrics", "MusicFaceLyricsSimple"]
# originals copied into shim/ (components + the Lyrics engine)
COPY = {
    "reusables/media/LyricsView.qml": "LyricsView.qml",
    "reusables/media/WavySeekBar.qml": "WavySeekBar.qml",
    "reusables/display/MarqueeText.qml": "MarqueeText.qml",
    "reusables/display/BoundedImage.qml": "BoundedImage.qml",
    "reusables/buttons/IconButton.qml": "IconButton.qml",
    "reusables/behavior/SubscriptionGate.qml": "SubscriptionGate.qml",
    "singletons/audio/Lyrics.qml": "Lyrics.qml",
    "singletons/audio/LyricsMatch.js": "LyricsMatch.js",
}
HAND_WRITTEN = ["MprisController.qml", "ClickButton.qml", "LyricsPicker.qml", "GlassFill.qml", "Spectrum.qml"]   # delivered next to this script
SHIM_TYPES = [   # lines appended to shim/qmldir when missing
    "singleton MprisController 1.0 MprisController.qml",
    "singleton Lyrics 1.0 Lyrics.qml", "singleton Spectrum 1.0 Spectrum.qml",
    "LyricsView 1.0 LyricsView.qml", "WavySeekBar 1.0 WavySeekBar.qml", "MarqueeText 1.0 MarqueeText.qml",
    "BoundedImage 1.0 BoundedImage.qml", "IconButton 1.0 IconButton.qml", "SubscriptionGate 1.0 SubscriptionGate.qml",
    "ClickButton 1.0 ClickButton.qml", "LyricsPicker 1.0 LyricsPicker.qml", "GlassFill 1.0 GlassFill.qml",
]
SERP_TYPES = ["EmberTwinMusic", "EmberTwinLyrics", "DarkBrambleDisc", "DarkBrambleLyrics"]
I18N_KEYS = ["music.nothing_playing", "music.searching_lyrics", "music.no_lyrics", "music.select_local_file"]

REL_IMPORT = re.compile(r'^\s*import "(\.\./)+[\w/]*"\s*$')

def clean(text, add_shim):
    out = [l for l in text.splitlines() if not REL_IMPORT.match(l)]
    text = "\n".join(out) + "\n"
    if add_shim:
        text = text.replace("import QtQuick\n", 'import QtQuick\nimport "../shim"\n', 1)
    return text

CAVA_FORWARDER = """pragma Singleton
import QtQuick

// Forwards to the real cava-backed Spectrum singleton, so everything that still says Cava.* (Visualizer,
// the older visualiser faces) gets real audio. Replaces the old fake spectrum.
QtObject {
    readonly property int barCount: Spectrum.barCount
    readonly property var barLevels: Spectrum.barLevels
    readonly property int activeConsumers: Spectrum.activeConsumers
    function registerConsumer() { Spectrum.registerConsumer(); }
    function unregisterConsumer() { Spectrum.unregisterConsumer(); }
}
"""

problems = []
for name in HAND_WRITTEN:
    if not (shim / name).exists():
        problems.append(f"missing hand-written shim/{name} (copy it from the delivered serp-music/shim/)")

for f in FACES:
    (faces / f"{f}.qml").write_text(clean((qs / "widgets/faces/music" / f"{f}.qml").read_text(), True))
def find(src):
    p = qs / src
    if p.exists(): return p
    hits = sorted(qs.rglob(pathlib.Path(src).name))      # file moved in a different version of the checkout
    return hits[0] if hits else None

missing = []
for src, dst in COPY.items():
    sp = find(src)
    if sp is None:
        missing.append(dst); (shim / dst).unlink(missing_ok=True); continue
    text = sp.read_text()
    if dst.endswith(".qml"):
        text = clean(text, False)
    if dst == "Lyrics.qml":          # its only use of the Caching singleton
        text = text.replace('(Caching.home + "/.cache")', '(Quickshell.env("HOME") + "/.cache")')
    (shim / dst).write_text(text)
for m_ in missing:
    problems.append(f"{m_} not found in this checkout (older/newer version?) - skipped; run `git pull` in the checkout if a face fails to load")
SHIM_TYPES = [l for l in SHIM_TYPES if (shim / l.split()[-1]).exists()]

# Lyrics.qml must not keep any other Caching dependency
if "Caching." in (shim / "Lyrics.qml").read_text():
    problems.append("shim/Lyrics.qml still references Caching.* (upstream changed?)")

def append_missing(path, lines):
    cur = path.read_text() if path.exists() else ""
    have = {l.split()[-3] for l in cur.splitlines() if len(l.split()) >= 3 and not l.startswith("#")}
    add = [l for l in lines if l.split()[-3] not in have]
    if add:
        path.write_text(cur.rstrip("\n") + "\n" + "\n".join(add) + "\n")
    return add

a1 = append_missing(shim / "qmldir", SHIM_TYPES)
a2 = append_missing(here / "qmldir", [f"{n} 1.0 {n}.qml" for n in SERP_TYPES])

# music strings into shim/I18n.qml (format written by port.py)
en = json.loads((repo / "src/assets/languages/en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."): cur = cur[p]
    return cur
i18n = shim / "I18n.qml"
txt = i18n.read_text()
m = re.search(r'readonly property var strings: \((\{.*?\})\)\n', txt, re.S)
if m:
    d = json.loads(m.group(1)); d.update({k: dig(k) for k in I18N_KEYS})
    i18n.write_text(txt[:m.start(1)] + json.dumps(d, indent=8) + txt[m.end(1):])
else:
    problems.append("could not find the strings map in shim/I18n.qml; add music.* keys by hand")

# ---- self-check: every singleton property / type the ported files use must exist in shim ----
used = {"ThemeBackend": set(), "Scaler": set()}
shim_files = {p.stem for p in shim.glob("*.qml")}
all_src = "\n".join(p.read_text() for p in list(faces.glob("Music*.qml")) + [shim / n for n in
        ["LyricsView.qml", "WavySeekBar.qml", "MarqueeText.qml", "BoundedImage.qml", "IconButton.qml", "SubscriptionGate.qml", "ClickButton.qml", "LyricsPicker.qml", "GlassFill.qml", "Spectrum.qml"] if (shim / n).exists()])
for s in used:
    used[s] = set(re.findall(rf'\b{s}\.(\w+)', all_src))
for s, props in used.items():
    f = shim / f"{s}.qml"
    body = f.read_text() if f.exists() else ""
    miss = sorted(p for p in props if not re.search(rf'\b{p}\b', body))
    if s == "ThemeBackend" and miss and f.exists():
        # missing palette tokens: add them (warm Outer Wilds neutrals) just before the closing brace; edit freely afterwards
        TOKENS = {"overlay0": "#5E5444", "overlay1": "#7A6E5A", "overlay2": "#968A74", "pink": "#C98F86", "sapphire": "#6FA3B0",
                  "teal": "#6FA89A", "peach": "#D9945B", "yellow": "#E3B958", "green": "#8FB070", "blue": "#7B9CC4",
                  "surface2": "#4A4234", "subtext1": "#CDBFA6", "subtext0": "#B0A28A"}
        add = [m for m in miss if m in TOKENS]
        if add and body.rstrip().endswith("}"):
            cut = body.rstrip().rfind("}")
            lines = "".join(f'    property color {m}: "{TOKENS[m]}"\n' for m in add)
            f.write_text(body[:cut] + "\n    // added by port_music.py (music faces need these tokens)\n" + lines + body[cut:])
            print("added to shim/ThemeBackend.qml:", ", ".join(add))
            miss = [m for m in miss if m not in add]
    if miss: problems.append(f"shim/{s}.qml lacks: {', '.join(miss)}")
# types used as `Name {` that nothing provides
qtish = set("Item Rectangle Text Row Column Image Timer Connections MultiEffect NumberAnimation SpringAnimation ColorAnimation "
            "Repeater RowLayout ColumnLayout Shape ShapePath Behavior MouseArea ShaderEffect ShaderEffectSource Canvas Flickable "
            "Loader Process StdioCollector FileView Scale Rotation Translate Gradient GradientStop PropertyAnimation SequentialAnimation "
            "ParallelAnimation PathLine PathArc PathAngleArc LinearGradient FontLoader Component QtObject Singleton Item Window Instantiator "
            "ListModel ListElement Layout SystemUsageCircle AnimatedImage PauseAnimation PropertyAction TapHandler WheelHandler HoverHandler "
            "DragHandler PointHandler Binding Timer Shape SplitParser".split())
for t in sorted(set(re.findall(r'(?m)^\s*(?:\w+:\s*)?([A-Z]\w+)\s*\{', all_src)) - qtish - shim_files):
    problems.append(f"type '{t}' is used but not in shim/")

# the existing (hand-made) shim types the music faces also drive: do they declare the properties the faces set?
NEEDS = {
    "WallpaperBlur": ["radius"],
    "Visualizer": "active continuous count curve fall gamma maxLength minLength mirrored opacityBase opacityRange "
                  "ringBarWidth ringRadius rise spacing threshold tintStrength".split(),
}
for typ, props in NEEDS.items():
    f = shim / f"{typ}.qml"
    body = f.read_text() if f.exists() else ""
    miss = [p for p in props if not re.search(rf'property\s+[\w.<>]+\s+{p}\b', body)]
    if miss:
        problems.append(f"shim/{typ}.qml (made earlier) lacks properties the music faces set: {', '.join(miss)} - send me that file")

cava_f = shim / "Cava.qml"
if cava_f.exists() and "MOCK" in cava_f.read_text():
    # the old fake spectrum: replace it with a forwarder to the real Spectrum (same API, so nothing else changes)
    cava_f.write_text((here / "Cava.qml.new").read_text() if (here / "Cava.qml.new").exists() else CAVA_FORWARDER)
    print("shim/Cava.qml: replaced the mock spectrum with a forwarder to the real cava data")
import shutil
if not shutil.which("cava"):
    problems.append("`cava` not found on PATH (the real spectrum needs it: sudo pacman -S cava)")
for q in ("ui/marquee_scroll", "audio/seekbar_wave"):
    if not (here / "assets/shaders" / f"{q}.frag.qsb").exists():
        problems.append(f"assets/shaders/{q}.frag.qsb not found (re-run port.py)")

print("faces:", len(FACES), "| shim files written:", len(COPY), "| qmldir lines added:", len(a1) + len(a2))
if problems:
    print("\nCHECK THESE:"); [print(" -", p) for p in problems]
else:
    print("self-check clean")
