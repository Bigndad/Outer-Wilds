.pragma library
// The System page's Bubble style (BubbleMonitor.qml): the logic of the design (~/Downloads/bubble-monitor: src/util.js
// and src/physics.js) carried over to QML, kept as close to it as possible (the same tunables, the same maths), and the
// charts' lines. Times are Date.now() ms.

// ---------- util.js ----------
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }
function lerp(a, b, t) { return a + (b - a) * t; }
function rnd(a, b) { return a + Math.random() * (b - a); }
function fill(n, f) { const out = []; for (let i = 0; i < n; i++) out.push(f(i)); return out; }
function easeIO(t) { return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; }
function easeBack(t) { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); }
function fmtMem(mb) { return mb >= 1000 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB"; }
// a length of time: "4h 52m", "3d 2h"; with `secs` short ones keep their seconds ("1m 23s", "42s")
function fmtSpan(sec, secs) {
    sec = Math.max(0, Math.floor(sec));
    const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
    if (d) return d + "d " + h + "h";
    if (h) return h + "h " + m + "m";
    if (secs) return m ? m + "m " + s + "s" : s + "s";
    return m + "m";
}
// how long ago: "just now", "12m ago", "4h 52m ago"
function fmtAgo(sec) { return sec < 60 ? "just now" : fmtSpan(sec) + " ago"; }
// exponential smoothing factor for a frame of `dt` seconds with time constant `tau`
function smoothK(dt, tau) { return 1 - Math.exp(-dt / tau); }

// ---------- the charts' lines ----------
// a smooth curve through points (Catmull–Rom as cubic Béziers), as an SVG path; `close` returns down to `baseY`
function smoothPath(pts, baseY) {
    if (pts.length < 2) return "M0,0";
    const f = v => v.toFixed(1);
    let d = "M" + f(pts[0][0]) + "," + f(pts[0][1]);
    for (let i = 0; i < pts.length - 1; i++) {
        const p0 = pts[Math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[Math.min(pts.length - 1, i + 2)];
        d += " C" + f(p1[0] + (p2[0] - p0[0]) / 6) + "," + f(p1[1] + (p2[1] - p0[1]) / 6) + " "
           + f(p2[0] - (p3[0] - p1[0]) / 6) + "," + f(p2[1] - (p3[1] - p1[1]) / 6) + " " + f(p2[0]) + "," + f(p2[1]);
    }
    if (baseY !== undefined) d += " L" + f(pts[pts.length - 1][0]) + "," + f(baseY) + " L" + f(pts[0][0]) + "," + f(baseY) + " Z";
    return d;
}
// the value at fraction t (0..1) of an array, on the same smooth curve
function curveAt(arr, t) {
    const n = arr.length, f = clamp(t, 0, 1) * (n - 1), i = Math.min(n - 2, Math.floor(f)), u = f - i;
    const p0 = arr[Math.max(0, i - 1)], p1 = arr[i], p2 = arr[i + 1], p3 = arr[Math.min(n - 1, i + 2)];
    return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u);
}
// The scan dot: the samples fixed across the width and a dot running over them once per sample (`frac` 0..1; a little
// past 1 when a sample is late, a little below 0 when it came early), only the stretch just behind it drawn (`tail` of
// the width), fading out backwards in `parts` pieces (the first faintest). Its run goes `margin` past both edges, so the
// dot slides right out of the box and back in from outside instead of popping up at the edge, and it never breaks
// off: while it comes back in on the left, the rest of its tail is still going out on the right, drawn from the samples
// it was running over then (`stale`, the same window one sample earlier).
function comet(fresh, stale, frac, w, h, toFrac, tail, parts, margin) {
    const pad = 6, m = margin || 0, run = w + 2 * m;
    const y = v => h - pad - clamp(toFrac(v), 0, 1) * (h - 2 * pad);
    const head = frac * run - m, len = tail * w, segs = [];
    // a point of the run: below -m it is the end of the last run, on the right
    const at = x => x >= -m ? [x, y(curveAt(fresh, clamp(x / w, 0, 1)))] : [x + run, y(curveAt(stale, clamp((x + run) / w, 0, 1)))];
    for (let k = 0; k < parts; k++) {
        const a = head - len + k * len / parts, b = head - len + (k + 1) * len / parts;
        let d = "", last = null;
        for (let x = a; ; x = Math.min(b, x + 3)) {
            const p = at(x), wrapped = x < -m;
            d += (last === null || last !== wrapped ? " M" : " L") + p[0].toFixed(1) + "," + p[1].toFixed(1);
            last = wrapped;
            if (x >= b) break;
        }
        segs.push(d.trim());
    }
    const dot = at(head);
    return { segs: segs, x: dot[0], y: dot[1] };
}
// Two ways at once as smooth lines scrolling between samples: `up` above the middle, `down` below it, each to its own
// scale, with a faint area to the middle.
function twoWay(up, down, phase, w, h, maxUp, maxDown, steps) {
    const mid = h / 2, room = mid - 6, step = w / steps;
    const side = (arr, max, dir) => {
        const n = arr.length, pts = [[w, mid - dir * clamp(lerp(arr[n - 2], arr[n - 1], easeIO(phase)) / max, 0, 1) * room]];
        for (let k = 0; k < n - 1; k++) {
            const x = w - (phase + k) * step;
            pts.push([x, mid - dir * clamp(arr[n - 2 - k] / max, 0, 1) * room]);
            if (x < -step) break;
        }
        return { line: smoothPath(pts), area: smoothPath(pts, mid), y: pts[0][1] };
    };
    const u = side(up, Math.max(0.001, maxUp), 1), d = side(down, Math.max(0.001, maxDown), -1);
    return { upLine: u.line, upArea: u.area, downLine: d.line, downArea: d.area, upY: u.y, downY: d.y };
}

// a jagged lightning segment from (ax,ay) to (bx,by), tapered at both ends
function boltPath(ax, ay, bx, by, amp) {
    const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy) || 1;
    const nx = -dy / len, ny = dx / len, segs = Math.max(3, Math.round(len / 12));
    let d = "M" + ax.toFixed(1) + "," + ay.toFixed(1);
    for (let i = 1; i < segs; i++) {
        const t = i / segs, j = (Math.random() * 2 - 1) * amp * Math.sin(Math.PI * t);
        d += " L" + (ax + dx * t + nx * j).toFixed(1) + "," + (ay + dy * t + ny * j).toFixed(1);
    }
    return d + " L" + bx.toFixed(1) + "," + by.toFixed(1);
}

