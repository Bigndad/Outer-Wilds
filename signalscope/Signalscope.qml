import QtQuick
import QtQuick.Shapes
import ".."

// =====================================================================
//  Signalscope: Outer Wilds style scope overlay. Put ONE inside CameraRig:
//
//      Signalscope { anchors.fill: parent; rig: root }
//
//  * z 30000: above WidgetLayer (29000) and the HUD (26000), below the Rumor Map (40000).
//  * Input-transparent (no MouseArea). Keys are window Shortcuts that only exist while it makes sense.
//  * Aiming reuses the rig's own mechanics: a channel switch sets rig.targetedPlanetId, the rig turns the
//    camera to it every frame, and any drag / right click drops that target, so "locked but movable" is free.
//  * Idle cost when stowed: the overlay is invisible and its frame hook is disabled.
//  * State (channels, aimed / locked ids, commands) lives in SignalscopeData.
// =====================================================================
Item {
    id: scope

    property var rig: null
    z: 30000

    readonly property bool on: SignalscopeData.equipped
    readonly property bool keysLive: rig !== null && (typeof RumorData === "undefined" || !RumorData.open)
                                      && (typeof MapData === "undefined" || !MapData.open)

    // ---------------- tuning knobs ----------------
    readonly property real u: Math.max(0.6, height / 1080.0)
    // AIMING: the screen centre is the aim point (the camera moves, as in the game). Every channel has its own pair of
    // white brackets, centred on the screen. A pair is wide open while its planet is far from the centre and closes
    // as the planet comes closer; when the planet reaches the centre the pair is shut around it (planet inside the
    // brackets = locked, green ring). "cursor" would aim with the mouse pointer instead.
    // A channel switch (Left/Right) targets a planet in the rig, which turns the camera so it sits at the centre.
    readonly property string aimSource: "center"                // "center" | "cursor"
    readonly property real lockEnter: 40 * u                    // px: planet edge this close to the aim point = locked
    readonly property real lockExit: lockEnter * 1.5            // px: stays locked a bit past that (no flicker)
    readonly property real coneRad: width * 0.12                // px: close enough to be "heard" (label + waveform)
    readonly property real minGap: 30 * u                       // px: half-gap of a pair shut around a small planet
    readonly property real openGap: width * 0.43                // px: half-gap of a pair whose planet is far from the aim point
    readonly property real farPx: width * 0.5                   // px: this far (or more) from the aim point = pair fully open
    readonly property real textScale: 1.0
    readonly property bool showHints: true

    readonly property string fontFamily: "monospace"
    readonly property color cWhite: "#F2EBDD"
    readonly property color cFreq: "#F0C040"
    readonly property color cCyan: "#6FEAEE"
    readonly property color cOrange: "#E98B55"
    readonly property color cLock: "#3CE06A"
    readonly property color cDim: "#99F2EBDD"

    opacity: on ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 180 } }

    // ---------------- per-frame state ----------------
    property var sig: []                // per channel: { ok, base, eff (px, aim point to planet edge), gap (px), dist, planet }
    property real aimAmt: 0             // 0..1 something is in the cone
    property real lockAmt: 0            // 0..1 locked
    property real distM: 0
    property string aimedPlanet: ""
    property real _acc: 0
    property real _t: 0

    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)); }

    function frame() {
        const rg = scope.rig;
        if (!rg) return;
        const D = SignalscopeData;
        const dt = Math.min(rg.lastDt > 0 ? rg.lastDt : 0.016, 0.1);
        _t += dt;

        const chs = D.channels;
        const out = [];
        const cx = width * 0.5, cy = height * 0.5;
        const useCursor = aimSource === "cursor" && rg.cursorIn;
        let bestI = -1, bestEff = 1e9;
        for (let i = 0; i < chs.length; i++) {
            const pm = rg.projectedMap[chs[i].planet];
            const body = rg.bodyCoords[chs[i].planet];
            if (!pm || !pm.visible || !body) { out.push({ ok: false }); continue; }
            // aim point: the pointer, except for the channel the rig is currently turned to (that one aims from the centre)
            const centred = rg.targetedPlanetId === chs[i].planet;
            const ax = (useCursor && !centred) ? rg.cursorX : cx;
            const ay = (useCursor && !centred) ? rg.cursorY : cy;
            const eff = Math.max(0, Math.hypot(ax - pm.sx, ay - pm.sy) - pm.screenR);   // aim point -> planet EDGE, px
            const t = clamp((eff - lockEnter) / (farPx - lockEnter), 0, 1);
            const wd = Math.hypot(body.x - rg.camX, body.y - rg.camY, body.z - rg.camZ);
            const shut = Math.max(pm.screenR * 1.35, minGap);                          // pair shut around this planet
            out.push({ ok: true, base: shut, t: t, eff: eff, gap: shut + (openGap - shut) * t,
                       dist: Math.max(0, wd - body.r), planet: chs[i].planet });
            if (eff < coneRad && eff < bestEff) { bestEff = eff; bestI = i; }
        }
        sig = out;

        const bestId = bestI >= 0 ? chs[bestI].id : "";
        let locked = "";
        if (bestId !== "") {
            const th = (bestId === D.lockedId) ? lockExit : lockEnter;
            if (bestEff < th) locked = bestId;
        }
        if (D.aimedId !== bestId) D.aimedId = bestId;
        if (D.lockedId !== locked) {
            D.lockedId = locked;
            if (locked !== "") D.lastId = locked;
        }


        const k = Math.min(1, 10 * dt);
        aimAmt += ((bestI >= 0 ? 1 : 0) - aimAmt) * k;
        lockAmt += ((locked !== "" ? 1 : 0) - lockAmt) * k;
        if (bestI >= 0) {
            distM = Math.round(out[bestI].dist * D.metersPerUnit);
            aimedPlanet = out[bestI].planet;
        }

        _acc += dt;
        if (_acc >= 0.033) { _acc = 0; updateWave(bestI); }
    }

    // ---------------- waveform ----------------
    function bandAt(k, chIdx) {
        if (SignalscopeData.useHudBands && typeof HudData !== "undefined") {
            const a = HudData.bandsA, b = HudData.bandsB;
            return [a.x, a.y, a.z, a.w, b.x, b.y, b.z, b.w][k];
        }
        const wob = 0.5 + 0.5 * Math.sin(_t * (1.7 + 0.55 * k) + k * 1.3 + chIdx * 2.1);
        return Math.min(1, Math.pow(wob, 1.5) * (1 - 0.06 * k) * 1.15);
    }

    function updateWave(bestI) {
        const ch = bestI >= 0 ? SignalscopeData.channels[bestI] : null;
        const playing = !!ch && ch.playing && !ch.muted;
        const amp = ch ? (playing ? 1.0 : 0.12) : 0.05;
        const bands = [];
        for (let k = 0; k < 8; k++) bands.push(playing ? bandAt(k, bestI) : 0.3);

        const N = 72, w = waveBox.width, h = waveBox.height;
        const pts = [];
        for (let i = 0; i <= N; i++) {
            const uu = i / N;
            let s = 0;
            for (let k = 0; k < 8; k++) s += bands[k] * Math.sin(uu * (6 + k * 7.0) + _t * (3 + k * 1.3) + k * 1.7);
            s /= 4.0;
            const env = 0.35 + 0.65 * Math.sin(Math.PI * uu);
            const noise = (Math.random() - 0.5) * (playing ? 0.35 : 0.9);
            const y = clamp(s * amp * env + noise * (0.06 + 0.2 * amp), -1, 1);
            pts.push(Qt.point(uu * w, h * 0.5 - y * h * 0.5));
        }
        wavePoly.path = pts;
    }

    // ---------------- keys ----------------
    Shortcut {
        sequence: SignalscopeData.keys.toggle
        enabled: scope.keysLive
        autoRepeat: false
        onActivated: SignalscopeData.dispatch("toggle")
    }
    Shortcut { sequence: SignalscopeData.keys.chanPrev;  enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("chan-prev") }
    Shortcut { sequence: SignalscopeData.keys.chanNext;  enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("chan-next") }
    Shortcut { sequence: SignalscopeData.keys.playPause; enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("playpause") }
    Shortcut { sequence: SignalscopeData.keys.trackPrev; enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("track-prev") }
    Shortcut { sequence: SignalscopeData.keys.trackNext; enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("track-next") }
    Shortcut { sequence: SignalscopeData.keys.mute;      enabled: scope.keysLive && scope.on; autoRepeat: false; onActivated: SignalscopeData.dispatch("mute") }
    Shortcut { sequence: SignalscopeData.keys.volUp;     enabled: scope.keysLive && scope.on; autoRepeat: true;  onActivated: SignalscopeData.dispatch("vol-up") }
    Shortcut { sequence: SignalscopeData.keys.volDown;   enabled: scope.keysLive && scope.on; autoRepeat: true;  onActivated: SignalscopeData.dispatch("vol-down") }

    // ---------------- rig hooks ----------------
    Connections {
        target: scope.rig
        enabled: scope.on && scope.rig !== null
        function onFrameUpdated() { scope.frame(); }
    }
    Connections {
        target: SignalscopeData
        function onEquippedChanged() {
            // free the camera so the scope can sweep around; position and speed are untouched
            if (SignalscopeData.equipped && scope.rig) scope.rig.lockedPlanetId = "";
        }
        function onAlignRequested(planetId) {
            if (!scope.rig) return;
            scope.rig.lockedPlanetId = "";
            scope.rig.targetedPlanetId = planetId;      // the rig turns the camera to it; a drag breaks it
        }
    }

    // ---------------- brackets (centre of the screen) ----------------
    readonly property real bandY: height * 0.5
    readonly property real bandH: 60 * u

    // one "(" or ")" bracket, centred on the screen. gap = distance of its tip from the centre, h = its height,
    // thDeg = half the angle the arc sweeps. At thDeg 90 with h = 2 * gap the left and right brackets are the two
    // halves of one circle, which is how a shut pair turns into the lock ring.
    component Paren: Shape {
        id: pr
        property bool isRight: false
        property real h: 70
        property real thDeg: 50
        property real gap: 100
        property color col: "white"
        property real lw: 2
        readonly property real th: thDeg * Math.PI / 180
        readonly property real rad: h / (2 * Math.sin(th))
        readonly property real depth: rad * (1 - Math.cos(th))
        width: depth + 2 * lw
        height: h + 2 * lw
        x: isRight ? scope.width * 0.5 + gap - width + lw : scope.width * 0.5 - gap - lw
        y: scope.bandY - height * 0.5
        ShapePath {
            strokeColor: pr.col
            strokeWidth: pr.lw
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: pr.isRight ? pr.lw - pr.rad * Math.cos(pr.th) : pr.lw + pr.rad
                centerY: pr.lw + pr.h * 0.5
                radiusX: pr.rad
                radiusY: pr.rad
                startAngle: pr.isRight ? -pr.thDeg : 180 - pr.thDeg
                sweepAngle: 2 * pr.thDeg
            }
        }
    }

    // outermost thin lines
    Repeater {
        model: 2
        Rectangle {
            required property int index
            width: Math.max(2, 3 * scope.u)
            height: scope.bandH * 0.95
            radius: width / 2
            color: scope.cWhite
            opacity: 0.85
            x: scope.width * 0.5 + (index === 0 ? -1 : 1) * scope.width * 0.455 - width / 2
            y: scope.bandY - height / 2
        }
    }

    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }

    // one white pair per channel. It closes in as THAT planet nears the centre, and as it closes it also bends from an
    // open "( )" into the two halves of a circle around the planet; once locked it turns green: the lock ring IS the brackets.
    Repeater {
        model: SignalscopeData.channels
        Item {
            id: pair
            required property int index
            required property var modelData
            readonly property var s: scope.sig[index]
            readonly property bool ok: !!s && s.ok
            readonly property bool isAimed: modelData.id === SignalscopeData.aimedId
            readonly property bool isLocked: modelData.id === SignalscopeData.lockedId
            readonly property real closure: ok ? 1 - s.t : 0                   // 0 = wide open, 1 = shut around the planet
            readonly property real e: closure * closure                         // the bend only really happens near the end
            readonly property real openH: scope.bandH * 0.78
            readonly property real shutH: ok ? 2 * s.base : openH                // circle diameter when shut
            readonly property real bh: openH + (shutH - openH) * e
            readonly property real thd: 50 + 40 * e                             // 50 deg ( ) ... 90 deg = half a circle each
            readonly property real g: ok ? s.gap : scope.openGap
            readonly property color col: scope.mix(scope.cWhite, scope.cLock, isLocked ? scope.lockAmt : 0)
            readonly property real lwid: Math.max(3, (isAimed ? 5.5 : 4) * scope.u)
            visible: ok
            opacity: isAimed ? 1.0 : 0.6
            Paren { isRight: false; h: pair.bh; thDeg: pair.thd; gap: pair.g; col: pair.col; lw: pair.lwid }
            Paren { isRight: true;  h: pair.bh; thDeg: pair.thd; gap: pair.g; col: pair.col; lw: pair.lwid }
        }
    }

    // small centre pip while nothing is locked
    Rectangle {
        width: 5 * scope.u
        height: width
        radius: width / 2
        color: scope.cWhite
        x: scope.width * 0.5 - width / 2
        y: scope.bandY - height / 2
        opacity: 0.6 * (1 - scope.lockAmt)
    }

    // ---------------- readout: PLANET NAME: 27037m ----------------
    readonly property var aimedCh: SignalscopeData.aimedChannel
    readonly property real aimedBase: {
        const i = SignalscopeData.channelIndex(SignalscopeData.aimedId);
        return (i >= 0 && sig[i] && sig[i].ok) ? sig[i].base : 0;
    }
    readonly property string signalName: {
        if (!rig || aimedPlanet === "") return "";
        const m = rig.bodyMeta[aimedPlanet];
        return m ? m.name.toUpperCase() : aimedPlanet.toUpperCase();
    }

    Row {
        id: readout
        spacing: 0
        opacity: scope.aimAmt
        anchors.horizontalCenter: parent.horizontalCenter
        // below the brackets (and below the ring, which grows with a big planet)
        y: scope.bandY + Math.max(80 * scope.u, scope.aimedBase + 26 * scope.u)
        Text {
            text: scope.signalName + ": "
            color: scope.cWhite
            font.family: scope.fontFamily
            font.pixelSize: Math.round(34 * scope.u * scope.textScale)
        }
        Text {
            text: scope.distM + "m"
            color: scope.cOrange
            font.family: scope.fontFamily
            font.pixelSize: Math.round(34 * scope.u * scope.textScale)
        }
    }

    // ---------------- frequency + waveform ----------------
    Column {
        id: freqBlock
        spacing: 4 * scope.u
        anchors.horizontalCenter: parent.horizontalCenter
        // sits just above the waveform
        y: waveBox.y - height - 14 * scope.u
        opacity: scope.aimAmt
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "FREQUENCY:"
            color: scope.cWhite
            font.family: scope.fontFamily
            font.pixelSize: Math.round(22 * scope.u * scope.textScale)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scope.aimedCh ? scope.aimedCh.name : ""
            color: scope.cFreq
            font.family: scope.fontFamily
            font.pixelSize: Math.round(22 * scope.u * scope.textScale)
            font.letterSpacing: 1 * scope.u
        }
    }

    Item {
        id: waveBox
        width: Math.min(scope.width * 0.4, 560 * scope.u)
        height: 60 * scope.u
        x: scope.width * 0.5 - width / 2
        y: scope.height * 0.77
        Rectangle { x: 0; width: Math.max(2, 2 * scope.u); height: parent.height; color: scope.cCyan; opacity: 0.9 }
        Rectangle { x: parent.width - width; width: Math.max(2, 2 * scope.u); height: parent.height; color: scope.cCyan; opacity: 0.9 }
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: (scope.aimedCh && scope.aimedCh.muted) ? "#806FEAEE" : scope.cCyan
                strokeWidth: Math.max(1.5, 2 * scope.u)
                fillColor: "transparent"
                joinStyle: ShapePath.RoundJoin
                PathPolyline { id: wavePoly; path: [] }
            }
        }
    }

    // status under the waveform (only while something is in the cone)
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: waveBox.y + waveBox.height + 10 * scope.u
        opacity: scope.aimAmt
        font.family: scope.fontFamily
        font.pixelSize: Math.round(15 * scope.u * scope.textScale)
        color: scope.cDim
        text: {
            const c = scope.aimedCh;
            if (!c) return "";
            const st = c.muted ? "MUTED" : (c.playing ? "PLAYING" : "PAUSED");
            const tt = c.title !== "" ? (c.title + (c.artist !== "" ? "  -  " + c.artist : "")) : "";
            return st + "  " + Math.round(c.volume * 100) + "%" + (tt !== "" ? "    " + tt : "");
        }
    }

    // ---------------- key hints ----------------
    Text {
        visible: scope.showHints
        anchors.horizontalCenter: parent.horizontalCenter
        y: scope.height - 44 * scope.u
        font.family: scope.fontFamily
        font.pixelSize: Math.round(13 * scope.u)
        color: scope.cDim
        text: {
            const k = SignalscopeData.keys;
            if (SignalscopeData.channels.length === 0)
                return "NO SIGNALS  -  START SOME MUSIC   [" + k.toggle + "] STOW";
            let s = "[" + k.toggle + "] STOW   [" + k.chanPrev + "/" + k.chanNext + "] CHANNEL";
            if (SignalscopeData.lockedId !== "")
                s += "   [" + k.playPause + "] PLAY/PAUSE   [" + k.trackPrev + " " + k.trackNext + "] TRACK   [" + k.mute + "] MUTE   [" + k.volUp + "/" + k.volDown + "] VOLUME";
            else
                s += "   AIM AT A SIGNAL TO TUNE IN";
            return s;
        }
    }

    // ---------------- scope model slot ----------------
    // The 3D signalscope mesh goes here later (bottom right, as in the game). Anchored and sized, nothing in it yet.
    Item {
        id: meshSlot
        objectName: "signalscopeMesh"
        width: scope.width * 0.5
        height: scope.height * 0.55
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: scope.on
    }
}
