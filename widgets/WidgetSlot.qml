import QtQuick
import ".."

// One widget orbiting a planet. Projects a point on a 3D orbit, fades by focus / occlusion /
// supernova / pinning, and forwards cfg & cardStyle live. No Quickshell / Hyprland types in here.
Item {
    id: slot

    property var rig: null
    property var def: null
    property real speedScale: 1.0

    property real angle: 0
    property real hold: 0
    property real presence: 0
    property real occlusion: 1
    property int missCount: 0
    property var hookedRig: null
    readonly property bool isPinned: slot.def ? WidgetConfig.isPinned(slot.def.id) : false
    readonly property bool isPinLocked: slot.def ? WidgetConfig.isPinLocked(slot.def.id) : false
    readonly property string orbitKind: slot.def ? WidgetConfig.progressKind(slot.def.source) : ""
    readonly property bool hasCustomProgress: loader.item !== null && typeof loader.item.progress === "number"
    readonly property bool hasPinOrbit: orbitKind !== "" || hasCustomProgress
    readonly property bool pinOrbitOn: slot.def ? WidgetConfig.pinOrbitEnabled(slot.def.id) : false
    readonly property bool showPinOrbit: isPinned && hasPinOrbit && pinOrbitOn
    property real orbitProgress: 0
    property real _paintedProg: -1
    property string orbitReadout: ""
    property real orbitHighlight: slotHover.hovered ? 1.0 : 0.0
    Behavior on orbitHighlight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    onOrbitHighlightChanged: if (showPinOrbit) pinOrbitCanvas.requestPaint()
    onShowPinOrbitChanged: if (showPinOrbit) { _paintedProg = -1; pinOrbitCanvas.requestPaint(); }
    onIsPinLockedChanged: if (showPinOrbit) pinOrbitCanvas.requestPaint()
    property real pinMultScale: isPinned ? WidgetConfig.pinScale : 1.0
    Behavior on pinMultScale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property bool isCircular: {
        const it = loader.item;
        if (it && (it.round === true || it.isRound === true)) return true;
        const src = slot.def ? String(slot.def.source || "") : "";
        return /(SunClock|AshTwinBattery|DarkBrambleDisc|QuantumMoonWeather|ImageRound|SunStationCpu|HollowsLanternTemp)\.qml$/.test(src);
    }
    readonly property real outlineRadius: {
        if (isCircular) return Math.min(width + 6, height + 6) / 2;
        const it = loader.item;
        const ui = (it && it.ui > 0) ? it.ui : 1.0;
        if (slot.def && slot.def.cardRadius >= 0) return slot.def.cardRadius * ui + 3;
        const src = slot.def ? String(slot.def.source || "") : "";
        if (src.startsWith("glyph/")) return 28 * ui + 3;
        if (src.startsWith("serp/")) return WidgetConfig.serpRadius * ui + 3;
        return WidgetConfig.widgetRadius * ui + 3;
    }
    readonly property bool held: (WidgetConfig.widgetHoldOnHover && (!slot.def || slot.def.holdOnHover !== false) && blocker.containsMouse) || (loader.item !== null && loader.item.wantsHold === true)

    width: loader.item ? loader.item.width : 0
    height: loader.item ? loader.item.height : 0
    transformOrigin: Item.Center
    visible: false
    opacity: 0

    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
    function sstep(a, b, x) {
        let t = clamp((x - a) / (b - a), 0, 1);
        return t * t * (3 - 2 * t);
    }

    function _fmtSec(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60), r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function computeOrbitData() {
        const item = loader.item;
        if (item && typeof item.progress === "number" && isFinite(item.progress)) {
            const v = clamp(item.progress, 0, 1);
            const lbl = (typeof item.progressLabel === "string" && item.progressLabel !== "") ? item.progressLabel : (Math.round(v * 100) + "%");
            return { v: v, label: lbl };
        }
        const k = slot.orbitKind;
        const bus = WidgetConfig.progressBus;
        if (k === "loop") {
            const lt = slot.rig ? slot.rig.loopTime : 0;
            const tot = slot.rig ? Math.max(1, slot.rig.maxLoopTime) : 1320;
            return { v: clamp(lt / tot, 0, 1), label: _fmtSec(Math.max(0, 1290 - lt)) };
        }
        if (k === "clock") {
            const now = new Date();
            const sec = now.getSeconds() + now.getMilliseconds() / 1000;
            return { v: sec / 60, label: Qt.formatTime(now, "HH:mm:ss") };
        }
        if (k === "date") {
            const now = new Date();
            const dim = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
            return { v: clamp(now.getDate() / Math.max(1, dim), 0, 1), label: "DAY " + now.getDate() + "/" + dim };
        }
        if (k === "rumor") {
            const tot = RumorData.notifications.length;
            const u = RumorData.unreadCount;
            return { v: tot > 0 ? clamp(u / tot, 0, 1) : 0, label: u + " UNREAD" };
        }
        if (k === "media") {
            if (WidgetConfig.mediaLen > 0) {
                const unit = WidgetConfig.mediaLen > 100000 ? 1e6 : 1;
                const dtS = WidgetConfig.mediaPlaying ? (Date.now() - WidgetConfig.mediaStamp) / 1000 : 0;
                const pos = Math.min(WidgetConfig.mediaLen, WidgetConfig.mediaPos + dtS * unit);
                return { v: clamp(pos / WidgetConfig.mediaLen, 0, 1), label: _fmtSec(pos / unit) + " / " + _fmtSec(WidgetConfig.mediaLen / unit) };
            }
            const chs = SignalscopeData.channels || [];
            for (let i = 0; i < chs.length; i++) {
                if (chs[i].playing) {
                    const vol = clamp(Number(chs[i].volume) || 0, 0, 1);
                    return { v: vol, label: "VOL " + Math.round(vol * 100) + "%" };
                }
            }
            return { v: 0, label: "IDLE" };
        }
        if (k === "cpu") { const v = bus.cpu !== undefined ? bus.cpu : HudData.cpu; return { v: clamp(v, 0, 1), label: "CPU " + Math.round(v * 100) + "%" }; }
        if (k === "ram") { const v = bus.ram !== undefined ? bus.ram : HudData.ram; return { v: clamp(v, 0, 1), label: "RAM " + Math.round(v * 100) + "%" }; }
        if (k === "gpu") { const v = bus.gpu !== undefined ? bus.gpu : HudData.battery; return { v: clamp(v, 0, 1), label: "GPU " + Math.round(v * 100) + "%" }; }
        if (k === "disk") {
            const idx = (slot.def && slot.def.cfg && slot.def.cfg.diskIndex !== undefined) ? Math.round(slot.def.cfg.diskIndex) : 0;
            const v = bus["disk" + idx] !== undefined ? bus["disk" + idx] : (bus.disk0 !== undefined ? bus.disk0 : 0);
            return { v: clamp(v, 0, 1), label: "DISK " + Math.round(v * 100) + "%" };
        }
        if (k === "temp") { const v = bus.temp !== undefined ? bus.temp : 0; return { v: clamp(v, 0, 1), label: "TEMP " + Math.round(25 + v * 70) + "°C" }; }
        if (k === "battery") { const v = bus.battery !== undefined ? bus.battery : 0; return { v: clamp(v, 0, 1), label: "BAT " + Math.round(v * 100) + "%" }; }
        if (k === "volume") { const v = bus.volume !== undefined ? bus.volume : 0; return { v: clamp(v, 0, 1), label: "VOL " + Math.round(v * 100) + "%" }; }
        if (k === "pomo") { const v = bus.pomo !== undefined ? bus.pomo : 0; return { v: clamp(v, 0, 1), label: "FOCUS " + Math.round(v * 100) + "%" }; }
        if (k === "timer") { const v = bus.timer !== undefined ? bus.timer : 0; return { v: clamp(v, 0, 1), label: "TIMER " + Math.round(v * 100) + "%" }; }
        if (k === "stopwatch") { const v = bus.stopwatch !== undefined ? bus.stopwatch : 0; return { v: clamp(v, 0, 1), label: Math.round(v * 60) + "s" }; }
        return { v: 0, label: "" };
    }

    function updateOrbitProgress(dt) {
        if (!slot.showPinOrbit) return;
        const d = computeOrbitData();
        const target = d.v;
        if (Math.abs(target - slot.orbitProgress) > 0.5) slot.orbitProgress = target;
        else slot.orbitProgress += (target - slot.orbitProgress) * Math.min(1, 10 * dt);
        if (slot.orbitReadout !== d.label) slot.orbitReadout = d.label;
        if (Math.abs(slot.orbitProgress - slot._paintedProg) > 0.0015) {
            slot._paintedProg = slot.orbitProgress;
            pinOrbitCanvas.requestPaint();
        }
    }

    function tick() {
        const rg = slot.rig;
        const item = loader.item;
        if (!item || !rg || !slot.def || !rg.active) { slot.visible = false; return; }

        const dt = (rg.lastDt > 0) ? Math.min(rg.lastDt, 0.1) : 1 / 60;
        const o = slot.def.orbit;
        const pinned = WidgetConfig.pinnedIds[slot.def.id] === true;
        const lockEntry = pinned ? WidgetConfig.lockedPins[slot.def.id] : undefined;
        const locked = lockEntry !== undefined && lockEntry !== false && lockEntry !== null;
        const nova = rg.loopTime < 1284 ? 1.0 : clamp((1290 - rg.loopTime) / 6, 0, 1);

        updateOrbitProgress(dt);

        // Stage-2 locked pin: freezes orbit in 3D space (still projects normally, so turning away hides it)
        if (locked) {
            if (typeof lockEntry === "object" && isFinite(lockEntry.angle)) angle = lockEntry.angle;
            else WidgetConfig.updatePinLockAngle(slot.def.id, angle);
        } else {
            hold += ((held ? 1 : 0) - hold) * Math.min(1, 6 * dt);
            angle += o.speed * speedScale * (1 - hold) * dt;
        }

        const host = rg.bodyCoords[slot.def.host];
        const proj = rg.projectedMap[slot.def.host];
        const hostOk = !!host && (locked || !!(proj && proj.visible));
        if (!host || !proj) {
            if (++missCount === 180)
                console.warn("WidgetSlot " + slot.def.id + ": host '" + slot.def.host + "' not in rig.bodyCoords / projectedMap");
        }
        const shouldDim = WidgetConfig.pinDimEnabled && !pinned && (
            WidgetConfig.pinDimScope === "everywhere"
                ? WidgetConfig.pinnedCount > 0
                : WidgetConfig.pinnedHosts[slot.def.host] === true
        );

        let target = 0;
        if (hostOk) {
            if (pinned || slot.def.show === "always" || WidgetConfig.previewId === slot.def.id) target = 1;
            else target = Math.max(rg.activeFocusId === slot.def.host ? 1 : 0, clamp((proj.screenR - 150) / 90, 0, 1));
        }
        presence += (target - presence) * Math.min(1, 7 * dt);

        if (!hostOk || presence < 0.004 || nova <= 0) { slot.visible = false; return; }

        const hostR = slot.def.host === "sun" ? rg.sunRadius : host.r;
        let rf = 1;
        if (slot.def.baseHost && slot.def.baseHost !== slot.def.host) {
            const bb = rg.bodyCoords[slot.def.baseHost];
            const bR = slot.def.baseHost === "sun" ? rg.sunRadius : (bb ? bb.r : 0);
            if (bR > 0) rf = Math.sqrt(hostR / bR);
        }
        const R = hostR * o.k + o.add * rf;
        const ca = Math.cos(angle), sa = Math.sin(angle);
        const tx = R * ca;
        const ty = R * sa * Math.sin(o.tilt);
        const tz = R * sa * Math.cos(o.tilt);
        const nd = o.node || 0;
        const cn = Math.cos(nd), sn = Math.sin(nd);
        const wx = host.x + tx * cn + tz * sn;
        const wy = host.y + ty;
        const wz = host.z - tx * sn + tz * cn;

        const w = rg.width, h = rg.height;
        const fov = Math.min(w, h) * 0.95;
        const p = rg.project3D(wx, wy, wz, w * 0.5, h * 0.5, fov);
        if (!p) { slot.visible = false; return; }

        const sc = Math.min(w, h) / 1080;
        const worldW = slot.def.worldWk !== undefined ? slot.def.worldWk * hostR : slot.def.worldW * rf;
        const raw = p.scale * worldW / item.designW;
        const farK = WidgetConfig.shrinkFar ? 0.4 : 1.0;
        const minUi = (slot.def.minUi !== undefined ? slot.def.minUi : 0.4) * sc * farK;
        const maxUi = (slot.def.maxUi !== undefined ? slot.def.maxUi : 1.5) * sc;
        const uiRaw = clamp(raw, minUi, maxUi);
        const minQ = (item.minLayoutUi !== undefined) ? item.minLayoutUi : 0.2;
        const q = Math.max(minQ, Math.round(uiRaw * 24) / 24);
        if (item.ui !== q) item.ui = q;
        slot.scale = (uiRaw / q) * slot.pinMultScale;

        const visW = slot.width * slot.scale, visH = slot.height * slot.scale;
        const mx = visW * 0.5 + 40, my = visH * 0.5 + 40;
        if (p.sx < -mx || p.sx > w + mx || p.sy < -my || p.sy > h + my) { slot.visible = false; return; }

        let occ = 1;
        if (proj && p.depth > proj.depth) {
            const dist = Math.hypot(p.sx - proj.sx, p.sy - proj.sy);
            occ = sstep(proj.screenR * 0.85, proj.screenR * 1.1 + visW * 0.15, dist);
        }
        occlusion += (occ - occlusion) * Math.min(1, 12 * dt);

        const pinMult = shouldDim ? WidgetConfig.pinDimOpacity : 1.0;
        const userOp = (slot.def && slot.def.opacity !== undefined ? slot.def.opacity : 1.0) * WidgetConfig.widgetOpacity;
        const op = presence * occlusion * nova * userOp * pinMult;
        slot.opacity = op;
        slot.visible = op > 0.01;
        slot.x = p.sx - slot.width * 0.5;
        slot.y = p.sy - slot.height * 0.5;
        slot.z = -p.depth;
    }

    function hook() {
        if (hookedRig === rig) return;
        if (hookedRig) hookedRig.frameUpdated.disconnect(slot.tick);
        hookedRig = rig;
        if (rig) rig.frameUpdated.connect(slot.tick);
    }
    onRigChanged: hook()
    Component.onCompleted: {
        if (def) angle = def.orbit.phase;
        hook();
    }
    Component.onDestruction: { if (hookedRig) hookedRig.frameUpdated.disconnect(slot.tick); }

    // Swallows mouse on bare card areas; double-click toggles pin, Alt+click passes fly-in through.
    MouseArea {
        id: blocker
        anchors.fill: parent
        enabled: slot.opacity > 0.12
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => { wheel.accepted = true; }
        onClicked: (mouse) => {
            if (WidgetConfig.widgetTyping) {
                WidgetConfig.clearWidgetTyping();
                if (slot.rig) slot.rig.forceActiveFocus();
                return;
            }
            if (mouse.button === Qt.LeftButton && (mouse.modifiers & Qt.AltModifier)) {
                if (slot.rig && typeof slot.rig.flyInAt === "function") {
                    const p = blocker.mapToItem(slot.rig, mouse.x, mouse.y);
                    slot.rig.flyInAt(p.x, p.y);
                }
            } else if (mouse.button === Qt.RightButton && slot.rig && slot.rig.lockedPlanetId === "" && slot.rig.targetedPlanetId !== "") {
                slot.rig.flyTo(slot.rig.targetedPlanetId);
            }
        }
        onDoubleClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || (mouse.modifiers & Qt.AltModifier)) return;
            if (!slot.def) return;
            if (WidgetConfig.tabHeld) {
                WidgetConfig.tabHeld = false;
                if (slot.isPinned) WidgetConfig.togglePinLock(slot.def.id, { angle: slot.angle });
            } else {
                WidgetConfig.togglePin(slot.def.id);
            }
        }
    }

    // Passive hover observer across the entire widget subtree (never intercepts clicks)
    HoverHandler {
        id: slotHover
        target: slot
    }

    // Alt+click anywhere on the widget (even over clickable widgets) passes fly-in through to the planet behind it.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        acceptedModifiers: Qt.AltModifier
        onTapped: (eventPoint) => {
            if (!slot.rig || typeof slot.rig.flyInAt !== "function") return;
            const p = slot.mapToItem(slot.rig, eventPoint.position.x, eventPoint.position.y);
            slot.rig.flyInAt(p.x, p.y);
        }
    }

    function pushCfg() {
        if (!loader.item || !slot.def) return;
        if (loader.item.cfg !== undefined && slot.def.cfg) loader.item.cfg = slot.def.cfg;
        if (loader.item.cardStyle !== undefined) {
            loader.item.cardStyle = {
                bg: slot.def.cardBg || "",
                accent: slot.def.cardAccent || "",
                border: slot.def.cardBorder || "",
                radius: slot.def.cardRadius !== undefined ? slot.def.cardRadius : -1,
                brackets: (slot.def.showBrackets !== false) && WidgetConfig.widgetBrackets,
                title: slot.def.customTitle || "",
                globalRadius: WidgetConfig.widgetRadius,
                globalAccent: WidgetConfig.widgetAccent,
                host: slot.def.host || "",
                cfg: slot.def.cfg || ({})
            };
        }
    }
    onDefChanged: pushCfg()
    Connections {
        target: WidgetConfig
        function onRevisionChanged() { slot.pushCfg(); }
    }

    Loader {
        id: loader
        source: slot.def ? Qt.resolvedUrl(slot.def.kind === "noctalia" ? "NoctaliaPlugin.qml" : slot.def.source) : ""
        onLoaded: {
            item.rig = slot.rig;
            slot.pushCfg();
            if (slot.def.title !== undefined && item.title !== undefined) item.title = slot.def.title;
            if (slot.def.kind === "noctalia") {
                item.pluginId = slot.def.id;
                item.pluginDir = slot.def.dir;
                if (slot.def.entry) item.entry = slot.def.entry;
                if (slot.def.settings) item.pluginSettings = slot.def.settings;
            }
        }
    }

    // Primary pin outline (Stage 1 = gold, Stage 2 locked = cyan)
    Rectangle {
        z: 99
        anchors.fill: parent
        anchors.margins: -3
        radius: slot.outlineRadius
        antialiasing: true
        color: "transparent"
        border.width: slot.isPinLocked ? 2.5 : 2
        border.color: slot.isPinLocked ? WidgetConfig.pinLockOutlineColor : WidgetConfig.pinOutlineColor
        opacity: (slot.isPinned && !slot.showPinOrbit) ? 0.96 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
    }

    // Stage-2 locked anchor pips (4 corners on cards, left/right wing ticks on circular widgets)
    Repeater {
        model: slot.isPinLocked ? (slot.isCircular ? 2 : 4) : 0
        delegate: Rectangle {
            required property int index
            z: 100
            width: slot.isCircular ? 8 : 6
            height: slot.isCircular ? 2 : 6
            radius: slot.isCircular ? 1 : 2
            color: WidgetConfig.pinLockOutlineColor
            x: slot.isCircular
                ? (index === 0 ? -11 : slot.width + 3)
                : ((index === 0 || index === 2) ? -6 : slot.width)
            y: slot.isCircular
                ? (slot.height - height) * 0.5
                : ((index === 0 || index === 1) ? -6 : slot.height)
        }
    }

    // Stage-2 locked indicator pill
    Rectangle {
        z: 101
        visible: opacity > 0.01
        opacity: slot.isPinLocked ? 0.95 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: -15
        width: lockLbl.implicitWidth + 12
        height: 16
        radius: 4
        color: "#F0070911"
        border.width: 1
        border.color: WidgetConfig.pinLockOutlineColor
        Text {
            id: lockLbl
            anchors.centerIn: parent
            text: "❖ LOCKED"
            color: WidgetConfig.pinLockOutlineColor
            font.family: "monospace"
            font.bold: true
            font.pixelSize: 8
            font.letterSpacing: 1
        }
    }

    // Pinned widget orbital progress ring (highlights when cursor hovers over the widget)
    Canvas {
        id: pinOrbitCanvas
        z: 102
        visible: slot.showPinOrbit
        anchors.fill: parent
        anchors.margins: -14
        onWidthChanged: if (visible) requestPaint()
        onHeightChanged: if (visible) requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Connections {
            target: WidgetConfig
            function onPinOutlineColorChanged() { if (pinOrbitCanvas.visible) pinOrbitCanvas.requestPaint(); }
            function onPinLockOutlineColorChanged() { if (pinOrbitCanvas.visible) pinOrbitCanvas.requestPaint(); }
        }

        function tracePerim(ctx, x0, y0, ow, oh, r, dist) {
            let rem = Math.max(0, dist);
            const lht = Math.max(0, ow * 0.5 - r);
            const lh  = Math.max(0, ow - 2 * r);
            const lv  = Math.max(0, oh - 2 * r);
            const la  = r * Math.PI * 0.5;
            let ex = x0 + ow * 0.5, ey = y0;
            ctx.beginPath();
            ctx.moveTo(ex, ey);
            function stepLine(nx, ny, seg) {
                if (seg <= 1e-6 || rem <= 0) return;
                const tk = Math.min(rem, seg), f = tk / seg;
                ex += (nx - ex) * f; ey += (ny - ey) * f;
                ctx.lineTo(ex, ey); rem -= tk;
            }
            function stepArc(cx, cy, a0, a1, seg) {
                if (seg <= 1e-6 || rem <= 0) return;
                const tk = Math.min(rem, seg), f = tk / seg;
                const ae = a0 + (a1 - a0) * f;
                ctx.arc(cx, cy, r, a0, ae, false);
                ex = cx + Math.cos(ae) * r; ey = cy + Math.sin(ae) * r;
                rem -= tk;
            }
            stepLine(x0 + ow - r, y0, lht);
            stepArc(x0 + ow - r, y0 + r, -Math.PI * 0.5, 0, la);
            stepLine(x0 + ow, y0 + oh - r, lv);
            stepArc(x0 + ow - r, y0 + oh - r, 0, Math.PI * 0.5, la);
            stepLine(x0 + r, y0 + oh, lh);
            stepArc(x0 + r, y0 + oh - r, Math.PI * 0.5, Math.PI, la);
            stepLine(x0, y0 + r, lv);
            stepArc(x0 + r, y0 + r, Math.PI, Math.PI * 1.5, la);
            stepLine(x0 + ow * 0.5, y0, lht);
            return { x: ex, y: ey };
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!slot.showPinOrbit || slot.width <= 4 || slot.height <= 4) return;

            const m = 14, pad = 4;
            const x0 = m - pad, y0 = m - pad;
            const ow = slot.width + pad * 2, oh = slot.height + pad * 2;
            const r = slot.isCircular
                ? Math.min(ow, oh) * 0.5
                : Math.max(4, Math.min(slot.outlineRadius + pad - 3, ow * 0.5, oh * 0.5));
            const perim = Math.max(1, 2 * Math.max(0, ow - 2 * r) + 2 * Math.max(0, oh - 2 * r) + 2 * Math.PI * r);
            const hl = slot.orbitHighlight;
            const prog = Math.max(0, Math.min(1, slot.orbitProgress));
            const col = Qt.color(slot.isPinLocked ? WidgetConfig.pinLockOutlineColor : WidgetConfig.pinOutlineColor);
            const rgba = (a) => "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a + ")";

            // 1. Clean base outline track
            ctx.save();
            ctx.strokeStyle = rgba(0.26 + 0.24 * hl);
            ctx.lineWidth = (slot.isPinLocked ? 2.2 : 1.8) + 0.4 * hl;
            tracePerim(ctx, x0, y0, ow, oh, r, perim);
            ctx.stroke();

            // 3. Progress arc (+ hover bloom glow)
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            let tip = { x: x0 + ow * 0.5, y: y0 };
            if (prog > 0.002) {
                if (hl > 0.01) {
                    ctx.strokeStyle = rgba(0.28 * hl);
                    ctx.lineWidth = 7.5;
                    tracePerim(ctx, x0, y0, ow, oh, r, perim * prog);
                    ctx.stroke();
                }
                ctx.strokeStyle = rgba(0.84 + 0.16 * hl);
                ctx.lineWidth = 2.2 + 1.4 * hl;
                tip = tracePerim(ctx, x0, y0, ow, oh, r, perim * prog);
                ctx.stroke();
            }

            // 4. Orbiting satellite dot at progress tip
            ctx.fillStyle = rgba(0.22 + 0.28 * hl);
            ctx.beginPath(); ctx.arc(tip.x, tip.y, 6.0 + 3.5 * hl, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = rgba(0.95);
            ctx.beginPath(); ctx.arc(tip.x, tip.y, 3.2 + 1.3 * hl, 0, Math.PI * 2); ctx.fill();
            ctx.fillStyle = "rgba(255,248,232," + (0.75 + 0.25 * hl) + ")";
            ctx.beginPath(); ctx.arc(tip.x, tip.y, 1.4 + 0.6 * hl, 0, Math.PI * 2); ctx.fill();
            ctx.restore();
        }
    }

    // Hover telemetry pill on the orbit bottom
    Rectangle {
        z: 103
        visible: slot.showPinOrbit && slot.orbitReadout !== "" && slot.orbitHighlight > 0.02
        opacity: slot.orbitHighlight
        anchors.horizontalCenter: parent.horizontalCenter
        y: slot.height + 6
        width: orbReadLbl.implicitWidth + 12
        height: 16
        radius: 4
        color: "#F0070911"
        border.width: 1
        border.color: slot.isPinLocked ? WidgetConfig.pinLockOutlineColor : WidgetConfig.pinOutlineColor
        Text {
            id: orbReadLbl
            anchors.centerIn: parent
            text: slot.orbitReadout
            color: slot.isPinLocked ? WidgetConfig.pinLockOutlineColor : WidgetConfig.pinOutlineColor
            font.family: "monospace"
            font.bold: true
            font.pixelSize: 8
            font.letterSpacing: 1
        }
    }
}