// ---------- data.js: classify ----------
const DEV = /^(node|deno|bun|python\d?(\.\d+)?|cargo|rustc|rust-analyzer|code|codium|go|gopls|java|gcc|g\+\+|clang|make|cmake|ninja|npm|pnpm|yarn|vite|esbuild|postgres|redis-server|mysqld|stress-ng|claude|qmllint|quickshell|qs)$/i;
const SYS = /^(systemd|gnome-shell|Xwayland|Xorg|pipewire|wireplumber|pulseaudio|dbus|kworker|dockerd|containerd|NetworkManager|kwin_wayland|plasmashell|sway|Hyprland|gdm|sddm|polkitd|udisksd|upowerd)/;
// 'app' | 'dev' | 'sys' — drives the bubble colour
function classify(name, user) {
    if (DEV.test(name)) return "dev";
    if (SYS.test(name) || user === "root") return "sys";
    return "app";
}

// ---------- physics.js ----------
const DEFAULT_PHYSICS = {
    bounce: 0.65,     // restitution for bubble/bubble and wall hits
    jelly: 1,         // wobble strength multiplier (0 = rigid)
    drift: 30,        // wandering acceleration, px/s²
    damping: 0.7,     // velocity decay per second
    gap: 16,          // minimum surface distance kept between bubbles
    spark: true,      // lightning + attraction on/off
    sparkRange: 110,  // surface distance where lightning starts
    attract: 45,      // max attraction, px/s², at zero distance
    grabK: 150,       // a held bubble follows the pointer on the duck's carry spring (DuckActor "held"):
    grabC: 17         // stiffness and damping, so it trails a little and swings a little past
};

class World {
    constructor(w, h, opts) {
        this.w = w; this.h = h; this.nodes = [];
        this.opts = Object.assign({}, DEFAULT_PHYSICS, opts || {});
        this.dragTarget = null;
        this.frame = 0;
        this.bolts = { weak: "", mid: "", strong: "" };
        this.hits = [];       // the closing speeds of this step's new knocks, bubble/bubble and wall (for the sound)
        this.touching = {};   // what was in contact last step: a knock only counts when the contact is new
    }

    add(props) {
        const n = Object.assign({
            x: this.w / 2, y: this.h / 2, vx: 0, vy: 0,
            r: 30, rT: 30, ef: 30,
            w: 0, ph: 0,
            hd: Math.random() * Math.PI * 2,
            grab: false, born: Date.now(), dying: null,
            sq: 0, sqA: 0                      // squash (0 round .. 0.3) and the direction it is pressed along, degrees
        }, props);
        n.r = n.ef = n.rT;
        this.nodes.push(n);
        return n;
    }

