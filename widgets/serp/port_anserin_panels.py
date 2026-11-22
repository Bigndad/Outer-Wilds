#!/usr/bin/env python3
"""Bring Anserin's two big panels onto Outer Wilds as full-screen overlays.

Usage:
    python3 ~/.config/quickshell/outerwilds/widgets/serp/port_anserin_panels.py /path/to/Anserin [--dry-run]

  * Bubble Monitor  (Anserin's System page, "Bubble" style): CPU / memory / temperature / network / disk as bubbles
    plus the busiest processes or the open apps. Tap a bubble for its page. Esc or the X closes it.
        toggle:  qs -c outerwilds ipc call bubble toggle
  * Network manager (Anserin's NetworkPopup): Ethernet / Wi-Fi / Bluetooth in one panel, centred on a dimmed screen.
        toggle:  qs -c outerwilds ipc call network toggle

Safe to re-run. Edits to your files are anchored and saved once as <file>.pre-anserin-panels; if an anchor is
missing it prints the line to add by hand. Needs python-psutil for the Bubble Monitor
(Arch: sudo pacman -S python-psutil) and jq + pactl for Bluetooth profiles in the network panel.
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
if not (qs / "network" / "NetworkPopup.qml").exists():
    sys.exit(f"{repo} does not look like an Anserin checkout (no src/quickshell/network/NetworkPopup.qml)")

changed = []
def write(path, text, mode=None):
    rel = str(path.relative_to(root))
    if DRY:
        changed.append("(dry) " + rel); return
    if path.exists() and path.read_text() == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    if mode: path.chmod(mode)
    changed.append(rel)

def backup(path):
    bak = path.with_name(path.name + ".pre-anserin-panels")
    if path.exists() and not bak.exists() and not DRY:
        shutil.copy2(path, bak)

def clean(text, name, extra=()):
    """drop Anserin's root/reusables imports, add our shim; keep Quickshell imports (these panels use the real thing)"""
    out = [l for l in text.splitlines() if not re.match(r'\s*import "(\.\./)+(reusables)?"\s*$', l)]
    text = "\n".join(out) + "\n"
    text = text.replace("import QtQuick\n", 'import QtQuick\nimport "../shim"\n', 1)
    for a, b in extra:
        if a not in text:
            sys.exit(f"{name}: expected text not found, did Anserin change? -> {a!r}")
        text = text.replace(a, b, 1)
    return text

def add_qmldir(path, lines):
    t = path.read_text() if path.exists() else ""
    have = {(l.split()[1] if l.startswith("singleton") else l.split()[0]) for l in t.splitlines() if l.strip() and not l.startswith("#")}
    add = [l for l in lines if (l.split()[1] if l.startswith("singleton") else l.split()[0]) not in have]
    if add:
        backup(path)
        write(path, t.rstrip("\n") + "\n" + "\n".join(add) + "\n")

panels = here / "panels"
shim = here / "shim"

# ============================================================ Bubble Monitor
SPHERE = '''        // sphere shading (port_anserin_panels.py): light from the top left, shade to the lower right
        Shape {
            visible: shell.sphere && !bub.paused
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: bub.rad * 0.6; centerY: bub.rad * 0.55
                    centerRadius: bub.rad * 1.6
                    GradientStop { position: 0.0; color: "#40FFFFFF" }
                    GradientStop { position: 0.45; color: "#00FFFFFF" }
                    GradientStop { position: 1.0; color: "#78000000" }
                }
                PathAngleArc { centerX: bub.rad; centerY: bub.rad; radiusX: bub.rad; radiusY: bub.rad; startAngle: 0; sweepAngle: 360 }
            }
        }
        Rectangle {
            visible: shell.sphere && !bub.paused && !bub.metric
            x: bub.rad * 0.30; y: bub.rad * 0.18
            width: bub.rad * 0.5; height: bub.rad * 0.28; radius: height / 2
            rotation: -28
            color: "#30FFFFFF"
        }
'''

