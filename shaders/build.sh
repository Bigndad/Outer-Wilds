#!/usr/bin/env bash
# Rebuild every .qsb from its .frag. Adjust the flags if you normally use different ones.
cd "$(dirname "$0")"
QSB="${QSB:-$(command -v qsb || echo /usr/lib/qt6/bin/qsb)}"
for f in *.frag; do "$QSB" --qt6 -o "$f.qsb" "$f" && echo "built $f.qsb"; done
