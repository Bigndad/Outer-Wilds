#!/usr/bin/env python3
from pathlib import Path
import sys

p = Path(__file__).resolve().parent / "rumor/RumorMapView.qml"
txt = p.read_text(encoding="utf-8")

old = (
    "        const target = list[nextIdx];\n"
    "        cursorId = target.id;\n"
    "        centerOn(target, true);"
)
new = (
    "        const target = list[nextIdx];\n"
    "        cursorId = target.id;\n"
    '        if (!target.archive && RumorData.stateOfNode(target) !== "locked") RumorData.markRead(target.id);\n'
    "        centerOn(target, true);"
)

if txt.count(old) != 1:
    sys.exit(f"ABORTED: expected 1 match in {p.name}, found {txt.count(old)}")

p.write_text(txt.replace(old, new, 1), encoding="utf-8")
print("Updated rumor/RumorMapView.qml")