bm_src = qs / "blankpanel" / "pages" / "BubbleMonitor.qml"
write(panels / "BubbleMonitor.qml", clean(bm_src.read_text(), "BubbleMonitor.qml", [
    # hosted as our own overlay: no full-screen button, Esc / close asks the host to close
    ("    property bool preview: false ",
     "    property bool hosted: false             // opened as Outer Wilds' full-screen overlay (port_anserin_panels.py)\n"
     "    property bool sphere: true              // shade the bubbles like spheres (port_anserin_panels.py)\n"
     "    signal closeRequested()\n    property bool preview: false "),
    # hosted: no black space / stars / black hole, the page is see-through so the solar system shows behind it
    ("            color: shell.cBg\n            focus: true\n",
     "            color: shell.hosted ? \"transparent\" : shell.cBg\n            focus: true\n"),
    ("                    id: space\n", "                    id: space\n                    visible: !shell.hosted\n"),
    ("        // paused: a dashed outline\n", SPHERE + "        // paused: a dashed outline\n"),
    ("                id: fullBtn\n", "                id: fullBtn\n                visible: !shell.hosted\n"),
    ("else if (shell.full && shell.fsT >= 1) shell.leaveFull(); }",
     "else if (shell.full && shell.fsT >= 1) shell.leaveFull(); else if (shell.hosted) shell.closeRequested(); }"),
]))
if not DRY:
    dst = panels / "bubble"
    if not dst.exists():
        shutil.copytree(qs / "blankpanel" / "pages" / "bubble", dst)
        changed.append("widgets/serp/panels/bubble/ (feed script, shaders, space art, sound)")
    (dst / "bubble-feed.py").chmod(0o755)
    # the water inside the bubbles uses this shader from Anserin's assets
    lw = here / "assets" / "shaders" / "fluid" / "level_wave.frag.qsb"
    if not lw.exists() and (assets / "shaders" / "fluid" / "level_wave.frag.qsb").exists():
        lw.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(assets / "shaders" / "fluid" / "level_wave.frag.qsb", lw)
        changed.append(str(lw.relative_to(root)))

write(shim / "PanelLayout.qml", '''pragma Singleton
import QtQuick

// Anserin's panel layout singleton, reduced to the one flag the Bubble Monitor sets.
QtObject {
    property bool bubbleFull: false
}
''')

write(panels / "BubbleWindow.qml", '''import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shim"
import "../../.."

// Full-screen overlay hosting Anserin's Bubble Monitor (BubbleMonitor.qml).
//   toggle:  qs -c outerwilds ipc call bubble toggle      (bind a key to this)
// The monitor only reads the system (bubble/bubble-feed.py, needs python-psutil) while this is open.
// Esc or the X closes it.
Scope {
    id: root
    property bool open: false

    IpcHandler {
        target: "bubble"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    PanelWindow {
        visible: root.open
        color: "#55000000"      // see-through: your solar system shows behind the bubbles
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-bubble"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        Loader {
            anchors.fill: parent
            active: root.open
            source: "BubbleMonitor.qml"
            onLoaded: {
                item.hosted = true;
                item.active = true;
                item.closeRequested.connect(function () { root.open = false; });
            }
        }

        Rectangle {
            z: 100
            anchors { left: parent.left; top: parent.top; margins: 14 }
            width: 38; height: 38; radius: 19
            color: closeMa.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
            Text { anchors.centerIn: parent; text: "\\u2715"; color: "#E8DFC8"; font.pixelSize: 16 }
            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
        }
    }
}
''')

# ============================================================ Network manager
net_src = qs / "network" / "NetworkPopup.qml"
write(panels / "NetworkPopup.qml", clean(net_src.read_text(), "NetworkPopup.qml"))
write(shim / "FillButton.qml", clean((qs / "reusables" / "buttons" / "FillButton.qml").read_text(), "FillButton.qml"))
# the popup runs <qsDir>/network/bluetooth_panel_logic.sh (qsDir is the serp folder)
write(here / "network" / "bluetooth_panel_logic.sh", (qs / "network" / "bluetooth_panel_logic.sh").read_text(), 0o755)

# the popup asks WallpaperBlur for `.active`; our stand-in has none
wb = shim / "WallpaperBlur.qml"
if wb.exists() and "property bool active" not in wb.read_text():
    t = wb.read_text()
    i = t.rstrip().rfind("}")
    backup(wb)
    write(wb, t[:i].rstrip() + "\n    readonly property bool active: false   // added by port_anserin_panels.py\n}\n")