    find(id) { return this.nodes.find(n => n.id === id); }

    // topmost live bubble under a world point
    hit(x, y) {
        for (let i = this.nodes.length - 1; i >= 0; i--) {
            const n = this.nodes[i];
            if (!n.dying && Math.hypot(x - n.x, y - n.y) <= n.ef) return n;
        }
        return null;
    }

    step(dt, now) {
        const o = this.opts, W = this.w, H = this.h;
        this.nodes = this.nodes.filter(n => !(n.dying && now - n.dying > 340));
        this.hits = [];
        const was = this.touching, now_ = {};
        // a contact starts when they really meet and lasts until they are 3 px apart; it knocks once, as it starts
        const knock = (key, speed) => { if (!was[key] && speed > 0) this.hits.push(speed); };
        const ns = this.nodes;

        for (const n of ns) {
            n.r += (n.rT - n.r) * (1 - Math.exp(-dt / 0.25));
            const life = n.dying ? Math.max(0, 1 - (now - n.dying) / 320) : easeBack(Math.min(1, (now - n.born) / 520));
            n.ef = Math.max(1, n.r * life);
            if (n.grab && this.dragTarget) {
                n.vx = clamp(n.vx + ((this.dragTarget.x - n.x) * o.grabK - n.vx * o.grabC) * dt, -2600, 2600);
                n.vy = clamp(n.vy + ((this.dragTarget.y - n.y) * o.grabK - n.vy * o.grabC) * dt, -2600, 2600);
            } else {
                n.hd += (Math.random() - 0.5) * dt * 10;
                n.vx += Math.cos(n.hd) * o.drift * dt;
                n.vy += Math.sin(n.hd) * o.drift * dt;
                const damp = Math.exp(-o.damping * dt);
                n.vx *= damp; n.vy *= damp;
            }
            n.x += n.vx * dt; n.y += n.vy * dt;
        }

        // four rounds, so packed bubbles end up touching instead of sunk into each other
        for (let it = 0; it < 4; it++) {
            for (let i = 0; i < ns.length; i++) for (let j = i + 1; j < ns.length; j++) {
                const a = ns[i], b = ns[j];
                const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 0.01, min = a.ef + b.ef + o.gap;
                if (it === 0 && o.spark && !a.dying && !b.dying) {
                    const gap = d - a.ef - b.ef;
                    if (gap > 0 && gap < o.sparkRange) {
                        const f = o.attract * (1 - gap / o.sparkRange) * dt / d;
                        if (!a.grab) { a.vx += dx * f; a.vy += dy * f; }
                        if (!b.grab) { b.vx -= dx * f; b.vy -= dy * f; }
                    }
                }
                const key = a.id + "|" + b.id;
                if (it === 0 && (was[key] ? d < min + 3 : d < min)) now_[key] = true;
                if (d >= min) continue;
                const nx = dx / d, ny = dy / d;
                const ia = a.grab ? 0 : 1 / (a.ef * a.ef), ib = b.grab ? 0 : 1 / (b.ef * b.ef), sum = ia + ib;
                if (!sum) continue;
                const ov = min - d;
                a.x -= nx * ov * ia / sum; a.y -= ny * ov * ia / sum;
                b.x += nx * ov * ib / sum; b.y += ny * ov * ib / sum;
                const vr = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
                if (vr < 0) {
                    if (it === 0) knock(key, -vr);
                    const jj = -(1 + o.bounce) * vr / sum;
                    a.vx -= jj * ia * nx; a.vy -= jj * ia * ny;
                    b.vx += jj * ib * nx; b.vy += jj * ib * ny;
                    const kick = Math.min(0.18, -vr / 2200) * o.jelly;
                    a.w = Math.min(0.22, a.w + kick); b.w = Math.min(0.22, b.w + kick);
                }
            }
        }

        for (const n of ns) {
            const r = n.ef, kick = v => Math.min(0.22, n.w + Math.abs(v) / 2600 * o.jelly);
            const near = (side, gap) => { const k = n.id + "|" + side; if (was[k] ? gap < 3 : gap < 0) now_[k] = true; };
            near("L", n.x - r); near("R", W - r - n.x); near("T", n.y - r); near("B", H - r - n.y);
            const wall = (side, v) => { knock(n.id + "|" + side, Math.abs(v) * 0.8); return -v * o.bounce; };   // a wall knock is a little softer
            if (n.x < r) { n.x = r; if (n.vx < 0) { n.w = kick(n.vx); n.vx = wall("L", n.vx); } }
            if (n.x > W - r) { n.x = W - r; if (n.vx > 0) { n.w = kick(n.vx); n.vx = wall("R", n.vx); } }
            if (n.y < r) { n.y = r; if (n.vy < 0) { n.w = kick(n.vy); n.vy = wall("T", n.vy); } }
            if (n.y > H - r) { n.y = H - r; if (n.vy > 0) { n.w = kick(n.vy); n.vy = wall("B", n.vy); } }
            n.ph += dt * 24; n.w *= Math.exp(-4.2 * dt);
        }

        this.touching = now_;

        // Squash: bubbles never pass into each other or out through a wall; what is left of an overlap when they are
        // packed tight is taken up by flattening both along the line between them (up to 30 %), and a bubble held
        // against a wall flattens against it. It eases back to round when the pressure goes.
        for (const n of ns) { n.sqT = 0; n.sqAT = n.sqA; }
        const press = (n, amount, angle) => { if (amount > n.sqT) { n.sqT = Math.min(0.3, amount); n.sqAT = angle; } };
        for (let i = 0; i < ns.length; i++) for (let j = i + 1; j < ns.length; j++) {
            const a = ns[i], b = ns[j];
            if (a.dying || b.dying) continue;
            const dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 0.01, ov = a.ef + b.ef - d;
            if (ov <= 0) continue;
            const ang = Math.atan2(dy, dx) * 180 / Math.PI;
            press(a, ov / 2 / a.ef, ang); press(b, ov / 2 / b.ef, ang);
        }
        if (this.dragTarget) for (const n of ns) {
            if (!n.grab) continue;
            const r = n.ef, t = this.dragTarget;
            const px = t.x < r ? r - t.x : t.x > W - r ? t.x - (W - r) : 0;
            const py = t.y < r ? r - t.y : t.y > H - r ? t.y - (H - r) : 0;
            if (px > 0) press(n, px / (r * 4), 0);
            if (py > 0) press(n, py / (r * 4), 90);
        }
        const ease = 1 - Math.exp(-dt / 0.07);
        for (const n of ns) {
            n.sq += (n.sqT - n.sq) * ease;
            if (n.sqT > 0) n.sqA = n.sqAT;
        }

        // lightning is regenerated every 3rd frame so it flickers instead of strobing
        if (++this.frame % 3 === 0) this.bolts = o.spark ? this.computeBolts() : { weak: "", mid: "", strong: "" };
    }

