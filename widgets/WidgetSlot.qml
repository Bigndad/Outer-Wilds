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

    function tick() {
        const rg = slot.rig;
        const item = loader.item;
        if (!item || !rg || !slot.def || !rg.active) { slot.visible = false; return; }

        const dt = (rg.lastDt > 0) ? Math.min(rg.lastDt, 0.1) : 1 / 60;
        const o = slot.def.orbit;

        hold += ((held ? 1 : 0) - hold) * Math.min(1, 6 * dt);
        angle += o.speed * speedScale * (1 - hold) * dt;

        const host = rg.bodyCoords[slot.def.host];
        const proj = rg.projectedMap[slot.def.host];
        const hostOk = !!(host && proj && proj.visible);
        if (!host || !proj) {
            if (++missCount === 180)
                console.warn("WidgetSlot " + slot.def.id + ": host '" + slot.def.host + "' not in rig.bodyCoords / projectedMap");
        }

        const pinned = WidgetConfig.pinnedIds[slot.def.id] === true;
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

        const nova = rg.loopTime < 1284 ? 1.0 : clamp((1290 - rg.loopTime) / 6, 0, 1);
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

        const mx = slot.width * 0.5 + 40, my = slot.height * 0.5 + 40;
        if (p.sx < -mx || p.sx > w + mx || p.sy < -my || p.sy > h + my) { slot.visible = false; return; }

        const sc = Math.min(w, h) / 1080;
        const worldW = slot.def.worldWk !== undefined ? slot.def.worldWk * hostR : slot.def.worldW * rf;
        const raw = p.scale * worldW / item.designW;
        const farK = WidgetConfig.shrinkFar ? 0.4 : 1.0;
        const minUi = (slot.def.minUi !== undefined ? slot.def.minUi : 0.4) * sc * farK;
        const maxUi = (slot.def.maxUi !== undefined ? slot.def.maxUi : 1.5) * sc;
        const uiRaw = clamp(raw, minUi, maxUi);
        const q = Math.max(0.2, Math.round(uiRaw * 24) / 24);
        if (item.ui !== q) item.ui = q;
        slot.scale = (uiRaw / q) * slot.pinMultScale;

        let occ = 1;
        if (p.depth > proj.depth) {
            const dist = Math.hypot(p.sx - proj.sx, p.sy - proj.sy);
            occ = sstep(proj.screenR * 0.85, proj.screenR * 1.1 + slot.width * 0.15, dist);
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
            if (slot.def) WidgetConfig.togglePin(slot.def.id);
        }
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
                globalAccent: WidgetConfig.widgetAccent
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

    // Pinned highlight outline (matches circular or rounded card shape)
    Rectangle {
        z: 99
        anchors.fill: parent
        anchors.margins: -3
        radius: slot.outlineRadius
        antialiasing: true
        color: "transparent"
        border.width: 2
        border.color: WidgetConfig.pinOutlineColor
        opacity: slot.isPinned ? 0.95 : 0.0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
}