write(panels / "NetworkWindow.qml", '''import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../shim"
import "../../.."

// Full-screen overlay hosting Anserin's network manager (NetworkPopup.qml): Ethernet, Wi-Fi and Bluetooth.
//   toggle:  qs -c outerwilds ipc call network toggle      (bind a key to this)
// Esc, the X, or a click outside the panel closes it (Esc first cancels a Wi-Fi password prompt).
// Keyboard focus is OnDemand (not Exclusive) so the overlay can never lock you out of typing a close command.
Scope {
    id: root
    property bool open: false
    property bool built: false          // the popup is only created the first time it opens
    onOpenChanged: if (open) built = true

    IpcHandler {
        target: "network"
        function toggle(): void { root.open = !root.open; }
        function show(): void { root.open = true; }
        function hide(): void { root.open = false; }
    }

    PanelWindow {
        visible: root.open
        color: "#66000000"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "outerwilds-network"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea { anchors.fill: parent; onClicked: root.open = false }

        // the popup consumes Esc itself, so it is handled here: first cancel a Wi-Fi password prompt, then close
        Shortcut {
            sequence: "Escape"
            enabled: root.open
            onActivated: {
                const p = pop.item;
                if (p && p.pendingWifiId !== "") { p.pendingWifiId = ""; p.pendingWifiSsid = ""; }
                else root.open = false;
            }
        }

        Rectangle {
            z: 100
            anchors { right: parent.right; top: parent.top; margins: 14 }
            width: 38; height: 38; radius: 19
            color: closeMa.containsMouse ? "#40FFFFFF" : "#22FFFFFF"
            Text { anchors.centerIn: parent; text: "\\u2715"; color: "#E8DFC8"; font.pixelSize: 16 }
            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.open = false }
        }

        Item {
            id: holder
            width: 720; height: 600          // the popup's own size; scaled up to fill most of the screen
            anchors.centerIn: parent
            scale: Math.max(0.6, Math.min(1.6, (parent.height - 80) / 600, (parent.width - 80) / 720))
            MouseArea { anchors.fill: parent }       // clicks inside do not close

            Loader {
                id: pop
                anchors.fill: parent
                active: root.built
                source: "NetworkPopup.qml"
                onLoaded: item.visible = Qt.binding(function () { return root.open; })
            }
        }
    }
}
''')


# Anserin's real ClickButton (ours was a 49-line stand-in: no `triggered`, no contentAlignment ...). A superset, so the
# Serpantinum faces that use it keep working. It reads three I18n members our shim lacks.
cb = shim / "ClickButton.qml"
if cb.exists() and "action_highlight" not in cb.read_text():
    backup(cb)
    write(cb, clean((qs / "reusables" / "buttons" / "ClickButton.qml").read_text(), "ClickButton.qml", [
        ('    property string buttonText: ""\n', '    property string buttonText: ""\n    property real bgOpacity: 1.0   // used by the Serpantinum faces\n'),
    ]))
i18n_s = shim / "I18n.qml"
ti = i18n_s.read_text()
if "property bool rtl" not in ti:
    backup(i18n_s)
    k = ti.rstrip().rfind("}")
    write(i18n_s, ti[:k].rstrip() + """

    // added by port_anserin_panels.py (Anserin's ClickButton / Input read these)
    readonly property bool rtl: false
    readonly property int layoutDirection: Qt.LeftToRight
    readonly property int textAlignment: Text.AlignLeft
}
""")

# ============================================================ shared: i18n strings, qmldir, shell.qml
add_qmldir(shim / "qmldir", ["singleton PanelLayout 1.0 PanelLayout.qml", "FillButton 1.0 FillButton.qml"])
add_qmldir(root / "qmldir", ["BubbleWindow 1.0 widgets/serp/panels/BubbleWindow.qml",
                             "NetworkWindow 1.0 widgets/serp/panels/NetworkWindow.qml"])

en = json.loads((assets / "languages" / "en.json").read_text())
def dig(k):
    cur = en
    for p in k.split("."):
        cur = cur[p]
    return cur
keys = set(re.findall(r'I18n\.t\("([^"]+)"', net_src.read_text()))
want = {}
for k in sorted(keys):
    try:
        v = dig(k)
        if isinstance(v, str): want[k] = v
    except (KeyError, TypeError):
        pass
i18n = shim / "I18n.qml"
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

manual = []
shell = root / "shell.qml"
t = shell.read_text()
if "BubbleWindow" not in t:
    a = re.search(r'^(\s*)ScreentimeWindow \{ \}.*$', t, re.M)
    if a:
        backup(shell)
        ind = a.group(1)
        write(shell, t[:a.end()] + f"\n{ind}BubbleWindow {{ }}\n{ind}NetworkWindow {{ }}" + t[a.end():])
    else:
        manual.append("add these two lines inside ShellRoot in shell.qml:\n    BubbleWindow { }\n    NetworkWindow { }")