    computeBolts() {
        const o = this.opts, ns = this.nodes, B = { weak: "", mid: "", strong: "" };
        for (let i = 0; i < ns.length; i++) for (let j = i + 1; j < ns.length; j++) {
            const p = ns[i], q = ns[j];
            if (p.dying || q.dying) continue;
            const dx = q.x - p.x, dy = q.y - p.y, d = Math.hypot(dx, dy) || 0.01, g = d - p.ef - q.ef;
            if (g > o.sparkRange) continue;
            const I = 1 - Math.max(0, g) / o.sparkRange, ux = dx / d, uy = dy / d;
            const bucket = I > 0.75 ? "strong" : I > 0.4 ? "mid" : "weak";
            if (Math.random() > (bucket === "strong" ? 1 : bucket === "mid" ? 0.8 : 0.25 + I)) continue;
            const rot = r => { const a = (Math.random() - 0.5) * 0.7; return [(ux * Math.cos(a) - uy * Math.sin(a)) * r, (ux * Math.sin(a) + uy * Math.cos(a)) * r]; };
            const po = rot(p.ef), qo = rot(q.ef);
            const ax = p.x + po[0], ay = p.y + po[1], bx = q.x - qo[0], by = q.y - qo[1];
            const amp = Math.min(14, 3 + Math.max(4, g) * 0.16);
            B[bucket] += boltPath(ax, ay, bx, by, amp) + " ";
            if (bucket === "strong") {
                B.strong += boltPath(ax, ay, bx, by, amp * 0.6) + " ";
                p.w = Math.min(0.22, p.w + 0.01 * o.jelly); q.w = Math.min(0.22, q.w + 0.01 * o.jelly);
                if (Math.random() < 0.5) {
                    const mx = (ax + bx) / 2, my = (ay + by) / 2, s = Math.random() < 0.5 ? -1 : 1;
                    B.mid += boltPath(mx, my, mx + (-uy * s + ux * 0.4) * 20, my + (ux * s + uy * 0.4) * 20, 4) + " ";
                }
            }
        }
        return B;
    }
}
