#!/usr/bin/env bash
# Installs NoctaliaBridge: copies the singleton, registers it in qmldir, and adds
# flyTo() + a Connections block to core/CameraRig.qml. Safe to re-run.
set -euo pipefail
CFG="${OW_DIR:-$HOME/.config/quickshell/outerwilds}"
ARCH="${OW_ARCHIVE:-$HOME/outerwilds-archive}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$ARCH"
cp "$HERE/NoctaliaBridge.qml" "$CFG/data/NoctaliaBridge.qml"
grep -q NoctaliaBridge "$CFG/qmldir" || \
  echo "singleton NoctaliaBridge 1.0 data/NoctaliaBridge.qml" >> "$CFG/qmldir"

python3 - "$CFG/core/CameraRig.qml" "$ARCH" <<'PY'
import sys, shutil, pathlib
p = pathlib.Path(sys.argv[1]); arch = pathlib.Path(sys.argv[2])
t = p.read_text()
if "NoctaliaBridge" in t:
    print("CameraRig already patched"); sys.exit(0)
anchor = "    function flyInAt(mx, my) { return mouseArea.engageAt(mx, my); }\n"
if anchor not in t:
    sys.exit("anchor line (flyInAt) not found in CameraRig.qml - not patched")
shutil.copy(p, arch / "CameraRig.qml.pre-bridge")
add = anchor + """
    // fly to a planet and lock on (same as double-clicking it); used by NoctaliaBridge
    function flyTo(planetId) { mouseArea.engageAutopilot(planetId); }
    Connections {
        target: NoctaliaBridge
        function onPlanetRequested(planetId, panelId) { root.flyTo(planetId); }
    }
"""
p.write_text(t.replace(anchor, add, 1))
print("CameraRig patched (backup in " + str(arch) + ")")
PY
echo "done. restart:  qs kill -c outerwilds; qs -c outerwilds"
echo "test camera:    qs -c outerwilds ipc call bridge fly dark_bramble"
echo "test bridge:    open the launcher on an empty workspace, then: qs -c outerwilds log | grep NoctaliaBridge"
