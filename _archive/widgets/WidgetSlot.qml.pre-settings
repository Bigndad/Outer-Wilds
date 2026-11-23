import QtQuick
import ".."

// One widget orbiting a planet. It is a plain 2D item that this script places each frame by
// projecting a point on a 3D orbit (same projection as the planets), fading it by focus,
// occlusion (behind its planet) and the supernova. No Quickshell / Hyprland types in here.
Item {
    id: slot

    property var rig: null
    property var def: null
    property real speedScale: 1.0    // global orbit speed multiplier (set by WidgetLayer)

    property real angle: 0
    property real hold: 0           // 0..1: how paused the orbit is (hover / typing)
    property real presence: 0       // 0..1: shown by focus / "always"
    property real occlusion: 1      // 0..1: 0 while hidden behind its own planet
    property int missCount: 0
    property var hookedRig: null
    readonly property bool held: blocker.containsMouse || (loader.item !== null && loader.item.wantsHold === true)

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

        // orbit keeps turning even while hidden; hover / typing eases it to a stop
        hold += ((held ? 1 : 0) - hold) * Math.min(1, 6 * dt);
        angle += o.speed * speedScale * (1 - hold) * dt;

        const host = rg.bodyCoords[slot.def.host];
        const proj = rg.projectedMap[slot.def.host];
        const hostOk = !!(host && proj && proj.visible);
        if (!host || !proj) {
            if (++missCount === 180)
                console.warn("WidgetSlot " + slot.def.id + ": host '" + slot.def.host + "' not in rig.bodyCoords / projectedMap");
        }

        let target = 0;
        if (hostOk) {
            if (slot.def.show === "always") target = 1;
            else target = Math.max(rg.activeFocusId === slot.def.host ? 1 : 0, clamp((proj.screenR - 150) / 90, 0, 1));
        }
        presence += (target - presence) * Math.min(1, 7 * dt);

        // the red giant swallows everything just before the supernova; back after the reset
        const nova = rg.loopTime < 1284 ? 1.0 : clamp((1290 - rg.loopTime) / 6, 0, 1);
        if (!hostOk || presence < 0.004 || nova <= 0) { slot.visible = false; return; }

        const hostR = slot.def.host === "sun" ? rg.sunRadius : host.r;
        const R = hostR * o.k + o.add;
        const ca = Math.cos(angle), sa = Math.sin(angle);
        // circle in its plane, tilted about X, then the whole plane turned about Y by `node`
        // (node = 0 is the old behaviour), so several widgets on one planet can use different axes
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

        // fully off-screen (or flung out by the projection near the camera): skip all the work below
        const mx = slot.width * 0.5 + 40, my = slot.height * 0.5 + 40;
        if (p.sx < -mx || p.sx > w + mx || p.sy < -my || p.sy > h + my) { slot.visible = false; return; }

        // size: world width -> pixels, clamped, quantised so text stays crisp; the rest is a tiny scale
        const sc = Math.min(w, h) / 1080;
        const worldW = slot.def.worldWk !== undefined ? slot.def.worldWk * hostR : slot.def.worldW;
        const raw = p.scale * worldW / item.designW;
        const minUi = (slot.def.minUi !== undefined ? slot.def.minUi : 0.4) * sc;
        const maxUi = (slot.def.maxUi !== undefined ? slot.def.maxUi : 1.5) * sc;
        const uiRaw = clamp(raw, minUi, maxUi);
        const q = Math.max(0.2, Math.round(uiRaw * 24) / 24);
        if (item.ui !== q) item.ui = q;
        slot.scale = uiRaw / q;

        // behind its planet -> fade out
        let occ = 1;
        if (p.depth > proj.depth) {
            const dist = Math.hypot(p.sx - proj.sx, p.sy - proj.sy);
            occ = sstep(proj.screenR * 0.85, proj.screenR * 1.1 + slot.width * 0.15, dist);
        }
        occlusion += (occ - occlusion) * Math.min(1, 12 * dt);

        const op = presence * occlusion * nova;
        slot.opacity = op;
        slot.visible = op > 0.01;
        slot.x = p.sx - slot.width * 0.5;
        slot.y = p.sy - slot.height * 0.5;
        slot.z = -p.depth;
    }

    // (re)connects to the rig's frame signal whenever slot.rig changes, so creation order never matters
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

    // swallows mouse so clicking / dragging a widget never turns the camera or clears the lock
    MouseArea {
        id: blocker
        anchors.fill: parent
        enabled: slot.opacity > 0.35
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => { wheel.accepted = true; }
        // A double-click on a bare part of a card (anything the card's own controls don't use) still flies in
        // to the planet that is behind the cursor, so widgets never block that gesture.
        onDoubleClicked: (mouse) => {
            if (mouse.button !== Qt.LeftButton || !slot.rig || typeof slot.rig.flyInAt !== "function") return;
            const p = blocker.mapToItem(slot.rig, mouse.x, mouse.y);
            slot.rig.flyInAt(p.x, p.y);
        }
    }

    Loader {
        id: loader
        source: slot.def ? Qt.resolvedUrl(slot.def.kind === "noctalia" ? "NoctaliaPlugin.qml" : slot.def.source) : ""
        onLoaded: {
            item.rig = slot.rig;
            if (slot.def.title !== undefined && item.title !== undefined) item.title = slot.def.title;
            if (slot.def.kind === "noctalia") {
                item.pluginId = slot.def.id;
                item.pluginDir = slot.def.dir;
                if (slot.def.entry) item.entry = slot.def.entry;
                if (slot.def.settings) item.pluginSettings = slot.def.settings;
            }
        }
    }
}
