import QtQuick
import "../shim"
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "bubble/BubbleLogic.js" as B

// The System page's Bubble style (panel.styles.system "bubble"), from the Bubble Monitor design (~/Downloads/
// bubble-monitor, Claude Design): this machine as bubbles drifting in space, read once a second by bubble/
// bubble-feed.py (psutil and Hyprland's open windows, read-only) only while the page is shown or full screen.
//   The bubbles: dials for CPU, memory, temperature, network and disk; the busiest processes or the open apps (each
//   app's windows and everything they started, white), picked top left; full screen shows both. They drift on their
//   own, knock with a soft sound (bubble/bloop.wav) and flatten when packed; a held one trails the pointer on the desktop
//   duck's carry spring; drag the empty space to move, the wheel zooms 30–100 % in eased steps of 10 %. Behind them
//   endless space with the black hole (bubble/space/).
//   A tapped bubble's page slides in on the left (60 % of the page, 30 % of the screen full screen) and the camera
//   keeps that bubble in the middle of what is left; another bubble's page, from a tap or the four buttons under the
//   full-screen one (CPU, memory, temperature, disk; the wheel steps through them), takes its place by moving up.
//   Full screen (the button top right): the page is sucked like a cloth into that button and ink spreads from it over
//   the screen (bubble/shaders/); the bubbles get the whole screen at 50 %. Esc or the button brings it back into the
//   panel, which stays open meanwhile (PanelLayout.bubbleFull).
// The logic (physics, lightning, the charts' lines) is bubble/BubbleLogic.js.
Item {
    id: shell

    property bool active: false             // the page is shown
    property bool hosted: false             // opened as Outer Wilds' full-screen overlay (port_anserin_panels.py)
    property bool sphere: true              // shade the bubbles like spheres (port_anserin_panels.py)
    signal closeRequested()
    property bool preview: false            // the Edit panel's live preview: it never goes full screen
    readonly property bool running: active || full || preview
    readonly property string bump: "bloop"

    // the design's tokens, from the theme
    // the design's tokens, from the theme or as drawn
    readonly property color cBg: ThemeBackend.base
    readonly property color cPanel: ThemeBackend.surface0
    readonly property color cLine: ThemeBackend.surface1
    readonly property color cLine2: ThemeBackend.surface2
    readonly property color cText: ThemeBackend.text
    readonly property color cMuted: ThemeBackend.subtext1
    readonly property color cInk: ThemeBackend.crust
    readonly property color cAccent: lift(ThemeBackend.mauve)
    readonly property color cHot: lift(ThemeBackend.red)
    readonly property color cWarm: lift(ThemeBackend.yellow)
    readonly property color cSky: lift(ThemeBackend.blue)
    readonly property color cMint: lift(ThemeBackend.teal)
    readonly property color cWhite: Qt.lighter(ThemeBackend.text, 1.12)      // the open apps' bubbles
    readonly property color cBolt: Qt.tint(ThemeBackend.text, Qt.alpha(ThemeBackend.blue, 0.35))
    // a data colour bright enough to read on the dark and to carry dark ink: some Matugen palettes make it deep
    function lift(c) {
        const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        return l >= 0.5 ? c : Qt.hsla(c.hslHue < 0 ? 0 : c.hslHue, Math.min(1, c.hslSaturation + 0.1), Math.max(c.hslLightness, 0.72), 1);
    }
    readonly property string fMono: ThemeBackend.fontFamily
    readonly property string fDisplay: ThemeBackend.fontFamily

    // ---------- full screen. Going: the page moves into the full-screen window at the same spot and is sucked like a
    // cloth into its full-screen button, the parts nearest the button first (shaders/bubble_cloth.vert, drawing the
    // page live); then the page takes the whole screen, and ink spreads from the button until it covers the screen,
    // the full-screen monitor showing wherever it has reached (shaders/bubble_ink.frag). Coming back runs it backwards.
    property bool full: false
    property bool leaving: false
    property real fsT: 0
    property rect slotRect: Qt.rect(0, 0, 1, 1)                  // where the page is on the screen (set going full)
    property var camBeforeFull: null
    readonly property point btnCenter: Qt.point(pageSlot.width - 12 - 20, 12 + 20)      // the full-screen button, in the page
    readonly property var homeScreen: typeof masterWindow !== "undefined" && masterWindow.screen ? masterWindow.screen : Quickshell.screens[0]
    readonly property real screenW: homeScreen.width
    readonly property real screenH: homeScreen.height
    // the left panel stays open while the page is away full screen (its auto-hide waits)
    onFullChanged: PanelLayout.bubbleFull = full
    Component.onDestruction: if (full) PanelLayout.bubbleFull = false
    NumberAnimation {
        id: fsAnim
        target: shell; property: "fsT"
        onFinished: if (shell.fsT <= 0) {
            page.parent = pageSlot;
            shell.full = false;
            shell.leaving = false;
            page.forceActiveFocus();
        }
    }
    // halfway the page changes size: whole screen on the way out (the cloth has gone into the middle), its own on the
    // way back (the ink has drawn in)
    onFsTChanged: {
        if (!full) return;
        if (!leaving && fsT >= 0.5 && page.parent === clothHolder) {
            page.parent = fsHost;
            page.resizeWorld(screenW / 0.5, screenH / 0.5);
            page.camZ = 0.5; page.camX = (screenW - page.worldW * 0.5) / 2; page.camY = (screenH - page.worldH * 0.5) / 2;
        } else if (leaving && fsT <= 0.5 && page.parent === fsHost) {
            page.parent = clothHolder;
            page.resizeWorld(page.worldSize.w, page.worldSize.h);
            const c = camBeforeFull || page.fitCam();
            page.camX = c.x; page.camY = c.y; page.camZ = c.z;
        }
    }
    function goFull() {
        if (full || preview) return;
        // the page's place on the screen: in the main window, which starts frameInset in from the screen's edge
        const p = pageSlot.mapToItem(null, 0, 0), inset = typeof masterWindow !== "undefined" ? masterWindow.frameInset : 0;
        slotRect = Qt.rect(p.x + inset, p.y + inset, pageSlot.width, pageSlot.height);
        begin();
    }
    function begin() {
        camBeforeFull = { x: page.camX, y: page.camY, z: page.camZ };
        full = true;
        page.parent = clothHolder;
        page.forceActiveFocus();
        fsAnim.stop(); fsAnim.from = 0; fsAnim.to = 1; fsAnim.duration = 1800; fsAnim.start();
    }
    function leaveFull() {
        if (!full || leaving || fsT < 1) return;
        page.closeNow();
        leaving = true;
        fsAnim.stop(); fsAnim.from = 1; fsAnim.to = 0; fsAnim.duration = 1500; fsAnim.start();
    }
    PanelWindow {
        id: fsWin
        visible: shell.full
        screen: shell.homeScreen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "anserin-bubble-monitor"
        WlrLayershell.keyboardFocus: shell.full ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        readonly property bool moving: shell.fsT < 1 || shell.leaving

        Item { id: fsHost; anchors.fill: parent }
        ShaderEffectSource { id: fsSource; anchors.fill: parent; sourceItem: fsHost; hideSource: fsWin.moving; live: fsWin.moving; visible: false }
        // the page at its own size and place while it is the cloth (drawn only through the cloth); once it has gone
        // to full size the cloth keeps its last picture for the little that is left of it
        Item { id: clothHolder; x: shell.slotRect.x; y: shell.slotRect.y; width: shell.slotRect.width; height: shell.slotRect.height }
        ShaderEffectSource { id: clothSource; sourceItem: clothHolder; hideSource: true; visible: false; live: page.parent === clothHolder }

        // the ink, spreading from the button once the cloth has gone in (0.5–1); far enough to reach every corner
        // even where its ragged edge lags most
        ShaderEffect {
            id: ink
            anchors.fill: parent
            visible: fsWin.moving && shell.fsT > 0.5
            readonly property real t: B.clamp((shell.fsT - 0.5) / 0.5, 0, 1)
            readonly property point from: Qt.point(shell.slotRect.x + shell.btnCenter.x, shell.slotRect.y + shell.btnCenter.y)
            readonly property real reach: Math.max(Math.hypot(from.x, from.y), Math.hypot(width - from.x, from.y),
                                                   Math.hypot(from.x, height - from.y), Math.hypot(width - from.x, height - from.y))
            property var source: fsSource
            property vector2d res: Qt.vector2d(width, height)
            property vector2d center: Qt.vector2d(from.x, from.y)
            property real inkR: (1 - Math.pow(1 - t, 3)) * (reach / 0.76 + 60)
            property real time: page.clock % 1000
            property color inkColor: Qt.darker(ThemeBackend.base, 1.2)
            property color rimColor: shell.cAccent
            fragmentShader: Qt.resolvedUrl("bubble/shaders/bubble_ink.frag.qsb")
        }
        // the cloth (0–0.6): the UI on a fine mesh, sucked into its full-screen button
        ShaderEffect {
            id: cloth
            x: shell.slotRect.x; y: shell.slotRect.y
            width: shell.slotRect.width; height: shell.slotRect.height
            visible: fsWin.moving && shell.fsT < 0.6
            mesh: GridMesh { resolution: Qt.size(44, 40) }
            property var source: clothSource
            property real prog: B.clamp(shell.fsT / 0.6, 0, 1)
            property real swirl: 1.2
            property vector2d size: Qt.vector2d(width, height)
            property vector2d target: Qt.vector2d(shell.btnCenter.x, shell.btnCenter.y)
            vertexShader: Qt.resolvedUrl("bubble/shaders/bubble_cloth.vert.qsb")
            fragmentShader: Qt.resolvedUrl("bubble/shaders/bubble_cloth.frag.qsb")
        }
        // nothing is taken while it moves
        MouseArea { anchors.fill: parent; enabled: fsWin.moving; acceptedButtons: Qt.AllButtons }
    }

    // the bump sound: four players taken in turn, so knocks close together can overlap
    Item {
        id: monitorBump
        property int next: 0
        readonly property url src: shell.bump !== "" ? Qt.resolvedUrl("bubble/" + shell.bump + ".wav") : ""
        SoundEffect { id: bump0; source: monitorBump.src }
        SoundEffect { id: bump1; source: monitorBump.src }
        SoundEffect { id: bump2; source: monitorBump.src }
        SoundEffect { id: bump3; source: monitorBump.src }
        function play(volume) {
            if (shell.bump === "") return;
            const fx = [bump0, bump1, bump2, bump3][next];
            next = (next + 1) % 4;
            fx.volume = volume;
            fx.play();
        }
    }

    // ---------- the page (in its slot; it moves to the full-screen window and back) ----------
    Item {
        id: pageSlot
        anchors.fill: parent
        Rectangle {
            id: page
            anchors.fill: parent
            clip: true
            radius: shell.full ? 0 : ThemeBackend.clampedBorderRadius
            color: shell.hosted ? "transparent" : shell.cBg
            focus: true

            // ---------- CONFIG (main.js) ----------
            readonly property int tickMs: 1000
            readonly property var worldSize: ({ w: 1265, h: 1080 })    // the design's 1100 × 940, 15 % roomier
            readonly property real zoomMin: 0.3
            readonly property real zoomMax: 1
            readonly property real smoothTau: 0.3
            readonly property real hotCpu: 45
            readonly property int maxProcs: 12
            readonly property int linger: 8000          // ms a process stays after leaving the busiest
            readonly property var kindLabel: ({ app: "App", dev: "Dev", sys: "System" })
            function kindColor(k) { return k === "dev" ? shell.cAccent : k === "sys" ? shell.cMuted : shell.cText; }
            function metricColor(key) { return key === "cpu" ? shell.cAccent : key === "mem" ? shell.cText : key === "temp" ? shell.cWarm : key === "disk" ? shell.cMint : shell.cSky; }
            function procR(cpu) { return 24 + Math.sqrt(Math.max(0, cpu)) * 7.5; }

            // ---------- state ----------
            property var world: new B.World(worldSize.w, worldSize.h, { attract: 0 })     // they drift, nothing pulls
            property real worldW: worldSize.w
            property real worldH: worldSize.h
            onWorldWChanged: world.w = worldW
            onWorldHChanged: world.h = worldH
            property var source: null
            property real bumpAt: 0
            readonly property color fg: shell.cText
            readonly property color fgAccent: ov ? ov.color : shell.cAccent
            property var ms: ({
                snap: null, live: true, pausedAt: 0, lastTick: Date.now(), stressUntil: 0,
                cores: B.fill(16, () => ({ t: 0, v: 0 })),
                hist: B.fill(62, () => 0), tempHist: B.fill(62, () => 50), up: B.fill(44, () => 0), down: B.fill(44, () => 0),
                temp: { t: 50, v: 50 }, apps: { t: 0, v: 0 }, cache: { t: 0, v: 0 }, netU: { t: 0, v: 0 }, netD: { t: 0, v: 0 },
                maxU: 10, maxD: 40, camT: null, press: null, pan: null, open: null, period: 1000,
                dR: { t: 0, v: 0 }, dW: { t: 0, v: 0 }, dRh: B.fill(44, () => 0), dWh: B.fill(44, () => 0), maxDR: 5, maxDW: 5
            })
            property real camX: 0
            property real camY: 0
            property real camZ: 0.7
            property int tick: 0                 // bumped every frame; what the bubbles redraw by
            // what the top bar, the dials and the overlay show (set each frame)
            property real vAvg: 0
            property real vTemp: 50
            property real vMem: 0
            property real vTotal: 8
            property string upTxt: "—"
            // What the field shows besides the dials: in the panel's page either the busiest processes or the open apps
            // (the switch by the full-screen button); full screen, both.
            property string mode: "procs"
            readonly property bool showProcs: mode === "procs" || shell.full
            readonly property bool showApps: mode === "apps" || shell.full
            onShowProcsChanged: refill()
            onShowAppsChanged: refill()
            function refill() { closeNow(); if (ms.snap) { reconcileProcs(ms.snap.procs); reconcileApps(ms.snap.apps || []); } }
            property real vDisk: 0                   // the drives' used share
            property var battery: null               // { pct, plugged } (none without a battery)
            // The open bubble's page (details()), worked out again four times a second or when another bubble opens:
            // building it every frame remade every row of the page each frame (the stutter in full screen). What
            // moves every frame reads `phase` (how far it is to the next sample) instead.
            property var info: null
            property string infoId: ""
            property real infoAt: 0
            property real phase: 0
            // where the scan dot is: it moves on at the samples' real pace, and each sample takes one run off, so it
            // never jumps (a little past 1 while a sample is late, a little below 0 after one came early)
            property real sweep: 0
            property int swapDir: 1                  // which way the next page change moves: 1 up, -1 down
            property var ov: null                // the open bubble's page: header and everything its page draws

            ListModel { id: bubbles }           // { nid } of every bubble on the field, in the world's order
            property var bubbleItems: ({})          // nid → its Bubble (each registers itself)
            function dialFrac(k) {
                return B.clamp(k === "cpu" ? vAvg / 100 : k === "mem" ? vMem / vTotal : k === "temp" ? (vTemp - 30) / 70
                             : k === "disk" ? vDisk : ms.netD.v / 120, 0.01, 1);
            }
            function dialText(k) {
                return k === "cpu" ? Math.round(vAvg) + "%" : k === "mem" ? vMem.toFixed(1) + "G" : k === "temp" ? Math.round(vTemp) + "°"
                     : k === "disk" ? Math.round(vDisk * 100) + "%" : ms.netD.v.toFixed(0) + "M";
            }

            // ---------- data in ----------
            function makeSource() { source = { kind: "live" }; }
            Process {
                id: feed
                running: shell.running
                // stopped on its own while the page is shown: start it again a moment later
                onExited: if (shell.running) feedRestart.restart()
                command: ["python3", decodeURIComponent(Qt.resolvedUrl("bubble/bubble-feed.py").toString().replace("file://", "")), "1"]
                stdout: SplitParser {
                    onRead: (line) => {
                        let snap = null;
                        try { snap = JSON.parse(line); } catch (e) { return; }
                        if (snap && !snap.error && page.source && page.source.kind === "live") page.onSnapshot(snap);
                    }
                }
            }

            Timer { id: feedRestart; interval: 1000; onTriggered: if (shell.running && !feed.running) feed.running = true }

            function onSnapshot(snap) {
                const st = ms;
                if (!st.live) return;
                const n = snap.cpu.cores.length;
                if (st.cores.length !== n) st.cores = B.fill(n, () => ({ t: 0, v: 0 }));
                if (!st.snap) {           // first sample: start graphs and dials at real values instead of zero
                    const a0 = snap.cpu.cores.reduce((a, b) => a + b, 0) / n;
                    st.hist.fill(a0); st.tempHist.fill(snap.tempC); st.up.fill(snap.net.upMBs); st.down.fill(snap.net.downMBs);
                    snap.cpu.cores.forEach((v, i) => { st.cores[i].v = v; });
                    st.temp.v = snap.tempC; st.apps.v = snap.mem.appsGB; st.cache.v = snap.mem.cacheGB;
                }
                st.snap = snap;
                snap.cpu.cores.forEach((v, i) => { st.cores[i].t = v; });
                const avg = snap.cpu.cores.reduce((a, b) => a + b, 0) / n;
                const push = (arr, v) => { arr.push(v); arr.shift(); };
                push(st.hist, avg); push(st.tempHist, snap.tempC); push(st.up, snap.net.upMBs); push(st.down, snap.net.downMBs);
                st.temp.t = snap.tempC; st.apps.t = snap.mem.appsGB; st.cache.t = snap.mem.cacheGB; st.netU.t = snap.net.upMBs; st.netD.t = snap.net.downMBs;
                if (snap.disk) {
                    st.dR.t = snap.disk.readMBs; st.dW.t = snap.disk.writeMBs;
                    push(st.dRh, snap.disk.readMBs); push(st.dWh, snap.disk.writeMBs);
                    const used = snap.disk.drives.reduce((a, d) => a + d.usedGB, 0), total = snap.disk.drives.reduce((a, d) => a + d.totalGB, 0);
                    vDisk = total > 0 ? used / total : 0;
                }
                battery = snap.battery || null;
                reconcileProcs(snap.procs);
                reconcileApps(snap.apps || []);
                sweep = Math.max(-0.3, sweep - 1);
                const gap = Date.now() - st.lastTick;
                if (gap > 300 && gap < 3000) st.period += (gap - st.period) * 0.3;
                st.lastTick = Date.now();
            }

            function addNode(props) {
                const n = world.add(props);
                bubbles.append({ nid: n.id });
                return n;
            }
            function seedMetrics() {
                [{ id: "cpu", name: "CPU", r0: 70 }, { id: "mem", name: "Memory", r0: 60 }, { id: "temp", name: "Thermal", r0: 54 }, { id: "net", name: "Network", r0: 54 },
                 { id: "disk", name: "Disk", r0: 52 }]
                    .forEach((m, i) => {
                        const cell = (i * 7) % 16;
                        addNode({ id: m.id, type: "metric", key: m.id, name: m.name, rT: m.r0,
                                  x: ((cell % 4) + 0.5) * world.w / 4, y: (Math.floor(cell / 4) + 0.5) * world.h / 4 });
                    });
            }
            // keep the process bubbles in step with the latest snapshot (keyed by pid)
            function reconcileProcs(procs) {
                const now = Date.now();
                if (!showProcs) {
                    for (const n of world.nodes) if (n.type === "proc" && !n.dying) n.dying = now;
                    return;
                }
                const top = procs.slice().sort((a, b) => b.cpu - a.cpu).slice(0, maxProcs);
                const seen = {};
                let slot = world.nodes.length;
                for (const p of top) {
                    const id = "p" + p.pid; seen[id] = true;
                    let n = world.find(id);
                    if (!n || n.dying) {
                        if (n) world.nodes = world.nodes.filter(x => x !== n);
                        const cell = (slot++ * 7) % 16;
                        n = addNode({ id: id, type: "proc", pid: p.pid, cpu: p.cpu, rT: procR(p.cpu),
                                      x: ((cell % 4) + 0.5) * world.w / 4 + (Math.random() - 0.5) * 140,
                                      y: (Math.floor(cell / 4) + 0.5) * world.h / 4 + (Math.random() - 0.5) * 120,
                                      vx: (Math.random() - 0.5) * 80, vy: (Math.random() - 0.5) * 80 });
                    }
                    Object.assign(n, { name: p.name, cmd: p.cmd, user: p.user, memMB: p.memMB, state: p.state, kind: B.classify(p.name, p.user),
                                       cpuT: p.cpu, paused: p.state === "T", h: (n.h || B.fill(32, () => p.cpu)), outSince: 0,
                                       threads: p.threads, started: p.started, cpuSec: p.cpuSec, readMB: p.readMB, writeMB: p.writeMB });
                    n.h.push(p.cpu); n.h.shift();
                }
                // Dropped out of the busiest: it stays, easing down, until it has been out for `linger` (a process near
                // the cut would otherwise pop in and out every second); the open bubble stays while its page is open.
                // Still in the snapshot below the top: its numbers keep coming.
                const byPid = {};
                for (const p of procs) byPid["p" + p.pid] = p;
                for (const n of world.nodes) {
                    if (n.type !== "proc" || seen[n.id] || n.dying) continue;
                    const p = byPid[n.id];
                    if (p) { n.cpuT = p.cpu; n.memMB = p.memMB; n.state = p.state; n.paused = p.state === "T";
                             if (p.threads !== undefined) Object.assign(n, { threads: p.threads, cpuSec: p.cpuSec, readMB: p.readMB, writeMB: p.writeMB }); }
                    else n.cpuT *= 0.7;
                    n.h.push(n.cpuT); n.h.shift();
                    if (!n.outSince) n.outSince = now;
                    if (now - n.outSince > linger && !(ms.open && ms.open.id === n.id)) n.dying = now;
                }
                // and the field never holds more than a few over maxProcs: the quietest lingering ones go first
                const procNodes = world.nodes.filter(x => x.type === "proc" && !x.dying);
                const extra = procNodes.length - (maxProcs + 4);
                if (extra > 0) procNodes.filter(x => !seen[x.id] && !(ms.open && ms.open.id === x.id))
                                       .sort((a, b) => a.cpuT - b.cpuT).slice(0, extra).forEach(x => x.dying = now);
            }

            // The world's size: the full screen's is the whole screen at 50 %. Growing, the bubbles keep their places
            // round the middle; shrinking, their places scale down with it (none is cut off at a wall), and a few
            // quick steps part the ones that came too close.
            function resizeWorld(w, h) {
                const w0 = world.w, h0 = world.h, grow = w >= w0;
                for (const n of world.nodes) {
                    if (grow) { n.x += (w - w0) / 2; n.y += (h - h0) / 2; }
                    else { n.x *= w / w0; n.y *= h / h0; }
                }
                worldW = w; worldH = h;
                world.w = w; world.h = h;
                ms.camT = null; ms.camBack = null; ms.press = null; ms.pan = null; world.dragTarget = null;
                if (!grow) for (let i = 0; i < 8; i++) world.step(0.016, Date.now());
            }

            // one bubble per open app (its windows' class), white, sized by all its processes' CPU together
            function reconcileApps(apps) {
                const now = Date.now(), seen = {};
                let slot = world.nodes.length;
                if (showApps) for (const a of apps) {
                    const id = "a" + a.cls; seen[id] = true;
                    let n = world.find(id);
                    if (!n || n.dying) {
                        if (n) world.nodes = world.nodes.filter(x => x !== n);
                        const cell = (slot++ * 7 + 3) % 16;
                        n = addNode({ id: id, type: "group", cpu: a.cpu, rT: procR(a.cpu),
                                      x: ((cell % 4) + 0.5) * world.w / 4 + (Math.random() - 0.5) * 140,
                                      y: (Math.floor(cell / 4) + 0.5) * world.h / 4 + (Math.random() - 0.5) * 120,
                                      vx: (Math.random() - 0.5) * 80, vy: (Math.random() - 0.5) * 80 });
                    }
                    Object.assign(n, { name: a.name, cls: a.cls, cpuT: a.cpu, memMB: a.memMB, windows: a.windows, ws: a.ws, titles: a.titles,
                                       procCount: a.procCount, procs: a.procs, h: (n.h || B.fill(32, () => a.cpu)) });
                    n.h.push(a.cpu); n.h.shift();
                }
                // a closed app goes (its page stays open until closed)
                for (const n of world.nodes)
                    if (n.type === "group" && !seen[n.id] && !n.dying && !(ms.open && ms.open.id === n.id)) n.dying = now;
            }

            // ---------- interaction ----------
            function toWorld(p) { return { x: (p.x - camX) / camZ, y: (p.y - camY) / camZ }; }
            function grab() {
                const p = ms.press; if (!p) return;
                const n = world.find(p.id); p.drag = true;
                if (n) { n.grab = true; n.w = Math.min(0.22, n.w + 0.12); world.dragTarget = { x: p.wx, y: p.wy }; }
            }
            function release() {
                for (const n of world.nodes) if (n.grab) { n.grab = false; n.vx = B.clamp(n.vx, -1400, 1400); n.vy = B.clamp(n.vy, -1400, 1400); }
                ms.press = null; world.dragTarget = null;
            }
            // one step of 10 % in (dir 1) or out (-1) around p, eased toward (steps add up while it moves)
            function zoomStep(p, dir) {
                const base = ms.camT ? ms.camT : { x: camX, y: camY, z: camZ };
                const z1 = B.clamp(Math.round((base.z + dir * 0.1) * 10) / 10, zoomMin, zoomMax);
                if (z1 === base.z) return;
                zoomAt(p, z1 / base.z, true);
            }
            property real wheelAcc: 0
            function zoomAt(p, f, animate) {
                const base = animate && ms.camT ? ms.camT : { x: camX, y: camY, z: camZ };
                const z1 = B.clamp(base.z * f, zoomMin, zoomMax);
                const wx = (p.x - base.x) / base.z, wy = (p.y - base.y) / base.z;
                const t = { x: p.x - wx * z1, y: p.y - wy * z1, z: z1 };
                if (animate) ms.camT = t; else { ms.camT = null; camX = t.x; camY = t.y; camZ = t.z; }
            }
            function fitCam() {
                const z = B.clamp(Math.floor(Math.min(field.width / world.w, field.height / world.h) * 10 + 0.001) / 10, zoomMin, zoomMax);
                return { x: (field.width - world.w * z) / 2, y: (field.height - world.h * z) / 2, z: z };
            }

            // ---------- the overlay ----------
            function openNode(n) {
                release();
                ms.open = { id: n.id, node: n, prog: 0, dir: 1, x: 0, y: 0, r: 30, kind: kindOf(n) };
                page.forceActiveFocus();
            }
            function closeOverlay() { if (ms.open) ms.open.dir = -1; }
            function closeNow() { ms.open = null; ov = null; }
            // the open bubble's own page in place of another's (a moon of RAM is a process)
            // (with the side panel open the panel stays and shows the other bubble; the camera goes over to it)
            function openId(id) {
                const n = world.find(id);
                if (!n || n.dying) return;
                if (ms.open && ms.open.dir > 0) {
                    if (ms.open.id !== id) Object.assign(ms.open, { id: n.id, node: n, kind: kindOf(n) });
                    return;
                }
                ms.open = null;
                openNode(n);
            }
            property real clock: 0
            Keys.onEscapePressed: { if (ms.open) closeOverlay(); else if (shell.full && shell.fsT >= 1) shell.leaveFull(); else if (shell.hosted) shell.closeRequested(); }
            // ---------- frame loop ----------
            FrameAnimation {
                running: page.visible && shell.running
                onTriggered: page.frame(Math.min(0.033, frameTime))
            }
            function frame(dt) {
                const st = ms, now = Date.now(), k = B.smoothK(dt, smoothTau);
                if (st.live) {
                    for (const c of st.cores) c.v += (c.t - c.v) * k;
                    for (const o of [st.temp, st.apps, st.cache, st.netU, st.netD, st.dR, st.dW]) o.v += (o.t - o.v) * k;
                    for (const n of world.nodes) if (n.type === "proc" || n.type === "group") n.cpu += ((n.paused ? 0 : n.cpuT) - n.cpu) * k;
                    st.maxDR += (Math.max(5, ...st.dRh) - st.maxDR) * k;
                    st.maxDW += (Math.max(5, ...st.dWh) - st.maxDW) * k;
                    st.maxU += (Math.max(10, ...st.up) - st.maxU) * k;
                    st.maxD += (Math.max(40, ...st.down) - st.maxD) * k;
                }
                if (st.press && !st.press.drag && now - st.press.t0 > 220) grab();
                // Glass + Dive: the camera comes close (100 %) and keeps the open bubble in the middle of the UI (the card
                // covers its lower part); closing, it goes back to where it was
                if (st.open) {
                    if (!st.camBack) st.camBack = { x: camX, y: camY, z: camZ };
                    const n = world.find(st.open.id);
                    if (n && st.open.dir > 0) {
                        // close in (100 %), the bubble in the middle of the whole UI, the card over its lower part
                        const z = zoomMax;
                        const cx = glassCard.width + (field.width - glassCard.width) / 2;     // the middle of what the panel leaves
                        st.camT = { x: cx - n.x * z, y: page.height / 2 - field.y - n.y * z, z: z };
                    } else if (st.camBack) { st.camT = st.camBack; }
                } else if (st.camBack && !st.open) { st.camT = st.camBack; st.camBack = null; }
                if (st.camT) {
                    const kc = B.smoothK(dt, 0.12), t = st.camT;
                    camX += (t.x - camX) * kc; camY += (t.y - camY) * kc; camZ += (t.z - camZ) * kc;
                    if (Math.abs(t.z - camZ) < 0.001 && Math.abs(t.x - camX) < 0.3 && !st.open) st.camT = null;
                }
                if (st.open) {
                    st.open.prog = B.clamp(st.open.prog + st.open.dir * dt / 0.5, 0, 1);
                    if (st.open.dir < 0 && st.open.prog === 0) st.open = null;
                }
                for (const n of world.nodes) if (n.type === "proc" || n.type === "group") n.rT = procR(n.cpu);
                world.step(dt, now);
                // the hardest bump of this step, if it is a real knock and the last sound has had a moment
                if (shell.bump !== "" && world.hits.length) {
                    const hit = Math.max(...world.hits);
                    if (hit > 5 && now - bumpAt > 60) { bumpAt = now; monitorBump.play(B.clamp(0.22 + hit / 420, 0.22, 0.85)); }
                }

                // the field's bubbles follow the world (removed ones shrank out already)
                for (let i = bubbles.count - 1; i >= 0; i--) if (!world.find(bubbles.get(i).nid)) bubbles.remove(i);
                for (const n of world.nodes) { const it = bubbleItems[n.id]; if (it) it.sync(n); }

                // the numbers everything shows
                vAvg = st.cores.reduce((a, x) => a + x.v, 0) / st.cores.length;
                vTemp = st.temp.v;
                vMem = st.apps.v + st.cache.v * 0.25;
                vTotal = st.snap ? (st.snap.mem.totalExactGB || st.snap.mem.totalGB) : 8;
                if (st.snap) upTxt = B.fmtSpan(st.snap.uptimeSec);
                phase = B.clamp((now - st.lastTick) / tickMs, 0, 1);
                sweep = Math.min(1.2, sweep + dt * 1000 / st.period);
                if (st.open) {
                    if (st.open.id !== infoId || now - infoAt > 250) {
                        info = Object.assign(details(world.find(st.open.id) || st.open.node, now), { id: st.open.id });
                        infoId = st.open.id; infoAt = now;
                    }
                } else if (info) { info = null; infoId = ""; }
                ov = st.open ? overlay(now) : null;
                clock = now / 1000;
                tick++;
            }

            // the open page: where its colour spreads from, how far it is open, and all it shows
            function overlay(now) {
                const o = ms.open, n = world.find(o.id) || o.node;
                if (world.nodes.indexOf(n) >= 0) { o.x = camX + n.x * camZ; o.y = field.y + camY + n.y * camZ; o.r = n.ef * camZ; }
                return Object.assign({}, info, {
                    id: o.id, x: o.x, y: o.y, r: o.r, R: B.lerp(o.r, Math.hypot(page.width, page.height) * 1.05, B.easeIO(o.prog)),
                    co: B.clamp((o.prog - 0.5) / 0.35, 0, 1), opening: o.dir > 0, prog: o.prog, e: B.easeIO(o.prog)
                });
            }
            function kindOf(n) { return n.type === "metric" ? n.key : n.type === "group" ? "group" : "app"; }

            // Everything a bubble's page shows, the same order for each: title and a line under it, the number, how it
            // looks (a chart, bars or a gauge), facts in two columns (those marked full only full screen) and lists
            // (`panel`: how many rows fit the panel's page). The rest feeds the other inside styles.
            function details(n, now) {
                const st = ms, kind = kindOf(n);
                const phase = B.clamp((now - st.lastTick) / tickMs, 0, 1);
                const snap = st.snap || { cpu: { threads: st.cores.length, model: "", freqGHz: 0, load: [0, 0, 0], procCount: 0 },
                                          mem: { swapGB: 0, swapTotalGB: 0, freeGB: 0 }, net: { iface: "", sentGB: 0, recvGB: 0 }, sensors: [] };
                const sensors = snap.sensors || [];
                const coreTemps = sensors.filter(x => x.label.startsWith("Core"));
                const hottest = coreTemps.length ? Math.max(...coreTemps.map(x => x.c)) : vTemp;
                const liveProcs = world.nodes.filter(x => x.type === "proc" && !x.dying);
                const disk = snap.disk || { readGB: 0, writtenGB: 0, drives: [] };
                const one = v => v.toFixed(v < 10 ? 1 : 0);
                const mb = v => v.toFixed(v < 10 ? 1 : 0) + " MB/s";
                const known = v => v === undefined || v === null ? "—" : v;
                const color = n.type === "metric" ? metricColor(n.key) : n.type === "group" ? shell.cWhite : kindColor(n.kind);
                const procRow = (p, val, frac) => ({ id: world.find(p.id || ("p" + p.pid)) ? (p.id || "p" + p.pid) : "", name: p.name, val: val, frac: frac });
                const memFree = snap.mem.freeGB !== undefined ? snap.mem.freeGB : Math.max(0, vTotal - st.apps.v - st.cache.v);
                const rank = n.type === "proc" ? liveProcs.slice().sort((a, b) => b.cpuT - a.cpuT).indexOf(n) + 1 : 0;
                const d = {
                    kind: kind, color: color, phase: phase, title: n.name || "", sub: "", num: "", unit: "", note: "",
                    facts: [], list: null, list2: null,
                    // what the kinds' looks draw
                    peak: Math.max(...st.hist), hist: st.hist, cores: st.cores.map(x => x.v),
                    memApps: st.apps.v, memCache: st.cache.v, memFree: memFree,
                    topMem: liveProcs.slice().sort((a, b) => b.memMB - a.memMB).slice(0, 10).map(p => ({ id: p.id, name: p.name, memMB: p.memMB })),
                    tempPeak: Math.max(...st.tempHist), tempAvg: st.tempHist.reduce((a, b) => a + b, 0) / st.tempHist.length,
                    netPeak: Math.max(...st.down)
                };
                if (kind === "cpu") {
                    d.sub = snap.cpu.model.replace(/\(R\)|\(TM\)|CPU |@.*$/g, "").replace(/\s+/g, " ").trim() + " · " + snap.cpu.threads + " threads";
                    d.num = String(Math.round(vAvg)); d.unit = "%";
                    d.facts = [{ lbl: "Clock", val: snap.cpu.freqGHz.toFixed(2) + " GHz" }, { lbl: "Peak (1 min)", val: Math.round(d.peak) + "%" },
                               { lbl: "Processes", val: String(snap.cpu.procCount || 0), full: true },
                               { lbl: "Busy threads", val: st.cores.filter(x => x.v > 50).length + " of " + st.cores.length, full: true }];
                    d.list = { title: "Top processes", panel: 3, rows: liveProcs.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 8)
                                   .map(p => procRow(p, one(p.cpu) + "%", p.cpu / 100)) };
                } else if (kind === "mem") {
                    d.sub = vTotal.toFixed(1) + " GB installed"; d.num = vMem.toFixed(1); d.unit = "GB";
                    d.facts = [{ lbl: "In use", val: Math.round(vMem / vTotal * 100) + "%" },
                               { lbl: "Swap", val: snap.mem.swapGB.toFixed(1) + " / " + (snap.mem.swapTotalGB || 0).toFixed(1) + " GB" }];
                    const top = d.topMem, max = top.length ? Math.max(1, top[0].memMB) : 1;
                    d.list = { title: "Top processes", panel: 5, rows: top.map(p => procRow(p, B.fmtMem(p.memMB), p.memMB / max)) };
                } else if (kind === "temp") {
                    d.sub = vTemp > 80 ? "Hot" : vTemp > 65 ? "Warm" : "Cool"; d.num = String(Math.round(vTemp)); d.unit = "°C";
                    const ssd = sensors.find(x => x.label === "SSD");
                    d.facts = [{ lbl: "Peak (1 min)", val: Math.round(d.tempPeak) + "°C" }, { lbl: "Average (1 min)", val: Math.round(d.tempAvg) + "°C" },
                               { lbl: "Hottest core", val: Math.round(hottest) + "°C" }, { lbl: "SSD", val: ssd ? Math.round(ssd.c) + "°C" : "—" }];
                    d.list = { title: "Sensors", panel: 4, rows: sensors.map(x => ({ name: x.label, val: Math.round(x.c) + "°C", frac: (x.c - 20) / 80 })) };
                } else if (kind === "net") {
                    d.sub = snap.net.iface; d.num = one(st.netD.v); d.unit = "MB/s down";
                    d.legend = ["Up", "Down"]; d.io = { up: st.up, down: st.down, maxUp: st.maxU, maxDown: st.maxD };
                    d.facts = [{ lbl: "Down", val: mb(st.netD.v) }, { lbl: "Up", val: mb(st.netU.v) },
                               { lbl: "Peak down (1 min)", val: mb(d.netPeak) }, { lbl: "Peak up (1 min)", val: mb(Math.max(...st.up)) },
                               { lbl: "Received in all", val: (snap.net.recvGB || 0).toFixed(2) + " GB", full: true },
                               { lbl: "Sent in all", val: (snap.net.sentGB || 0).toFixed(2) + " GB", full: true }];
                } else if (kind === "disk") {
                    const used = disk.drives.reduce((a, x) => a + x.usedGB, 0), total = disk.drives.reduce((a, x) => a + x.totalGB, 0);
                    d.sub = Math.round(used) + " of " + Math.round(total) + " GB"; d.num = String(Math.round(vDisk * 100)); d.unit = "% used";
                    d.legend = ["Read", "Write"]; d.io = { up: st.dRh, down: st.dWh, maxUp: st.maxDR, maxDown: st.maxDW };
                    d.facts = [{ lbl: "Read", val: mb(st.dR.v) }, { lbl: "Write", val: mb(st.dW.v) },
                               { lbl: "Read in all", val: (disk.readGB || 0).toFixed(1) + " GB", full: true },
                               { lbl: "Written in all", val: (disk.writtenGB || 0).toFixed(1) + " GB", full: true }];
                    d.list = { title: "Drives", rows: disk.drives.map(x => ({ name: x.mount, val: Math.round(x.usedGB) + " / " + Math.round(x.totalGB) + " GB",
                                                                              frac: x.usedGB / Math.max(1, x.totalGB) })) };
                } else if (kind === "app") {
                    d.sub = "PID " + n.pid + " · " + kindLabel[n.kind] + " · " + n.user;
                    d.num = n.paused ? "0" : one(n.cpu); d.unit = "% CPU"; d.hist = n.h.slice(-30);
                    d.facts = [{ lbl: "Memory", val: B.fmtMem(n.memMB) }, { lbl: "State", val: n.dying ? "Ended" : n.paused ? "Paused" : n.cpu > 5 ? "Running" : "Sleeping" },
                               { lbl: "Rank by CPU", val: rank + " of " + liveProcs.length }, { lbl: "Threads", val: String(known(n.threads)) },
                               { lbl: "Started", val: n.started ? B.fmtAgo(Date.now() / 1000 - n.started) : "—" },
                               { lbl: "CPU time", val: n.cpuSec === undefined || n.cpuSec === null ? "—" : B.fmtSpan(n.cpuSec, true) },
                               { lbl: "Disk read", val: n.readMB === undefined || n.readMB === null ? "—" : B.fmtMem(n.readMB), full: true },
                               { lbl: "Disk written", val: n.writeMB === undefined || n.writeMB === null ? "—" : B.fmtMem(n.writeMB), full: true }];
                } else if (kind === "group") {
                    d.sub = n.windows + (n.windows === 1 ? " window" : " windows") + (n.ws && n.ws.length ? " · workspace " + n.ws.join(", ") : "");
                    d.num = one(n.cpu); d.unit = "% CPU"; d.hist = (n.h || []).slice(-30);
                    d.facts = [{ lbl: "Memory", val: B.fmtMem(n.memMB) }, { lbl: "Processes", val: String(n.procCount) }];
                    const procs = n.procs || [], max = Math.max(1, ...procs.map(p => p.memMB));
                    d.list2 = { title: "Windows", full: true, rows: (n.titles || []).map(t => ({ name: t || "Untitled" })) };
                    d.list = { title: "Processes", panel: 3, rows: procs.map(p => procRow(p, B.fmtMem(p.memMB) + " · " + one(p.cpu) + "%", p.memMB / max)) };
                }
                return d;
            }

            Component.onCompleted: {
                makeSource();
                const z = 0.7;
                camX = shell.width / 2 - world.w / 2 * z; camY = shell.height / 2 - world.h / 2 * z; camZ = z;
                seedMetrics();
            }

            // ================================================================================================================
            // the field
            // ================================================================================================================
            Item {
                id: field
                y: 0
                width: parent.width; height: parent.height - y
                clip: true

                // Space, endless: a deep ground, far stars, the black hole, near stars. Each layer moves a part of what
                // the camera does (the farther, the less) and grows a little with the zoom, so a drag reads as travel.
                Item {
                    id: space
                    visible: !shell.hosted
                    anchors.fill: parent
                    // how far the world's centre is from the view's: the background's centre follows it (a part of it)
                    readonly property real panX: page.camX + page.worldW / 2 * page.camZ - field.width / 2
                    readonly property real panY: page.camY + page.worldH / 2 * page.camZ - field.height / 2
                    readonly property real zoomT: (page.camZ - page.zoomMin) / (page.zoomMax - page.zoomMin)
                    Rectangle { anchors.fill: parent; color: Qt.darker(ThemeBackend.base, 1.2) }
                    StarLayer { source: "bubble/space/stars-far.png"; depth: 0.1; grow: 0.06 }
                    Image {
                        readonly property real k: 0.85 + 0.15 * space.zoomT
                        width: 1150 * 0.7 * k; height: 640 * 0.7 * k
                        x: (field.width - width) / 2 + space.panX * 0.18
                        y: (field.height - height) / 2 + space.panY * 0.18
                        source: "bubble/space/black-hole.png"
                        asynchronous: true
                        smooth: true
                    }
                    StarLayer { source: "bubble/space/stars-near.png"; depth: 0.3; grow: 0.14 }
                }
                // the world, under the camera
                Item {
                    id: worldItem
                    width: page.world.w; height: page.world.h
                    transform: [ Scale { xScale: page.camZ; yScale: page.camZ }, Translate { x: page.camX; y: page.camY } ]

                    // lightning
                    Shape {
                        id: boltShape
                        anchors.fill: parent
                        readonly property var bolts: { page.tick; return page.world.bolts; }
                        ShapePath { strokeColor: Qt.alpha(shell.cSky, 0.22); strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: (boltShape.bolts.mid + boltShape.bolts.strong) || "M0,0" } }
                        ShapePath { strokeColor: Qt.alpha(shell.cBolt, 0.35); strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: boltShape.bolts.weak || "M0,0" } }
                        ShapePath { strokeColor: Qt.alpha(shell.cBolt, 0.7); strokeWidth: 1.4; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: boltShape.bolts.mid || "M0,0" } }
                        ShapePath { strokeColor: Qt.lighter(shell.cBolt, 1.05); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                    PathSvg { path: boltShape.bolts.strong || "M0,0" } }
                    }

                    Repeater {
                        model: bubbles
                        delegate: Bubble {}
                    }
                }

                // taps, holds, drags and the wheel
                MouseArea {
                    id: fieldMa
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton
                    cursorShape: { page.tick; return (page.ms.pan || (page.ms.press && page.ms.press.drag)) ? Qt.ClosedHandCursor : Qt.OpenHandCursor; }
                    onPressed: (m) => {
                        const p = { x: m.x, y: m.y }, w = page.toWorld(p), st = page.ms;
                        const n = page.world.hit(w.x, w.y);
                        st.camT = null;
                        if (n) st.press = { id: n.id, sx: p.x, sy: p.y, wx: w.x, wy: w.y, t0: Date.now(), drag: false };
                        else st.pan = { sx: p.x, sy: p.y, cx: page.camX, cy: page.camY };
                        page.forceActiveFocus();
                    }
                    onPositionChanged: (m) => {
                        const p = { x: m.x, y: m.y }, st = page.ms;
                        if (st.press) {
                            const w = page.toWorld(p); st.press.wx = w.x; st.press.wy = w.y;
                            if (!st.press.drag && Math.hypot(p.x - st.press.sx, p.y - st.press.sy) > 6) page.grab();
                            if (st.press && st.press.drag) page.world.dragTarget = { x: w.x, y: w.y };
                        } else if (st.pan) {
                            page.camX = st.pan.cx + p.x - st.pan.sx; page.camY = st.pan.cy + p.y - st.pan.sy;
                        }
                    }
                    onReleased: {
                        const st = page.ms;
                        if (st.press) {
                            if (!st.press.drag) { const n = page.world.find(st.press.id); st.press = null; if (n) page.openNode(n); }
                            else page.release();
                        }
                        st.pan = null;
                    }
                    onCanceled: { page.release(); page.ms.pan = null; }
                    onWheel: (w) => {
                        // a wheel click (or a swipe's worth) is one 10 % step
                        page.wheelAcc += w.angleDelta.y;
                        while (Math.abs(page.wheelAcc) >= 120) {
                            page.zoomStep({ x: w.x, y: w.y }, page.wheelAcc > 0 ? 1 : -1);
                            page.wheelAcc -= page.wheelAcc > 0 ? 120 : -120;
                        }
                    }
                }

            }

            // Processes or open apps, top left (the panel's page only; full screen shows both): the mark slides to the
            // one picked. Out of the way while a page is open on the left.
            Rectangle {
                z: 20
                visible: !shell.full
                x: 12; y: 12
                width: modeRow.implicitWidth + 8; height: 40; radius: 20
                color: Qt.alpha(shell.cBg, 0.82)
                opacity: 1 - glass.e
                Rectangle {
                    readonly property Item on: page.mode === "apps" ? appsSeg : procsSeg
                    x: modeRow.x + on.x; y: modeRow.y
                    width: on.width; height: 32; radius: 16
                    color: Qt.alpha(shell.cText, 0.16)
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    ModeSeg { id: procsSeg; label: "Processes"; value: "procs" }
                    ModeSeg { id: appsSeg; label: "Apps"; value: "apps" }
                }
            }
            // full screen and back
            Rectangle {
                id: fullBtn
                visible: !shell.hosted
                z: 40          // above an open page's dimming, so they still work
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
                width: 40; height: 40; radius: 20
                color: Qt.alpha(fullMa.containsMouse ? shell.cLine : shell.cBg, 0.82)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text { anchors.centerIn: parent; text: shell.full ? "󰊔" : "󰊓"; font.family: ThemeBackend.iconFont; font.pixelSize: 17; color: shell.cText }
                MouseArea { id: fullMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: shell.full ? shell.leaveFull() : shell.goFull() }
            }
            // the battery beside it, the size of the button: a drawn battery lying down (as on the System page's
            // Graphs), filled to the charge, the percentage under it
            Rectangle {
                z: 40          // above an open page's dimming, so they still work
                visible: !!page.battery
                anchors.right: fullBtn.left; anchors.rightMargin: 8; anchors.verticalCenter: fullBtn.verticalCenter
                width: 40; height: 40; radius: 20
                color: Qt.alpha(shell.cBg, 0.82)
                readonly property real pct: page.battery ? page.battery.pct : 0
                readonly property bool low: pct <= 20 && !(page.battery && page.battery.plugged)
                Item {
                    id: batGlyph
                    x: (parent.width - width) / 2; y: 8
                    width: 24; height: 12
                    Rectangle {
                        width: parent.width - 3; height: parent.height
                        radius: 3.5; color: "transparent"
                        border.width: 1.5; border.color: Qt.alpha(shell.cText, 0.55)
                        Rectangle {
                            x: 2.5; y: 2.5; height: parent.height - 5; radius: 1.5
                            width: Math.max(2, (parent.width - 5) * parent.parent.parent.pct / 100)
                            color: parent.parent.parent.low ? shell.cHot : shell.cAccent
                            Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        }
                        Text { anchors.centerIn: parent; visible: !!(page.battery && page.battery.plugged); text: "󱐋"; font.family: ThemeBackend.iconFont; font.pixelSize: 9; color: ThemeBackend.crust }
                    }
                    Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 5; radius: 1; color: Qt.alpha(shell.cText, 0.55) }
                }
                FlowText { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: batGlyph.bottom; anchors.topMargin: 2
                           target: Math.round(parent.pct) + "%"; font.family: shell.fMono; font.pixelSize: 9; color: shell.cText }
            }
            // The special buttons under it: CPU, memory, temperature and disk in a column. A click, or the wheel over
            // them (one step a click, stopping at either end, as the panel's sidebar does), opens that bubble's page;
            // the mark slides to it.
            Rectangle {
                id: quick
                z: 40          // above an open page's dimming, so they still work
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.top: fullBtn.bottom; anchors.topMargin: 8
                width: 40; height: quickCol.implicitHeight + 8; radius: 20
                color: Qt.alpha(shell.cBg, 0.82)
                readonly property var keys: ["cpu", "mem", "temp", "disk"]
                readonly property int at: page.info ? keys.indexOf(page.info.id) : -1
                property int last: 0
                onAtChanged: if (at >= 0) last = at
                function go(i) {
                    i = Math.max(0, Math.min(keys.length - 1, i));
                    // back up the list, the page comes down into place instead of up
                    page.swapDir = at >= 0 && i < at ? -1 : 1;
                    page.openId(keys[i]);
                }
                Rectangle {
                    visible: quick.at >= 0
                    x: 4; y: 4 + quick.last * 32
                    width: 32; height: 32; radius: 16
                    color: Qt.alpha(shell.cText, 0.16)
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                Column {
                    id: quickCol
                    x: 4; y: 4
                    Repeater {
                        model: ["󰻠", "󰍛", "󰔏", "󰋊"]
                        Item {
                            required property int index
                            required property string modelData
                            width: 32; height: 32
                            Text { anchors.centerIn: parent; text: parent.modelData; font.family: ThemeBackend.iconFont; font.pixelSize: 15
                                   color: quick.at === parent.index || qMa.containsMouse ? shell.cText : shell.cMuted
                                   Behavior on color { ColorAnimation { duration: 200 } } }
                            MouseArea { id: qMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: quick.go(parent.index) }
                        }
                    }
                }
                // the sidebar's way (BlankPanel's sideWheel): a wheel click is one step; a touchpad swipe counts once
                function step(dir) { go((at >= 0 ? at : last - dir) + dir); }
                property real wheelAcc: 0
                Timer { id: quickSwipe; property bool locked: false; interval: 220; onTriggered: { locked = false; quick.wheelAcc = 0; } }
                WheelHandler {
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (e) => {
                        const d = e.angleDelta.y;
                        if (d === 0) return;
                        if (!quickSwipe.running && Math.abs(d) % 120 === 0) { quick.step(d < 0 ? 1 : -1); return; }
                        if (Math.abs(d) >= 120) return;
                        const locked = quickSwipe.locked;
                        quickSwipe.restart();
                        if (locked) return;
                        quick.wheelAcc += d;
                        if (Math.abs(quick.wheelAcc) < 120) return;
                        quick.step(quick.wheelAcc < 0 ? 1 : -1);
                        quick.wheelAcc = 0;
                        quickSwipe.locked = true;
                    }
                }
            }

            // ================================================================================================================
            // Glass: the field stays (dimmed, the bubble ringed); the bubble's page slides in from the left
            // ================================================================================================================
            Item {
                id: glass
                anchors.fill: parent
                z: 30
                visible: !!page.ov
                readonly property real e: page.ov ? page.ov.e : 0
                Rectangle {
                    anchors.fill: parent
                    color: shell.cBg
                    opacity: 0.22 * glass.e
                    // a bubble shows its page in the panel; anywhere else closes it
                    MouseArea {
                        anchors.fill: parent; acceptedButtons: Qt.AllButtons
                        onClicked: (m) => {
                            const w = page.toWorld({ x: m.x, y: m.y - field.y }), n = page.world.hit(w.x, w.y);
                            if (n && !n.dying) page.openId(n.id); else page.closeOverlay();
                        }
                        onWheel: (w) => w.accepted = true
                    }
                }
                Rectangle {
                    readonly property real rr: page.ov ? page.ov.r + 7 : 0
                    x: (page.ov ? page.ov.x : 0) - rr; y: (page.ov ? page.ov.y : 0) - rr
                    width: 2 * rr; height: 2 * rr; radius: rr
                    color: "transparent"; border.width: 2; border.color: page.ov ? page.ov.color : "transparent"
                    opacity: glass.e
                }
                // one sheet down the whole left side, sliding in: 60 % of the panel's page, 30 % of the screen
                InfoPanel {
                    id: glassCard
                    width: Math.round(parent.width * (shell.full ? 0.3 : 0.6))
                    height: parent.height
                    x: -width * (1 - glass.e)
                }
            }
        }
    }

    component Dot: Item {
        id: dot
        property color color: shell.cAccent
        property real cx: 0
        property real cy: 0
        property bool pulse: false
        property real breath: 0
        SequentialAnimation on breath { running: dot.pulse; loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine } NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutSine } }
        x: cx; y: cy
        Rectangle { readonly property real s: 16 + 6 * dot.breath; x: -s / 2; y: -s / 2; width: s; height: s; radius: s / 2; color: Qt.alpha(dot.color, 0.25) }
        Rectangle { x: -4; y: -4; width: 8; height: 8; radius: 4; color: dot.color }
    }

    // The left panel: one sheet with a bubble's page. Another bubble's page takes its place by moving up: the old one
    // goes up and away, the new one comes up from below into its place (two pages taking turns); stepped back up the
    // buttons, the same downwards.
    component InfoPanel: Rectangle {
        id: panel
        property var d: page.info
        property bool big: shell.full
        property bool closable: true
        property bool moving: true           // its charts and water move
        property var oldD: null
        property bool flip: false            // which page is the live one
        property string lastKey: ""
        property var lastD: null
        property real swap: 1                // 0 → 1 while one page gives way to the other
        property int dir: 1                  // up (1) or down (-1), taken from page.swapDir as it starts
        onDChanged: {
            const k = d ? (d.id || d.kind) : "";
            if (k === "") { lastKey = ""; lastD = null; return; }
            if (lastKey !== "" && k !== lastKey) { oldD = lastD; flip = !flip; dir = page.swapDir; page.swapDir = 1; swapAnim.restart(); }
            lastKey = k; lastD = d;
        }
        NumberAnimation { id: swapAnim; target: panel; property: "swap"; from: 0; to: 1; duration: 460; easing.type: Easing.OutCubic }
        color: Qt.alpha(ThemeBackend.mantle, 0.96)
        clip: true
        MouseArea { anchors.fill: parent; enabled: panel.closable; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }
        Repeater {
            model: 2
            InfoPage {
                required property int index
                readonly property bool live: (index === 1) === panel.flip
                x: 22; width: panel.width - 44
                // the old one is gone before the new one is halfway up, so they never sit on each other
                y: live ? 22 + 80 * panel.dir * (1 - panel.swap) : 22 - 80 * panel.dir * panel.swap
                opacity: live ? B.clamp((panel.swap - 0.12) * 1.8, 0, 1) : B.clamp(1 - panel.swap * 2.4, 0, 1)
                visible: live || panel.swap < 1
                d: live ? panel.d : panel.oldD
                big: panel.big
                moving: panel.moving
            }
        }
        Rectangle {
            visible: panel.closable
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
            width: 32; height: 32; radius: 16; color: xMa.containsMouse ? shell.cLine : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
            Text { anchors.centerIn: parent; text: "󰅖"; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: shell.cText }
            MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.closeOverlay() }
        }
    }

    // A bubble's page, the same order for every kind: its shape and title with a line under it, the number, how it
    // looks (a chart, water or a gauge), facts in two columns, lists. `big`: the full screen's, with what only fits there.
    component InfoPage: Column {
        id: info
        property var d: null
        property bool big: false
        property bool moving: true
        readonly property real phase: moving ? page.phase : 0.5
        readonly property real sweep: moving ? page.sweep : 0.5
        readonly property string kind: d ? d.kind : ""
        spacing: 16
        Column {
            width: parent.width
            spacing: 4
            Row {
                spacing: 10
                Glyph { anchors.verticalCenter: parent.verticalCenter; kind: info.kind; color: info.d ? info.d.color : "transparent" }
                Text { width: Math.min(implicitWidth, info.width - 60); elide: Text.ElideRight; text: info.d ? info.d.title : ""
                       font.family: shell.fDisplay; font.pixelSize: 20; font.weight: Font.DemiBold; color: page.fg }
            }
            Text { width: parent.width - 40; elide: Text.ElideRight; text: info.d ? info.d.sub : ""
                   font.family: shell.fMono; font.pixelSize: 12; color: Qt.alpha(page.fg, 0.62) }
        }
        Row {
            FlowText { id: infoNum; target: info.d ? info.d.num : ""; font.family: shell.fDisplay; font.pixelSize: 56; font.weight: Font.DemiBold
                       color: info.d ? info.d.color : page.fg }
            Text { anchors.baseline: infoNum.baseline; text: info.d ? "  " + info.d.unit : ""; font.family: shell.fMono; font.pixelSize: 15
                   color: Qt.alpha(page.fg, 0.62) }
        }
        Loader {
            width: parent.width
            sourceComponent: ({ cpu: cpuLook, mem: memLook, temp: tempLook, net: ioLook, disk: ioLook, app: histLook, group: histLook })[info.kind] || null
        }
        Facts { items: info.d ? info.d.facts.filter(f => info.big || !f.full) : [] }
        InfoList { list: info.d ? info.d.list2 : null; big: info.big }
        InfoList { list: info.d ? info.d.list : null; big: info.big }

        // CPU: its history, and every thread as a glass of water filled to how busy it is
        Component {
            id: cpuLook
            Column {
                width: parent ? parent.width : 0
                spacing: 12
                Rectangle {
                    width: parent.width; height: info.big ? 96 : 72; radius: 12; color: Qt.alpha(page.fg, 0.06)
                    Chart { anchors.fill: parent; anchors.margins: 6; values: info.d ? info.d.hist : []; phase: info.phase; sweep: info.sweep }
                }
                Row {
                    id: coreRow
                    readonly property var cores: info.d ? info.d.cores : []
                    width: parent.width
                    spacing: 5
                    Repeater {
                        model: coreRow.cores.length
                        Column {
                            required property int index
                            readonly property real v: coreRow.cores[index] || 0
                            width: (coreRow.width - 5 * (coreRow.cores.length - 1)) / Math.max(1, coreRow.cores.length)
                            spacing: 4
                            Rectangle {
                                width: parent.width; height: 40; radius: 6; color: Qt.alpha(page.fg, 0.08)
                                Water { anchors.fill: parent; radius: 6; level: parent.parent.v / 100; period: 2400 + parent.parent.index * 260; moving: info.moving }
                            }
                            FlowText { anchors.horizontalCenter: parent.horizontalCenter; target: String(Math.round(parent.v)); font.family: shell.fMono; font.pixelSize: 11
                                       color: Qt.alpha(page.fg, 0.7) }
                        }
                    }
                }
            }
        }
        // memory: what holds it, in one bar
        Component {
            id: memLook
            Column {
                width: parent ? parent.width : 0
                spacing: 10
                Rectangle {
                    width: parent.width; height: 22; radius: 8; color: Qt.alpha(page.fg, 0.1); clip: true
                    Row {
                        spacing: 3
                        Rectangle { width: info.d ? parent.parent.width * info.d.memApps / page.vTotal : 0; height: 22; radius: 8; color: page.fgAccent
                                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
                        Rectangle { width: info.d ? parent.parent.width * info.d.memCache / page.vTotal : 0; height: 22; radius: 8; color: Qt.alpha(page.fg, 0.4)
                                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
                    }
                }
                Legend { items: info.d ? [{ t: "Apps " + info.d.memApps.toFixed(1), a: 1 }, { t: "Cache " + info.d.memCache.toFixed(1), a: 0.4 },
                                          { t: "Free " + info.d.memFree.toFixed(1), a: 0.12 }] : [] }
            }
        }
        // temperature: where it sits from 30 to 100 °C
        Component {
            id: tempLook
            Item {
                width: parent ? parent.width : 0; height: 62
                readonly property real pct: B.clamp((page.vTemp - 30) / 70, 0, 1)
                Rectangle {
                    x: (parent.width - width) * parent.pct
                    width: markText.implicitWidth + 20; height: 22; radius: 11; color: page.fgAccent
                    FlowText { id: markText; anchors.centerIn: parent; target: Math.round(page.vTemp) + "°C"; font.family: shell.fMono; font.pixelSize: 12; font.weight: Font.Medium
                               color: ThemeBackend.crust }
                }
                Rectangle {
                    y: 30; width: parent.width; height: 8; radius: 4; color: Qt.alpha(page.fg, 0.1); clip: true
                    Rectangle { width: parent.width * parent.parent.pct; height: 8; radius: 4; color: page.fgAccent }
                }
                Repeater {
                    model: [{ t: "30°", f: 0 }, { t: "50°", f: 0.286 }, { t: "70°", f: 0.571 }, { t: "90°", f: 0.857 }, { t: "100°", f: 1 }]
                    Text {
                        required property var modelData
                        y: 46
                        x: modelData.f === 0 ? 0 : modelData.f === 1 ? parent.width - implicitWidth : parent.width * modelData.f - implicitWidth / 2
                        text: modelData.t; font.family: shell.fMono; font.pixelSize: 11; color: Qt.alpha(page.fg, 0.62)
                    }
                }
            }
        }
        // network and disk: both ways at once, one above the middle and one below, as smooth lines; which is which in
        // the box's corner
        Component {
            id: ioLook
            Rectangle {
                id: ioBox
                width: parent ? parent.width : 0; height: info.big ? 150 : 118
                radius: 12; color: Qt.alpha(page.fg, 0.06); clip: true
                readonly property var io: info.d && info.d.io ? info.d.io : null
                readonly property var lines: io && io.up.length > 2 ? B.twoWay(io.up, io.down, info.phase, width - 12, height, io.maxUp, io.maxDown, 40) : null
                Rectangle { y: parent.height / 2; width: parent.width; height: 1; color: Qt.alpha(page.fg, 0.12) }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath { strokeColor: "transparent"; fillColor: Qt.alpha(page.fgAccent, 0.14); PathSvg { path: ioBox.lines ? ioBox.lines.upArea : "M0,0" } }
                    ShapePath { strokeColor: "transparent"; fillColor: Qt.alpha(page.fg, 0.08); PathSvg { path: ioBox.lines ? ioBox.lines.downArea : "M0,0" } }
                    ShapePath { strokeColor: page.fgAccent; strokeWidth: 2.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                PathSvg { path: ioBox.lines ? ioBox.lines.upLine : "M0,0" } }
                    ShapePath { strokeColor: Qt.alpha(page.fg, 0.6); strokeWidth: 2.6; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                                PathSvg { path: ioBox.lines ? ioBox.lines.downLine : "M0,0" } }
                }
                Dot { visible: !!ioBox.lines; color: page.fgAccent; cx: ioBox.width - 12; cy: ioBox.lines ? ioBox.lines.upY : 0 }
                Dot { visible: !!ioBox.lines; color: Qt.alpha(page.fg, 0.8); cx: ioBox.width - 12; cy: ioBox.lines ? ioBox.lines.downY : 0 }
                Legend { x: 12; y: 10; spacing: 14
                         items: info.d && info.d.legend ? [{ t: info.d.legend[0], a: 1 }, { t: info.d.legend[1], a: 0.6 }] : [] }
            }
        }
        // a process or an app: its CPU over time
        Component {
            id: histLook
            Rectangle {
                width: parent ? parent.width : 0; height: 80; radius: 12; color: Qt.alpha(page.fg, 0.06)
                Chart { anchors.fill: parent; anchors.margins: 6; values: info.d && info.d.hist ? info.d.hist : []; phase: info.phase; sweep: info.sweep }
            }
        }
    }

    // the shape beside a page's title, one for each kind, slowly turning
    component Glyph: Item {
        id: glyph
        property string kind
        property color color
        width: 14; height: 14
        readonly property string path: {
            const c = 7, poly = (n, r, a0, sy) => { let d = ""; for (let i = 0; i < n; i++) {
                const a = a0 + i * 2 * Math.PI / n; d += (i ? " L" : "M") + (c + Math.cos(a) * r).toFixed(2) + "," + (c + Math.sin(a) * r * (sy || 1)).toFixed(2); }
                return d + " Z"; };
            if (kind === "cpu") return poly(4, 7.6, Math.PI / 4);                       // square
            if (kind === "mem") return poly(6, 7, 0);                                    // hexagon
            if (kind === "temp") return poly(3, 7.6, -Math.PI / 2);                      // triangle
            if (kind === "net") return "M7,0 L11.5,7 L7,14 L2.5,7 Z";                   // narrow diamond
            if (kind === "disk") return poly(5, 7.2, -Math.PI / 2);                      // pentagon
            if (kind === "app") {                                                        // four-point star
                let d = ""; for (let i = 0; i < 8; i++) { const a = -Math.PI / 2 + i * Math.PI / 4, r = i % 2 ? 2.6 : 7;
                    d += (i ? " L" : "M") + (c + Math.cos(a) * r).toFixed(2) + "," + (c + Math.sin(a) * r).toFixed(2); } return d + " Z"; }
            return "M5,0 L9,0 L9,5 L14,5 L14,9 L9,9 L9,14 L5,14 L5,9 L0,9 L0,5 L5,5 Z"; // a cross, an app
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: glyph.color; strokeWidth: 1; joinStyle: ShapePath.RoundJoin; fillColor: glyph.color; PathSvg { path: glyph.path } }
        }
        RotationAnimation on rotation { running: glyph.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 8000 }
    }

    // Text whose number glides to each new value (counting through the ones between); the words round it stay put
    component FlowText: Text {
        id: flow
        property string target: ""
        readonly property var match: /-?\d+(?:\.\d+)?/.exec(target)
        readonly property real goal: match ? parseFloat(match[0]) : 0
        readonly property int decimals: match && match[0].indexOf(".") >= 0 ? match[0].length - match[0].indexOf(".") - 1 : 0
        property real shown: 0
        property bool ready: false
        Behavior on shown { enabled: flow.ready; NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        onGoalChanged: shown = goal
        Component.onCompleted: { shown = goal; ready = true; }
        text: match ? target.slice(0, match.index) + shown.toFixed(decimals) + target.slice(match.index + match[0].length) : target
    }

    // water up to `level` with rolling waves (the shell's own water: src/assets/shaders/fluid/level_wave.frag)
    component Water: ShaderEffect {
        id: water
        property real level: 0
        property bool moving: true
        property int period: 2600
        property real radius: 6
        property real fillLevel: Math.max(0.04, Math.min(1, level))
        Behavior on fillLevel { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        property real waveAmp: fillLevel < 0.99 ? 1.6 + 1.4 * Math.sin(fillLevel * Math.PI) : 0
        property vector2d itemSize: Qt.vector2d(width, height)
        property real phase: 0
        NumberAnimation on phase { running: water.visible && water.moving; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: water.period }
        property color color1: Qt.lighter(page.fgAccent, 1.15)
        property color color2: page.fgAccent
        property color backColor: Qt.alpha(page.fgAccent, 0.35)
        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/fluid/level_wave.frag.qsb"
    }

    // a list on a page: its heading and rows (in the panel's page only as many as fit; some only full screen)
    component InfoList: Column {
        id: infoList
        property var list: null
        property bool big: false
        readonly property var rows: !list || (list.full && !big) ? [] : (big || !list.panel ? list.rows : list.rows.slice(0, list.panel))
        visible: rows.length > 0
        width: parent.width
        spacing: 8
        Text { text: infoList.list ? infoList.list.title : ""; font.family: shell.fMono; font.pixelSize: 12; color: Qt.alpha(page.fg, 0.62) }
        RankRows { rows: infoList.rows }
    }

    // a key on a chart: a dot (a share of the page's colour) and words for each
    component Legend: Row {
        id: legend
        property var items: []        // [{ t, a }]
        spacing: 18
        Repeater {
            model: legend.items.length
            Row {
                required property int index
                readonly property var it: legend.items[index] || ({ t: "", a: 1 })
                spacing: 7
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4
                            color: parent.it.a === 1 ? page.fgAccent : Qt.alpha(page.fg, parent.it.a) }
                FlowText { target: parent.it.t; font.family: shell.fMono; font.pixelSize: 12; color: page.fg }
            }
        }
    }

    // one side of the Processes / Apps switch
    component ModeSeg: Item {
        id: seg
        property string label
        property string value
        readonly property bool on: page.mode === value
        width: segText.implicitWidth + 28; height: 32
        Text { id: segText; anchors.centerIn: parent; text: seg.label; font.family: shell.fMono; font.pixelSize: 12
               color: seg.on || segMa.containsMouse ? shell.cText : shell.cMuted
               Behavior on color { ColorAnimation { duration: 200 } } }
        MouseArea { id: segMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.mode = seg.value }
    }

    // a layer of stars that repeats for ever, moved by `depth` of the camera's pan and grown by up to `grow` with the zoom
    component StarLayer: Item {
        id: layer
        property url source
        property real depth: 0.2
        property real grow: 0.1
        readonly property real k: 1 - layer.grow / 2 + layer.grow * space.zoomT
        readonly property real tile: 512
        anchors.fill: parent
        Item {
            anchors.fill: parent
            transform: Scale { origin.x: layer.width / 2; origin.y: layer.height / 2; xScale: layer.k; yScale: layer.k }
            Image {
                source: layer.source
                fillMode: Image.Tile
                // a tile wider all round than the view, shifted by the pan modulo one tile: it never runs out
                width: layer.width / layer.k + 4 * layer.tile
                height: layer.height / layer.k + 4 * layer.tile
                readonly property real ox: ((space.panX * layer.depth / layer.k) % layer.tile + layer.tile) % layer.tile
                readonly property real oy: ((space.panY * layer.depth / layer.k) % layer.tile + layer.tile) % layer.tile
                x: (layer.width - width) / 2 + ox
                y: (layer.height - height) / 2 + oy
                smooth: true
            }
        }
    }

    // ================================================================================================================
    // pieces
    // ================================================================================================================
    // One bubble: a process (by kind, paused dashed, hot ring), an open app (white) or a metric dial. The world moves
    // its node in place every frame; frame() hands each bubble just the numbers that move (sync), so a bubble redraws
    // only what changed (a binding to the whole node, copied every frame, re-ran all of its bindings every frame).
    component Bubble: Item {
        id: bub
        required property string nid
        property string type: ""
        property string key: ""
        property string kind: ""
        property string name: ""
        property real rad: 0
        property real sq: 0
        property real sqA: 0
        property real wv: 0
        property bool grab: false
        property bool paused: false
        property bool hot: false
        property string value: ""                 // the number under the name
        property real pct: 0.01                   // a dial's arc, in steps of 0.5 % (it redraws only when it moves)
        property real dialRad: 0                  // the dial's size, in half pixels (the same)
        function sync(o) {
            type = o.type; key = o.key || ""; kind = o.kind || ""; name = o.name || "";
            rad = o.ef; x = o.x - o.ef; y = o.y - o.ef;
            sq = o.sq; sqA = o.sqA; wv = o.w * Math.sin(o.ph);
            grab = !!o.grab; paused = !!o.paused;
            hot = o.type !== "metric" && o.cpu > page.hotCpu && !o.paused && !o.dying;
            if (o.type === "metric") {
                pct = Math.round(page.dialFrac(key) * 200) / 200;
                dialRad = Math.round(o.ef * 2) / 2;
                value = page.dialText(key);
            } else value = o.paused ? "Paused" : o.cpu.toFixed(o.cpu < 10 ? 1 : 0) + "%";
        }
        Component.onCompleted: { page.bubbleItems[nid] = bub; const o = page.world.find(nid); if (o) sync(o); }
        Component.onDestruction: delete page.bubbleItems[nid]
        readonly property bool metric: type === "metric"
        readonly property bool app: type === "group"
        readonly property real lift: grab ? 1.08 : 1
        readonly property color fillColor: app ? shell.cWhite : metric ? shell.cPanel : paused ? "transparent" : kind === "dev" ? shell.cAccent : kind === "sys" ? shell.cPanel : shell.cText
        readonly property color textColor: metric ? shell.cText : paused ? shell.cMuted : kind === "sys" ? shell.cText : shell.cInk
        width: 2 * rad; height: 2 * rad
        z: grab ? 10 : 0
        // flattened along where it is pressed (turned to that line, squeezed, turned back), then the jelly wobble
        transform: [
            Rotation { origin.x: bub.rad; origin.y: bub.rad; angle: -bub.sqA },
            Scale { origin.x: bub.rad; origin.y: bub.rad; xScale: 1 - bub.sq; yScale: 1 + bub.sq * 0.55 },
            Rotation { origin.x: bub.rad; origin.y: bub.rad; angle: bub.sqA },
            Scale { origin.x: bub.rad; origin.y: bub.rad; xScale: (1 + bub.wv) * bub.lift; yScale: (1 - bub.wv) * bub.lift }
        ]

        // a pulsing ring above hotCpu
        Rectangle {
            id: hotRing
            visible: bub.hot
            anchors.centerIn: parent
            property real grow: 0
            width: bub.width + 2 * grow; height: width; radius: width / 2
            color: "transparent"; border.width: 2; border.color: shell.cHot
            opacity: 0.6 * (1 - grow / 18)
            NumberAnimation on grow { running: bub.hot; from: 0; to: 18; duration: 1600; loops: Animation.Infinite; easing.type: Easing.OutCubic }
        }
        // an open app: a soft white halo round it
        Rectangle {
            visible: bub.app
            anchors.centerIn: parent
            width: bub.width + 10; height: width; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Qt.alpha(shell.cWhite, 0.3)
        }
        // lifted while held
        Rectangle {
            visible: bub.grab
            anchors.centerIn: parent; anchors.verticalCenterOffset: 10
            width: bub.width + 8; height: width; radius: width / 2
            color: Qt.alpha("#000000", 0.35)
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: bub.fillColor
            border.width: bub.metric ? 1 : (!bub.paused && bub.kind === "sys" ? 1.5 : 0)
            border.color: bub.metric ? shell.cLine : shell.cMuted
        }
        // sphere shading (port_anserin_panels.py): light from the top left, shade to the lower right
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
        // paused: a dashed outline
        Shape {
            visible: bub.paused
            anchors.fill: parent
            ShapePath {
                strokeColor: shell.cLine2; strokeWidth: 1.5; fillColor: "transparent"
                strokeStyle: ShapePath.DashLine; dashPattern: [3, 3]
                PathAngleArc { centerX: bub.rad; centerY: bub.rad; radiusX: Math.max(0, bub.rad - 1); radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
        }
        // a dial: track and the metric's arc, centred on the bubble
        Shape {
            visible: bub.metric
            x: bub.rad - bub.dialRad; y: x
            width: 2 * bub.dialRad; height: width
            ShapePath {
                strokeColor: shell.cLine; strokeWidth: bub.dialRad * 0.1; fillColor: "transparent"
                PathAngleArc { centerX: bub.dialRad; centerY: bub.dialRad; radiusX: bub.dialRad * 0.9; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: bub.metric ? page.metricColor(bub.key) : "transparent"; strokeWidth: bub.dialRad * 0.1; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: bub.dialRad; centerY: bub.dialRad; radiusX: bub.dialRad * 0.9; radiusY: radiusX; startAngle: -90; sweepAngle: bub.pct * 360 }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 1
            readonly property bool tiny: !bub.metric && bub.rad * page.camZ < 22
            readonly property bool small: !bub.metric && bub.rad < 42
            visible: !tiny
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: bub.metric && bub.key === "net" ? "Net ↓" : bub.name
                width: Math.min(implicitWidth, bub.rad * 2 - 14); elide: Text.ElideRight
                font.family: bub.metric ? shell.fMono : shell.fDisplay
                font.pixelSize: Math.round(bub.metric ? Math.max(6, bub.rad * 0.17) : B.clamp(bub.rad * 0.28, 10, 19))
                font.weight: bub.metric ? Font.Normal : Font.DemiBold
                color: bub.metric ? shell.cMuted : bub.textColor
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !parent.small
                text: bub.value
                font.family: bub.metric ? shell.fDisplay : shell.fMono
                font.pixelSize: Math.round(bub.metric ? Math.max(8, bub.rad * 0.4) : B.clamp(bub.rad * 0.2, 7, 14))
                font.weight: bub.metric ? Font.Medium : Font.Normal
                opacity: bub.metric ? 1 : 0.75
                color: bub.textColor
            }
        }
    }

    // ---------- the detail pages (ink on the bubble's colour) ----------
    component Facts: Grid {
        id: facts
        property var items: []        // [{ lbl, val }]
        property int valSize: 17
        width: parent.width
        columns: 2
        rowSpacing: 14
        columnSpacing: 12
        // as many cells as items, kept from one update to the next (so their numbers can glide)
        Repeater {
            model: facts.items.length
            Column {
                required property int index
                readonly property var it: facts.items[index] || ({ lbl: "", val: "" })
                width: (facts.width - facts.columnSpacing) / 2
                spacing: 3
                Text { width: parent.width; elide: Text.ElideRight; text: parent.it.lbl; font.family: shell.fMono; font.pixelSize: 12; color: Qt.alpha(page.fg, 0.62) }
                FlowText { width: parent.width; elide: Text.ElideRight; target: parent.it.val; font.family: shell.fMono; font.pixelSize: facts.valSize; font.weight: Font.Medium; color: page.fg }
            }
        }
    }

    // a ranked list: name, a thin bar, the value; a row that is a bubble opens it
    component RankRows: Column {
        id: ranks
        property var rows: []         // [{ id?, name, frac 0..1 (no bar without), val? }]
        width: parent.width
        Repeater {
            model: ranks.rows.length
            Item {
                id: rankRow
                required property int index
                readonly property var it: ranks.rows[index] || ({ name: "" })
                readonly property bool bar: it.frac !== undefined
                readonly property real nameW: bar ? Math.min(160, width * 0.36) : width - 16
                width: ranks.width; height: 30
                Rectangle { x: -8; width: parent.width + 16; height: parent.height; radius: 10
                            color: Qt.alpha(page.fg, rankMa.containsMouse && rankRow.it.id ? 0.08 : 0)
                            Behavior on color { ColorAnimation { duration: 120 } } }
                Text { width: rankRow.nameW; anchors.verticalCenter: parent.verticalCenter; text: rankRow.it.name; elide: Text.ElideRight
                       font.family: shell.fMono; font.pixelSize: 13; color: page.fg }
                Rectangle {
                    visible: rankRow.bar
                    x: rankRow.nameW + 14; anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - x - rankVal.implicitWidth - 14); height: 4; radius: 2; color: Qt.alpha(page.fg, 0.1)
                    Rectangle { width: parent.width * B.clamp(rankRow.it.frac || 0, 0, 1); height: 4; radius: 2; color: page.fgAccent
                                Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
                }
                FlowText { id: rankVal; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; target: rankRow.it.val || ""
                           font.family: shell.fMono; font.pixelSize: 13; color: page.fg }
                MouseArea { id: rankMa; anchors.fill: parent; hoverEnabled: true; enabled: !!rankRow.it.id
                            cursorShape: Qt.PointingHandCursor; onClicked: page.openId(rankRow.it.id) }
            }
        }
    }

    // A history as the scan dot: the last samples laid across the width and a dot running over them once per sample,
    // only the stretch just behind it drawn, fading out backwards.
    component Chart: Item {
        id: chart
        clip: true
        property var values: []
        property real phase: page.phase
        property real sweep: page.sweep
        property var toFrac: function(v) { return B.clamp(v, 0, 100) / 100; }    // 0 bottom .. 1 top
        property int span: 40              // samples across the width
        property color lineColor: page.fgAccent
        readonly property int used: Math.min(span, values.length - 1)      // a process's history is shorter
        readonly property var comet: used >= 3
            ? B.comet(values.slice(-used), values.slice(-used - 1, -1), sweep, width, height, chart.toFrac, 0.32, 8, 14) : null
        Repeater {
            model: 8
            Shape {
                id: tailPart
                required property int index
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath { strokeColor: Qt.alpha(chart.lineColor, (tailPart.index + 1) / 8); strokeWidth: 2.6; fillColor: "transparent"
                            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                            PathSvg { path: chart.comet ? chart.comet.segs[tailPart.index] : "M0,0" } }
            }
        }
        Dot { visible: !!chart.comet; color: chart.lineColor; cx: chart.comet ? chart.comet.x : 0; cy: chart.comet ? chart.comet.y : 0 }
    }

}
