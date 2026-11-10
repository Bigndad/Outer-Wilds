#!/usr/bin/env python3
"""Copy Lucid's widgets into this folder with their imports pointed at ./shim.
Usage: python3 port.py /path/to/lucid/lucidwidgets   (originals are never edited)"""
import re, sys, pathlib

src = pathlib.Path(sys.argv[1])
here = pathlib.Path(__file__).parent
jobs = {
    "ClockWidget.qml": here / "ClockWidget.qml",
    "BatteryWidget.qml": here / "BatteryWidget.qml",
    "CalendarWidget.qml": here / "CalendarWidget.qml",
    "WeatherWidget.qml": here / "WeatherWidget.qml",
    "VisualiserWidget.qml": here / "VisualiserWidget.qml",
    "WidgetBody.qml": here / "shim" / "WidgetBody.qml",
}

def port(text, name):
    inshim = name == "WidgetBody.qml"
    text = re.sub(r'^import qs\.lucidui\s*\n', '', text, flags=re.M)
    text = re.sub(r'^import qs\s*\n', '' if inshim else 'import "shim"\n', text, flags=re.M)
    text = re.sub(r'^import Quickshell[\w.]*\s*\n', '', text, flags=re.M)
    if name == "VisualiserWidget.qml":
        # wallpaper frosting needs Quickshell's FileView; Theme.blurAmount is 0 here so it never shows
        text, n = re.subn(r'    FileView \{.*?\n    \}\n\n', '', text, count=1, flags=re.S)
        assert n == 1, "FileView block not found"
    if name == "ClockWidget.qml":
        # poster variant needs the Lucid font via Quickshell.shellPath; not supported here
        text, n = re.subn(r'"file://" \+ Quickshell\.shellPath\([^)]*\)', '""', text)
        assert n == 1, "poster font source not found"
    leftovers = [l for l in text.splitlines() if re.search(r'\bQuickshell\.|\bFileView\b|\bimport qs\b', l)]
    assert not leftovers, (name, leftovers)
    return text

for s, d in jobs.items():
    t = port((src / s).read_text(), s)
    d.write_text(t)
    print("ported", s, "->", d.relative_to(here))