# ============================================================ small cards for the widget list
# Compact orbit cards; a click opens the full panel (same pattern as the Screen time card).
write(here / "AnserinNetworkCard.qml", r"""import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Small network card (port_anserin_panels.py). Click opens Anserin's network manager:
//   qs -c outerwilds ipc call network toggle
WidgetCard {
    id: w
    title: "NETWORK"
    designW: 240
    designH: 110

    property bool up: false
    property string kind: ""
    property string conn: ""
    property string iface: ""
    property real rxRate: 0
    property real txRate: 0
    property var prev: null

    function rate(b) {
        if (b < 1024) return Math.round(b) + " B/s";
        if (b < 1048576) return Math.round(b / 1024) + " KB/s";
        return (b / 1048576).toFixed(1) + " MB/s";
    }
    // nmcli -t escapes ':' and '\' with a backslash
    function splitT(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) { cur += line[i + 1]; i++; }
            else if (c === ":") { out.push(cur); cur = ""; }
            else cur += c;
        }
        out.push(cur);
        return out;
    }
    function parse(txt) {
        const parts = txt.split("\n---\n");
        let best = null;
        for (const raw of (parts[0] || "").split("\n")) {
            if (!raw) continue;
            const f = splitT(raw);
            if (f.length >= 4 && f[1] === "connected" && (f[0] === "wifi" || f[0] === "ethernet")) { best = f; break; }
        }
        if (!best) { w.up = false; w.conn = ""; w.kind = ""; w.iface = ""; w.rxRate = 0; w.txRate = 0; w.prev = null; return; }
        w.up = true; w.kind = best[0]; w.conn = best[2]; w.iface = best[3];
        for (const line of (parts[1] || "").split("\n")) {
            const tk = line.trim().replace(":", " ").split(/\s+/);
            if (tk[0] !== w.iface || tk.length < 10) continue;
            const now = Date.now(), rx = Number(tk[1]), tx = Number(tk[9]);
            if (w.prev && w.prev.iface === w.iface && now > w.prev.t) {
                const dt = (now - w.prev.t) / 1000;
                w.rxRate = Math.max(0, (rx - w.prev.rx) / dt);
                w.txRate = Math.max(0, (tx - w.prev.tx) / dt);
            }
            w.prev = { iface: w.iface, t: now, rx: rx, tx: tx };
        }
    }

    Process {
        id: proc
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE,CONNECTION,DEVICE device 2>/dev/null; echo ---; cat /proc/net/dev"]
        stdout: StdioCollector { onStreamFinished: w.parse(text) }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

    Rectangle {
        id: dot
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 6 * w.ui
        width: 9 * w.ui; height: width; radius: width / 2
        color: w.up ? w.cGold : w.cDim
    }
    Text {
        anchors.left: dot.right
        anchors.leftMargin: 8 * w.ui
        anchors.right: parent.right
        anchors.verticalCenter: dot.verticalCenter
        text: w.up ? w.conn : "OFFLINE"
        elide: Text.ElideRight
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.round(15 * w.ui)
    }
    Text {
        id: sub
        anchors.top: dot.bottom
        anchors.topMargin: 8 * w.ui
        anchors.left: parent.left
        text: w.up ? (w.kind === "wifi" ? "WI-FI" : "ETHERNET") + "  " + w.iface : "NO CONNECTION"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(11 * w.ui)
    }
    Row {
        visible: w.up
        anchors.top: sub.bottom
        anchors.topMargin: 10 * w.ui
        anchors.left: parent.left
        spacing: 16 * w.ui
        Text { text: "\u2193 " + w.rate(w.rxRate); color: w.cCream; font.family: "monospace"; font.pixelSize: Math.round(12 * w.ui) }
        Text { text: "\u2191 " + w.rate(w.txRate); color: w.cDim; font.family: "monospace"; font.pixelSize: Math.round(12 * w.ui) }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "network", "toggle"])
    }
}
""")

