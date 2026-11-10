#!/usr/bin/env bash
# Self-contained installer for ilyamiro's app launcher in the outerwilds config.
# Usage: bash install_launcher_standalone.sh [path/to/applauncher.qml]
set -euo pipefail
CFG="${OW_DIR:-$HOME/.config/quickshell/outerwilds}"
ARCH="${OW_ARCHIVE:-$HOME/outerwilds-archive}"

# find his applauncher.qml
SRC="${1:-}"
if [ -z "$SRC" ]; then
  for c in "$PWD/applauncher.qml" "$CFG/applauncher.qml" "$CFG/launcher/applauncher.qml" "$HOME/Downloads/applauncher.qml" "$HOME/applauncher.qml"; do
    if [ -f "$c" ]; then SRC="$c"; break; fi
  done
fi
if [ ! -f "$SRC" ]; then
  echo "applauncher.qml not found. Run:  bash $0 /path/to/applauncher.qml"; exit 1
fi
echo "using $SRC"

mkdir -p "$CFG/launcher" "$ARCH"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/patch.py" <<'PYEOF'
#!/usr/bin/env python3
"""Adapts ilyamiro's applauncher.qml: no Caching/app_fetcher.py/qs_manager.sh, apps come
from Quickshell's DesktopEntries, closing emits closeRequested(). Usage: patch_applauncher.py in.qml out.qml"""
import sys, re
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()

def must_replace(old, new, what):
    global t
    if old not in t:
        sys.exit(f"patch failed: could not find {what}")
    t = t.replace(old, new, 1)

must_replace("    id: window\n    focus: true\n",
             "    id: window\n    focus: true\n\n    signal closeRequested()\n    property var entryMap: ({})\n",
             "root id/focus lines")
must_replace("    Caching { id: paths }\n", "", "Caching line")

start = t.find("    Process {\n        id: appFetcher")
end = t.find("    ListModel { id: appModel }")
if start < 0 or end < 0 or end < start:
    sys.exit("patch failed: could not find the appFetcher Process block")
loader = '''    // apps come straight from Quickshell's desktop entries (replaces app_fetcher.py)
    function loadApps() {
        const entries = DesktopEntries.applications.values;
        let list = [];
        let map = ({});
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay) continue;
            list.push({ name: e.name, icon: e.icon || "", exec: e.execString || "" });
            map[e.name] = e;
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        window.entryMap = map;
        window.allApps = list;
        appModel.clear();
        for (let j = 0; j < list.length; j++) appModel.append(list[j]);
        window.projDirty = true;
        window.rebuildProjCache();
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { window.loadApps(); }
    }

    Component.onCompleted: window.loadApps()

'''
t = t[:start] + loader + t[end:]

must_replace('Quickshell.execDetached(["bash", paths.serpantinumDir + "/scripts/qs_manager.sh", "close"])',
             "window.closeRequested()", "qs_manager close call")
must_replace('''        Quickshell.execDetached(["python3", paths.qsDir + "/applauncher/app_fetcher.py", "--log", appName]);
        Quickshell.execDetached(["bash", "-c", execStr]);
''', '''        const entry = window.entryMap[appName];
        if (entry) entry.execute();
        else if (execStr) Quickshell.execDetached(["bash", "-c", execStr]);
''', "launchApp body")

if "paths." in t:
    sys.exit("patch failed: leftover 'paths.' references")
open(dst, "w").write(t)
print("ok")
PYEOF
python3 "$TMP/patch.py" "$SRC" "$CFG/launcher/AppLauncher.qml"

cat > "$CFG/launcher/Scaler.qml" <<'QMLEOF'
import QtQuick

// stand-in for ilyamiro's Scaler: s(px) scales a 1080p design size to the current width
QtObject {
    property real currentWidth: 1920
    function s(val) {
        return Math.round(val * (currentWidth > 0 ? currentWidth / 1920 : 1));
    }
}
QMLEOF
cat > "$CFG/launcher/MatugenColors.qml" <<'QMLEOF'
import QtQuick

// stand-in for ilyamiro's MatugenColors: just the palette the launcher reads.
// Outer Wilds colours for now (gold accent = "mauve", the focus colour). Tweak freely.
QtObject {
    property color base:     "#07080C"
    property color mantle:   "#0B0D14"
    property color crust:    "#04050A"
    property color surface0: "#161A26"
    property color surface1: "#222839"
    property color surface2: "#2E364C"
    property color text:     "#E6D5B8"
    property color subtext0: "#A89B82"
    property color overlay0: "#6B6A62"
    property color blue:     "#4D82E0"
    property color mauve:    "#D4AF37"
    property color teal:     "#469A7E"
    property color peach:    "#FF8C42"
    property color yellow:   "#F2D16B"
    property color sapphire: "#6FB3E0"
}
QMLEOF
cat > "$CFG/launcher/LauncherWindow.qml" <<'QMLEOF'
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// Fullscreen overlay hosting ilyamiro's app launcher (AppLauncher.qml).
//   toggle:  qs -c outerwilds ipc call launcher toggle     (bind your launcher key to this)
//   also opened by NoctaliaBridge when the Noctalia launcher is opened from the bar.
Scope {
    id: root
    property bool open: false

    onOpenChanged: if (open) NoctaliaBridge.planetRequested("dark_bramble", "launcher")

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    Connections {
        target: NoctaliaBridge
        function onLauncherRequested() { root.open = true; }
    }

    PanelWindow {
        visible: root.open
        color: "#B307080C"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        Loader {
            anchors.fill: parent
            active: root.open
            sourceComponent: AppLauncher {
                onCloseRequested: root.open = false
            }
        }
    }
}
QMLEOF

# every type must be listed here (this Qt does not find unlisted sibling files)
for n in LauncherWindow AppLauncher Scaler MatugenColors; do
  grep -q "^$n " "$CFG/qmldir" || echo "$n 1.0 launcher/$n.qml" >> "$CFG/qmldir"
done

python3 - "$CFG/shell.qml" "$ARCH" <<'PY'
import sys, shutil, pathlib
p = pathlib.Path(sys.argv[1]); arch = pathlib.Path(sys.argv[2])
t = p.read_text()
if "LauncherWindow" in t:
    print("shell.qml already has LauncherWindow"); sys.exit(0)
anchor = "    Variants {\n"
if anchor not in t:
    sys.exit("could not find Variants in shell.qml - add  LauncherWindow { }  inside ShellRoot by hand")
shutil.copy(p, arch / "shell.qml.pre-launcher")
p.write_text(t.replace(anchor, "    LauncherWindow { }\n\n" + anchor, 1))
print("shell.qml patched (backup in " + str(arch) + ")")
PY
echo
echo "restart:  qs kill -c outerwilds; qs -c outerwilds"
echo "test:     qs -c outerwilds ipc call launcher toggle     (Escape closes)"
echo "needs the qt6-5compat package:  pacman -Qs qt6-5compat"
