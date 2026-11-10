import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root
    focus: true

    onActiveFocusChanged: {
        if (!activeFocus) {
            keysDown = ({});
            isInteracting = false;
        }
    }

    readonly property color colBg: "#07080C"
    readonly property color colGold: "#D4AF37"
    readonly property color colCream: "#E6D5B8"
    readonly property color colDimOrbit: "#2AD4AF37"
    readonly property color colLockBlue: "#4D82E0"

    // --- 22-MINUTE LOOP STATE ---
    property real loopTime: 0.0
    readonly property real maxLoopTime: 1320.0
    property real timeScale: 1.0
    property bool isInteracting: false
    signal frameUpdated()        // end of every frame: the orbiting widgets reposition on this
    property real lastDt: 0.016
    property bool active: NoctaliaBridge.desktopVisible   // stage 5: set false when fullscreen-occluded to stop all per-frame work
    readonly property string activeFocusId: lockedPlanetId !== "" ? lockedPlanetId : targetedPlanetId

    // last-painted state for the background canvas (it only repaints when something it shows changed)
    property real _pX: NaN
    property real _pY: NaN
    property real _pZ: NaN
    property real _pYaw: NaN
    property real _pPitch: NaN
    property real _pW: NaN
    property real _pH: NaN
    property string _pHl: ""

    readonly property real sunProgress: Math.min(1.0, loopTime / 1280.0)
    readonly property real sunRadius: {
        if (loopTime < 1280.0) return 280 + Math.pow(sunProgress, 3.5) * 400;
        if (loopTime < 1290.0) {
            let t = (loopTime - 1280.0) / 10.0;
            return 680 * (1.0 - t) + 28 * t;
        }
        return 28;
    }
    readonly property real swellRatio: Math.min(1.0, Math.max(0.0, (sunRadius - 280) / 400.0))
    readonly property real supernovaRadius: loopTime >= 1290.0 ? ((loopTime - 1290.0) / 30.0) * 8500.0 : 0.0
    readonly property real supernovaAlpha: loopTime >= 1290.0 ? Math.min(1.0, Math.max(0.0, 1.0 - ((loopTime - 1305.0) / 15.0))) : 0.0

    // --- 3D CAMERA & SHIP FLIGHT STATE ---
    property real camX: 0.0
    property real camY: 1690.0     // home view = old (0, 1300, 3200) * spaceScale
    property real camZ: 4160.0
    property real velX: 0.0
    property real velY: 0.0
    property real velZ: 0.0

    property real camYaw: 0.0
    property real camPitch: -0.38
    property real targetYaw: 0.0
    property real targetPitch: -0.38

    // Cached per-frame camera trig
    property real _cy: 1.0
    property real _sy: 0.0
    property real _cp: Math.cos(0.38)
    property real _sp: Math.sin(0.38)

    property string hoveredPlanetId: ""
    // pointer position, for the Signalscope (read-only views of the main MouseArea)
    readonly property real cursorX: mouseArea.mouseX
    readonly property real cursorY: mouseArea.mouseY
    readonly property bool cursorIn: mouseArea.containsMouse
    property string targetedPlanetId: ""
    property string lockedPlanetId: ""
    property real lockDist: 480.0
    property real targetLockDist: 480.0

    property var keysDown: ({})

    // --- SPACE DRIFT ---
    // Ctrl toggles drift off (= the old flight model: thrust, then the ship stops by itself).
    property bool spaceDrift: true
    readonly property real driftCruise: 80.0     // relaxed coasting speed in units/s (everything below scales with it)
    property var _dwell: ({})                    // seconds spent inside each planet's capture zone
    property real _driftGrace: 0.0               // after you thrust, the governor leaves your speed alone for a while
    // 0..1, "actively travelling": while you thrust (or scroll) the Sun keep-out, the outer wall and the vertical band
    // let go; when you stop they come back gently, so merely drifting can never carry you into them.
    property real _pushFree: 0.0
    // distance the camera settles at when you lock onto a planet (double-click / Alt+click): max(radius * K, MIN).
    // Was 4.2 / 220; bigger = a calmer, wider orbit. You can still scroll/W in closer.
    readonly property real lockOrbitK: 6.5
    readonly property real lockOrbitMin: 360.0

    Keys.onPressed: (event) => {
        if (event.isAutoRepeat) return;
        keysDown[event.key] = true;
        if (event.key === Qt.Key_Control) spaceDrift = !spaceDrift;
        if (event.key === Qt.Key_Escape) {
            lockedPlanetId = "";
            targetedPlanetId = "";
        }
    }
    Keys.onReleased: (event) => {
        if (event.isAutoRepeat) return;
        keysDown[event.key] = false;
    }

    // called by WidgetSlot when a double-click lands on dead card area, so widgets never block the fly-in
    function flyInAt(mx, my) { return mouseArea.engageAt(mx, my); }

    // fly to a planet and lock on (same as double-clicking it); used by NoctaliaBridge
    function flyTo(planetId) { mouseArea.engageAutopilot(planetId); }
    Connections {
        target: NoctaliaBridge
        function onPlanetRequested(planetId, panelId) { root.flyTo(planetId); }
    }

    function shortestYawTarget(currentYaw, desiredYaw) {
        let diff = desiredYaw - currentYaw;
        diff = Math.atan2(Math.sin(diff), Math.cos(diff));
        return currentYaw + diff;
    }

    // --- 3D STARFIELD, SPARSE VELOCITY DUST & PRE-BAKED ORBIT PATHS ---
    property var stars: []
    property var dustParticles: []
    property var bakedOrbits: []
    readonly property int dustCount: 24
    readonly property real dustBoxSize: 1500.0

    // Static metadata separated from per-frame coordinates to eliminate 72 binding updates/frame
    readonly property var bodyMeta: ({
        "sun":             { name: "The Sun",          role: "Clock / Loop",     color: "#FFAA22", accent: "#FF4500", bType: 0,  isSun: true },
        "sun_station":     { name: "Sun Station",      role: "System Power",          color: "#E6D5B8", accent: "#AA8844", bType: 1,  isSun: false },
        "ash_twin":        { name: "Ash Twin",         role: "Timer / Sand",          color: "#D2B48C", accent: "#8B7355", bType: 2,  isSun: false },
        "ember_twin":      { name: "Ember Twin",       role: "Audio / Media",         color: "#CD5C5C", accent: "#8B3A3A", bType: 3,  isSun: false },
        "timber_hearth":   { name: "Timber Hearth",    role: "Workspaces",            color: "#3B7A57", accent: "#2B4F81", bType: 4,  isSun: false },
        "attlerock":       { name: "Attlerock",        role: "Quick Notes",            color: "#9999A5", accent: "#666670", bType: 5,  isSun: false },
        "brittle_hollow":  { name: "Brittle Hollow",   role: "Memory / Disk",         color: "#483D8B", accent: "#FF6347", bType: 6,  isSun: false },
        "hollows_lantern": { name: "Hollow's Lantern", role: "CPU Temp",              color: "#4A2511", accent: "#FF4500", bType: 7,  isSun: false },
        "giants_deep":     { name: "Giant's Deep",     role: "Network / Tray",        color: "#1E6B52", accent: "#469A7E", bType: 8,  isSun: false },
        "dark_bramble":    { name: "Dark Bramble",     role: "App Launcher",          color: "#3A4B3C", accent: "#7A6855", bType: 9,  isSun: false },
        "interloper":      { name: "The Interloper",   role: "Notifications / Shots", color: "#88D8FF", accent: "#E0FFFF", bType: 10, isSun: false },
        "quantum_moon":    { name: "Quantum Moon",     role: "Quantum Satellite",     color: "#8B849C", accent: "#D1C7BD", bType: 11, isSun: false }
    })

    Component.onCompleted: {
        let s = [];
        for (let i = 0; i < 380; i++) {
            let u = Math.random() * 2 - 1;
            let theta = Math.random() * Math.PI * 2;
            let r = Math.sqrt(1 - u * u);
            let dist = 8500 + Math.random() * 4500;
            s.push({
                x: dist * r * Math.cos(theta),
                y: dist * u,
                z: dist * r * Math.sin(theta),
                size: 0.8 + Math.random() * 1.6,
                alpha: 0.25 + Math.random() * 0.7
            });
        }
        stars = s;

        let d = [];
        for (let j = 0; j < dustCount; j++) {
            d.push({
                x: (Math.random() - 0.5) * dustBoxSize,
                y: (Math.random() - 0.5) * dustBoxSize,
                z: (Math.random() - 0.5) * dustBoxSize,
                alpha: 0.15 + Math.random() * 0.3
            });
        }
        dustParticles = d;

        let orbList = [];
        for (let i = 0; i < planets.length; i++) {
            let pl = planets[i];
            let steps = pl.e > 0.4 ? 240 : 140;
            let pts = [];
            for (let st = 0; st <= steps; st++) {
                let E = (st / steps) * (Math.PI * 2);
                pts.push(calculateOrbitPathPoint(pl, E));
            }
            orbList.push({ id: pl.id, points: pts });
        }
        bakedOrbits = orbList;
    }

    // --- SYSTEM SCALE (tuning) ---
    readonly property real planetScale: 1.2     // planet / moon radius multiplier (Sun not included)
    readonly property real spaceScale: 1.3      // distance multiplier: orbit sizes, moon orbits, twin separation

    // --- KEPLERIAN ORBIT ENGINE ---
    // GM scales with spaceScale^3 so every planet keeps exactly the same angular speed as before
    readonly property real sysGM: 2400000.0 * spaceScale * spaceScale * spaceScale

    function solveKepler(M, e) {
        if (e < 0.0001) return M;
        let E = M;
        for (let i = 0; i < 4; i++) {
            let f = E - e * Math.sin(E) - M;
            let fPrime = 1.0 - e * Math.cos(E);
            E -= f / fPrime;
        }
        let sinNu = (Math.sqrt(1.0 - e * e) * Math.sin(E)) / (1.0 - e * Math.cos(E));
        let cosNu = (Math.cos(E) - e) / (1.0 - e * Math.cos(E));
        return Math.atan2(sinNu, cosNu);
    }
    
    function calculateOrbitPathPoint(pl, E) {
    let a = pl.a;
    let e = pl.e || 0.0;
    let w = pl.omega || 0.0;
    let inc = pl.inc || 0.0;
    let node = pl.node || 0.0;

    // Ellipse in orbital plane aligned to periapsis
    let xOrb = a * (Math.cos(E) - e);
    let zOrb = a * Math.sqrt(Math.max(0.0, 1.0 - e * e)) * Math.sin(E);

    // Rotate by argument of periapsis (omega)
    let cosW = Math.cos(w), sinW = Math.sin(w);
    let xp = xOrb * cosW - zOrb * sinW;
    let zp = xOrb * sinW + zOrb * cosW;

    // Apply inclination (inc)
    let y1 = -zp * Math.sin(inc);
    let z1 =  zp * Math.cos(inc);

    // Rotate by longitude of ascending node
    let cosN = Math.cos(node), sinN = Math.sin(node);
    let wx = xp * cosN - z1 * sinN;
    let wy = y1;
    let wz = xp * sinN + z1 * cosN;

    return { x: wx, y: wy, z: wz };
}
    
    

    function calculateKeplerianPoint(p, timeVal) {
        let n = Math.sqrt(sysGM / Math.pow(p.a, 3));
        let M = (timeVal * n * (p.timeMult || 1.0)) % (Math.PI * 2);
        let e = p.e || 0.0;
        let nu = solveKepler(M, e);

        let r = p.a * (1.0 - e * e) / (1.0 + e * Math.cos(nu));
        let w = p.omega || 0.0;
        let theta = nu + w;

        let xp = r * Math.cos(theta);
        let zp = r * Math.sin(theta);

        let inc = p.inc || 0.0;
        let node = p.node || 0.0;

        let y1 = -zp * Math.sin(inc);
        let z1 =  zp * Math.cos(inc);

        let wx = xp * Math.cos(node) - z1 * Math.sin(node);
        let wy = y1;
        let wz = xp * Math.sin(node) + z1 * Math.cos(node);

        return { x: wx, y: wy, z: wz };
    }

    // --- 3D PLANET REGISTRY ---
    property var bodyCoords: ({})
    readonly property var bodyKeys: [
        "sun", "sun_station", "ash_twin", "ember_twin",
        "timber_hearth", "attlerock", "brittle_hollow",
        "hollows_lantern", "giants_deep", "dark_bramble", "interloper", "quantum_moon"
    ]

    // Orbital speeds slowed down gently with timeMult: 0.45 so desktop observation is relaxed
    readonly property var planets: [
        { id: "sun_station", name: "Sun Station", a: 390 * spaceScale, e: 0.0, inc: 0.28, node: 0.35, omega: 0.0, timeMult: 0.45, radius: 18.0 * planetScale, bType: 1 },
        { id: "twins_bary", name: "Hourglass Twins", a: 780 * spaceScale, e: 0.015, inc: 0.06, node: 0.8, omega: 0.2, timeMult: 0.45, radius: 0, bType: 2, isBarycenter: true },
        { id: "timber_hearth", name: "Timber Hearth", a: 1350 * spaceScale, e: 0.01, inc: 0.0, node: 0.0, omega: 0.0, timeMult: 0.45, radius: 62 * planetScale, bType: 4 },
        { id: "brittle_hollow", name: "Brittle Hollow", a: 1980 * spaceScale, e: 0.035, inc: -0.12, node: 2.1, omega: 0.5, timeMult: 0.45, radius: 72 * planetScale, bType: 6 },
        { id: "giants_deep", name: "Giant's Deep", a: 2800 * spaceScale, e: 0.02, inc: 0.05, node: 1.2, omega: 1.0, timeMult: 0.45, radius: 135 * planetScale, bType: 8 },
        { id: "dark_bramble", name: "Dark Bramble", a: 3750 * spaceScale, e: 0.04, inc: -0.16, node: 4.1, omega: 2.4, timeMult: 0.45, radius: 108 * planetScale, bType: 9 },
        { id: "interloper", name: "The Interloper", a: 2280 * spaceScale, e: 0.80, inc: 0.44, node: 0.95, omega: 3.14, timeMult: 0.45, radius: 34.0 * planetScale, bType: 10, isComet: true }
    ]

    readonly property var qmHosts: ["timber_hearth", "brittle_hollow", "giants_deep", "dark_bramble"]
    property int qmHostIndex: 0
    property real qmAngle: 0.0
    property bool qmObserved: false

    function checkQuantumObserver() {
        let pQM = projectedMap["quantum_moon"];
        let isVis = pQM && pQM.visible && pQM.sx >= 0 && pQM.sx <= root.width && pQM.sy >= 0 && pQM.sy <= root.height;
        let isTracked = (root.lockedPlanetId === "quantum_moon" || root.targetedPlanetId === "quantum_moon" || root.hoveredPlanetId === "quantum_moon");

        if (isVis || isTracked) {
            root.qmObserved = true;
        } else if (root.qmObserved) {
            root.qmObserved = false;
            let offscreen = [];
            let others = [];
            for (let i = 0; i < qmHosts.length; i++) {
                if (i === root.qmHostIndex) continue;
                others.push(i);
                let hp = projectedMap[qmHosts[i]];
                let hb = bodyCoords[qmHosts[i]];
                let off = true;
                if (hp && hp.visible && hb) {
                    // margin = projected QM orbit radius + host size + slack, so the moon can't pop into view
                    let m = (hb.r * 2.3 + 75.0 * spaceScale) * hp.scale + hp.screenR + 40.0;
                    off = hp.sx < -m || hp.sx > root.width + m || hp.sy < -m || hp.sy > root.height + m;
                }
                if (off) offscreen.push(i);
            }
            let pool = offscreen.length > 0 ? offscreen : others;
            let nextIndex = pool[Math.floor(Math.random() * pool.length)];
            root.qmHostIndex = nextIndex;
            root.qmAngle = Math.random() * Math.PI * 2;
        }
    }

    function _smooth(a, b, x) {
        let t = Math.max(0.0, Math.min(1.0, (x - a) / (b - a)));
        return t * t * (3.0 - 2.0 * t);
    }

    // One step of drifting flight. Newtonian-ish: soft planet gravity (big capture orbits that fade after a
    // while, so you are never stuck), a soft keep-out around the Sun, a soft outer wall and a soft
    // vertical band, and a speed governor that keeps the ride relaxed.
    function driftStep(dt, ax, ay, az, thrusting, rightX, rightZ) {
        const c = root.driftCruise;
        const vMin = 0.6 * c, vMax = 1.8 * c, vHard = 3.5 * c;

        root.velX += ax * dt; root.velY += ay * dt; root.velZ += az * dt;
        if (thrusting) root._driftGrace = 1.5; else root._driftGrace = Math.max(0.0, root._driftGrace - dt);
        // active travel beats the barriers: they fade out fast while you thrust and return over ~1-2 s once you stop
        root._pushFree += ((thrusting ? 1.0 : 0.0) - root._pushFree) * Math.min(1.0, (thrusting ? 8.0 : 1.2) * dt);
        const bar = 1.0 - root._pushFree;

        // 1. planets
        let inWell = false;
        const dw = root._dwell;
        for (let k = 0; k < root.bodyKeys.length; k++) {
            const key = root.bodyKeys[k];
            if (key === "sun" || key === "quantum_moon") continue;
            const b = root.bodyCoords[key];
            if (!b || b.hidden) continue;
            const r = b.r;
            const dx = b.x - root.camX, dy = b.y - root.camY, dz = b.z - root.camZ;
            const d = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1.0;

            // capture fatigue: after ~1.2 orbits inside the capture zone the planet slowly lets go
            const period = 0.39 * r * 80.0 / c;
            let t = dw[key] || 0.0;
            if (d < 9.0 * r) t += dt; else t = Math.max(0.0, t - 0.6 * dt);
            dw[key] = t;
            const f = 1.0 - root._smooth(1.2 * period, 2.2 * period, t);

            if (d >= 18.0 * r) continue;
            const nx = dx / d, ny = dy / d, nz = dz / d;

            // gravity (softened), fading out between 10r and 18r
            const w = 1.0 - root._smooth(10.0 * r, 18.0 * r, d);
            const sft = 1.5 * r;
            const den = Math.pow(d * d + sft * sft, 1.5);
            const g = (7.0 * c * c * r) * w * f / den;
            root.velX += dx * g * dt; root.velY += dy * g * dt; root.velZ += dz * g * dt;

            // thin "dust" drag in a ring 5r..14r: bleeds energy so a slow pass can become a big orbit
            const drag = 0.03 * f * root._smooth(4.5 * r, 5.5 * r, d) * (1.0 - root._smooth(8.0 * r, 14.0 * r, d));
            if (drag > 0.0) {
                const sc = 1.0 - Math.min(0.5, drag * dt);
                root.velX *= sc; root.velY *= sc; root.velZ *= sc;
            }

            // soft keep-out so a close pass skims instead of crashing
            const keep = 2.5 * r;
            if (d < keep) {
                const push = (keep - d) * 8.0;
                root.velX -= nx * push * dt; root.velY -= ny * push * dt; root.velZ -= nz * push * dt;
                const vr = root.velX * nx + root.velY * ny + root.velZ * nz;
                if (vr > 0.0) {
                    const kd = Math.min(1.0, 6.0 * dt);
                    root.velX -= nx * vr * kd; root.velY -= ny * vr * kd; root.velZ -= nz * vr * kd;
                }
            }
            if (d < 12.0 * r && f > 0.3) inWell = true;
        }

        // 2. Sun keep-out: kills the inward speed progressively, so you slide around it
        const camDist = Math.sqrt(root.camX * root.camX + root.camY * root.camY + root.camZ * root.camZ) || 1.0;
        const sx = root.camX / camDist, sy = root.camY / camDist, sz = root.camZ / camDist;
        const sunKeep = Math.max(650.0, root.sunRadius * 1.15 + 200.0);
        const sunZone = 500.0;
        if (bar > 0.001 && camDist < sunKeep + sunZone) {
            const s = (sunKeep + sunZone - camDist) / sunZone;
            const vIn = root.velX * sx + root.velY * sy + root.velZ * sz;
            if (vIn < 0.0) {
                const kd = Math.min(1.0, (2.0 + 6.0 * s) * dt * bar);
                root.velX -= sx * vIn * kd; root.velY -= sy * vIn * kd; root.velZ -= sz * vIn * kd;
            }
            const aOut = 60.0 * s * s * bar;
            root.velX += sx * aOut * dt; root.velY += sy * aOut * dt; root.velZ += sz * aOut * dt;
        }

        // 3. outer wall (soft) and vertical band (soft): you stay inside the solar system
        const wallStart = 4900.0, wallZone = 700.0;
        if (bar > 0.001 && camDist > wallStart) {
            const s = Math.min(1.0, (camDist - wallStart) / wallZone);   // capped: coming back from far out stays gentle
            const vOut = root.velX * sx + root.velY * sy + root.velZ * sz;
            if (vOut > 0.0) {
                const kd = Math.min(1.0, (1.0 + 4.0 * s) * dt * bar);
                root.velX -= sx * vOut * kd; root.velY -= sy * vOut * kd; root.velZ -= sz * vOut * kd;
            }
            const aIn = 40.0 * s * s * bar;
            root.velX -= sx * aIn * dt; root.velY -= sy * aIn * dt; root.velZ -= sz * aIn * dt;
        }
        const ay0 = Math.abs(root.camY);
        if (bar > 0.001 && ay0 > 2200.0) {
            const s = Math.min(1.0, (ay0 - 2200.0) / 800.0);
            const dir = root.camY > 0 ? 1.0 : -1.0;
            if (root.velY * dir > 0.0) root.velY -= root.velY * Math.min(1.0, (1.0 + 4.0 * s) * dt * bar);
            root.velY -= dir * 40.0 * s * s * dt * bar;
        }

        // 4. speed governor (relaxed cruise); never fights you while you thrust, or inside a planet's well
        let speed = Math.sqrt(root.velX * root.velX + root.velY * root.velY + root.velZ * root.velZ);
        if (speed < 0.1) {
            root.velX = rightX * c; root.velY = 0.0; root.velZ = rightZ * c;
        } else {
            let scale = 1.0;
            if (speed > vHard) {
                scale = 1.0 - ((speed - vHard) / speed) * Math.min(1.0, 3.0 * dt);
            } else if (!thrusting && root._driftGrace <= 0.0 && !inWell) {
                if (speed < vMin) scale = 1.0 + ((c - speed) / speed) * Math.min(1.0, 0.5 * dt);
                else if (speed > vMax) scale = 1.0 - ((speed - vMax) / speed) * Math.min(1.0, 0.4 * dt);
            }
            root.velX *= scale; root.velY *= scale; root.velZ *= scale;
        }

        root.camX += root.velX * dt;
        root.camY += root.velY * dt;
        root.camZ += root.velZ * dt;

        // last-resort guards (should never trigger): never inside the Sun's keep-out core or inside a planet
        const nd = Math.sqrt(root.camX * root.camX + root.camY * root.camY + root.camZ * root.camZ) || 1.0;
        const core = Math.max(60.0, root.sunRadius * 1.12);      // you may fly right up to the Sun's surface, never into it
        if (nd < core) {
            const q = core / nd;
            root.camX *= q; root.camY *= q; root.camZ *= q;
            const vi = (root.velX * root.camX + root.velY * root.camY + root.velZ * root.camZ) / (core * core);
            if (vi < 0.0) { root.velX -= root.camX * vi; root.velY -= root.camY * vi; root.velZ -= root.camZ * vi; }
        }
        // hard limits so active travel can never lose you completely (far beyond the soft wall, and the vertical band)
        const hardR = 11000.0;
        if (nd > hardR) {
            const q = hardR / nd;
            root.camX *= q; root.camY *= q; root.camZ *= q;
            const vo = (root.velX * root.camX + root.velY * root.camY + root.velZ * root.camZ) / (hardR * hardR);
            if (vo > 0.0) { root.velX -= root.camX * vo; root.velY -= root.camY * vo; root.velZ -= root.camZ * vo; }
        }
        if (Math.abs(root.camY) > 5200.0) {
            root.camY = root.camY > 0 ? 5200.0 : -5200.0;
            if (root.velY * root.camY > 0.0) root.velY = 0.0;
        }
        for (let k = 0; k < root.bodyKeys.length; k++) {
            const key = root.bodyKeys[k];
            if (key === "sun") continue;
            const b = root.bodyCoords[key];
            if (!b || b.hidden) continue;
            const dx = root.camX - b.x, dy = root.camY - b.y, dz = root.camZ - b.z;
            const d = Math.sqrt(dx * dx + dy * dy + dz * dz) || 1.0;
            const minD = b.r * 1.3;
            if (d < minD) {
                const q = minD / d;
                root.camX = b.x + dx * q; root.camY = b.y + dy * q; root.camZ = b.z + dz * q;
            }
        }
    }

    function updateCameraTrig() {
        _cy = Math.cos(-camYaw);
        _sy = Math.sin(-camYaw);
        _cp = Math.cos(-camPitch);
        _sp = Math.sin(-camPitch);
    }

    function updateOrbits(dt) {
        let coords = {};
        let t = loopTime;

        coords["sun"] = { x: 0, y: 0, z: 0, r: root.sunRadius, bType: 0, isSun: true };

        for (let i = 0; i < planets.length; i++) {
            let p = planets[i];
            let pos = calculateKeplerianPoint(p, t);

            if (p.isBarycenter) {
                let binAngle = t * 0.12;
                let dx = 78 * spaceScale * Math.cos(binAngle);
                let dz = 78 * spaceScale * Math.sin(binAngle);
                coords["ash_twin"] = { x: pos.x + dx, y: pos.y, z: pos.z + dz, r: 35.0 * planetScale, bType: 2 };
                coords["ember_twin"] = { x: pos.x - dx, y: pos.y, z: pos.z - dz, r: 35.0 * planetScale, bType: 3 };
                coords["twins_bary"] = { x: pos.x, y: pos.y, z: pos.z, r: 84 * planetScale, hidden: true };
            } else {
                coords[p.id] = { x: pos.x, y: pos.y, z: pos.z, r: p.radius, bType: p.bType };

                if (p.id === "interloper") {
                    let posNext = calculateKeplerianPoint(p, t + 0.1);
                    let vx = posNext.x - pos.x;
                    let vy = posNext.y - pos.y;
                    let vz = posNext.z - pos.z;
                    let vLen = Math.hypot(vx, vy, vz) || 1.0;
                    coords["interloper"].vel3D = Qt.vector3d(vx / vLen, vy / vLen, vz / vLen);
                } else if (p.id === "timber_hearth") {
                    let mAngle = t * 0.05;
                    coords["attlerock"] = {
                        x: pos.x + 260 * spaceScale * Math.cos(mAngle),
                        y: pos.y + 80 * spaceScale * Math.sin(mAngle * 0.8),
                        z: pos.z + 260 * spaceScale * Math.sin(mAngle),
                        r: 20.0 * planetScale, bType: 5
                    };
                } else if (p.id === "brittle_hollow") {
                    let hlAngle = t * 0.06;
                    coords["hollows_lantern"] = {
                        x: pos.x + 300 * spaceScale * Math.cos(hlAngle),
                        y: pos.y + 70 * spaceScale * Math.cos(hlAngle * 0.7),
                        z: pos.z + 300 * spaceScale * Math.sin(hlAngle),
                        r: 22.0 * planetScale, bType: 7
                    };
                }
            }
        }

        root.qmAngle = (root.qmAngle + 0.22 * dt * root.timeScale) % (Math.PI * 2);
        let hostKey = qmHosts[root.qmHostIndex];
        let hp = coords[hostKey] || coords["timber_hearth"];
        let qmDist = hp.r * 2.3 + 75.0 * spaceScale;

        coords["quantum_moon"] = {
            x: hp.x + qmDist * Math.cos(root.qmAngle),
            y: hp.y + (qmDist * 0.45) * Math.sin(root.qmAngle * 0.7),
            z: hp.z + qmDist * Math.sin(root.qmAngle),
            r: 32.0 * planetScale,
            bType: 11
        };

        bodyCoords = coords;
    }

    function dirToViewSpace(wx, wy, wz, bTypeVal) {
        let x1 = wx * _cy + wz * _sy;
        let z1 = -wx * _sy + wz * _cy;

        let y2 = wy * _cp - z1 * _sp;
        let z2 = wy * _sp + z1 * _cp;

        let len = Math.hypot(x1, y2, z2) || 1.0;
        return Qt.vector4d(x1 / len, y2 / len, z2 / len, bTypeVal);
    }

    function project3D(wx, wy, wz, halfW, halfH, fov) {
        let dx = wx - camX;
        let dy = wy - camY;
        let dz = wz - camZ;

        let x1 = dx * _cy + dz * _sy;
        let z1 = -dx * _sy + dz * _cy;

        let y2 = dy * _cp - z1 * _sp;
        let z2 = dy * _sp + z1 * _cp;

        let depth = -z2;
        if (depth <= 2.0) return null;

        let scale = fov / depth;
        return {
            sx: halfW + x1 * scale,
            sy: halfH - y2 * scale,
            depth: depth,
            scale: scale
        };
    }

    property var projectedMap: ({})
    property var screenHitboxes: []

    FrameAnimation {
        running: root.active
        onTriggered: {
            let dt = Math.min(frameTime, 0.05);

            if (!(root.isInteracting && root.loopTime >= 1288.0)) {
                root.loopTime += dt * root.timeScale;
                if (root.loopTime >= root.maxLoopTime) root.loopTime = 0.0;
            }

            root.updateOrbits(dt);

            // Only auto-orient camera yaw/pitch when TARGETED (single-click centering),
            // NOT when LOCKED (so the user can freely orbit around a locked planet!).
            if (root.lockedPlanetId === "" && root.targetedPlanetId !== "" && root.bodyCoords[root.targetedPlanetId]) {
                let tb = root.bodyCoords[root.targetedPlanetId];
                let dx = tb.x - root.camX;
                let dy = tb.y - root.camY;
                let dz = tb.z - root.camZ;
                let dist = Math.hypot(dx, dy, dz) || 1.0;
                root.targetYaw = root.shortestYawTarget(root.camYaw, Math.atan2(-dx, -dz));
                root.targetPitch = Math.asin(Math.max(-0.98, Math.min(0.98, dy / dist)));
            }

            let lookStiff = Math.min(1.0, 12.0 * dt);
            root.camYaw += (root.targetYaw - root.camYaw) * lookStiff;
            root.camPitch += (root.targetPitch - root.camPitch) * lookStiff;
            root.updateCameraTrig();

            let fwdX = -Math.sin(root.camYaw) * Math.cos(root.camPitch);
            let fwdY = Math.sin(root.camPitch);
            let fwdZ = -Math.cos(root.camYaw) * Math.cos(root.camPitch);
            let rightX = Math.cos(root.camYaw);
            let rightZ = -Math.sin(root.camYaw);

            if (root.lockedPlanetId !== "" && root.bodyCoords[root.lockedPlanetId]) {
                let target = root.bodyCoords[root.lockedPlanetId];

                if (root.keysDown[Qt.Key_W]) root.targetLockDist = Math.max(target.r * 2.2, root.targetLockDist - 650 * dt);
                if (root.keysDown[Qt.Key_S]) root.targetLockDist = Math.min(8500, root.targetLockDist + 650 * dt);
                if (root.keysDown[Qt.Key_A]) root.targetYaw -= 1.8 * dt;
                if (root.keysDown[Qt.Key_D]) root.targetYaw += 1.8 * dt;
                if (root.keysDown[Qt.Key_Space]) root.targetPitch = Math.max(-1.45, root.targetPitch - 1.4 * dt);
                if (root.keysDown[Qt.Key_Shift]) root.targetPitch = Math.min(1.45, root.targetPitch + 1.4 * dt);

                root.lockDist += (root.targetLockDist - root.lockDist) * Math.min(1.0, 8.0 * dt);

                // Directly anchor camera on the spherical orbit shell around the target planet
                root.camX = target.x - fwdX * root.lockDist;
                root.camY = target.y - fwdY * root.lockDist;
                root.camZ = target.z - fwdZ * root.lockDist;
                root.velX = 0; root.velY = 0; root.velZ = 0;
            } else {
                const drift = root.spaceDrift;
                let thrust = drift ? 300.0 : 1800.0;
                let ax = 0, ay = 0, az = 0;
                let thrusting = false;
                if (root.keysDown[Qt.Key_W]) { ax += fwdX * thrust; ay += fwdY * thrust; az += fwdZ * thrust; thrusting = true; }
                if (root.keysDown[Qt.Key_S]) { ax -= fwdX * thrust; ay -= fwdY * thrust; az -= fwdZ * thrust; thrusting = true; }
                if (root.keysDown[Qt.Key_D]) { ax += rightX * thrust; az += rightZ * thrust; thrusting = true; }
                if (root.keysDown[Qt.Key_A]) { ax -= rightX * thrust; az -= rightZ * thrust; thrusting = true; }
                if (root.keysDown[Qt.Key_Space]) { ay += thrust; thrusting = true; }
                if (root.keysDown[Qt.Key_Shift]) { ay -= thrust; thrusting = true; }

                if (drift) {
                    root.driftStep(dt, ax, ay, az, thrusting, rightX, rightZ);
                } else {
                    // classic flight: no drift, the ship damps to a stop
                    let damp = Math.pow(0.06, dt);
                    root.velX = (root.velX + ax * dt) * damp;
                    root.velY = (root.velY + ay * dt) * damp;
                    root.velZ = (root.velZ + az * dt) * damp;
                    root._driftGrace = 0.0;
                    root.camX += root.velX * dt;
                    root.camY += root.velY * dt;
                    root.camZ += root.velZ * dt;
                }
            }

                

            if (Math.abs(root.velX) > 0.01 || Math.abs(root.velY) > 0.01 || Math.abs(root.velZ) > 0.01) {
                let hBox = root.dustBoxSize * 0.5;
                for (let k = 0; k < root.dustParticles.length; k++) {
                    let dp = root.dustParticles[k];
                    dp.x -= root.velX * dt;
                    dp.y -= root.velY * dt;
                    dp.z -= root.velZ * dt;
                    if (dp.x > hBox) dp.x -= root.dustBoxSize; else if (dp.x < -hBox) dp.x += root.dustBoxSize;
                    if (dp.y > hBox) dp.y -= root.dustBoxSize; else if (dp.y < -hBox) dp.y += root.dustBoxSize;
                    if (dp.z > hBox) dp.z -= root.dustBoxSize; else if (dp.z < -hBox) dp.z += root.dustBoxSize;
                }
            }

            let w = root.width, h = root.height;
            let halfW = w * 0.5, halfH = h * 0.5;
            let fov = Math.min(w, h) * 0.95;
            let pMap = {};
            let hits = [];

            for (let i = 0; i < root.bodyKeys.length; i++) {
                let key = root.bodyKeys[i];
                let b = root.bodyCoords[key];
                if (!b) continue;
                let proj = root.project3D(b.x, b.y, b.z, halfW, halfH, fov);
                if (proj) {
                    let sr = Math.max(4.0, (b.isSun ? root.sunRadius : b.r) * proj.scale);
                    let lVec;
                    let sunViewDir = root.dirToViewSpace(-b.x, -b.y, -b.z, b.bType);
                    if (b.isSun) {
                        lVec = Qt.vector4d(0, 0, 1, 0.0);
                    } else if (b.bType === 10 && b.vel3D) {
                        lVec = Qt.vector4d(b.vel3D.x, b.vel3D.y, b.vel3D.z, 10.0);
                    } else {
                        lVec = sunViewDir;
                    }

                    pMap[key] = {
                        visible: true,
                        sx: proj.sx,
                        sy: proj.sy,
                        depth: proj.depth,
                        scale: proj.scale,
                        screenR: sr,
                        lightDir: lVec,
                        sunXY: Qt.point(sunViewDir.x, sunViewDir.y),
                        zOrder: b.isSun ? (-proj.depth - 250) : (-proj.depth)
                    };
                    hits.push({ id: key, sx: proj.sx, sy: proj.sy, r: Math.max(sr + 10, 22), depth: proj.depth });
                } else {
                    pMap[key] = { visible: false };
                }
            }
            hits.sort((a, b) => a.depth - b.depth);
            root.projectedMap = pMap;
            root.screenHitboxes = hits;

            root.checkQuantumObserver();

            // background canvas: stars/orbits/dust only change when the camera or a highlight changes
            let hlKey = root.lockedPlanetId + "|" + root.targetedPlanetId + "|" + root.hoveredPlanetId;
            if (root.camX !== root._pX || root.camY !== root._pY || root.camZ !== root._pZ ||
                root.camYaw !== root._pYaw || root.camPitch !== root._pPitch ||
                w !== root._pW || h !== root._pH || hlKey !== root._pHl) {
                root._pX = root.camX; root._pY = root.camY; root._pZ = root.camZ;
                root._pYaw = root.camYaw; root._pPitch = root.camPitch;
                root._pW = w; root._pH = h; root._pHl = hlKey;
                bgCanvas.requestPaint();
            }
            if (root.supernovaRadius > 0) novaCanvas.requestPaint();

            // planets orbit under a still cursor, so keep hover fresh without mouse movement
            if (mouseArea.containsMouse) mouseArea.updateHover(mouseArea.mouseX, mouseArea.mouseY);

            root.lastDt = dt;
            root.frameUpdated();
        }
    }
    // --- LAYER 0: BACKGROUND FILL (plain item instead of a per-frame fillRect) ---
    Rectangle {
        anchors.fill: parent
        color: root.colBg
        z: -2000000
    }

    // --- LAYER 1: STARFIELD, VELOCITY DUST & ORBITS ---
    // Repainted only when the camera moved or a highlight changed (see FrameAnimation).
    Canvas {
        id: bgCanvas
        anchors.fill: parent
        z: -1000000

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let w = width, h = height;
            let halfW = w * 0.5, halfH = h * 0.5;
            let fov = Math.min(w, h) * 0.95;

            const cx = root.camX, cy = root.camY, cz = root.camZ;
            const rcy = root._cy, rsy = root._sy, rcp = root._cp, rsp = root._sp;
            // allocation-free projection into view space: v = [x, y, depth]
            let v = [0, 0, 0];
            function toView(wx, wy, wz) {
                let dx = wx - cx, dy = wy - cy, dz = wz - cz;
                let x1 = dx * rcy + dz * rsy;
                let z1 = -dx * rsy + dz * rcy;
                v[0] = x1;
                v[1] = dy * rcp - z1 * rsp;
                v[2] = -(dy * rsp + z1 * rcp);
            }

            ctx.fillStyle = "#FFFFFF";
            for (let i = 0; i < root.stars.length; i++) {
                let st = root.stars[i];
                toView(cx + st.x, cy + st.y, cz + st.z);
                if (v[2] <= 2.0) continue;
                let sc = fov / v[2];
                let sx = halfW + v[0] * sc, sy = halfH - v[1] * sc;
                if (sx >= 0 && sx <= w && sy >= 0 && sy <= h) {
                    ctx.globalAlpha = st.alpha;
                    ctx.fillRect(sx, sy, st.size, st.size);
                }
            }

            let curSpeed = Math.hypot(root.velX, root.velY, root.velZ);
            ctx.strokeStyle = "#BBD4AF37";
            ctx.lineWidth = 1.0;
            for (let d = 0; d < root.dustParticles.length; d++) {
                let dp = root.dustParticles[d];
                toView(cx + dp.x, cy + dp.y, cz + dp.z);
                if (v[2] <= 2.0) continue;
                let sc1 = fov / v[2];
                let sx1 = halfW + v[0] * sc1, sy1 = halfH - v[1] * sc1;
                if (sx1 >= 0 && sx1 <= w && sy1 >= 0 && sy1 <= h) {
                    ctx.globalAlpha = dp.alpha;
                    let streaked = false;
                    if (curSpeed > 35.0) {
                        // streak = where this dust mote is heading, projected through the real camera
                        toView(cx + dp.x - root.velX * 0.022, cy + dp.y - root.velY * 0.022, cz + dp.z - root.velZ * 0.022);
                        if (v[2] > 2.0) {
                            let sc2 = fov / v[2];
                            ctx.beginPath();
                            ctx.moveTo(sx1, sy1);
                            ctx.lineTo(halfW + v[0] * sc2, halfH - v[1] * sc2);
                            ctx.stroke();
                            streaked = true;
                        }
                    }
                    if (!streaked) ctx.fillRect(sx1, sy1, 1.2, 1.2);
                }
            }
            ctx.globalAlpha = 1.0;

            // orbits, clipped against a near plane so nothing projects to absurd coordinates
            const NEAR = 4.0;
            ctx.lineWidth = 1.2;
            for (let i = 0; i < root.bakedOrbits.length; i++) {
                let orb = root.bakedOrbits[i];
                let isTwins = (orb.id === "twins_bary") && (
                    root.lockedPlanetId === "ash_twin" || root.lockedPlanetId === "ember_twin" ||
                    root.targetedPlanetId === "ash_twin" || root.targetedPlanetId === "ember_twin" ||
                    root.hoveredPlanetId === "ash_twin" || root.hoveredPlanetId === "ember_twin"
                );
                let isHighlighted = isTwins || root.lockedPlanetId === orb.id || root.targetedPlanetId === orb.id || root.hoveredPlanetId === orb.id;
                ctx.strokeStyle = isHighlighted ? root.colCream : root.colDimOrbit;
                ctx.beginPath();
                let pts = orb.points;
                let havePrev = false, penDown = false;
                let px = 0, py = 0, pd = 0, psx = 0, psy = 0;
                for (let s = 0; s < pts.length; s++) {
                    let pt = pts[s];
                    toView(pt.x, pt.y, pt.z);
                    let cx1 = v[0], cy2 = v[1], cd = v[2];
                    let csx = 0, csy = 0;
                    if (cd >= NEAR) {
                        let sc = fov / cd;
                        csx = halfW + cx1 * sc;
                        csy = halfH - cy2 * sc;
                    }
                    if (havePrev) {
                        let prevIn = pd >= NEAR, curIn = cd >= NEAR;
                        if (prevIn && curIn) {
                            if (!penDown) { ctx.moveTo(psx, psy); penDown = true; }
                            ctx.lineTo(csx, csy);
                        } else if (prevIn || curIn) {
                            let t = (NEAR - pd) / (cd - pd);
                            let isx = halfW + (px + (cx1 - px) * t) * fov / NEAR;
                            let isy = halfH - (py + (cy2 - py) * t) * fov / NEAR;
                            if (prevIn) {
                                if (!penDown) ctx.moveTo(psx, psy);
                                ctx.lineTo(isx, isy);
                                penDown = false;
                            } else {
                                ctx.moveTo(isx, isy);
                                ctx.lineTo(csx, csy);
                                penDown = true;
                            }
                        } else {
                            penDown = false;
                        }
                    }
                    px = cx1; py = cy2; pd = cd; psx = csx; psy = csy;
                    havePrev = true;
                }
                ctx.stroke();
            }
        }
    }

    // --- TWIN LINK BEAM (moves every frame, so it is a cheap GPU item instead of canvas content) ---
    Rectangle {
        id: twinLink
        readonly property var pA: root.projectedMap["ash_twin"]
        readonly property var pE: root.projectedMap["ember_twin"]
        readonly property bool shown: !!(pA && pA.visible && pE && pE.visible)
        readonly property real ddx: shown ? pE.sx - pA.sx : 0
        readonly property real ddy: shown ? pE.sy - pA.sy : 0

        visible: shown
        z: -900000
        antialiasing: true
        color: "#D9E6C280"
        x: shown ? pA.sx : 0
        y: shown ? pA.sy - height / 2 : 0
        width: Math.hypot(ddx, ddy)
        height: shown ? Math.max(3.5, 7.5 * ((pA.scale + pE.scale) * 0.5)) : 1
        transformOrigin: Item.Left
        rotation: Math.atan2(ddy, ddx) * 180 / Math.PI
    }

    // --- LAYER 2: SHADER PLANETS ---
    Repeater {
        model: root.bodyKeys

        Item {
            property string key: modelData
            property var meta: root.bodyMeta[key]
            property var pData: root.projectedMap[key]

            visible: pData ? pData.visible : false
            x: pData && pData.visible ? pData.sx : -9999
            y: pData && pData.visible ? pData.sy : -9999
            z: pData && pData.visible ? pData.zOrder : 0

            PlanetShader {
                bodyId: parent.key
                bodyName: parent.meta.name
                bodyRole: parent.meta.role
                baseColor: parent.meta.color
                accentColor: parent.meta.accent
                bodyType: parent.meta.bType
                isSun: parent.meta.isSun
                isLocked: root.lockedPlanetId === parent.key || root.targetedPlanetId === parent.key
                screenRadius: parent.pData && parent.pData.visible ? parent.pData.screenR : 10
                bodyDepth: parent.pData && parent.pData.visible ? parent.pData.depth : 1000
                lightDir: parent.pData && parent.pData.visible ? parent.pData.lightDir : Qt.vector4d(1, 0, 0, 4)
                shaderParams: Qt.vector4d(
                    root.loopTime,
                    root.sunProgress,
                    root.swellRatio,
                    (root.lockedPlanetId === parent.key || root.targetedPlanetId === parent.key) ? 1.0 : 0.0
                )
                camAngles: Qt.vector4d(
                    root.camYaw,
                    root.camPitch,
                    parent.pData && parent.pData.visible ? parent.pData.sunXY.x : 0.0,
                    parent.pData && parent.pData.visible ? parent.pData.sunXY.y : 0.0
                )
            }
        }
    }

    // --- LAYER 3a: SUPERNOVA RING (only exists during the last 30 s of the loop) ---
    Canvas {
        id: novaCanvas
        anchors.fill: parent
        z: 24990
        visible: root.supernovaRadius > 0

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let sunP = root.projectedMap["sun"];
            if (root.supernovaRadius > 0 && sunP && sunP.visible) {
                let snR = root.supernovaRadius * sunP.scale;
                let grad = ctx.createRadialGradient(sunP.sx, sunP.sy, snR * 0.72, sunP.sx, sunP.sy, snR);
                grad.addColorStop(0.0, `rgba(120, 200, 255, 0.0)`);
                grad.addColorStop(0.85, `rgba(180, 235, 255, ${root.supernovaAlpha * 0.7})`);
                grad.addColorStop(1.0, `rgba(255, 255, 255, ${root.supernovaAlpha})`);

                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.arc(sunP.sx, sunP.sy, snR, 0, Math.PI * 2);
                ctx.fill();

                ctx.strokeStyle = `rgba(220, 245, 255, ${root.supernovaAlpha})`;
                ctx.lineWidth = Math.max(4.0, 18.0 * sunP.scale);
                ctx.stroke();
            }
        }
    }

    // --- LAYER 3b: HOVER RETICLE (small canvas that follows the planet) ---
    Canvas {
        id: hoverRet
        readonly property var pH: (root.hoveredPlanetId !== "" && root.hoveredPlanetId !== root.activeFocusId)
                                  ? root.projectedMap[root.hoveredPlanetId] : null
        readonly property bool vis: !!(pH && pH.visible)
        readonly property real hR: vis ? Math.max(pH.screenR + 18, 30) : 30
        readonly property bool shown: vis && hR < 3000
        readonly property int side: Math.ceil((hR + 8) / 32) * 64
        readonly property real left0: shown ? pH.sx - side / 2 : 0
        readonly property real top0: shown ? pH.sy - side / 2 : 0
        readonly property real fracX: left0 - Math.floor(left0)
        readonly property real fracY: top0 - Math.floor(top0)

        width: side
        height: side
        x: Math.floor(left0)
        y: Math.floor(top0)
        visible: shown
        z: 25000

        onFracXChanged: requestPaint()
        onFracYChanged: requestPaint()
        onHRChanged: requestPaint()
        onSideChanged: requestPaint()
        onShownChanged: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            if (!shown) return;
            ctx.translate(width / 2 + fracX, height / 2 + fracY);
            let diagAngles = [Math.PI / 4, 3 * Math.PI / 4, 5 * Math.PI / 4, 7 * Math.PI / 4];
            ctx.strokeStyle = "rgba(220, 235, 245, 0.38)";
            ctx.lineWidth = 1.2;
            let span = 0.14;
            for (let d = 0; d < 4; d++) {
                ctx.beginPath();
                ctx.arc(0, 0, hR, diagAngles[d] - span, diagAngles[d] + span);
                ctx.stroke();
            }
        }
    }

    // --- LAYER 3c: LOCK RETICLE (small canvas that follows the planet) ---
    Canvas {
        id: lockRet
        readonly property var pL: root.activeFocusId !== "" ? root.projectedMap[root.activeFocusId] : null
        readonly property bool vis: !!(pL && pL.visible)
        readonly property real rad: vis ? Math.max(pL.screenR + 20, 34) : 34
        readonly property bool shown: vis && rad < 3000
        readonly property string lockColor: root.activeFocusId === "quantum_moon" ? "#9D74E8" : root.colLockBlue
        readonly property int side: Math.ceil((rad + 24) / 32) * 64
        readonly property real left0: shown ? pL.sx - side / 2 : 0
        readonly property real top0: shown ? pL.sy - side / 2 : 0
        readonly property real fracX: left0 - Math.floor(left0)
        readonly property real fracY: top0 - Math.floor(top0)

        width: side
        height: side
        x: Math.floor(left0)
        y: Math.floor(top0)
        visible: shown
        z: 25000

        onFracXChanged: requestPaint()
        onFracYChanged: requestPaint()
        onRadChanged: requestPaint()
        onSideChanged: requestPaint()
        onShownChanged: requestPaint()
        onLockColorChanged: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            if (!shown) return;
            ctx.translate(width / 2 + fracX, height / 2 + fracY);
            let diagAngles = [Math.PI / 4, 3 * Math.PI / 4, 5 * Math.PI / 4, 7 * Math.PI / 4];

            ctx.strokeStyle = lockColor;
            ctx.lineWidth = 2.0;
            let diagSpan = 0.28;
            for (let q = 0; q < 4; q++) {
                ctx.beginPath();
                ctx.arc(0, 0, rad, diagAngles[q] - diagSpan, diagAngles[q] + diagSpan);
                ctx.stroke();
            }

            let chR = rad + 10;
            ctx.fillStyle = lockColor;
            for (let i = 0; i < 4; i++) {
                let a = diagAngles[i];
                ctx.save();
                ctx.translate(chR * Math.cos(a), chR * Math.sin(a));
                ctx.rotate(a);
                ctx.beginPath();
                ctx.moveTo(-6, -5);
                ctx.lineTo(2, 0);
                ctx.lineTo(-6, 5);
                ctx.lineTo(-4, 0);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
            }

            let dotR = rad + 6;
            ctx.fillStyle = "#FFFFFF";
            let pips = [
                { x: 0, y: -dotR },
                { x: 0, y: dotR },
                { x: -dotR, y: 0 },
                { x: dotR, y: 0 }
            ];
            for (let k = 0; k < 4; k++) {
                ctx.fillRect(pips[k].x - 1.5, pips[k].y - 1.5, 3, 3);
            }
        }
    }

    // --- MOUSE LOOK, HOVER, CLICK (CENTER) & ALT-CLICK / DOUBLE-CLICK (ZOOM FLY-IN) ---
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        z: 28000
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real lastX: 0
        property real lastY: 0
        property bool dragged: false
        property bool skipNextRelease: false

        function updateHover(mx, my) {
            let hits = root.screenHitboxes;
            let foundHover = "";
            for (let i = 0; i < hits.length; i++) {
                let h = hits[i];
                if (Math.hypot(mx - h.sx, my - h.sy) <= h.r) {
                    foundHover = h.id;
                    break;
                }
            }
            if (root.hoveredPlanetId !== foundHover) {
                root.hoveredPlanetId = foundHover;
            }
        }

        // fly-in at a screen point; returns true if a planet was there (also used by WidgetSlot for double-clicks on cards)
        function engageAt(mx, my) {
            let hits = root.screenHitboxes;
            for (let i = 0; i < hits.length; i++) {
                let h = hits[i];
                if (Math.hypot(mx - h.sx, my - h.sy) <= h.r) {
                    engageAutopilot(h.id);
                    return true;
                }
            }
            return false;
        }

        function engageAutopilot(targetId) {
            let targetBody = root.bodyCoords[targetId];
            if (!targetBody) return;
            let dx = targetBody.x - root.camX;
            let dy = targetBody.y - root.camY;
            let dz = targetBody.z - root.camZ;
            let dist = Math.hypot(dx, dy, dz) || 1.0;

            root.targetYaw = root.shortestYawTarget(root.camYaw, Math.atan2(-dx, -dz));
            root.targetPitch = Math.asin(Math.max(-0.98, Math.min(0.98, dy / dist)));
            root.camYaw = root.targetYaw;
            root.camPitch = root.targetPitch;
            root.updateCameraTrig();

            // Start lockDist at actual current distance so we fly in smoothly without snapping!
            root.lockDist = dist;
            root.targetLockDist = Math.max(targetBody.r * root.lockOrbitK, root.lockOrbitMin);
            root.lockedPlanetId = targetId;
            root.targetedPlanetId = targetId;
        }

        onPositionChanged: (mouse) => {
            if (pressed && (mouse.buttons & Qt.LeftButton)) {
                let dx = mouse.x - lastX;
                let dy = mouse.y - lastY;
                if (Math.abs(dx) > 2 || Math.abs(dy) > 2) {
                    dragged = true;
                    // If only single-click centered (not locked), dragging breaks the centering lock so you can look around freely
                    if (root.lockedPlanetId === "" && root.targetedPlanetId !== "") {
                        root.targetedPlanetId = "";
                    }
                }

                // When locked onto a planet, dragging orbits around it; in free-flight, dragging turns the camera
                let sens = root.lockedPlanetId !== "" ? 0.0055 : 0.0045;
                root.targetYaw -= dx * sens;
                root.targetPitch = Math.max(-1.48, Math.min(1.48, root.targetPitch - dy * sens));

                lastX = mouse.x;
                lastY = mouse.y;
            }

            updateHover(mouse.x, mouse.y);
        }

        onCanceled: {
            // a stolen press (compositor grab, focus loss) must not leave the loop frozen
            root.isInteracting = false;
        }

        onPressed: (mouse) => {
            root.forceActiveFocus();
            root.isInteracting = true;
            lastX = mouse.x;
            lastY = mouse.y;
            dragged = false;

            if (mouse.button === Qt.RightButton) {
                root.lockedPlanetId = "";
                root.targetedPlanetId = "";
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                if (engageAt(mouse.x, mouse.y)) skipNextRelease = true;
            }
        }

        onReleased: (mouse) => {
            root.isInteracting = false;
            if (skipNextRelease) {
                skipNextRelease = false;
                return;
            }
            if (!dragged && mouse.button === Qt.LeftButton) {
                let hits = root.screenHitboxes;
                let hitPlanet = false;

                for (let i = 0; i < hits.length; i++) {
                    let h = hits[i];
                    if (Math.hypot(mouse.x - h.sx, mouse.y - h.sy) <= h.r) {
                        hitPlanet = true;
                        let targetBody = root.bodyCoords[h.id];

                        if (mouse.modifiers & Qt.AltModifier) {
                            engageAutopilot(h.id);
                        } else if (root.lockedPlanetId === h.id) {
                            // Clicking the already-locked planet keeps it locked
                        } else {
                            root.lockedPlanetId = "";
                            root.targetedPlanetId = (root.targetedPlanetId === h.id) ? "" : h.id;
                            if (root.targetedPlanetId !== "" && targetBody) {
                                let dx = targetBody.x - root.camX;
                                let dy = targetBody.y - root.camY;
                                let dz = targetBody.z - root.camZ;
                                let dist = Math.hypot(dx, dy, dz) || 1;
                                root.targetYaw = root.shortestYawTarget(root.camYaw, Math.atan2(-dx, -dz));
                                root.targetPitch = Math.asin(Math.max(-0.98, Math.min(0.98, dy / dist)));
                            }
                        }
                        break;
                    }
                }

                if (!hitPlanet && !(mouse.modifiers & Qt.AltModifier)) {
                    root.targetedPlanetId = "";
                    root.lockedPlanetId = "";
                }
            }
        }

        onWheel: (wheel) => {
            let delta = wheel.angleDelta.y;
            if (root.lockedPlanetId !== "") {
                let factor = delta > 0 ? Math.pow(0.84, delta / 120.0) : Math.pow(1.18, -delta / 120.0);
                let minD = root.bodyCoords[root.lockedPlanetId] ? root.bodyCoords[root.lockedPlanetId].r * 2.2 : 50;
                root.targetLockDist = Math.max(minD, Math.min(8500, root.targetLockDist * factor));
            } else {
                let step = (delta / 120.0) * (root.spaceDrift ? 165.0 : 550.0);
                root._pushFree = 1.0;      // scrolling forward is active travel too
                root.velX += -Math.sin(root.camYaw) * Math.cos(root.camPitch) * step;
                root.velY += Math.sin(root.camPitch) * step;
                root.velZ += -Math.cos(root.camYaw) * Math.cos(root.camPitch) * step;
            }
        }
    }

    // --- ORBITING WIDGETS (above the mouse area so they are clickable) ---
    WidgetLayer {
        anchors.fill: parent
        rig: root
    }

    // --- SATELLITE HUD (stage 3): gauges, audio globe, movement indicator, key prompts ---
    SatelliteHUD {
        anchors.fill: parent
        rig: root
    }

    // --- SIGNALSCOPE (z 30000): reticle, readout, waveform, channel keys; stowed = invisible and idle ---
    Signalscope {
        anchors.fill: parent
        rig: root
    }

    // --- RUMOR MAP (ship log overlay): above everything (z 40000); pauses the rig via `active` while open ---
    RumorMap {
        anchors.fill: parent
        rig: root
    }

    // --- MAP VIEW (ship log map overlay, z 29500): grid + planet pages; pauses the rig via `active` while open ---
    MapHost {
        anchors.fill: parent
        rig: root
    }

    // --- "Back to Map" chip, only while the Rumor Map was entered from the Map View (z 40500) ---
    MapReturnChip {
        anchors.fill: parent
    }

    // --- DEBUG PANEL ---
    Rectangle {
        z: 32000
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 18
        width: 380
        height: 140
        radius: 8
        color: "#CC07080C"
        border.color: root.colGold
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Text {
                color: root.colCream
                font.family: "monospace"
                font.pixelSize: 13
                text: {
                    let mins = Math.floor(root.loopTime / 60);
                    let secs = Math.floor(root.loopTime % 60).toString().padStart(2, '0');
                    let activeId = root.lockedPlanetId !== "" ? root.lockedPlanetId : root.targetedPlanetId;
                    let activeName = activeId !== "" && root.bodyMeta[activeId]
                        ? `${root.bodyMeta[activeId].name} [${root.lockedPlanetId !== "" ? "LOCKED" : "TARGETED"}]`
                        : (root.spaceDrift ? "6-DOF Drift" : "6-DOF Free Flight (no drift)");
                    return `LOOP: ${mins}:${secs} / 22:00 | ${activeName}`;
                }
            }

            Text {
                color: "#99E6D5B8"
                font.family: "monospace"
                font.pixelSize: 11
                text: "Click: Center | Dbl-Click: Lock & Orbit | Ctrl: drift on/off"
            }

            Row {
                spacing: 10
                Text {
                    color: root.colGold
                    font.family: "monospace"
                    font.pixelSize: 12
                    text: `Speed: ${Math.round(root.timeScale)}x`
                    width: 85
                }
                Slider {
                    from: 1
                    to: 200
                    value: root.timeScale
                    width: 245
                    onMoved: root.timeScale = value
                }
            }

            Row {
                spacing: 8
                Button {
                    text: "21:15 (Red Giant)"
                    onClicked: root.loopTime = 1275.0
                }
                Button {
                    text: "Reset Loop"
                    onClicked: root.loopTime = 0.0
                }
                Button {
                    text: "Home View"
                    onClicked: {
                        root.lockedPlanetId = "";
                        root.targetedPlanetId = "";
                        root.hoveredPlanetId = "";
                        root.camX = 0; root.camY = 1690; root.camZ = 4160; root._dwell = ({}); root._driftGrace = 0;
                        root.velX = 0; root.velY = 0; root.velZ = 0;
                        root.targetYaw = 0; root.targetPitch = -0.38;
                        root.camYaw = 0; root.camPitch = -0.38;
                        root.updateCameraTrig();
                    }
                }
            }
        }
    }
}
