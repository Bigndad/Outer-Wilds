#!/usr/bin/env python3
"""Rebuild this folder from a Serpantinum checkout.
Usage: python3 port.py /path/to/serpantinum   (the checkout is never modified)"""
import json, pathlib, re, shutil, sys

repo = pathlib.Path(sys.argv[1])
qs = repo / "src" / "quickshell"
assets = repo / "src" / "assets"
here = pathlib.Path(__file__).parent
(here / "faces").mkdir(exist_ok=True)
(here / "shim").mkdir(exist_ok=True)

FACES = {
    "faces/BatteryFace.qml": "widgets/faces/battery/BatteryFace.qml",
    "faces/BatteryFaceCircle.qml": "widgets/faces/battery/BatteryFaceCircle.qml",
    "faces/ClockFaceMaterialLumen.qml": "widgets/faces/clock/ClockFaceMaterialLumen.qml",
    "faces/ClockFaceMaterialAnalog.qml": "widgets/faces/clock/ClockFaceMaterialAnalog.qml",
    "faces/ClockFaceAnalog.qml": "widgets/faces/clock/ClockFaceAnalog.qml",
    "faces/WeatherFaceRound.qml": "widgets/faces/weather/WeatherFaceRound.qml",
    "faces/WeatherFaceFull.qml": "widgets/faces/weather/WeatherFaceFull.qml",
    "faces/VisualizerFace.qml": "widgets/faces/visualizer/VisualizerFace.qml",
    "faces/VisualizerFaceContinuous.qml": "widgets/faces/visualizer/VisualizerFaceContinuous.qml",
}
REUSABLES = {
    "shim/SystemUsageCircle.qml": "reusables/display/SystemUsageCircle.qml",
    "shim/FluidWave.qml": "reusables/display/FluidWave.qml",
    "shim/LoaderIcon.qml": "reusables/display/LoaderIcon.qml",
    "shim/Visualizer.qml": "reusables/media/Visualizer.qml",
}

def clean(text, inshim):
    out = []
    for line in text.splitlines():
        if re.match(r'\s*import Quickshell', line):
            continue
        if re.match(r'\s*import "(\.\./)+(reusables)?"\s*$', line):
            continue
        out.append(line)
    text = "\n".join(out) + "\n"
    if not inshim:
        text = text.replace("import QtQuick\n", 'import QtQuick\nimport "../shim"\n', 1)
    assert "Quickshell" not in text, "Quickshell reference left over"
    return text

for dst, src in FACES.items():
    (here / dst).write_text(clean((qs / src).read_text(), False))
for dst, src in REUSABLES.items():
    (here / dst).write_text(clean((qs / src).read_text(), True))

for sub in ("shaders",):
    d = here / "assets" / sub
    if d.exists(): shutil.rmtree(d)
    shutil.copytree(assets / sub, d)
(here / "assets" / "fonts").mkdir(parents=True, exist_ok=True)
shutil.copy(assets / "fonts" / "SymbolsNerdFontMono-Regular.ttf", here / "assets" / "fonts")

# real English strings for the keys the faces use
en = json.loads((assets / "languages" / "en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."):
        cur = cur[p]
    return cur
keys = ["calendar.weather.feels", "syspanel.battery.charging", "syspanel.battery.charging_time",
        "syspanel.battery.discharging", "syspanel.battery.fully_charged", "syspanel.battery.left_time"]
(here / "shim" / "I18n.qml").write_text(
    "pragma Singleton\nimport QtQuick\n\nQtObject {\n    readonly property var strings: (" + json.dumps({k: dig(k) for k in keys}, indent=8) + ")\n"
    "    function t(key, params) {\n        var s = strings[key] !== undefined ? strings[key] : key;\n"
    "        if (params) for (var p in params) s = s.split(\"{\" + p + \"}\").join(params[p]);\n        return s;\n    }\n}\n")
print("ported", len(FACES), "faces,", len(REUSABLES), "reusables")
