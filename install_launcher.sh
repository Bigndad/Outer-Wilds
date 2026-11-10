#!/usr/bin/env bash
# Installs ilyamiro's app launcher into the outerwilds config.
# Usage: bash install_launcher.sh [path/to/applauncher.qml]   (default: the copy next to this script)
set -euo pipefail
CFG="${OW_DIR:-$HOME/.config/quickshell/outerwilds}"
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-$HERE/applauncher.original.qml}"
ARCH="${OW_ARCHIVE:-$HOME/outerwilds-archive}"

mkdir -p "$CFG/launcher" "$ARCH"
python3 "$HERE/patch_applauncher.py" "$SRC" "$CFG/launcher/AppLauncher.qml"
cp "$HERE/Scaler.qml" "$HERE/MatugenColors.qml" "$HERE/LauncherWindow.qml" "$CFG/launcher/"
grep -q LauncherWindow "$CFG/qmldir" || echo "LauncherWindow 1.0 launcher/LauncherWindow.qml" >> "$CFG/qmldir"

# add LauncherWindow {} to shell.qml (right before the Variants block)
python3 - "$CFG/shell.qml" "$ARCH" <<'PY'
import sys, shutil, pathlib
p = pathlib.Path(sys.argv[1]); arch = pathlib.Path(sys.argv[2])
t = p.read_text()
if "LauncherWindow" in t:
    print("shell.qml already has LauncherWindow"); sys.exit(0)
anchor = "    Variants {\n"
if anchor not in t:
    sys.exit("could not find 'Variants {' in shell.qml - add  LauncherWindow { }  inside ShellRoot by hand")
shutil.copy(p, arch / "shell.qml.pre-launcher")
p.write_text(t.replace(anchor, "    LauncherWindow { }\n\n" + anchor, 1))
print("shell.qml patched (backup in " + str(arch) + ")")
PY
echo "restart:  qs kill -c outerwilds; qs -c outerwilds"
echo "test:     qs -c outerwilds ipc call launcher toggle     (Escape closes)"
echo "needs the qt6-5compat package:  pacman -Qs qt6-5compat"
