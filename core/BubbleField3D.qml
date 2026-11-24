import QtQuick
import QtQuick.Shapes
import ".."

// True 3D interactive bubble cluster inside CameraRig's solar system.
// Renders on top of widgets/HUD (z: 35000), uses analytic 3D GLSL spheres,
// spaced-out metric hubs with orbiting process/app moons, family cohesion,
// and crosshair-targeted STOP/KILL with implosion animation.
Item {
    id: root
    property var rig: null
    z: 35000
    visible: BubbleState.open && rig !== null && rig.active

    property real anchorX: 0
    property real anchorY: 1600
    property real anchorZ: 3800
    property bool anchored: false

    property var nodes: []
    property var nodeMap: ({})
    property string dragId: ""
    property real dragDepth: 300
    property string selectedId: ""
    property string aimedId: ""
    property var info: null
    property real openProg: selectedId !== "" ? 1.0 : 0.0
    Behavior on openProg { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    property var lastSnap: null
    property var cores: []
    property var cpuHist: []
    property var tempHist: []
    property var netUpHist: []
    property var netDownHist: []
    property var diskReadHist: []
    property var diskWriteHist: []
    property real vAvg: 0
    property real vTemp: 50
    property real vAppsGB: 0
    property real vCacheGB: 0
    property real vMem: 0
    property real vTotal: 8
    property real vDisk: 0
    property real vNetDown: 0
    property real vNetUp: 0
    property real vDiskR: 0
    property real vDiskW: 0

    ListModel { id: bubbleModel }
    property var itemMap: ({})

    readonly property color cBg: "#F2070911"
    readonly property color cCard: "#0D1322"
    readonly property color cGold: "#D4AF37"
    readonly property color cCream: "#E6D5B8"
    readonly property color cDim: "#8A7F66"
    readonly property color cOff: "#4A4536"
    readonly property color cLine: "#33D4AF37"
    readonly property color cHot: "#D9694A"
    readonly property color cWarm: "#E8B949"
    readonly property color cSky: "#74B8E8"
    readonly property color cMint: "#64C9A8"
    readonly property string fMono: "monospace"

    readonly property var hubOffsets: ({
        "cpu":  { x:  0.00, y:  0.22, z:  0.00 },
        "mem":  { x: -0.92, y:  0.14, z:  0.28 },
        "temp": { x:  0.92, y:  0.14, z:  0.28 },
        "net":  { x: -0.58, y: -0.26, z: -0.72 },
        "disk": { x:  0.58, y: -0.26, z: -0.72 }
    })

    Component.onCompleted: {
        cpuHist = new Array(48).fill(0);
        tempHist = new Array(48).fill(50);
        netUpHist = new Array(40).fill(0);
        netDownHist = new Array(40).fill(0);
        diskReadHist = new Array(40).fill(0);
        diskWriteHist = new Array(40).fill(0);
    }

    function fmtMem(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB";
        return Math.round(mb) + " MB";
    }
    function one(v) { return Number(v || 0).toFixed(v < 10 ? 1 : 0); }

    function metricColor(k) {
        if (k === "cpu") return cGold;
        if (k === "mem") return cCream;
        if (k === "temp") return cHot;
        if (k === "disk") return cMint;
        return cSky;
    }

    function dialFrac(k) {
        const v = k === "cpu" ? vAvg / 100
                : k === "mem" ? vMem / Math.max(1, vTotal)
                : k === "temp" ? (vTemp - 30) / 70
                : k === "disk" ? vDisk
                : vNetDown / 120;
        return Math.max(0.02, Math.min(1.0, v));
    }

    function dialText(k) {
        if (k === "cpu") return Math.round(vAvg) + "%";
        if (k === "mem") return vMem.toFixed(1) + "G";
        if (k === "temp") return Math.round(vTemp) + "°";
        if (k === "disk") return Math.round(vDisk * 100) + "%";
        return vNetDown.toFixed(0) + "M";
    }

    function procRadius(cpu, memMB) {
        const sc = WidgetConfig.bubbleSphereSize;
        const cTerm = Math.sqrt(Math.max(0, cpu)) * 0.95;
        const mTerm = Math.sqrt(Math.max(0, (memMB || 0) / 220.0)) * 0.65;
        return Math.max(5.5, Math.min(15.0, (5.8 + cTerm + mTerm))) * sc;
    }

    function procFamily(name, cmd) {
        const nm = String(name || "").toLowerCase().trim();
        if (nm.indexOf("isolated web") >= 0 || nm.indexOf("web content") >= 0 || nm.indexOf("webextensions") >= 0 ||
            nm.indexOf("rdd process") >= 0 || nm.indexOf("privileged cont") >= 0 || nm.indexOf("utility process") >= 0 ||
            nm === "zen-bin" || nm === "firefox" || nm === "brave" || nm === "chromium") return "fam_web";
        if (nm.indexOf("kworker") === 0 || nm.indexOf("ksoftirqd") === 0 || nm.indexOf("migration") === 0 ||
            nm.indexOf("rcu_") === 0 || nm.indexOf("irq/") === 0) return "fam_kworker";
        if (nm.indexOf("pipewire") >= 0 || nm.indexOf("wireplumber") >= 0) return "fam_audio";
        if (nm.indexOf("systemd") === 0 || nm.indexOf("dbus") >= 0 || nm === "polkitd" || nm === "udisksd") return "fam_sys";
        if (nm === "electron" || nm.indexOf("discord") >= 0 || nm === "vesktop") return "fam_electron";
        return "fam_" + nm.replace(/\/.*$/, "").replace(/[:\d]+$/, "");
    }

    function assignHub(name, cmd, cpu, memMB, readMB, writeMB) {
        const nm = String(name || "").toLowerCase();
        if (nm.indexOf("zen") >= 0 || nm.indexOf("firefox") >= 0 || nm.indexOf("brave") >= 0 ||
            nm.indexOf("chrom") >= 0 || nm.indexOf("discord") >= 0 || nm.indexOf("vesktop") >= 0 ||
            nm.indexOf("spotify") >= 0 || nm.indexOf("telegram") >= 0 || nm.indexOf("qbittorrent") >= 0 ||
            nm.indexOf("network") >= 0 || nm === "ssh" || nm === "curl") return "net";
        if ((readMB || 0) + (writeMB || 0) > 8.0 || nm.indexOf("jbd2") === 0 || nm.indexOf("btrfs") === 0 || nm === "udisksd") return "disk";
        if (nm.indexOf("kworker") === 0 || nm.indexOf("hyprland") >= 0 || nm.indexOf("quickshell") >= 0 ||
            nm === "qs" || nm === "xwayland" || nm.indexOf("systemd") === 0) return "temp";
        if ((memMB || 0) > 260 && (cpu || 0) < 6.0) return "mem";
        return "cpu";
    }

    function placeAnchorInFront() {
        if (!rig) return;
        const fwdX = -Math.sin(rig.camYaw) * Math.cos(rig.camPitch);
        const fwdY = Math.sin(rig.camPitch);
        const fwdZ = -Math.cos(rig.camYaw) * Math.cos(rig.camPitch);
        let ax = rig.camX + fwdX * 370;
        let ay = rig.camY + fwdY * 370;
        let az = rig.camZ + fwdZ * 370;

        const dSun = Math.hypot(ax, ay, az) || 1.0;
        const minSun = Math.max(640, rig.sunRadius + 300);
        if (dSun < minSun) {
            const q = minSun / dSun;
            ax *= q; ay *= q; az *= q;
        }
        const dx = ax - anchorX, dy = ay - anchorY, dz = az - anchorZ;
        anchorX = ax; anchorY = ay; anchorZ = az;
        if (anchored) {
            for (let i = 0; i < nodes.length; i++) {
                nodes[i].x += dx; nodes[i].y += dy; nodes[i].z += dz;
            }
        }
        anchored = true;
    }

    function addNode(props) {
        const sp = WidgetConfig.bubbleHubSpacing;
        let sx = anchorX, sy = anchorY, sz = anchorZ;
        if (props.type === "metric" && hubOffsets[props.key]) {
            const off = hubOffsets[props.key];
            sx += off.x * sp;
            sy += off.y * sp;
            sz += off.z * sp;
        } else {
            const hub = nodeMap[props.hubId || "cpu"];
            const bx = hub ? hub.x : anchorX;
            const by = hub ? hub.y : anchorY;
            const bz = hub ? hub.z : anchorZ;
            const th = Math.random() * Math.PI * 2;
            const u = (Math.random() - 0.5) * 0.9;
            const r0 = 26 + Math.random() * 24;
            sx = bx + r0 * Math.cos(th);
            sy = by + r0 * u;
            sz = bz + r0 * Math.sin(th);
        }

        const n = Object.assign({
            x: sx, y: sy, z: sz,
            vx: (Math.random() - 0.5) * 14,
            vy: (Math.random() - 0.5) * 14,
            vz: (Math.random() - 0.5) * 14,
            r: props.rT || 10,
            rT: props.rT || 10,
            sq: 0,
            seed: Math.random() * 100,
            orbitDir: Math.random() < 0.5 ? 1 : -1,
            cpu: 0, cpuT: 0, memMB: 0,
            paused: false,
            dying: false,
            killing: false,
            killT: 0.0,
            hist: new Array(32).fill(0)
        }, props);
        nodes.push(n);
        nodeMap[n.id] = n;
        bubbleModel.append({ nid: n.id });
        return n;
    }

    function seedMetrics() {
        const sc = WidgetConfig.bubbleSphereSize;
        const defs = [
            { id: "cpu",  type: "metric", key: "cpu",  name: "CPU",     baseR: 15.0, rT: 15.0 * sc },
            { id: "mem",  type: "metric", key: "mem",  name: "Memory",  baseR: 13.5, rT: 13.5 * sc },
            { id: "temp", type: "metric", key: "temp", name: "Thermal", baseR: 12.5, rT: 12.5 * sc },
            { id: "net",  type: "metric", key: "net",  name: "Network", baseR: 12.0, rT: 12.0 * sc },
            { id: "disk", type: "metric", key: "disk", name: "Disk",    baseR: 12.0, rT: 12.0 * sc }
        ];
        for (let i = 0; i < defs.length; i++) {
            if (!nodeMap[defs[i].id]) addNode(defs[i]);
        }
    }

    function openById(id) {
        if (!id || !nodeMap[id]) return;
        if (selectedId === id) {
            selectedId = "";
            info = null;
            return;
        }
        selectedId = id;
        rebuildInfo();
    }

    function triggerKill(targetId) {
        const id = targetId || selectedId || aimedId;
        const n = nodeMap[id];
        if (!n || n.type === "metric" || n.killing) return;

        const pids = n.type === "group" ? (n.pids || []) : (n.pid ? [n.pid] : []);
        BubbleState.sendSignal(pids, "TERM", n.name);

        n.killing = true;
        n.killT = 0.0;
        if (selectedId === id) { selectedId = ""; info = null; }

        for (let i = 0; i < nodes.length; i++) {
            const o = nodes[i];
            if (o === n || o.type === "metric") continue;
            const dx = o.x - n.x, dy = o.y - n.y, dz = o.z - n.z;
            const d = Math.hypot(dx, dy, dz) || 1.0;
            if (d < 120) {
                const kick = (120 - d) * 1.1;
                o.vx += (dx / d) * kick;
                o.vy += (dy / d) * kick;
                o.vz += (dz / d) * kick;
            }
        }
    }

    function triggerStopToggle(targetId) {
        const id = targetId || selectedId || aimedId;
        const n = nodeMap[id];
        if (!n || n.type === "metric" || n.killing) return;

        const pids = n.type === "group" ? (n.pids || []) : (n.pid ? [n.pid] : []);
        const nextPause = !n.paused;
        BubbleState.sendSignal(pids, nextPause ? "STOP" : "CONT", n.name);
        n.paused = nextPause;
        if (nextPause) { n.vx *= 0.1; n.vy *= 0.1; n.vz *= 0.1; }
        if (selectedId === id) rebuildInfo();
    }

    function applySnapshot(snap) {
        if (!snap) return;
        const first = !lastSnap;
        lastSnap = snap;
        const cArr = (snap.cpu && snap.cpu.cores) ? snap.cpu.cores : [];
        if (cArr.length) {
            cores = cArr.slice();
            vAvg = cArr.reduce((a, b) => a + b, 0) / cArr.length;
        }
        if (snap.tempC !== undefined) vTemp = Number(snap.tempC);
        if (snap.mem) {
            vAppsGB = Number(snap.mem.appsGB || 0);
            vCacheGB = Number(snap.mem.cacheGB || 0);
            vMem = vAppsGB + vCacheGB * 0.25;
            vTotal = Number(snap.mem.totalExactGB || snap.mem.totalGB || 8);
        }
        if (snap.net) {
            vNetDown = Number(snap.net.downMBs || 0);
            vNetUp = Number(snap.net.upMBs || 0);
        }
        if (snap.disk) {
            vDiskR = Number(snap.disk.readMBs || 0);
            vDiskW = Number(snap.disk.writeMBs || 0);
            if (snap.disk.drives) {
                const used = snap.disk.drives.reduce((a, d) => a + d.usedGB, 0);
                const tot = snap.disk.drives.reduce((a, d) => a + d.totalGB, 0);
                vDisk = tot > 0 ? used / tot : 0;
            }
        }

        function pushH(arr, v, fillAll) {
            const copy = arr.slice();
            if (fillAll) copy.fill(v);
            else { copy.push(v); copy.shift(); }
            return copy;
        }
        cpuHist = pushH(cpuHist, vAvg, first);
        tempHist = pushH(tempHist, vTemp, first);
        netUpHist = pushH(netUpHist, vNetUp, first);
        netDownHist = pushH(netDownHist, vNetDown, first);
        diskReadHist = pushH(diskReadHist, vDiskR, first);
        diskWriteHist = pushH(diskWriteHist, vDiskW, first);

        const sc = WidgetConfig.bubbleSphereSize;
        for (let i = 0; i < nodes.length; i++) {
            if (nodes[i].type === "metric") nodes[i].rT = (nodes[i].baseR || 13.0) * sc;
        }

        const showProcs = BubbleState.mode === "procs" || BubbleState.mode === "both";
        const showApps  = BubbleState.mode === "apps"  || BubbleState.mode === "both";
        const seen = {};
        const appOwnedPids = {};

        if (showApps && snap.apps) {
            const apps = snap.apps.slice(0, 14);
            for (let i = 0; i < apps.length; i++) {
                const a = apps[i];
                const id = "a" + a.cls;
                seen[id] = true;
                const plist = a.pids || [];
                for (let k = 0; k < plist.length; k++) appOwnedPids[plist[k]] = true;

                const hub = assignHub(a.name, a.cls, a.cpu, a.memMB, 0, 0);
                let n = nodeMap[id];
                if (!n) n = addNode({ id: id, type: "group", cls: a.cls, name: a.name, hubId: hub, family: "fam_app_" + a.cls, rT: procRadius(a.cpu, a.memMB), hist: new Array(32).fill(a.cpu || 0) });
                n.dying = false;
                n.hubId = hub;
                n.name = a.name; n.memMB = a.memMB || 0; n.windows = a.windows || 0;
                n.ws = a.ws || []; n.titles = a.titles || []; n.procs = a.procs || [];
                n.pids = plist;
                n.procCount = a.procCount || 0; n.cpuT = a.cpu || 0;
                n.rT = procRadius(n.cpuT, n.memMB);
                n.hist.push(n.cpuT); n.hist.shift();
            }
        }

        if (showProcs && snap.procs) {
            const cap = WidgetConfig.bubbleMaxProcs;
            let added = 0;
            for (let i = 0; i < snap.procs.length && added < cap; i++) {
                const p = snap.procs[i];
                if (BubbleState.mode === "both" && appOwnedPids[p.pid]) continue;
                added++;
                const id = "p" + p.pid;
                seen[id] = true;
                const hub = assignHub(p.name, p.cmd, p.cpu, p.memMB, p.readMB, p.writeMB);
                const fam = procFamily(p.name, p.cmd);
                let n = nodeMap[id];
                if (!n) n = addNode({ id: id, type: "proc", pid: p.pid, name: p.name, hubId: hub, family: fam, rT: procRadius(p.cpu, p.memMB), hist: new Array(32).fill(p.cpu || 0) });
                n.dying = false;
                n.hubId = hub;
                n.family = fam;
                n.name = p.name; n.user = p.user; n.memMB = p.memMB || 0;
                n.state = p.state; n.paused = (p.state === "T"); n.threads = p.threads; n.cpuT = p.cpu || 0;
                n.cpuSec = p.cpuSec; n.readMB = p.readMB; n.writeMB = p.writeMB;
                n.rT = procRadius(n.cpuT, n.memMB);
                n.hist.push(n.cpuT); n.hist.shift();
            }
        }

        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (n.type !== "metric" && !seen[n.id] && n.id !== selectedId && n.id !== dragId && !n.killing) {
                n.dying = true;
            }
        }
        if (selectedId !== "") rebuildInfo();
    }

    function rebuildInfo() {
        const n = nodeMap[selectedId];
        if (!n) { info = null; return; }
        const snap = lastSnap || {
            cpu: { threads: cores.length, model: "", freqGHz: 0, procCount: 0 },
            mem: { swapGB: 0, swapTotalGB: 0, freeGB: 0 },
            net: { iface: "", sentGB: 0, recvGB: 0 },
            disk: { readGB: 0, writtenGB: 0, drives: [] },
            sensors: []
        };
        const kind = n.type === "metric" ? n.key : (n.type === "group" ? "group" : "app");
        const color = n.type === "metric" ? metricColor(n.key) : (n.type === "group" ? cCream : cGold);
        const liveProcs = nodes.filter(x => x.type === "proc" && !x.dying);
        const sensors = snap.sensors || [];
        const disk = snap.disk || { readGB: 0, writtenGB: 0, drives: [] };
        const memFree = snap.mem && snap.mem.freeGB !== undefined ? snap.mem.freeGB : Math.max(0, vTotal - vAppsGB - vCacheGB);

        const d = {
            id: n.id, kind: kind, color: color, title: n.name || "", sub: "", num: "", unit: "",
            canControl: n.type !== "metric", paused: !!n.paused,
            facts: [], list: null, list2: null,
            hist: cpuHist.slice(), cores: cores.slice(),
            memApps: vAppsGB, memCache: vCacheGB, memFree: memFree,
            io: null, legend: null
        };

        if (kind === "cpu") {
            const mdl = String(snap.cpu.model || "").replace(/\(R\)|\(TM\)|CPU |@.*$/g, "").replace(/\s+/g, " ").trim();
            d.sub = (mdl ? mdl + " · " : "") + (snap.cpu.threads || cores.length) + " threads";
            d.num = String(Math.round(vAvg)); d.unit = "%";
            d.facts = [
                { lbl: "Clock", val: Number(snap.cpu.freqGHz || 0).toFixed(2) + " GHz" },
                { lbl: "Peak (1m)", val: Math.round(Math.max(0, ...cpuHist)) + "%" },
                { lbl: "Processes", val: String(snap.cpu.procCount || 0) },
                { lbl: "Busy threads", val: cores.filter(x => x > 50).length + " / " + cores.length }
            ];
            d.list = {
                title: "TOP PROCESSES",
                rows: liveProcs.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 7).map(p => ({
                    id: p.id, name: p.name, val: one(p.cpu) + "%", frac: Math.min(1, p.cpu / 100)
                }))
            };
        } else if (kind === "mem") {
            d.sub = vTotal.toFixed(1) + " GB installed";
            d.num = vMem.toFixed(1); d.unit = "GB";
            d.facts = [
                { lbl: "In use", val: Math.round(vMem / Math.max(1, vTotal) * 100) + "%" },
                { lbl: "Swap", val: Number(snap.mem.swapGB || 0).toFixed(1) + " / " + Number(snap.mem.swapTotalGB || 0).toFixed(1) + " GB" }
            ];
            const topM = liveProcs.slice().sort((a, b) => b.memMB - a.memMB).slice(0, 7);
            const mx = topM.length ? Math.max(1, topM[0].memMB) : 1;
            d.list = {
                title: "TOP MEMORY",
                rows: topM.map(p => ({ id: p.id, name: p.name, val: fmtMem(p.memMB), frac: p.memMB / mx }))
            };
        } else if (kind === "temp") {
            d.sub = vTemp > 80 ? "Hot" : vTemp > 65 ? "Warm" : "Cool";
            d.num = String(Math.round(vTemp)); d.unit = "°C";
            const coreTemps = sensors.filter(x => String(x.label || "").startsWith("Core"));
            const hottest = coreTemps.length ? Math.max(...coreTemps.map(x => x.c)) : vTemp;
            const avgT = tempHist.reduce((a, b) => a + b, 0) / Math.max(1, tempHist.length);
            d.facts = [
                { lbl: "Peak (1m)", val: Math.round(Math.max(0, ...tempHist)) + "°C" },
                { lbl: "Average", val: Math.round(avgT) + "°C" },
                { lbl: "Hottest core", val: Math.round(hottest) + "°C" },
                { lbl: "Sensors", val: String(sensors.length) }
            ];
            d.list = {
                title: "SENSORS",
                rows: sensors.slice(0, 6).map(x => ({ name: x.label, val: Math.round(x.c) + "°C", frac: Math.max(0, Math.min(1, (x.c - 20) / 80)) }))
            };
        } else if (kind === "net") {
            d.sub = (snap.net && snap.net.iface) ? snap.net.iface : "network";
            d.num = one(vNetDown); d.unit = "MB/s down";
            d.legend = ["Up", "Down"];
            d.io = { up: netUpHist.slice(), down: netDownHist.slice() };
            d.facts = [
                { lbl: "Down", val: one(vNetDown) + " MB/s" },
                { lbl: "Up", val: one(vNetUp) + " MB/s" },
                { lbl: "Total recv", val: Number(snap.net.recvGB || 0).toFixed(2) + " GB" },
                { lbl: "Total sent", val: Number(snap.net.sentGB || 0).toFixed(2) + " GB" }
            ];
        } else if (kind === "disk") {
            const used = disk.drives.reduce((a, x) => a + x.usedGB, 0);
            const tot = disk.drives.reduce((a, x) => a + x.totalGB, 0);
            d.sub = Math.round(used) + " of " + Math.round(tot) + " GB";
            d.num = String(Math.round(vDisk * 100)); d.unit = "% used";
            d.legend = ["Read", "Write"];
            d.io = { up: diskReadHist.slice(), down: diskWriteHist.slice() };
            d.facts = [
                { lbl: "Read", val: one(vDiskR) + " MB/s" },
                { lbl: "Write", val: one(vDiskW) + " MB/s" },
                { lbl: "Total read", val: Number(disk.readGB || 0).toFixed(1) + " GB" },
                { lbl: "Total write", val: Number(disk.writtenGB || 0).toFixed(1) + " GB" }
            ];
            d.list = {
                title: "DRIVES",
                rows: disk.drives.map(x => ({
                    name: x.mount, val: Math.round(x.usedGB) + " / " + Math.round(x.totalGB) + " GB",
                    frac: x.usedGB / Math.max(1, x.totalGB)
                }))
            };
        } else if (kind === "app") {
            d.sub = "PID " + n.pid + (n.user ? " · " + n.user : "") + " · orbit: " + String(n.hubId || "cpu").toUpperCase();
            d.num = n.paused ? "STOP" : one(n.cpu); d.unit = n.paused ? "paused" : "% CPU";
            d.hist = (n.hist || []).slice();
            d.facts = [
                { lbl: "Memory", val: fmtMem(n.memMB) },
                { lbl: "State", val: n.paused ? "Stopped (SIGSTOP)" : (n.cpu > 5 ? "Running" : "Sleeping") },
                { lbl: "Threads", val: String(n.threads || "—") },
                { lbl: "Disk read", val: (n.readMB !== undefined && n.readMB !== null) ? fmtMem(n.readMB) : "—" }
            ];
        } else if (kind === "group") {
            d.sub = (n.windows || 0) + (n.windows === 1 ? " window" : " windows") + (n.ws && n.ws.length ? " · ws " + n.ws.join(", ") : "");
            d.num = n.paused ? "STOP" : one(n.cpu); d.unit = n.paused ? "paused" : "% CPU";
            d.hist = (n.hist || []).slice();
            d.facts = [
                { lbl: "Memory", val: fmtMem(n.memMB) },
                { lbl: "Processes", val: String(n.procCount || 0) }
            ];
            const ps = n.procs || [];
            const mx = Math.max(1, ...ps.map(p => p.memMB || 0));
            d.list2 = (n.titles && n.titles.length) ? { title: "WINDOWS", rows: n.titles.slice(0, 4).map(t => ({ name: t || "Untitled" })) } : null;
            d.list = ps.length ? {
                title: "PROCESSES",
                rows: ps.slice(0, 6).map(p => ({
                    id: nodeMap["p" + p.pid] ? ("p" + p.pid) : "",
                    name: p.name, val: fmtMem(p.memMB) + " · " + one(p.cpu) + "%", frac: (p.memMB || 0) / mx
                }))
            } : null;
        }
        info = d;
    }

    function stepAndProject(dt) {
        if (!rig || !BubbleState.open) return;
        const tNow = rig.loopTime;
        const hubSp = WidgetConfig.bubbleHubSpacing;
        const grav = WidgetConfig.bubbleGravity;
        const orbitPull = WidgetConfig.bubbleOrbitPull;
        const famPull = WidgetConfig.bubbleGroupAttract;
        const maxClusterR = hubSp * 2.1;
        const damp = Math.pow(0.56, dt);
        const minSun = Math.max(460, rig.sunRadius + 150);

        for (let i = nodes.length - 1; i >= 0; i--) {
            const n = nodes[i];
            n.cpu += (n.cpuT - n.cpu) * Math.min(1, 5.0 * dt);
            n.sq *= Math.pow(0.03, dt);

            if (n.killing) {
                n.killT += dt / 0.65;
                if (n.killT >= 1.0) {
                    delete nodeMap[n.id];
                    nodes.splice(i, 1);
                    for (let m = bubbleModel.count - 1; m >= 0; m--) {
                        if (bubbleModel.get(m).nid === n.id) { bubbleModel.remove(m); break; }
                    }
                    continue;
                }
                n.vx *= 0.85; n.vy *= 0.85; n.vz *= 0.85;
                n.x += n.vx * dt; n.y += n.vy * dt; n.z += n.vz * dt;
                continue;
            }

            const targetR = n.dying ? 0.0 : n.rT;
            n.r += (targetR - n.r) * Math.min(1, 6.0 * dt);
            if (n.dying && n.r < 0.6) {
                delete nodeMap[n.id];
                nodes.splice(i, 1);
                for (let m = bubbleModel.count - 1; m >= 0; m--) {
                    if (bubbleModel.get(m).nid === n.id) { bubbleModel.remove(m); break; }
                }
                continue;
            }
            if (n.id === dragId) continue;

            let ax = 0, ay = 0, az = 0;

            if (n.type === "metric") {
                const off = hubOffsets[n.key] || { x: 0, y: 0, z: 0 };
                const tx = anchorX + off.x * hubSp;
                const ty = anchorY + off.y * hubSp;
                const tz = anchorZ + off.z * hubSp;
                const kHub = 0.45 + grav * 1.1;
                ax += (tx - n.x) * kHub;
                ay += (ty - n.y) * kHub;
                az += (tz - n.z) * kHub;
            } else {
                const hub = nodeMap[n.hubId || "cpu"];
                if (hub && !n.paused) {
                    const dx = n.x - hub.x;
                    const dy = n.y - hub.y;
                    const dz = n.z - hub.z;
                    const dist = Math.hypot(dx, dy, dz) || 0.001;
                    const desiredR = hub.r + n.r + 22.0 + (n.seed % 26.0);
                    const radialErr = dist - desiredR;
                    const nx = dx / dist, ny = dy / dist, nz = dz / dist;

                    ax -= nx * radialErr * (orbitPull * 1.45);
                    ay -= ny * radialErr * (orbitPull * 1.45);
                    az -= nz * radialErr * (orbitPull * 1.45);

                    const swirl = orbitPull * 18.0 * n.orbitDir;
                    ax += -nz * swirl;
                    az +=  nx * swirl;
                }

                const cdx = n.x - anchorX, cdy = n.y - anchorY, cdz = n.z - anchorZ;
                const cdist = Math.hypot(cdx, cdy, cdz) || 0.001;
                ax -= cdx * grav;
                ay -= cdy * grav;
                az -= cdz * grav;

                if (cdist > maxClusterR) {
                    const over = cdist - maxClusterR;
                    ax -= (cdx / cdist) * over * 1.8;
                    ay -= (cdy / cdist) * over * 1.8;
                    az -= (cdz / cdist) * over * 1.8;
                }
            }

            if (!n.paused) {
                ax += Math.sin(tNow * 0.45 + n.seed) * 3.5;
                ay += Math.cos(tNow * 0.38 + n.seed * 1.3) * 3.5;
                az += Math.sin(tNow * 0.32 + n.seed * 1.7) * 3.5;
            }

            n.vx = (n.vx + ax * dt) * damp;
            n.vy = (n.vy + ay * dt) * damp;
            n.vz = (n.vz + az * dt) * damp;

            const spd = Math.hypot(n.vx, n.vy, n.vz);
            if (spd > 190) {
                const s = 190 / spd;
                n.vx *= s; n.vy *= s; n.vz *= s;
            }

            n.x += n.vx * dt;
            n.y += n.vy * dt;
            n.z += n.vz * dt;

            const dSun = Math.hypot(n.x, n.y, n.z) || 1.0;
            if (dSun < minSun) {
                const q = minSun / dSun;
                n.x *= q; n.y *= q; n.z *= q;
            }
        }

        for (let i = 0; i < nodes.length; i++) {
            const a = nodes[i];
            if (a.killing) continue;
            for (let j = i + 1; j < nodes.length; j++) {
                const b = nodes[j];
                if (b.killing) continue;
                const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
                const d = Math.hypot(dx, dy, dz) || 0.001;
                const nx = dx / d, ny = dy / d, nz = dz / d;

                if (a.type === "metric" && b.type === "metric" && d < hubSp * 1.15) {
                    const rep = (hubSp * 1.15 - d) * 1.4 * dt;
                    if (a.id !== dragId) { a.vx -= nx * rep; a.vy -= ny * rep; a.vz -= nz * rep; }
                    if (b.id !== dragId) { b.vx += nx * rep; b.vy += ny * rep; b.vz += nz * rep; }
                }

                if (famPull > 0.01 && a.type !== "metric" && b.type !== "metric" &&
                    a.family && a.family === b.family && d > (a.r + b.r + 12) && d < 160) {
                    const coh = famPull * 16.0 * dt;
                    if (a.id !== dragId && !a.paused) { a.vx += nx * coh; a.vy += ny * coh; a.vz += nz * coh; }
                    if (b.id !== dragId && !b.paused) { b.vx -= nx * coh; b.vy -= ny * coh; b.vz -= nz * coh; }
                }

                const minD = a.r + b.r + 3.5;
                if (d < minD) {
                    const pen = (minD - d) * 0.5;
                    if (a.id !== dragId) { a.x -= nx * pen; a.y -= ny * pen; a.z -= nz * pen; }
                    if (b.id !== dragId) { b.x += nx * pen; b.y += ny * pen; b.z += nz * pen; }
                    const rvx = b.vx - a.vx, rvy = b.vy - a.vy, rvz = b.vz - a.vz;
                    const vn = rvx * nx + rvy * ny + rvz * nz;
                    if (vn < 0) {
                        const imp = -0.80 * vn;
                        if (a.id !== dragId) { a.vx -= nx * imp; a.vy -= ny * imp; a.vz -= nz * imp; }
                        if (b.id !== dragId) { b.vx += nx * imp; b.vy += ny * imp; b.vz += nz * imp; }
                        const sqAmt = Math.min(0.15, Math.abs(vn) * 0.0022);
                        a.sq = Math.max(a.sq, sqAmt);
                        b.sq = Math.max(b.sq, sqAmt);
                    }
                }
            }
        }

        const w = root.width, h = root.height;
        const halfW = w * 0.5, halfH = h * 0.5;
        const fov = Math.min(w, h) * 0.95;

        let bestAimId = "";
        let bestAimScore = 1e9;

        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            const it = itemMap[n.id];
            if (!it) continue;
            const p = rig.project3D(n.x, n.y, n.z, halfW, halfH, fov);
            if (!p || p.depth <= 6.0 || n.r < 0.6) {
                it.visible = false;
                continue;
            }
            const sr = n.r * p.scale;
            if (sr < 2.0 || p.sx < -sr - 40 || p.sx > w + sr + 40 || p.sy < -sr - 40 || p.sy > h + sr + 40) {
                it.visible = false;
                continue;
            }
            const sunDir = rig.dirToViewSpace(-n.x, -n.y, -n.z, tNow);
            it.sync(n, p.sx, p.sy, sr, p.depth, sunDir);

            if (n.type !== "metric" && !n.killing && !n.dying) {
                const centerDist = Math.hypot(p.sx - halfW, p.sy - halfH);
                if (centerDist <= Math.max(95, sr + 28)) {
                    const score = centerDist + p.depth * 0.05;
                    if (score < bestAimScore) {
                        bestAimScore = score;
                        bestAimId = n.id;
                    }
                }
            }
        }
        aimedId = bestAimId;
    }

    Connections {
        target: BubbleState
        function onOpenChanged() {
            if (BubbleState.open) {
                root.placeAnchorInFront();
                root.seedMetrics();
                if (BubbleState.snap) root.applySnapshot(BubbleState.snap);
            } else {
                root.selectedId = "";
                root.aimedId = "";
                root.info = null;
                root.dragId = "";
            }
        }
        function onSnapSeqChanged() {
            if (BubbleState.open) root.applySnapshot(BubbleState.snap);
        }
        function onModeChanged() {
            if (BubbleState.open && BubbleState.snap) root.applySnapshot(BubbleState.snap);
        }
        function onRecenterSeqChanged() {
            if (BubbleState.open) root.placeAnchorInFront();
        }
    }

    Connections {
        target: root.rig
        function onFrameUpdated() {
            if (root.visible) root.stepAndProject(root.rig.lastDt);
        }
    }

    // Center crosshair for aiming at a sphere to kill/stop
    Item {
        z: 99990
        anchors.centerIn: parent
        width: 24; height: 24
        opacity: root.aimedId !== "" ? 0.85 : 0.25
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Rectangle { anchors.centerIn: parent; width: 14; height: 1; color: root.aimedId !== "" ? root.cHot : root.cGold }
        Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: root.aimedId !== "" ? root.cHot : root.cGold }
    }

    Repeater {
        model: bubbleModel
        delegate: Item {
            id: bItem
            required property string nid
            property string bType: "proc"
            property string bKey: ""
            property string bName: ""
            property string bVal: ""
            property real rad: 10
            property real depth: 400
            property real pct: 0.05
            property real sq: 0
            property vector4d lDir: Qt.vector4d(-0.4, 0.5, 0.7, 0)
            property bool hot: false
            property bool paused: false
            property bool killing: false
            property real killT: 0.0
            readonly property bool isMetric: bType === "metric"
            readonly property bool isApp: bType === "group"
            readonly property bool isSelected: root.selectedId === nid
            readonly property bool isAimed: root.aimedId === nid
            readonly property bool isDragged: root.dragId === nid
            readonly property color sphereBase: killing ? (killT < 0.3 ? "#FF6A2B" : "#FF2A1A")
                                              : paused ? "#2A303E"
                                              : isApp ? "#C9D3E6"
                                              : isMetric ? "#121828"
                                              : (hot ? root.cHot : "#4E688F")
            readonly property color sphereAccent: killing ? "#FFD27D"
                                                : paused ? root.cDim
                                                : isMetric ? root.metricColor(bKey)
                                                : (isApp ? root.cCream : root.cGold)
            readonly property real killScale: {
                if (!killing) return 1.0;
                if (killT < 0.28) return 1.0 + (killT / 0.28) * 0.42;
                const t2 = (killT - 0.28) / 0.72;
                return Math.max(0.01, 1.42 * (1.0 - t2 * t2));
            }

            visible: false
            width: rad * 2
            height: rad * 2
            opacity: killing ? Math.max(0.0, 1.0 - Math.max(0, (killT - 0.45) / 0.55)) : (paused ? 0.68 : 1.0)
            scale: (isDragged ? 1.1 : 1.0) * (1.0 + sq * 0.45) * killScale

            function sync(n, sx, sy, sr, dp, sunVec) {
                bType = n.type;
                bKey = n.key || "";
                bName = n.name || "";
                rad = sr;
                depth = dp;
                sq = n.sq;
                lDir = sunVec;
                paused = !!n.paused;
                killing = !!n.killing;
                killT = n.killT || 0.0;
                hot = !isMetric && n.cpu > 45;
                if (isMetric) {
                    pct = root.dialFrac(bKey);
                    bVal = root.dialText(bKey);
                } else {
                    bVal = paused ? "STOP" : (n.cpu.toFixed(n.cpu < 10 ? 1 : 0) + "%");
                }
                x = sx - sr;
                y = sy - sr;
                z = -dp;
                visible = true;
            }

            Component.onCompleted: root.itemMap[nid] = bItem
            Component.onDestruction: delete root.itemMap[nid]

            Rectangle {
                visible: bItem.killing
                anchors.centerIn: parent
                width: bItem.width * (1.0 + bItem.killT * 2.8)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: Math.max(1.5, 4.0 * (1.0 - bItem.killT))
                border.color: "#FF8844"
                opacity: Math.max(0, 1.0 - bItem.killT)
            }

            Rectangle {
                visible: !bItem.killing && (bItem.isSelected || bItem.isAimed || bMa.containsMouse)
                anchors.centerIn: parent
                width: parent.width + 10; height: width; radius: width / 2
                color: "transparent"
                border.width: (bItem.isSelected || bItem.isAimed) ? 2 : 1
                border.color: bItem.isAimed && !bItem.isSelected ? root.cHot : bItem.sphereAccent
                opacity: bItem.isSelected ? 0.95 : (bItem.isAimed ? 0.85 : 0.55)
            }

            ShaderEffect {
                anchors.fill: parent
                property color baseColor: bItem.sphereBase
                property color accentColor: bItem.sphereAccent
                property vector4d lightDir: bItem.lDir
                property vector4d params: Qt.vector4d(
                    bItem.isMetric ? 1.0 : 0.0,
                    bItem.pct,
                    (bItem.hot || bItem.killing) ? 1.0 : 0.0,
                    (bItem.isSelected || bItem.isAimed || bMa.containsMouse) ? 1.0 : 0.0
                )
                fragmentShader: Qt.resolvedUrl("../shaders/bubble_sphere.frag.qsb")
            }

            Column {
                anchors.centerIn: parent
                visible: bItem.rad >= 14 && !bItem.killing
                spacing: 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, bItem.rad * 1.55)
                    elide: Text.ElideRight
                    text: bItem.bName
                    font.family: root.fMono
                    font.pixelSize: Math.max(7, Math.round(bItem.rad * (bItem.isMetric ? 0.23 : 0.28)))
                    font.bold: true
                    color: bItem.isApp ? "#0A0D14" : (bItem.isMetric ? root.cDim : root.cCream)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: bItem.rad >= 20
                    text: bItem.bVal
                    font.family: root.fMono
                    font.pixelSize: Math.max(8, Math.round(bItem.rad * (bItem.isMetric ? 0.36 : 0.23)))
                    font.bold: bItem.isMetric
                    color: bItem.isApp ? "#182030" : root.cCream
                }
            }

            MouseArea {
                id: bMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: bItem.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                property real startX: 0
                property real startY: 0
                property real lastX: 0
                property real lastY: 0
                property real lastT: 0
                property bool moved: false

                onPressed: (m) => {
                    const p = bMa.mapToItem(root, m.x, m.y);
                    startX = lastX = p.x;
                    startY = lastY = p.y;
                    lastT = Date.now();
                    moved = false;
                    root.dragId = bItem.nid;
                    root.dragDepth = bItem.depth;
                    if (root.rig) root.rig.isInteracting = true;
                }
                onPositionChanged: (m) => {
                    if (!pressed || root.dragId !== bItem.nid || !root.rig) return;
                    const p = bMa.mapToItem(root, m.x, m.y);
                    if (Math.hypot(p.x - startX, p.y - startY) > 5) moved = true;
                    if (!moved) return;

                    const now = Date.now();
                    const dt = Math.max(0.008, (now - lastT) / 1000.0);
                    const dsx = p.x - lastX;
                    const dsy = p.y - lastY;
                    lastX = p.x; lastY = p.y; lastT = now;

                    const n = root.nodeMap[bItem.nid];
                    if (!n) return;
                    const fov = Math.min(root.width, root.height) * 0.95;
                    const worldPerPx = root.dragDepth / Math.max(1, fov);

                    const r = root.rig;
                    const rightX = Math.cos(r.camYaw), rightZ = -Math.sin(r.camYaw);
                    const upX = Math.sin(r.camYaw) * Math.sin(r.camPitch);
                    const upY = Math.cos(r.camPitch);
                    const upZ = Math.cos(r.camYaw) * Math.sin(r.camPitch);

                    const wx = (rightX * dsx - upX * dsy) * worldPerPx;
                    const wy = (-upY * dsy) * worldPerPx;
                    const wz = (rightZ * dsx - upZ * dsy) * worldPerPx;

                    n.x += wx; n.y += wy; n.z += wz;
                    n.vx = Math.max(-170, Math.min(170, wx / dt * 0.5));
                    n.vy = Math.max(-170, Math.min(170, wy / dt * 0.5));
                    n.vz = Math.max(-170, Math.min(170, wz / dt * 0.5));
                }
                onReleased: {
                    if (root.rig) root.rig.isInteracting = false;
                    root.dragId = "";
                    if (!moved) root.openById(bItem.nid);
                }
                onCanceled: {
                    if (root.rig) root.rig.isInteracting = false;
                    root.dragId = "";
                }
            }
        }
    }

    readonly property string activeActionId: root.selectedId !== "" ? root.selectedId : root.aimedId
    readonly property var activeActionNode: activeActionId !== "" ? root.nodeMap[activeActionId] : null
    readonly property bool canSignalTarget: activeActionNode !== null && activeActionNode !== undefined && activeActionNode.type !== "metric" && !activeActionNode.killing

    Rectangle {
        z: 100000
        x: 16 + (leftPanel.width + 12) * root.openProg
        y: 16
        width: barRow.implicitWidth + 18
        height: 34
        radius: 17
        color: "#E0070911"
        border.width: 1
        border.color: "#55D4AF37"

        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "3D BUBBLES"
                color: root.cGold
                font.family: root.fMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5
            }
            Repeater {
                model: [{ k: "both", l: "ALL" }, { k: "procs", l: "PROCS" }, { k: "apps", l: "APPS" }]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: BubbleState.mode === modelData.k
                    width: ml.implicitWidth + 10; height: 22; radius: 11
                    color: on ? "#33D4AF37" : "transparent"
                    Text { id: ml; anchors.centerIn: parent; text: modelData.l; color: on ? root.cGold : root.cDim; font.family: root.fMono; font.pixelSize: 9 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: BubbleState.mode = modelData.k }
                }
            }
            Rectangle {
                width: recLbl.implicitWidth + 12; height: 22; radius: 11
                color: recMa.containsMouse ? "#28D4AF37" : "#14D4AF37"
                Text { id: recLbl; anchors.centerIn: parent; text: "SUMMON"; color: root.cCream; font.family: root.fMono; font.pixelSize: 9 }
                MouseArea { id: recMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.placeAnchorInFront() }
            }

            Row {
                visible: root.canSignalTarget
                spacing: 5
                Rectangle { width: 1; height: 16; anchors.verticalCenter: parent.verticalCenter; color: root.cLine }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 95); elide: Text.ElideRight
                    text: root.activeActionNode ? root.activeActionNode.name : ""
                    color: root.cCream; font.family: root.fMono; font.pixelSize: 9; font.bold: true
                }
                Rectangle {
                    width: stpLbl.implicitWidth + 10; height: 22; radius: 11
                    color: stpMa.containsMouse ? "#33E8B949" : "#1CE8B949"
                    border.width: 1; border.color: "#66E8B949"
                    Text {
                        id: stpLbl; anchors.centerIn: parent
                        text: (root.activeActionNode && root.activeActionNode.paused) ? "RESUME" : "STOP"
                        color: root.cWarm; font.family: root.fMono; font.pixelSize: 9; font.bold: true
                    }
                    MouseArea { id: stpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerStopToggle(root.activeActionId) }
                }
                Rectangle {
                    width: kilLbl.implicitWidth + 10; height: 22; radius: 11
                    color: kilMa.containsMouse ? "#44D9694A" : "#22D9694A"
                    border.width: 1; border.color: root.cHot
                    Text { id: kilLbl; anchors.centerIn: parent; text: "KILL"; color: root.cHot; font.family: root.fMono; font.pixelSize: 9; font.bold: true }
                    MouseArea { id: kilMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerKill(root.activeActionId) }
                }
            }

            Rectangle {
                width: 22; height: 22; radius: 11
                color: clMa.containsMouse ? "#33D9694A" : "transparent"
                Text { anchors.centerIn: parent; text: "✕"; color: root.cCream; font.pixelSize: 11 }
                MouseArea { id: clMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: BubbleState.open = false }
            }
        }
    }

    Rectangle {
        visible: BubbleState.statusMsg !== ""
        z: 100000
        x: 16 + (leftPanel.width + 12) * root.openProg
        y: 56
        width: stMsg.implicitWidth + 18
        height: 24
        radius: 12
        color: "#E0070911"
        border.width: 1
        border.color: root.cHot
        Text { id: stMsg; anchors.centerIn: parent; text: BubbleState.statusMsg; color: root.cCream; font.family: root.fMono; font.pixelSize: 10 }
    }

    Rectangle {
        id: quickPill
        z: 100000
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 42
        height: quickCol.implicitHeight + 10
        radius: 21
        color: "#E0070911"
        border.width: 1
        border.color: "#55D4AF37"

        readonly property var keys: ["cpu", "mem", "temp", "net", "disk"]
        readonly property var icons: ["CPU", "RAM", "TMP", "NET", "DSK"]
        readonly property int at: keys.indexOf(root.selectedId)
        property int last: 0
        onAtChanged: if (at >= 0) last = at

        function go(i) {
            i = Math.max(0, Math.min(keys.length - 1, i));
            root.openById(keys[i]);
        }

        Rectangle {
            visible: quickPill.at >= 0
            x: 4; y: 5 + quickPill.last * 34
            width: 34; height: 34; radius: 17
            color: "#33D4AF37"
            border.width: 1; border.color: root.cGold
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        Column {
            id: quickCol
            x: 4; y: 5
            Repeater {
                model: quickPill.keys.length
                Item {
                    required property int index
                    readonly property bool active: quickPill.at === index
                    width: 34; height: 34
                    Text {
                        anchors.centerIn: parent
                        text: quickPill.icons[parent.index]
                        font.family: root.fMono; font.pixelSize: 9; font.bold: true
                        color: parent.active ? root.cGold : (qMa.containsMouse ? root.cCream : root.cDim)
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: qMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: quickPill.go(parent.index)
                    }
                }
            }
        }

        WheelHandler {
            orientation: Qt.Vertical
            onWheel: (e) => {
                if (e.angleDelta.y === 0) return;
                const dir = e.angleDelta.y < 0 ? 1 : -1;
                const next = (quickPill.at >= 0 ? quickPill.at : quickPill.last - dir) + dir;
                quickPill.go(next);
            }
        }
    }

    Rectangle {
        id: leftPanel
        z: 100000
        width: Math.min(390, Math.max(310, Math.round(parent.width * 0.26)))
        y: 16
        height: parent.height - 32
        x: 16 - (width + 24) * (1.0 - root.openProg)
        visible: root.openProg > 0.005
        radius: 14
        color: root.cBg
        border.width: 1
        border.color: "#66D4AF37"
        clip: true

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: (w) => w.accepted = true }

        Rectangle {
            z: 10
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14
            width: 28; height: 28; radius: 8
            color: lpCloseMa.containsMouse ? "#28D4AF37" : root.cCard
            border.width: 1; border.color: lpCloseMa.containsMouse ? root.cGold : root.cLine
            Text { anchors.centerIn: parent; text: "✕"; color: root.cCream; font.family: root.fMono; font.pixelSize: 11 }
            MouseArea { id: lpCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedId = ""; root.info = null; } }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentWidth: width
            contentHeight: detailCol.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: detailCol
                width: parent.width
                spacing: 14
                readonly property var d: root.info
                readonly property string kind: d ? d.kind : ""
                readonly property color acc: d ? d.color : root.cGold

                Column {
                    width: parent.width; spacing: 4
                    Row {
                        spacing: 10
                        Item {
                            width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter
                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer
                                ShapePath {
                                    strokeColor: detailCol.acc; strokeWidth: 1.2; fillColor: detailCol.acc
                                    PathSvg {
                                        path: detailCol.kind === "cpu" ? "M2,2 L12,2 L12,12 L2,12 Z"
                                            : detailCol.kind === "mem" ? "M7,0 L13,3.5 L13,10.5 L7,14 L1,10.5 L1,3.5 Z"
                                            : detailCol.kind === "temp" ? "M7,1 L13,13 L1,13 Z"
                                            : detailCol.kind === "net" ? "M7,0 L12,7 L7,14 L2,7 Z"
                                            : "M7,1 L13,5.5 L10.5,13 L3.5,13 L1,5.5 Z"
                                    }
                                }
                            }
                            RotationAnimation on rotation { running: leftPanel.visible; loops: Animation.Infinite; from: 0; to: 360; duration: 9000 }
                        }
                        Text {
                            width: detailCol.width - 64; elide: Text.ElideRight
                            text: detailCol.d ? String(detailCol.d.title).toUpperCase() : ""
                            color: root.cCream; font.family: root.fMono; font.pixelSize: 16; font.bold: true; font.letterSpacing: 2
                        }
                    }
                    Text {
                        width: parent.width - 36; elide: Text.ElideRight
                        text: detailCol.d ? detailCol.d.sub : ""
                        color: root.cDim; font.family: root.fMono; font.pixelSize: 10
                    }
                }

                Row {
                    spacing: 6
                    Text {
                        id: bigNum
                        text: detailCol.d ? detailCol.d.num : ""
                        color: detailCol.acc; font.family: root.fMono; font.pixelSize: 40; font.bold: true
                    }
                    Text {
                        anchors.baseline: bigNum.baseline
                        text: detailCol.d ? detailCol.d.unit : ""
                        color: root.cDim; font.family: root.fMono; font.pixelSize: 12
                    }
                }

                Row {
                    visible: !!(detailCol.d && detailCol.d.canControl)
                    spacing: 8
                    Rectangle {
                        width: lpStopTxt.implicitWidth + 18; height: 28; radius: 8
                        color: lpStopMa.containsMouse ? "#33E8B949" : "#1AE8B949"
                        border.width: 1; border.color: root.cWarm
                        Text {
                            id: lpStopTxt; anchors.centerIn: parent
                            text: (detailCol.d && detailCol.d.paused) ? "RESUME (CONT)" : "STOP (PAUSE)"
                            color: root.cWarm; font.family: root.fMono; font.pixelSize: 10; font.bold: true
                        }
                        MouseArea { id: lpStopMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerStopToggle(root.selectedId) }
                    }
                    Rectangle {
                        width: lpKillTxt.implicitWidth + 18; height: 28; radius: 8
                        color: lpKillMa.containsMouse ? "#44D9694A" : "#22D9694A"
                        border.width: 1; border.color: root.cHot
                        Text {
                            id: lpKillTxt; anchors.centerIn: parent
                            text: "KILL PROCESS"
                            color: root.cHot; font.family: root.fMono; font.pixelSize: 10; font.bold: true
                        }
                        MouseArea { id: lpKillMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerKill(root.selectedId) }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: root.cLine }

                Column {
                    visible: detailCol.kind === "cpu"
                    width: parent.width; spacing: 10
                    SparkChart {
                        width: parent.width; height: 76
                        values: detailCol.d ? detailCol.d.hist : []
                        lineColor: detailCol.acc
                    }
                    Row {
                        id: coreBars
                        width: parent.width; spacing: 4
                        readonly property var cList: detailCol.d ? detailCol.d.cores : []
                        Repeater {
                            model: coreBars.cList.length
                            Column {
                                required property int index
                                readonly property real v: coreBars.cList[index] || 0
                                width: (coreBars.width - 4 * Math.max(0, coreBars.cList.length - 1)) / Math.max(1, coreBars.cList.length)
                                spacing: 3
                                Rectangle {
                                    width: parent.width; height: 38; radius: 4; color: root.cCard; border.width: 1; border.color: root.cLine; clip: true
                                    Rectangle {
                                        anchors.bottom: parent.bottom; width: parent.width
                                        height: Math.max(2, parent.height * Math.min(1, parent.parent.v / 100))
                                        color: detailCol.acc; radius: 3
                                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(parent.v); color: root.cDim; font.family: root.fMono; font.pixelSize: 8
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: detailCol.kind === "mem"
                    width: parent.width; spacing: 8
                    Rectangle {
                        width: parent.width; height: 18; radius: 6; color: root.cCard; border.width: 1; border.color: root.cLine; clip: true
                        Row {
                            spacing: 2
                            Rectangle {
                                width: detailCol.d ? parent.parent.width * detailCol.d.memApps / Math.max(1, root.vTotal) : 0
                                height: 18; radius: 5; color: root.cGold
                                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                            }
                            Rectangle {
                                width: detailCol.d ? parent.parent.width * detailCol.d.memCache / Math.max(1, root.vTotal) : 0
                                height: 18; radius: 5; color: Qt.rgba(0.9, 0.84, 0.72, 0.4)
                                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Row {
                        spacing: 14
                        Text { text: "■ Apps " + (detailCol.d ? detailCol.d.memApps.toFixed(1) : "0") + "G"; color: root.cGold; font.family: root.fMono; font.pixelSize: 10 }
                        Text { text: "■ Cache " + (detailCol.d ? detailCol.d.memCache.toFixed(1) : "0") + "G"; color: root.cCream; font.family: root.fMono; font.pixelSize: 10 }
                        Text { text: "■ Free " + (detailCol.d ? detailCol.d.memFree.toFixed(1) : "0") + "G"; color: root.cDim; font.family: root.fMono; font.pixelSize: 10 }
                    }
                }

                Column {
                    visible: detailCol.kind === "temp"
                    width: parent.width; spacing: 6
                    Rectangle {
                        width: parent.width; height: 10; radius: 5; color: root.cCard; border.width: 1; border.color: root.cLine; clip: true
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, (root.vTemp - 30) / 70))
                            height: 10; radius: 5; color: root.cHot
                            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                        }
                    }
                    Item {
                        width: parent.width; height: 14
                        Text { anchors.left: parent.left; text: "30°"; color: root.cDim; font.family: root.fMono; font.pixelSize: 9 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "65°"; color: root.cDim; font.family: root.fMono; font.pixelSize: 9 }
                        Text { anchors.right: parent.right; text: "100°"; color: root.cDim; font.family: root.fMono; font.pixelSize: 9 }
                    }
                }

                Column {
                    visible: detailCol.kind === "net" || detailCol.kind === "disk"
                    width: parent.width; spacing: 6
                    SparkChart {
                        width: parent.width; height: 82
                        values: (detailCol.d && detailCol.d.io) ? detailCol.d.io.down : []
                        values2: (detailCol.d && detailCol.d.io) ? detailCol.d.io.up : []
                        autoScale: true
                        lineColor: detailCol.acc
                        lineColor2: root.cGold
                    }
                    Row {
                        spacing: 14
                        Text { text: "— " + ((detailCol.d && detailCol.d.legend) ? detailCol.d.legend[1] : ""); color: detailCol.acc; font.family: root.fMono; font.pixelSize: 10 }
                        Text { text: "— " + ((detailCol.d && detailCol.d.legend) ? detailCol.d.legend[0] : ""); color: root.cGold; font.family: root.fMono; font.pixelSize: 10 }
                    }
                }

                SparkChart {
                    visible: detailCol.kind === "app" || detailCol.kind === "group"
                    width: parent.width; height: 72
                    values: detailCol.d ? detailCol.d.hist : []
                    lineColor: detailCol.acc
                }

                Grid {
                    width: parent.width; columns: 2; rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: detailCol.d ? detailCol.d.facts : []
                        Column {
                            required property var modelData
                            width: (detailCol.width - 10) / 2; spacing: 2
                            Text { text: modelData.lbl.toUpperCase(); color: root.cDim; font.family: root.fMono; font.pixelSize: 9; font.letterSpacing: 1 }
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.val; color: root.cCream; font.family: root.fMono; font.pixelSize: 13; font.bold: true }
                        }
                    }
                }

                RankList { list: detailCol.d ? detailCol.d.list2 : null }
                RankList { list: detailCol.d ? detailCol.d.list : null }
            }
        }
    }

    component SparkChart: Rectangle {
        id: sc
        property var values: []
        property var values2: []
        property bool autoScale: false
        property color lineColor: root.cGold
        property color lineColor2: root.cCream
        radius: 8; color: root.cCard; border.width: 1; border.color: root.cLine
        onValuesChanged: scCanvas.requestPaint()
        onValues2Changed: scCanvas.requestPaint()

        Canvas {
            id: scCanvas
            anchors.fill: parent; anchors.margins: 8
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                const drawLine = (arr, col, fill) => {
                    if (!arr || arr.length < 2) return;
                    let mx = sc.autoScale ? Math.max(1, ...arr) : 100;
                    ctx.beginPath();
                    for (let i = 0; i < arr.length; i++) {
                        const x = (i / (arr.length - 1)) * w;
                        const y = h - Math.max(0, Math.min(1, arr[i] / mx)) * h;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.strokeStyle = col;
                    ctx.lineWidth = 2;
                    ctx.stroke();
                    if (fill) {
                        ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
                        ctx.fillStyle = fill;
                        ctx.fill();
                    }
                };
                drawLine(sc.values, sc.lineColor, Qt.rgba(sc.lineColor.r, sc.lineColor.g, sc.lineColor.b, 0.14));
                if (sc.values2 && sc.values2.length > 1) drawLine(sc.values2, sc.lineColor2, "");
            }
        }
    }

    component RankList: Column {
        id: rl
        property var list: null
        visible: !!list && list.rows && list.rows.length > 0
        width: parent.width; spacing: 6
        Rectangle { width: parent.width; height: 1; color: root.cLine }
        Text { text: rl.list ? rl.list.title : ""; color: root.cGold; font.family: root.fMono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5 }
        Repeater {
            model: (rl.list && rl.list.rows) ? rl.list.rows : []
            Rectangle {
                id: rRow
                required property var modelData
                readonly property bool clickable: !!modelData.id
                width: rl.width; height: 26; radius: 6
                color: (clickable && rMa.containsMouse) ? "#1FD4AF37" : "transparent"
                Text {
                    x: 4; width: modelData.frac !== undefined ? parent.width * 0.42 : parent.width - 8
                    anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                    text: modelData.name || ""; color: root.cCream; font.family: root.fMono; font.pixelSize: 11
                }
                Rectangle {
                    visible: modelData.frac !== undefined
                    x: parent.width * 0.45; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * 0.28; height: 4; radius: 2; color: "#22D4AF37"
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, modelData.frac || 0)); height: 4; radius: 2; color: root.cGold }
                }
                Text {
                    visible: !!modelData.val
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.val || ""; color: root.cDim; font.family: root.fMono; font.pixelSize: 10
                }
                MouseArea {
                    id: rMa; anchors.fill: parent; enabled: rRow.clickable; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openById(rRow.modelData.id)
                }
            }
        }
    }
}
