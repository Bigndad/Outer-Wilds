pragma ComponentBehavior: Bound
import QtQuick
import ".."

// The visible Rumor Map. Loaded by RumorMap.qml ONLY while the map is open, so while it is closed none of
// this exists (no items, no canvas, no animations).
//
// Look: WidgetCard palette (cream / gold / dim, dark panels, gold corner brackets), region colours per app.
// Crisp text: like WidgetCard, every size is a multiple of `ui`, the zoom has fixed steps (no smooth scaling),
// and every position is rounded to whole pixels, so text is never resampled.
Item {
    id: view
    objectName: "rumorView"
    anchors.fill: parent

    signal faded()                           // emitted once the close fade has finished (RumorMap then unloads us)
    property bool revealed: false
    opacity: revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    onOpacityChanged: if (opacity <= 0.001 && !revealed) faded()

    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property color cDim: "#8A7F66"

    // ---------------- SCALE / CAMERA ----------------
    readonly property real vw: width
    readonly property real vh: height
    readonly property real baseUi: Math.max(0.75, Math.round(vh / 1080 * 16) / 16)   // HUD text, panels
    readonly property var zoomLevels: [0.4, 0.55, 0.7, 0.85, 1.0, 1.25, 1.5]               // map zoom steps (x baseUi)
    property int zoomIdx: 4
    readonly property real ui: Math.round(baseUi * zoomLevels[zoomIdx] * 16) / 16     // map card scale (1/16 steps)

    property real camX: 0                    // world point at the screen centre
    property real camY: 0
    property bool smoothCam: false           // true only for the single assignment that should glide
    Behavior on camX { enabled: view.smoothCam; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on camY { enabled: view.smoothCam; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // ---------------- DATA ----------------
    // Rebuilt automatically whenever RumorData.notifications changes (live arrival while open).
    property var graph: RumorData.buildGraph()
    property string cursorId: ""             // the highlighted card
    property string hoverId: ""
    property int _lastCount: -1

    // search / filter / dismiss state
    property bool searchOpen: false          // the search box has the keyboard
    property string query: ""
    property bool unreadOnly: false
    property string dismissingId: ""
    property string pendingCursor: ""
    readonly property bool filtering: query !== "" || unreadOnly
    readonly property int matchCount: {
        let c = 0;
        for (let i = 0; i < graph.nodes.length; i++) if (matches(graph.nodes[i])) c++;
        return c;
    }

    readonly property var cur: graph.byId[cursorId] !== undefined ? graph.byId[cursorId] : null
    readonly property string curState: cur ? RumorData.stateOfNode(cur) : ""

    function sxOf(wx) { return Math.round(vw / 2 + (wx - camX) * ui); }
    function syOf(wy) { return Math.round(vh / 2 + (wy - camY) * ui); }

    function cardScale(id) {
        const n = graph.byId[id];
        return (id === cursorId ? 1.28 : 1.0) * (n ? n.sizeK : 1.0);
    }

    // does this card pass the search text and the unread filter? (locked cards only match on app / thread, never on hidden text)
    function matches(n) {
        const st = RumorData.stateOfNode(n);
        if (unreadOnly && st !== "unread" && st !== "locked") return false;
        if (query === "") return true;
        const hay = (n.app + " " + n.thread + " " + (n.archive ? "archive older " : "") + (st === "locked" ? "" : n.summary + " " + n.body)).toLowerCase();
        const terms = query.toLowerCase().split(" ");
        for (let i = 0; i < terms.length; i++)
            if (terms[i] !== "" && hay.indexOf(terms[i]) < 0) return false;
        return true;
    }
    function snapCursorToMatch() {
        if (cur && matches(cur)) return;
        let best = null;
        for (let i = 0; i < graph.nodes.length; i++) {
            const n = graph.nodes[i];
            if (matches(n) && (!best || n.time > best.time)) best = n;
        }
        if (best) { cursorId = best.id; centerOn(best, true); }
    }
    onQueryChanged: { snapCursorToMatch(); edges.requestPaint(); }
    onUnreadOnlyChanged: { snapCursorToMatch(); edges.requestPaint(); }

    function nodeAt(mx, my) {
        // the highlighted (enlarged, on top) card wins, then the rest
        let order = cur ? [cur] : [];
        for (let i = graph.nodes.length - 1; i >= 0; i--) if (graph.nodes[i] !== cur) order = order.concat([graph.nodes[i]]);
        for (let i = 0; i < order.length; i++) {
            const n = order[i];
            const k = cardScale(n.id);
            const hw = Math.round(n.w * ui * k) / 2;
            const hh = Math.round(n.h * ui * k) / 2;
            if (Math.abs(mx - sxOf(n.x)) <= hw && Math.abs(my - syOf(n.y)) <= hh) return n.id;
        }
        return "";
    }

    function clampCam() {
        const b = graph.bounds;
        if (graph.nodes.length === 0) { camX = 0; camY = 0; return; }
        camX = Math.max(b.minX - 500, Math.min(b.maxX + 500, camX));
        camY = Math.max(b.minY - 500, Math.min(b.maxY + 500, camY));
    }

    function centerOn(n, smooth) {
        smoothCam = smooth;
        camX = n.x;
        camY = n.y;
        smoothCam = false;
    }

    function fitView() {
        const b = graph.bounds;
        smoothCam = false;
        if (graph.nodes.length === 0) { zoomIdx = 4; camX = 0; camY = 0; return; }
        const worldW = b.maxX - b.minX + 120;
        const worldH = b.maxY - b.minY + 120;
        const usableW = vw * 0.9;
        const usableH = vh - 300 * baseUi;       // room for the title bar and the detail panel
        let idx = 0;
        for (let i = 4; i >= 0; i--) {           // never zoom in past 1.0 just to fit
            const u = Math.round(baseUi * zoomLevels[i] * 16) / 16;
            if (worldW * u <= usableW && worldH * u <= usableH) { idx = i; break; }
        }
        zoomIdx = idx;
        camX = (b.minX + b.maxX) / 2;
        // centre the map in the free band between the title bar and the detail panel
        camY = (b.minY + b.maxY) / 2 + (50 * baseUi) / ui;
    }

    function defaultCursor() {
        // newest card you could read right now (unread and not locked); otherwise simply the newest
        let best = null;
        let bestAny = null;
        for (let i = 0; i < graph.nodes.length; i++) {
            const n = graph.nodes[i];
            if (!bestAny || n.time > bestAny.time) bestAny = n;
            if (RumorData.stateOfNode(n) === "unread" && (!best || n.time > best.time)) best = n;
        }
        const pick = best ? best : bestAny;
        return pick ? pick.id : "";
    }

    function initView() {
        fitView();
        cursorId = defaultCursor();          // the cursor only highlights; nothing is marked read by opening
        // if the whole map would be too small to read, open on the cursor card at a readable zoom instead
        // (HOME still gives the overview)
        if (ui < 0.5 * baseUi + 0.001 && cur) {
            zoomIdx = 3;
            centerOn(cur, false);
            camY += (50 * baseUi) / ui;
        }
    }

    function zoomBy(step, mx, my) {
        const ni = Math.max(0, Math.min(zoomLevels.length - 1, zoomIdx + step));
        if (ni === zoomIdx) return;
        const wx = camX + (mx - vw / 2) / ui;    // keep the world point under the pointer fixed
        const wy = camY + (my - vh / 2) / ui;
        smoothCam = false;
        zoomIdx = ni;
        camX = wx - (mx - vw / 2) / ui;
        camY = wy - (my - vh / 2) / ui;
        clampCam();
    }

    // Clicking a card selects it AND reads it (an explicit action). Locked cards can only be selected.
    function explore(id) {
        const n = graph.byId[id];
        if (!n) return;
        if (n.archive) {                         // spread the stack out; the cursor lands on its newest card
            const ids = n.ids;
            RumorData.toggleArchive(n.app);
            const last = graph.byId[ids[ids.length - 1]];
            if (last) { cursorId = last.id; centerOn(last, true); }
            return;
        }
        if (RumorData.stateOfNode(n) !== "locked") RumorData.markRead(id);
    }

    function openCur() {
        if (cur && !cur.archive && curState !== "locked") RumorData.openApp(cur.id);
    }
    function pinCur() {
        if (cur && !cur.archive) RumorData.togglePin(cur.id);
    }
    function dismissCur() {
        if (!cur || dismissingId !== "") return;
        // after the card fades, the cursor moves to its predecessor, else the nearest other card
        let next = (cur.parent !== "" && graph.byId[cur.parent]) ? cur.parent : "";
        if (next === "") {
            let bestD = 1e18;
            for (let i = 0; i < graph.nodes.length; i++) {
                const n = graph.nodes[i];
                if (n === cur) continue;
                const d = Math.hypot(n.x - cur.x, n.y - cur.y);
                if (d < bestD) { bestD = d; next = n.id; }
            }
        }
        pendingCursor = next;
        dismissingId = cur.id;
        dismissTimer.restart();
    }
    Timer {
        id: dismissTimer
        interval: 200
        onTriggered: {
            const n = view.graph.byId[view.dismissingId];
            if (n) RumorData.dismissMany(n.archive ? n.ids : [n.id]);
            view.dismissingId = "";
            const nx = view.graph.byId[view.pendingCursor];
            view.cursorId = nx ? nx.id : "";
            if (nx) view.centerOn(nx, true);
        }
    }
    function pick(id) {
        cursorId = id;
        explore(id);
    }

    // direction: 0 left, 1 right, 2 up, 3 down. Picks the nearest card in that direction, preferring aligned ones.
    function moveCursor(direction) {
        if (graph.nodes.length === 0) return;
        if (!cur) { cursorId = defaultCursor(); return; }
        let best = null;
        let bestScore = 1e18;
        for (let i = 0; i < graph.nodes.length; i++) {
            const n = graph.nodes[i];
            if (n === cur || !matches(n)) continue;
            const dx = n.x - cur.x;
            const dy = n.y - cur.y;
            let along = 0;
            let perp = 0;
            if (direction === 0) { along = -dx; perp = Math.abs(dy); }
            else if (direction === 1) { along = dx; perp = Math.abs(dy); }
            else if (direction === 2) { along = -dy; perp = Math.abs(dx); }
            else { along = dy; perp = Math.abs(dx); }
            if (along <= 8) continue;
            const score = along + perp * 2.2;
            if (score < bestScore) { bestScore = score; best = n; }
        }
        if (best) {
            cursorId = best.id;
            centerOn(best, true);
        }
    }

    // called by RumorMap.qml for every key press while open; RumorMap accepts the event afterwards (nothing leaks)
    function handleKey(event) {
        if (searchOpen) {
            if (event.key === Qt.Key_Escape) { query = ""; searchOpen = false; RumorData.typing = false; return; }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { searchOpen = false; RumorData.typing = false; return; }
            if (event.key === Qt.Key_Backspace) { query = query.slice(0, -1); return; }
            if (event.text.length > 0 && event.text >= " " && event.text !== "\u007f") { query = query + event.text; return; }
            // anything else (arrows, Home, ...) falls through to the normal keys below
        }
        switch (event.key) {
        case Qt.Key_Escape:
            if (filtering) { query = ""; unreadOnly = false; }     // first Escape clears the filter, the next one leaves
            else RumorData.hide();
            break;
        case Qt.Key_Left: moveCursor(0); break;
        case Qt.Key_Right: moveCursor(1); break;
        case Qt.Key_Up: moveCursor(2); break;
        case Qt.Key_Down: moveCursor(3); break;
        case Qt.Key_Return:
        case Qt.Key_Enter: explore(cursorId); break;
        case Qt.Key_Home: fitView(); break;
        case Qt.Key_Plus:
        case Qt.Key_Equal:
        case Qt.Key_PageUp: zoomBy(1, vw / 2, vh / 2); break;
        case Qt.Key_Minus:
        case Qt.Key_PageDown: zoomBy(-1, vw / 2, vh / 2); break;
        case Qt.Key_Slash: searchOpen = true; RumorData.typing = true; break;
        case Qt.Key_U: unreadOnly = !unreadOnly; break;
        case Qt.Key_O: openCur(); break;
        case Qt.Key_P: pinCur(); break;
        case Qt.Key_X:
        case Qt.Key_Delete: dismissCur(); break;
        default: break;
        }
    }

    function linkCount(id) {
        let c = 0;
        for (let i = 0; i < graph.links.length; i++)
            if (graph.links[i].from === id || graph.links[i].to === id) c++;
        return c;
    }

    Component.onDestruction: RumorData.typing = false

    Component.onCompleted: {
        revealed = Qt.binding(() => RumorData.open);   // set after creation so the fade-in animates
        _lastCount = graph.nodes.length;
        initView();
    }

    onGraphChanged: {
        if (_lastCount === 0 && graph.nodes.length > 0) initView();   // first rumor arrived while open
        _lastCount = graph.nodes.length;
        if (cursorId !== "" && graph.byId[cursorId] === undefined) cursorId = "";
        edges.requestPaint();
    }
    onCamXChanged: edges.requestPaint()
    onCamYChanged: edges.requestPaint()
    onUiChanged: edges.requestPaint()
    onWidthChanged: edges.requestPaint()
    onHeightChanged: edges.requestPaint()
    onCursorIdChanged: edges.requestPaint()
    Connections {
        target: RumorData
        function onReadIdsChanged() { edges.requestPaint(); }
    }

    // ---------------- BACKGROUND ----------------
    Rectangle {
        anchors.fill: parent
        color: "#F507080C"
    }

    // grid, links and (empty state) ghost cards: one canvas, repainted only when something it shows changes
    Canvas {
        id: edges
        anchors.fill: parent
        onPaint: view.paintAll(getContext("2d"), width, height)
    }

    function rgba(rgb, a) { return "rgba(" + rgb[0] + "," + rgb[1] + "," + rgb[2] + "," + a + ")"; }

    // point where a ray from a card centre (unit direction ux, uy) leaves the card rectangle
    function edgePoint(cx, cy, hw, hh, ux, uy, gap) {
        const tx = Math.abs(ux) > 1e-6 ? hw / Math.abs(ux) : 1e9;
        const ty = Math.abs(uy) > 1e-6 ? hh / Math.abs(uy) : 1e9;
        const t = Math.min(tx, ty) + gap;
        return { x: cx + ux * t, y: cy + uy * t };
    }

    function paintAll(ctx, w, h) {
        ctx.clearRect(0, 0, w, h);
        const u = ui;

        // world grid (faint), the origin axes a little stronger, like the crosshair in the game
        const step = 200;
        ctx.lineWidth = 1;
        const gx0 = Math.floor((camX - w / 2 / u) / step) * step;
        const gx1 = camX + w / 2 / u;
        for (let gx = gx0; gx <= gx1; gx += step) {
            const sx = Math.round(w / 2 + (gx - camX) * u) + 0.5;
            ctx.strokeStyle = gx === 0 ? "rgba(230,213,184,0.11)" : "rgba(212,175,55,0.045)";
            ctx.beginPath(); ctx.moveTo(sx, 0); ctx.lineTo(sx, h); ctx.stroke();
        }
        const gy0 = Math.floor((camY - h / 2 / u) / step) * step;
        const gy1 = camY + h / 2 / u;
        for (let gy = gy0; gy <= gy1; gy += step) {
            const sy = Math.round(h / 2 + (gy - camY) * u) + 0.5;
            ctx.strokeStyle = gy === 0 ? "rgba(230,213,184,0.11)" : "rgba(212,175,55,0.045)";
            ctx.beginPath(); ctx.moveTo(0, sy); ctx.lineTo(w, sy); ctx.stroke();
        }

        if (graph.nodes.length === 0) { paintGhosts(ctx, w, h); return; }

        const lw = Math.max(1, Math.round(u * 1.5));
        for (let i = 0; i < graph.links.length; i++) {
            const L = graph.links[i];
            const a = graph.byId[L.from];
            const b = graph.byId[L.to];
            if (!a || !b) continue;

            const ka = cardScale(a.id);
            const kb = cardScale(b.id);
            const ax = sxOf(a.x), ay = syOf(a.y), bx = sxOf(b.x), by = syOf(b.y);
            let dx = bx - ax, dy = by - ay;
            const len = Math.hypot(dx, dy);
            if (len < 2) continue;
            dx /= len; dy /= len;
            const p0 = edgePoint(ax, ay, a.w * u * ka / 2, a.h * u * ka / 2, dx, dy, 2);
            const p1 = edgePoint(bx, by, b.w * u * kb / 2, b.h * u * kb / 2, -dx, -dy, 2);
            // skip links entirely off screen
            if (Math.max(p0.x, p1.x) < 0 || Math.min(p0.x, p1.x) > w || Math.max(p0.y, p1.y) < 0 || Math.min(p0.y, p1.y) > h) continue;

            const touched = (a.id === cursorId || b.id === cursorId);
            const st = RumorData.stateOfNode(b);
            let col;
            if (touched) col = "rgba(212,175,55,0.95)";
            else if (st === "locked") col = "rgba(138,127,102,0.35)";
            else col = rgba(b.rgb, st === "unread" ? 0.85 : 0.5);

            ctx.globalAlpha = (filtering && !(matches(a) && matches(b))) ? 0.12 : 1.0;   // dim links between filtered-out cards
            ctx.strokeStyle = col;
            ctx.fillStyle = col;
            ctx.lineWidth = touched ? lw + 1 : (L.kind === "thread" ? lw : Math.max(1, lw - 1));
            if (ctx.setLineDash) ctx.setLineDash(L.kind === "app" ? [5 * u, 5 * u] : []);
            ctx.beginPath(); ctx.moveTo(p0.x, p0.y); ctx.lineTo(p1.x, p1.y); ctx.stroke();
            if (ctx.setLineDash) ctx.setLineDash([]);

            // arrow head at the later card (direction of time)
            const sz = 7 * u;
            const nx = -dy, ny = dx;
            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p1.x - dx * sz + nx * sz * 0.5, p1.y - dy * sz + ny * sz * 0.5);
            ctx.lineTo(p1.x - dx * sz - nx * sz * 0.5, p1.y - dy * sz - ny * sz * 0.5);
            ctx.closePath();
            ctx.fill();
            ctx.globalAlpha = 1.0;
        }
    }

    // empty state: four unlit "???" cards and two dotted links around the message
    function paintGhosts(ctx, w, h) {
        const b = baseUi;
        const gs = [[-390, -70], [-300, 100], [360, -50], [290, 120]];
        const gw = Math.round(132 * b), gh = Math.round(56 * b);
        ctx.strokeStyle = "rgba(138,127,102,0.35)";
        ctx.lineWidth = 1;
        if (ctx.setLineDash) ctx.setLineDash([3 * b, 5 * b]);
        const pairs = [[0, 1], [2, 3]];
        for (let i = 0; i < pairs.length; i++) {
            const A = gs[pairs[i][0]], B = gs[pairs[i][1]];
            ctx.beginPath();
            ctx.moveTo(Math.round(w / 2 + A[0] * b), Math.round(h / 2 + A[1] * b));
            ctx.lineTo(Math.round(w / 2 + B[0] * b), Math.round(h / 2 + B[1] * b));
            ctx.stroke();
        }
        if (ctx.setLineDash) ctx.setLineDash([5 * b, 4 * b]);
        ctx.font = Math.round(22 * b) + "px monospace";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        for (let i = 0; i < gs.length; i++) {
            const cx = Math.round(w / 2 + gs[i][0] * b), cy = Math.round(h / 2 + gs[i][1] * b);
            ctx.fillStyle = "rgba(7,8,12,0.9)";
            ctx.fillRect(cx - gw / 2, cy - gh / 2, gw, gh);
            ctx.strokeStyle = "rgba(138,127,102,0.45)";
            ctx.strokeRect(cx - gw / 2 + 0.5, cy - gh / 2 + 0.5, gw, gh);
            ctx.fillStyle = "rgba(138,127,102,0.55)";
            ctx.fillText("?", cx, cy);
        }
        if (ctx.setLineDash) ctx.setLineDash([]);
    }

    // ---------------- INPUT (drag = pan, wheel = zoom, click = select + read) ----------------
    // Sits BELOW the cards and fully covers the screen: nothing can reach the solar system underneath.
    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        preventStealing: true
        cursorShape: view.hoverId !== "" ? Qt.PointingHandCursor : (moved ? Qt.ClosedHandCursor : Qt.ArrowCursor)

        property real lastX: 0
        property real lastY: 0
        property real pressX: 0
        property real pressY: 0
        property bool moved: false
        property real wheelAcc: 0

        onPressed: (mouse) => {
            lastX = mouse.x; lastY = mouse.y;
            pressX = mouse.x; pressY = mouse.y;
            moved = false;
        }
        onPositionChanged: (mouse) => {
            if (pressed) {
                if (!moved && Math.hypot(mouse.x - pressX, mouse.y - pressY) > 5) moved = true;
                if (moved) {
                    view.smoothCam = false;
                    view.camX -= (mouse.x - lastX) / view.ui;
                    view.camY -= (mouse.y - lastY) / view.ui;
                    view.clampCam();
                }
                lastX = mouse.x; lastY = mouse.y;
            } else {
                view.hoverId = view.nodeAt(mouse.x, mouse.y);
            }
        }
        onReleased: (mouse) => {
            if (!moved && mouse.button === Qt.LeftButton) {
                const id = view.nodeAt(mouse.x, mouse.y);
                // click a card = select + read it; click the open card again, or empty space = let go (nothing is deleted)
                if (id === "" || id === view.cursorId) view.cursorId = "";
                else view.pick(id);
            }
            moved = false;
        }
        onExited: view.hoverId = ""
        onWheel: (wheel) => {
            wheelAcc += wheel.angleDelta.y;
            while (wheelAcc >= 120) { view.zoomBy(1, wheel.x, wheel.y); wheelAcc -= 120; }
            while (wheelAcc <= -120) { view.zoomBy(-1, wheel.x, wheel.y); wheelAcc += 120; }
            wheel.accepted = true;
        }
    }

    // ---------------- CLUSTER LABELS ----------------
    Repeater {
        model: view.graph.clusters
        delegate: Text {
            required property var modelData
            x: view.sxOf(modelData.x) - Math.round(width / 2)
            y: view.syOf(modelData.y) - Math.round(height / 2)
            visible: x + width > 0 && x < view.vw && y + height > 0 && y < view.vh
            text: modelData.app.toUpperCase()
            color: Qt.rgba(modelData.rgb[0] / 255, modelData.rgb[1] / 255, modelData.rgb[2] / 255, 0.9)
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(12 * view.ui))
            font.letterSpacing: 3 * view.ui
        }
    }

    // ---------------- NODE CARDS ----------------
    Repeater {
        model: view.graph.nodes
        delegate: Item {
            id: card
            required property var modelData

            readonly property bool sel: modelData.id === view.cursorId
            readonly property string st: RumorData.stateOfNode(modelData)     // unread | read | locked
            readonly property real m: view.ui * view.cardScale(modelData.id)
            readonly property bool crit: modelData.urgency === "critical"
            readonly property color rc: Qt.rgba(modelData.rgb[0] / 255, modelData.rgb[1] / 255, modelData.rgb[2] / 255, 1)
            readonly property int bw: Math.max(1, Math.round(m * (sel ? 2 : 1.5)))
            readonly property bool hasImg: modelData.image !== ""   // game-style picture card: title on top, picture below
            readonly property int band: Math.round((hasImg ? 24 : 14) * m)
            readonly property bool tiny: view.ui < 0.5          // too small for text: coloured block + letter only

            width: Math.round(modelData.w * m)
            height: Math.round(modelData.h * m)
            x: view.sxOf(modelData.x) - Math.round(width / 2)
            y: view.syOf(modelData.y) - Math.round(height / 2)
            visible: x + width > 0 && x < view.vw && y + height > 0 && y < view.vh
            z: sel ? 20 : (st === "unread" ? 5 : 1)

            // fades: dismissed (burning away), filtered out by search, old (aged) cards
            opacity: (modelData.id === view.dismissingId ? 0 : 1)
                * (view.matches(modelData) ? 1 : 0.14)
                * (modelData.aged && !sel ? 0.55 : 1)
            Behavior on opacity { NumberAnimation { duration: 180 } }

            // stack look for "N older" cards: two cards peeking out behind
            Rectangle {
                visible: card.modelData.archive
                x: Math.round(8 * card.m); y: Math.round(8 * card.m)
                width: card.width; height: card.height
                color: "#E60C0D12"
                border.width: 1; border.color: "#448A7F66"
            }
            Rectangle {
                visible: card.modelData.archive
                x: Math.round(4 * card.m); y: Math.round(4 * card.m)
                width: card.width; height: card.height
                color: "#E60E0F15"
                border.width: 1; border.color: "#668A7F66"
            }

            // soft glow behind unread, critical and highlighted cards
            Rectangle {
                visible: card.st === "unread" || card.sel || card.crit
                anchors.fill: parent
                anchors.margins: -Math.round((card.crit ? 7 : 5) * card.m)
                radius: Math.round(4 * card.m)
                color: card.crit && !card.sel ? Qt.rgba(0.89, 0.33, 0.30, 0.24)
                    : Qt.rgba(card.rc.r, card.rc.g, card.rc.b, card.sel ? 0.22 : 0.13)
            }

            Rectangle {
                anchors.fill: parent
                color: card.st === "locked" ? "#E6101015" : "#F00A0B10"
                border.width: card.bw
                border.color: card.sel ? view.cGold
                    : (card.crit ? "#E2554C"
                    : card.st === "locked" ? "#668A7F66"
                    : (card.st === "unread" ? card.rc : Qt.rgba(card.rc.r, card.rc.g, card.rc.b, 0.55)))
            }

            // coloured header band with the app name (like the game's coloured card tops)
            Rectangle {
                x: card.bw
                y: card.bw
                width: card.width - 2 * card.bw
                height: (card.tiny && !card.hasImg) ? card.height - 2 * card.bw : card.band
                color: card.st === "locked" ? "#4D8A7F66"
                    : Qt.rgba(card.rc.r, card.rc.g, card.rc.b, card.st === "read" ? 0.55 : 0.92)
                Text {
                    visible: card.tiny
                    anchors.centerIn: parent
                    text: card.st === "locked" ? "?" : card.modelData.app.charAt(0).toUpperCase()
                    color: card.st === "locked" ? view.cDim : "#0A0B10"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round(14 * card.m))
                }
                Text {
                    visible: !card.tiny
                    x: Math.round(5 * card.m)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Math.round(10 * card.m)
                    // picture cards put the title in the band (like the game); text cards put the app name there
                    text: card.st === "locked" ? "? ? ?" : (card.hasImg ? card.modelData.summary : card.modelData.app.toUpperCase())
                    wrapMode: card.hasImg ? Text.WordWrap : Text.NoWrap
                    maximumLineCount: card.hasImg ? 2 : 1
                    elide: Text.ElideRight
                    horizontalAlignment: card.hasImg ? Text.AlignHCenter : Text.AlignLeft
                    color: card.st === "locked" ? view.cDim : "#0A0B10"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round((card.hasImg ? 9 : 9) * card.m))
                    font.letterSpacing: card.hasImg ? 0 : 1 * card.m
                }
            }

            // thumbnail. Text cards: small monogram square. Picture cards: the picture fills the card below the title band
            // (the monogram stays as the placeholder while a picture loads or if it fails to load).
            Rectangle {
                id: thumb
                visible: !card.tiny || card.hasImg
                x: card.hasImg ? card.bw : card.bw + Math.round(4 * card.m)
                y: card.bw + card.band + (card.hasImg ? 0 : Math.round(4 * card.m))
                width: card.hasImg ? card.width - 2 * card.bw : card.height - card.band - 2 * card.bw - Math.round(8 * card.m)
                height: card.hasImg ? card.height - card.band - 2 * card.bw : card.height - card.band - 2 * card.bw - Math.round(8 * card.m)
                color: card.hasImg ? "#10E6D5B8" : "#14E6D5B8"
                border.width: card.hasImg ? 0 : 1
                border.color: card.st === "locked" ? "#338A7F66" : Qt.rgba(card.rc.r, card.rc.g, card.rc.b, 0.5)
                Text {
                    anchors.centerIn: parent
                    visible: !(card.hasImg && cardImg.status === Image.Ready && card.st !== "locked")
                    text: card.st === "locked" ? "?" : (card.modelData.archive ? String(card.modelData.count) : card.modelData.app.charAt(0).toUpperCase())
                    color: card.st === "locked" ? view.cDim : card.rc
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(10, Math.round((card.hasImg ? 26 : 18) * card.m))
                }
                Image {
                    id: cardImg
                    anchors.fill: parent
                    // locked cards never show their picture
                    source: (card.hasImg && card.st !== "locked") ? card.modelData.image : ""
                    visible: status === Image.Ready
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize.width: 256
                    sourceSize.height: 256
                }
            }

            Text {
                visible: !card.tiny && !card.hasImg
                x: thumb.x + thumb.width + Math.round(6 * card.m)
                y: thumb.y
                width: card.width - x - card.bw - Math.round(5 * card.m)
                height: thumb.height
                text: card.st === "locked" ? "???" : card.modelData.summary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: card.st === "locked" ? view.cDim : (card.st === "read" ? "#B9AB91" : view.cCream)
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(10 * card.m))
            }

            // "!" marker on unread cards (the game's unexplored-rumor marker)
            Rectangle {
                visible: card.st === "unread"
                width: Math.round(14 * card.m)
                height: width
                radius: width / 2
                x: card.width - Math.round(width * 0.6)
                y: -Math.round(width * 0.4)
                color: card.crit ? "#E2554C" : view.cGold
                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#0A0B10"
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round(10 * card.m))
                }
            }

            // pin tag: pinned cards never age away or drop off the map
            Rectangle {
                visible: card.modelData.pinned
                width: Math.round(11 * card.m)
                height: width
                x: card.width - width - Math.round(3 * card.m)
                y: card.height - height - Math.round(3 * card.m)
                color: "#E607080C"
                border.width: 1
                border.color: view.cGold
                Text {
                    anchors.centerIn: parent
                    text: "P"
                    color: view.cGold
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(7, Math.round(8 * card.m))
                }
            }

            // gold corner brackets on the highlighted card (same as WidgetCard)
            Repeater {
                model: card.sel ? 4 : 0
                delegate: Item {
                    required property int index
                    readonly property bool atRight: index === 1 || index === 3
                    readonly property bool atBottom: index === 2 || index === 3
                    readonly property int arm: Math.round(9 * card.m)
                    readonly property int thick: Math.max(1, Math.round(card.m * 1.5))
                    width: arm
                    height: arm
                    x: (atRight ? card.width - arm : 0) + (atRight ? Math.round(3 * card.m) : -Math.round(3 * card.m))
                    y: (atBottom ? card.height - arm : 0) + (atBottom ? Math.round(3 * card.m) : -Math.round(3 * card.m))
                    Rectangle {
                        width: parent.width; height: parent.thick
                        y: parent.atBottom ? parent.height - height : 0
                        color: view.cGold
                    }
                    Rectangle {
                        height: parent.height; width: parent.thick
                        x: parent.atRight ? parent.width - width : 0
                        color: view.cGold
                    }
                }
            }
        }
    }

    // ---------------- SCREEN FRAME ----------------
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.round(18 * view.baseUi)
        color: "transparent"
        border.color: "#33D4AF37"
        border.width: Math.max(1, Math.round(view.baseUi))
    }

    // ---------------- TITLE + HINTS (top) ----------------
    Column {
        x: Math.round(40 * view.baseUi)
        y: Math.round(34 * view.baseUi)
        spacing: Math.round(6 * view.baseUi)
        Text {
            text: "SHIP LOG"
            color: view.cGold
            font.family: "monospace"
            font.bold: true
            font.pixelSize: Math.max(10, Math.round(22 * view.baseUi))
            font.letterSpacing: 5 * view.baseUi
        }
        Text {
            text: "RUMOR MAP   " + view.graph.nodes.length + " RUMORS   " + RumorData.unreadCount + " UNREAD"
            color: view.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(11 * view.baseUi))
            font.letterSpacing: 2 * view.baseUi
        }
        Text {
            text: "ARROWS select   ENTER read   DRAG pan   WHEEL zoom   HOME fit"
            color: "#AA8A7F66"
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * view.baseUi))
            font.letterSpacing: 1 * view.baseUi
        }
        Text {
            text: "O open   P pin   X dismiss   / search   U unread only"
            color: "#AA8A7F66"
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * view.baseUi))
            font.letterSpacing: 1 * view.baseUi
        }
    }

    // search / filter bar (shown while searching or while a filter is on)
    Rectangle {
        id: searchBar
        visible: view.searchOpen || view.filtering
        x: Math.round((view.width - width) / 2)
        y: Math.round(34 * view.baseUi)
        width: Math.round(searchText.implicitWidth + 28 * view.baseUi)
        height: Math.round(searchText.implicitHeight + 14 * view.baseUi)
        color: "#EA07080C"
        border.color: view.searchOpen ? view.cGold : "#668A7F66"
        border.width: Math.max(1, Math.round(view.baseUi))
        z: 30
        Text {
            id: searchText
            anchors.centerIn: parent
            text: "SEARCH  " + view.query + (view.searchOpen ? "_" : "")
                + "   " + view.matchCount + (view.matchCount === 1 ? " MATCH" : " MATCHES")
                + (view.unreadOnly ? "   UNREAD ONLY" : "")
            color: view.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(12 * view.baseUi))
            font.letterSpacing: 2 * view.baseUi
        }
    }

    component KeyChip: Item {
        id: chip
        property string label: ""
        property string keyName: ""
        property bool clickable: false
        signal clicked()
        width: row.width
        height: row.height
        Row {
            id: row
            spacing: Math.round(8 * view.baseUi)
            Text {
                text: chip.label
                color: view.cCream
                anchors.verticalCenter: parent.verticalCenter
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(12 * view.baseUi))
                font.letterSpacing: 2 * view.baseUi
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: keyText.width + Math.round(14 * view.baseUi)
                height: keyText.height + Math.round(8 * view.baseUi)
                color: "#E007080C"
                border.color: view.cGold
                border.width: Math.max(1, Math.round(view.baseUi))
                Text {
                    id: keyText
                    anchors.centerIn: parent
                    text: chip.keyName
                    color: view.cGold
                    font.family: "monospace"
                    font.pixelSize: Math.max(8, Math.round(11 * view.baseUi))
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: chip.clickable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Row {
        id: topRight
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.round(38 * view.baseUi)
        anchors.rightMargin: Math.round(40 * view.baseUi)
        spacing: Math.round(30 * view.baseUi)
        KeyChip { label: "ZOOM VIEW"; keyName: "WHEEL" }
        KeyChip {
            label: "LEAVE SHIP LOG"
            keyName: "ESC / " + RumorData.toggleKey
            clickable: true
            onClicked: RumorData.hide()
        }
    }

    // ---------------- DETAIL PANEL (bottom, like the game's text box) ----------------
    WidgetCard {
        id: detail
        visible: view.cur !== null
        ui: view.baseUi
        title: view.cur ? view.cur.app.toUpperCase() : ""
        designW: Math.round(Math.min(view.vw * 0.62, 920 * view.baseUi) / view.baseUi)
        designH: 160
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(40 * view.baseUi)
        z: 30

        // swallows clicks so a click on the panel never pans or selects; a plain left click on it lets go of the card
        // (the buttons sit above this and keep working)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: (mouse) => { if (mouse.button === Qt.LeftButton) view.cursorId = ""; }
            onWheel: (wheel) => { wheel.accepted = true; }
        }

        Item {
            anchors.fill: parent
            readonly property bool locked: view.curState === "locked"
            readonly property bool showPic: view.cur !== null && view.cur.image !== "" && !locked
            readonly property real textLeft: showPic ? Math.round(picBox.width + 14 * view.baseUi) : 0

            // picture (avatar / thumbnail), when the notification has one
            Rectangle {
                id: picBox
                visible: parent.showPic
                width: Math.round(96 * view.baseUi)
                height: width
                anchors.top: parent.top
                anchors.left: parent.left
                color: "#14E6D5B8"
                border.width: Math.max(1, Math.round(view.baseUi))
                border.color: view.cGold
                Text {
                    anchors.centerIn: parent
                    visible: picImg.status !== Image.Ready
                    text: view.cur ? view.cur.app.charAt(0).toUpperCase() : ""
                    color: view.cDim
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(10, Math.round(34 * view.baseUi))
                }
                Image {
                    id: picImg
                    anchors.fill: parent
                    anchors.margins: Math.max(1, Math.round(view.baseUi))
                    source: parent.visible && view.cur ? view.cur.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    sourceSize.width: 256
                    sourceSize.height: 256
                }
            }

            Text {
                id: dSummary
                anchors.left: parent.left
                anchors.leftMargin: parent.textLeft
                anchors.right: dTime.left
                anchors.rightMargin: Math.round(12 * view.baseUi)
                text: view.cur ? (parent.locked ? "???" : view.cur.summary) : ""
                elide: Text.ElideRight
                color: view.cCream
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(15 * view.baseUi))
            }
            Text {
                id: dTime
                anchors.right: parent.right
                anchors.verticalCenter: dSummary.verticalCenter
                text: view.cur && !parent.locked ? RumorData.formatTime(view.cur.time) : ""
                color: view.cDim
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(11 * view.baseUi))
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: parent.textLeft
                anchors.right: parent.right
                anchors.top: dSummary.bottom
                anchors.topMargin: Math.round(8 * view.baseUi)
                anchors.bottom: dActions.top
                anchors.bottomMargin: Math.round(6 * view.baseUi)
                text: view.cur ? (parent.locked
                    ? "Locked. Read the previous message in this thread to reveal this one."
                    : view.cur.body) : ""
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                color: parent.locked ? view.cDim : "#CDBFA6"
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(12 * view.baseUi))
                lineHeight: 1.15
            }
            Row {
                id: dActions
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Math.round(14 * view.baseUi)
                KeyChip { visible: view.cur !== null && view.cur.archive; label: "EXPAND"; keyName: "ENTER"; clickable: true; onClicked: view.explore(view.cursorId) }
                KeyChip { visible: view.cur !== null && !view.cur.archive && view.curState !== "locked"; label: "OPEN"; keyName: "O"; clickable: true; onClicked: view.openCur() }
                KeyChip { visible: view.cur !== null && !view.cur.archive; label: view.cur && view.cur.pinned ? "UNPIN" : "PIN"; keyName: "P"; clickable: true; onClicked: view.pinCur() }
                KeyChip { visible: view.cur !== null; label: view.cur && view.cur.archive ? "CLEAR" : "DISMISS"; keyName: "X"; clickable: true; onClicked: view.dismissCur() }
            }
            Text {
                id: dFooter
                anchors.left: parent.left
                anchors.right: dActions.left
                anchors.rightMargin: Math.round(12 * view.baseUi)
                anchors.verticalCenter: dActions.verticalCenter
                elide: Text.ElideRight
                text: view.cur
                    ? (view.cur.archive
                       ? "ARCHIVE STACK   " + view.cur.count + " OLDER"
                       : ((view.cur.urgency === "critical" ? "CRITICAL   " : "")
                          + (view.curState === "unread" ? "NEW RUMOR" : (view.curState === "read" ? "EXPLORED" : "LOCKED"))
                          + (view.cur.pinned ? "   PINNED" : "")
                          + "   " + (view.cur.thread !== "" ? "THREAD: " + view.cur.thread.toUpperCase() : "NO THREAD")
                          + "   LINKED TO " + view.linkCount(view.cur.id)))
                    : ""
                color: view.cDim
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(10 * view.baseUi))
                font.letterSpacing: 2 * view.baseUi
            }
        }
    }

    // ---------------- EMPTY STATE (first open with no history) ----------------
    WidgetCard {
        id: emptyCard
        visible: view.graph.nodes.length === 0
        ui: view.baseUi
        title: "SHIP LOG"
        designW: 440
        designH: 170
        anchors.centerIn: parent
        z: 30

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true; }
        }

        Column {
            anchors.fill: parent
            spacing: Math.round(10 * view.baseUi)
            Text {
                text: "NO RUMORS YET"
                color: view.cGold
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(17 * view.baseUi))
                font.letterSpacing: 3 * view.baseUi
            }
            Text {
                width: parent.width
                text: "Nothing has reached the ship log yet. Notifications you receive will appear here as cards, linked by app and thread."
                wrapMode: Text.WordWrap
                color: "#B9AB91"
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(12 * view.baseUi))
                lineHeight: 1.15
            }
            Text {
                text: "[ESC] or [" + RumorData.toggleKey + "] to leave"
                color: view.cDim
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(10 * view.baseUi))
                font.letterSpacing: 2 * view.baseUi
            }
        }
    }
}