write(here / "AnserinBubbleCard.qml", r"""import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Small process card (port_anserin_panels.py): the busiest processes as little shaded bubbles.
// Click opens Anserin's Bubble Monitor:  qs -c outerwilds ipc call bubble toggle
// Needs python-psutil (scripts/topprocs.py).
WidgetCard {
    id: w
    title: "PROCESSES"
    designW: 240
    designH: 130

    property var procs: []          // [{ name, cpu }]
    property bool missing: false

    function parse(txt) {
        const out = [];
        w.missing = false;
        for (const raw of txt.split("\n")) {
            if (raw.indexOf("!psutil") === 0) { w.missing = true; continue; }
            const m = raw.match(/^\s*([0-9.]+)\s+(.+)$/);
            if (m) out.push({ cpu: Number(m[1]), name: m[2] });
        }
        w.procs = out;
    }

    Process {
        id: proc
        command: ["python3", Qt.resolvedUrl("scripts/topprocs.py").toString().replace("file://", "")]
        stdout: StdioCollector { onStreamFinished: w.parse(text) }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

    Text {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        text: "CPU " + Sensors.cpuPercent + "%   RAM " + Sensors.ramPercent + "%" + (Sensors.cpuTempC > 0 ? "   " + Math.round(Sensors.cpuTempC) + "\u00b0" : "")
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.round(12 * w.ui)
    }

    Row {
        anchors.top: head.bottom
        anchors.topMargin: 8 * w.ui
        anchors.left: parent.left
        anchors.right: parent.right
        height: 62 * w.ui
        spacing: 8 * w.ui
        Repeater {
            model: w.procs
            delegate: Item {
                id: cell
                width: (parent.width - 3 * 8 * w.ui) / 4
                height: parent.height
                readonly property real d: Math.min(width, (16 + Math.sqrt(Math.max(0, modelData.cpu)) * 5) * w.ui)
                readonly property color base: index === 0 && modelData.cpu > 25 ? w.cGold : w.cCream
                Rectangle {
                    id: ball
                    width: cell.d; height: cell.d; radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4 * w.ui + (36 * w.ui - cell.d) / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(cell.base, 1.25) }
                        GradientStop { position: 1.0; color: Qt.darker(cell.base, 1.9) }
                    }
                    Rectangle {
                        x: parent.width * 0.2; y: parent.height * 0.14
                        width: parent.width * 0.38; height: parent.height * 0.22; radius: height / 2
                        rotation: -28
                        color: "#55FFFFFF"
                    }
                }
                Text {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: w.cCream
                    font.family: "monospace"
                    font.pixelSize: Math.round(9 * w.ui)
                }
            }
        }
    }
    Text {
        visible: w.procs.length === 0
        anchors.centerIn: parent
        text: w.missing ? "NEEDS PYTHON-PSUTIL" : "READING..."
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(11 * w.ui)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "bubble", "toggle"])
    }
}
""")

write(here / "scripts" / "topprocs.py", r"""#!/usr/bin/env python3
# Busiest processes, one "cpu% name" per line (used by AnserinBubbleCard.qml). Needs python-psutil.
import sys, time
try:
    import psutil
except ImportError:
    print("!psutil")
    sys.exit(0)
procs = []
for p in psutil.process_iter(["name"]):
    try:
        p.cpu_percent(None)
        procs.append(p)
    except Exception:
        pass
time.sleep(0.6)
out = []
for p in procs:
    try:
        out.append((p.cpu_percent(None), p.info["name"] or "?"))
    except Exception:
        pass
out.sort(reverse=True)
for c, n in out[:4]:
    print("%.1f %s" % (min(c, 999.0), n))
""", 0o755)

add_qmldir(here / "qmldir", ["AnserinNetworkCard 1.0 AnserinNetworkCard.qml", "AnserinBubbleCard 1.0 AnserinBubbleCard.qml"])

cat = root / "data" / "WidgetConfig.qml"
if cat.exists():
    ct = cat.read_text()
    if "AnserinNetworkCard" not in ct:
        ms = list(re.finditer(r'^([ \t]*)\{ source: "serp/Anserin[^"]*".*$', ct, re.M))
        if ms:
            last = ms[-1]
            grp = (re.search(r'group:\s*"([^"]*)"', last.group(0)) or [None, "Anserin"])[1]
            ind = last.group(1)
            ents = [f'{ind}{{ source: "serp/AnserinNetworkCard.qml", name: "Network (small)", group: "{grp}", designW: 240, title: "NETWORK" }}',
                    f'{ind}{{ source: "serp/AnserinBubbleCard.qml", name: "Processes (small)", group: "{grp}", designW: 240, title: "PROCESSES" }}']
            had_comma = last.group(0).rstrip().endswith(",")
            ins = ("" if had_comma else ",") + "\n" + ",\n".join(ents) + ("," if had_comma else "")
            backup(cat)
            write(cat, ct[:last.end()] + ins + ct[last.end():])
        else:
            manual.append("add to the catalog in data/WidgetConfig.qml:\n"
                          '    { source: "serp/AnserinNetworkCard.qml", name: "Network (small)", group: "Anserin", designW: 240, title: "NETWORK" },\n'
                          '    { source: "serp/AnserinBubbleCard.qml", name: "Processes (small)", group: "Anserin", designW: 240, title: "PROCESSES" },')

print("\n".join(changed) if changed else "nothing to do (already ported)")
for s in manual:
    print("\n!! " + s)
print("\nRestart: qs -c outerwilds     then try:  qs -c outerwilds ipc call bubble toggle   /   ... ipc call network toggle")
