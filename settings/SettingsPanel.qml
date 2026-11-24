import QtQuick
import ".."

// CONTROL CENTRE + detached left-side Pop-out Widget Inspector.
// Plain QtQuick only (no Quickshell import), so it also runs in `qml` on the Mint laptop.
Item {
    id: root

    signal closeRequested()
    signal flyRequested(string planetId)
    signal fileBrowseRequested(string title, string zenFilter, string kdFilter, var callback)
    signal presetExportRequested(string presetName, string jsonText)
    signal presetImportRequested()

    readonly property bool inspectorOpen: root.tab === "widgets" && root.expandedId !== "" && !root.picking && root.inspEntry !== null
    readonly property bool inspectorShown: inspectorOpen || inspectorPanel.slide > 0.01
    readonly property var inspEntry: root.expandedId !== "" ? WidgetConfig.entry(root.expandedId) : null
    readonly property alias mainPanelItem: mainHit
    readonly property alias inspectorHitItem: inspHit

    Item {
        id: mainHit
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: WidgetConfig.panelOpen ? 420 : 0
    }

    Item {
        id: inspHit
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        anchors.right: mainHit.left
        anchors.rightMargin: 10
        width: (root.inspectorOpen && WidgetConfig.panelOpen) ? 380 : 0
    }
    property string inspectorTab: "orbit"    // orbit | card | options
    property real panelSlide: WidgetConfig.panelOpen ? 1.0 : 0.0
    Behavior on panelSlide { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    readonly property bool panelShown: WidgetConfig.panelOpen || panelSlide > 0.01
    implicitWidth: 810

    readonly property var systemFonts: {
        const pinned = ["monospace", "sans-serif", "serif"];
        const seen = { "monospace": 1, "sans-serif": 1, "serif": 1 };
        const list = Qt.fontFamilies();
        const out = pinned.slice();
        for (let i = 0; i < list.length; i++) {
            const f = list[i];
            if (f && !seen[f]) { seen[f] = 1; out.push(f); }
        }
        return out;
    }
    readonly property var planetChoices: {
        const out = [];
        for (let i = 0; i < WidgetConfig.planets.length; i++) {
            const pl = WidgetConfig.planets[i];
            out.push({ value: pl.id, label: pl.name, dot: WidgetConfig.planetColor(pl.id) });
        }
        return out;
    }

    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property color cDim: "#8A7F66"
    readonly property color cOff: "#4A4536"
    readonly property color cLine: "#33D4AF37"
    readonly property color cHover: "#1AD4AF37"
    readonly property color cDanger: "#D9694A"
    readonly property string mono: "monospace"

    readonly property string tab: WidgetConfig.panelTab

    property string expandedId: ""
    onTabChanged: { if (tab !== "widgets" && expandedId !== "") { expandedId = ""; WidgetConfig.previewId = ""; } }
    property string query: ""
    property var collapsed: ({})
    property var optOpen: ({})
    function toggleOpt(k) {
        const c = {};
        for (const x in optOpen) c[x] = optOpen[x];
        c[k] = !(optOpen[k] === true);
        optOpen = c;
    }
    property bool picking: false
    property string pickMode: "add"
    property string pickTarget: ""
    property string pickQuery: ""
    property bool confirmReset: false
    property string confirmPlanet: ""       // BACKUP & RESET PLANET: the planet waiting for its second click
    property string pickGroup: ""           // add-widget list: only this catalog group ("" = all)
    property var pickGroups: []
    property bool confirmClean: false
    property bool confirmAll: false
    property string lastHost: "timber_hearth"
    property string capturing: ""
    property string capLone: ""
    property string capHeld: ""
    onCapturingChanged: { WidgetConfig.capturingKeys = (capturing !== ""); capLone = ""; capHeld = ""; }
    property string keyMsg: ""
    property string presetMsg: ""
    property bool confirmClearNotifs: false
    property int textFocusCount: 0
    readonly property bool isTyping: textFocusCount > 0
    focus: true

    // Control Centre runs in its own exclusive-focus layer window, so it owns the toggle keys while open
    Shortcut {
        sequence: Keybinds.seq("edit")
        enabled: WidgetConfig.panelOpen && root.capturing === "" && !root.isTyping && Keybinds.seq("edit") !== ""
        autoRepeat: false
        onActivated: root.closeRequested()
    }
    Shortcut {
        sequence: Keybinds.seq("keys")
        enabled: WidgetConfig.panelOpen && root.capturing === "" && !root.isTyping && Keybinds.seq("keys") !== ""
        autoRepeat: false
        onActivated: {
            if (root.tab === "keys") root.closeRequested();
            else root.setTab("keys");
        }
    }

    Keys.onPressed: (event) => {
        if (root.capturing !== "") {
            event.accepted = true;
            root.capHeld = root.modsText(event.modifiers);
            const lone = Keybinds.loneOf(event);
            if (lone !== "") { root.capLone = lone; return; }
            root.capLone = "";
            if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_Escape) { root.capturing = ""; root.keyMsg = ""; return; }
            if (event.modifiers === Qt.NoModifier && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
                Keybinds.unbind(root.capturing);
                root.capturing = ""; root.keyMsg = "";
                return;
            }
            const s = Keybinds.fromEvent(event);
            if (s === "") { root.keyMsg = "That key cannot be used."; return; }
            const why = Keybinds.assign(root.capturing, s);
            root.keyMsg = why;
            if (why === "") root.capturing = "";
            return;
        }
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            if (picking) picking = false;
            else if (expandedId !== "") { expandedId = ""; WidgetConfig.previewId = ""; }
            else root.closeRequested();
            return;
        }
        if (!root.isTyping && Keybinds.matches("edit", event)) {
            event.accepted = true;
            root.closeRequested();
        }
    }

    Keys.onReleased: (event) => {
        if (root.capturing === "") return;
        event.accepted = true;
        root.capHeld = root.modsText(event.modifiers);
        const lone = Keybinds.loneOf(event);
        if (lone !== "" && lone === root.capLone) {
            root.capLone = "";
            const why = Keybinds.assign(root.capturing, lone);
            root.keyMsg = why;
            if (why === "") root.capturing = "";
        }
    }

    function modsText(m) {
        const t = [];
        if (m & Qt.ControlModifier) t.push("Ctrl");
        if (m & Qt.AltModifier) t.push("Alt");
        if (m & Qt.ShiftModifier) t.push("Shift");
        if (m & Qt.MetaModifier) t.push("Super");
        return t.join(" + ");
    }

    // ---------------- list structure (WIDGETS tab) ----------------
    property var structure: []
    property string _structKey: ""
    property int widgetCount: 0
    property int offCount: 0

    function _matches(e) {
        if (query === "") return true;
        const q = query.toLowerCase();
        return WidgetConfig.widgetName(e).toLowerCase().indexOf(q) >= 0 || WidgetConfig.planetName(e.host).toLowerCase().indexOf(q) >= 0;
    }

    function buildStructure() {
        const all = WidgetConfig.entries();
        const byHost = {};
        let off = 0;
        for (let i = 0; i < all.length; i++) {
            const h = all[i].host;
            if (!byHost[h]) byHost[h] = [];
            byHost[h].push(all[i]);
            if (all[i].enabled === false) off++;
        }
        const searching = query !== "";
        const out = [];
        const hosts = [];
        for (let p = 0; p < WidgetConfig.planets.length; p++) hosts.push(WidgetConfig.planets[p].id);
        for (const h in byHost) if (hosts.indexOf(h) < 0) hosts.push(h);
        for (let p = 0; p < hosts.length; p++) {
            const id = hosts[p];
            const l = byHost[id] || [];
            const shown = [];
            for (let j = 0; j < l.length; j++) if (_matches(l[j])) shown.push(l[j]);
            if (searching && shown.length === 0) continue;
            const isCollapsed = !searching && collapsed[id] === true;
            out.push({ kind: "header", planet: id, count: l.length, collapsed: isCollapsed });
            if (isCollapsed) continue;
            for (let j = 0; j < shown.length; j++) out.push({ kind: "row", id: shown[j].id });
        }
        widgetCount = all.length;
        offCount = off;
        const key = JSON.stringify(out);
        if (key !== _structKey) { _structKey = key; structure = out; }
    }

    onQueryChanged: buildStructure()
    onCollapsedChanged: buildStructure()

    Timer {
        id: structTimer
        interval: 80
        onTriggered: { root.buildStructure(); if (root.picking) root.buildPick(); }
    }
    Connections {
        target: WidgetConfig
        function onRevisionChanged() { structTimer.restart(); }
        function onPanelOpenChanged() { if (!WidgetConfig.panelOpen) { root.capturing = ""; root.picking = false; root.expandedId = ""; root.confirmClearNotifs = false; root.forceActiveFocus(); } }
    }
    Component.onCompleted: { buildStructure(); buildPick(); }

    function toggleCollapse(planet) {
        const c = {};
        for (const k in collapsed) c[k] = collapsed[k];
        c[planet] = !(collapsed[planet] === true);
        collapsed = c;
    }

    function toggleExpand(id) {
        capturing = ""; keyMsg = "";
        if (expandedId === id && inspectorOpen) { expandedId = ""; WidgetConfig.previewId = ""; }
        else { expandedId = id; WidgetConfig.previewId = id; inspectorTab = "orbit"; const e = WidgetConfig.entry(id); if (e) lastHost = e.host; }
    }

    // ---------------- picker (add / change type) ----------------
    property var pickModel: []

    function buildPick() {
        const q = pickQuery.toLowerCase();
        const out = [];
        const placesMap = {};
        if (pickMode === "add") {
            const allEnt = WidgetConfig.entries();
            for (let k = 0; k < allEnt.length; k++) {
                const src = allEnt[k].source;
                if (!placesMap[src]) placesMap[src] = [];
                placesMap[src].push({ id: allEnt[k].id, host: allEnt[k].host });
            }
        }
        const cat = WidgetConfig.catalog;
        let lastGroup = "";
        for (let i = 0; i < cat.length; i++) {
            if (pickGroup !== "" && cat[i].group !== pickGroup) continue;
            const places = pickMode === "add" ? (placesMap[cat[i].source] || []) : [];
            const where = [];
            let canMove = false;
            for (let k = 0; k < places.length; k++) {
                const pn = WidgetConfig.planetName(places[k].host);
                if (where.indexOf(pn) < 0) where.push(pn);
                if (places[k].host !== lastHost) canMove = true;
            }
            if (q !== "" && cat[i].name.toLowerCase().indexOf(q) < 0 && cat[i].group.toLowerCase().indexOf(q) < 0
                && where.join(" ").toLowerCase().indexOf(q) < 0) continue;
            if (cat[i].group !== lastGroup) { out.push({ kind: "group", text: cat[i].group.toUpperCase() }); lastGroup = cat[i].group; }
            out.push({ kind: "item", source: cat[i].source, name: cat[i].name, where: where, canMove: canMove });
        }
        pickModel = out;
    }
    onPickQueryChanged: buildPick()
    onPickModeChanged: buildPick()
    onPickGroupChanged: buildPick()

    property bool pickFromFocus: false
    function startPick(mode, target, host) {
        pickMode = mode;
        pickTarget = target;
        pickFromFocus = false;
        if (mode === "add") {
            if (host !== undefined && host !== "") lastHost = host;
            else if (WidgetConfig.focusPlanet !== "") { lastHost = WidgetConfig.focusPlanet; pickFromFocus = true; }
        }
        pickQuery = "";
        pickGroup = "";
        const gs = [], cat = WidgetConfig.catalog;
        for (let i = 0; i < cat.length; i++) if (gs.indexOf(cat[i].group) < 0) gs.push(cat[i].group);
        pickGroups = gs;
        buildPick();
        picking = true;
    }

    function pickChosen(source) {
        picking = false;
        if (pickMode === "add") {
            const id = WidgetConfig.addWidget(source, lastHost);
            expandedId = id;
            if (collapsed[lastHost] === true) toggleCollapse(lastHost);
        } else {
            WidgetConfig.setField(pickTarget, "source", source);
        }
    }

    // an existing widget of this file goes to the planet instead of a duplicate being made
    function pickMove(source) {
        picking = false;
        const id = WidgetConfig.moveHere(source, lastHost);
        if (id === "") return;
        expandedId = id;
        if (collapsed[lastHost] === true) toggleCollapse(lastHost);
    }

    function pickRestore(id) {
        picking = false;
        WidgetConfig.restoreWidget(id);
        expandedId = id;
        const e = WidgetConfig.entry(id);
        if (e) {
            lastHost = e.host;
            if (collapsed[e.host] === true) toggleCollapse(e.host);
        }
    }

    function fmtSpeed(v) {
        if (Math.abs(v) < 0.005) return "parked";
        return (v > 0 ? "+" : "-") + Math.abs(v).toFixed(2) + "  ·  " + Math.round(2 * Math.PI / Math.abs(v)) + " s";
    }

    function setTab(t) {
        WidgetConfig.panelTab = t;
        capturing = ""; keyMsg = "";
        picking = false;
        forceActiveFocus();
    }

    function startCapture(id) {
        keyMsg = "";
        capturing = id;
        forceActiveFocus();
    }

    // ---------------- small controls ----------------
    component OWBrackets: Canvas {
        id: br
        property color col: "#CCD4AF37"
        property real arm: 13
        property real thick: 2
        property real cornerRadius: (parent && parent.radius !== undefined) ? parent.radius : 0
        anchors.fill: parent
        z: 30
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onCornerRadiusChanged: requestPaint()
        onColChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 2 || height <= 2) return;
            const lw = br.thick, ins = lw * 0.5, w = width, h = height;
            const r = Math.max(0, Math.min(br.cornerRadius - ins, w * 0.4, h * 0.4));
            const a = Math.min(w * 0.44, h * 0.44, Math.max(ins + r + 5, ins + br.arm));
            ctx.strokeStyle = br.col; ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(ins, a); ctx.lineTo(ins, ins + r);
            if (r > 0.5) ctx.arcTo(ins, ins, ins + r, ins, r); else ctx.lineTo(ins, ins);
            ctx.lineTo(a, ins);
            ctx.moveTo(w - a, ins); ctx.lineTo(w - ins - r, ins);
            if (r > 0.5) ctx.arcTo(w - ins, ins, w - ins, ins + r, r); else ctx.lineTo(w - ins, ins);
            ctx.lineTo(w - ins, a);
            ctx.moveTo(w - ins, h - a); ctx.lineTo(w - ins, h - ins - r);
            if (r > 0.5) ctx.arcTo(w - ins, h - ins, w - ins - r, h - ins, r); else ctx.lineTo(w - ins, h - ins);
            ctx.lineTo(w - a, h - ins);
            ctx.moveTo(a, h - ins); ctx.lineTo(ins + r, h - ins);
            if (r > 0.5) ctx.arcTo(ins, h - ins, ins, h - ins - r, r); else ctx.lineTo(ins, h - ins);
            ctx.lineTo(ins, h - a);
            ctx.stroke();
        }
    }

    component InsetCard: Rectangle {
        id: ic
        property string heading: ""
        default property alias content: icCol.data
        height: icCol.height + (heading !== "" ? 38 : 20)
        radius: 8
        color: "#0B101D"
        border.width: 1
        border.color: "#2AD4AF37"
        Text {
            visible: ic.heading !== ""
            x: 12; y: 10
            text: ic.heading
            color: root.cGold
            font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2
        }
        Column {
            id: icCol
            x: 12
            y: ic.heading !== "" ? 28 : 10
            width: parent.width - 24
            spacing: 7
        }
    }

    component OWWheel: WheelHandler {
        id: wh
        property var scrollTarget: null
        property real targetY: 0
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        target: null
        property NumberAnimation anim: NumberAnimation {
            target: wh.scrollTarget
            property: "contentY"
            duration: 95
            easing.type: Easing.OutCubic
        }
        onWheel: (e) => {
            e.accepted = true;
            if (!wh.scrollTarget) return;
            const maxY = Math.max(0, wh.scrollTarget.contentHeight - wh.scrollTarget.height);
            if (maxY <= 0) return;
            const sens = WidgetConfig.uiScrollSens || 1.0;
            const step = (e.angleDelta.y !== 0 && Math.abs(e.pixelDelta.y) < 40)
                ? (e.angleDelta.y / 120.0) * 220 * sens
                : e.pixelDelta.y * 2.8 * sens;
            const base = wh.anim.running ? wh.targetY : wh.scrollTarget.contentY;
            wh.targetY = Math.max(0, Math.min(maxY, base - step));
            wh.anim.stop();
            wh.anim.from = wh.scrollTarget.contentY;
            wh.anim.to = wh.targetY;
            wh.anim.start();
        }
    }

    component OWScroll: Item {
        id: sc
        property Flickable target: null
        readonly property bool overflow: target !== null && target.contentHeight > target.height + 1
        visible: overflow
        z: 50
        x: target ? target.x + target.width + 2 : 0
        y: target ? target.y : 0
        width: 8
        height: target ? target.height : 0
        Rectangle { anchors.fill: parent; color: "#22D4AF37"; radius: 4 }
        Rectangle {
            id: knob
            width: parent.width
            height: sc.target ? Math.max(28, sc.height * sc.target.height / sc.target.contentHeight) : 28
            y: sc.target ? (sc.height - height) * (sc.target.contentY / Math.max(1, sc.target.contentHeight - sc.target.height)) : 0
            radius: 4
            color: (sbm.pressed || sbm.containsMouse) ? "#B0D4AF37" : "#77D4AF37"
        }
        MouseArea {
            id: sbm
            anchors.fill: parent
            hoverEnabled: true
            function setFrom(my) {
                if (!sc.target) return;
                const travel = Math.max(1, sc.height - knob.height);
                const f = Math.max(0, Math.min(1, (my - knob.height / 2) / travel));
                sc.target.contentY = f * Math.max(0, sc.target.contentHeight - sc.target.height);
            }
            onPressed: (m) => setFrom(m.y)
            onPositionChanged: (m) => { if (pressed) setFrom(m.y) }
        }
    }

    component OWButton: Rectangle {
        id: b
        property string label: ""
        property bool active: false
        property bool danger: false
        property bool dim: false
        property int pad: 10
        signal clicked()
        implicitWidth: t.implicitWidth + pad * 2
        implicitHeight: 26
        radius: 7
        color: b.active ? (ma.containsMouse ? "#45D4AF37" : "#30D4AF37")
             : (b.danger && ma.containsMouse ? "#2BD9694A" : (ma.containsMouse ? "#24D4AF37" : "#0D1322"))
        border.width: 1
        border.color: b.danger ? root.cDanger : (b.active || ma.containsMouse ? root.cGold : root.cLine)
        opacity: b.dim ? 0.5 : 1
        scale: ma.pressed ? 0.96 : 1.0
        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        Text {
            id: t
            anchors.centerIn: parent
            text: b.label
            color: b.danger ? root.cDanger : (b.active ? root.cGold : root.cCream)
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 1
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    component OWSwitch: Rectangle {
        id: sw
        property bool on: false
        signal toggled(bool v)
        width: 32; height: 17; radius: 9
        color: sw.on ? "#4AD4AF37" : (swMa.containsMouse ? "#1AD4AF37" : "#0D1322")
        border.width: 1
        border.color: sw.on ? root.cGold : (swMa.containsMouse ? "#77D4AF37" : root.cOff)
        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 11; height: 11; radius: 6
            anchors.verticalCenter: parent.verticalCenter
            x: sw.on ? parent.width - width - 3 : 3
            color: sw.on ? root.cGold : (swMa.containsMouse ? root.cCream : root.cOff)
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        MouseArea {
            id: swMa
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled(!sw.on)
        }
    }

    component OWResetBtn: Text {
        id: rb
        property bool shown: false
        signal clicked()
        visible: shown
        text: "↺"
        color: rbMa.containsMouse ? root.cGold : root.cDim
        font.family: root.mono
        font.pixelSize: 13
        MouseArea { id: rbMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rb.clicked() }
    }

    component FieldLabel: Text {
        color: root.cDim
        font.family: root.mono
        font.pixelSize: 10
        font.letterSpacing: 2
    }

    component FieldHeader: Item {
        id: fh
        property string label: ""
        property bool modified: false
        signal resetClicked()
        width: parent ? parent.width : 0
        height: 15
        FieldLabel { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: fh.label }
        OWResetBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; shown: fh.modified; onClicked: fh.resetClicked() }
    }

    component OWToggleRow: Item {
        id: tr
        property string label: ""
        property bool on: false
        property bool modified: false
        signal toggled(bool v)
        signal resetClicked()
        width: parent ? parent.width : 0
        height: 22
        Text {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (tr.modified ? 60 : 40); elide: Text.ElideRight
            text: tr.label; color: root.cCream; font.family: root.mono; font.pixelSize: 11
        }
        OWResetBtn {
            anchors.right: trSw.left; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            shown: tr.modified; onClicked: tr.resetClicked()
        }
        OWSwitch {
            id: trSw
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            on: tr.on; onToggled: (v) => tr.toggled(v)
        }
    }

    component OWSlider: Item {
        id: s
        property real from: 0
        property real to: 1
        property real value: 0
        property real step: 0.01
        property string text: ""
        property bool bipolar: false
        property real typedScale: 1.0
        property real _liveFrac: (isFinite(value) && to > from) ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
        property real _pendingVal: value
        property bool _hasPending: false
        signal moved(real v)
        function commitTyped(str) {
            const m = String(str).match(/-?\d+(?:\.\d+)?|-?\.\d+/);
            if (!m) return;
            const v = parseFloat(m[0]) / s.typedScale;
            if (isFinite(v)) s.moved(v);
        }
        readonly property real frac: ma.pressed ? _liveFrac : ((isFinite(value) && to > from) ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0)
        implicitHeight: 24

        Timer {
            id: emitTimer
            interval: 50
            onTriggered: {
                if (s._hasPending) {
                    s._hasPending = false;
                    s.moved(s._pendingVal);
                }
            }
        }

        Rectangle {
            id: track
            x: 0
            width: s.width - 102
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: "#22D4AF37"
            Rectangle {
                x: s.bipolar ? parent.width * Math.min(s.frac, 0.5) : 0
                width: s.bipolar ? parent.width * Math.abs(s.frac - 0.5) : parent.width * s.frac
                height: parent.height
                radius: 2
                color: root.cGold
                Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                width: 11; height: 11; radius: 3; rotation: 45
                x: parent.width * s.frac - 5.5
                anchors.verticalCenter: parent.verticalCenter
                color: ma.pressed ? root.cCream : root.cGold
                scale: (ma.pressed || ma.containsMouse) ? 1.25 : 1.0
                Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        TextInput {
            id: valBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 94
            horizontalAlignment: TextInput.AlignRight
            text: s.text
            color: activeFocus ? root.cGold : root.cCream
            font.family: root.mono
            font.pixelSize: 11
            selectByMouse: true
            clip: true
            property bool _ft: false
            function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
            Component.onDestruction: _st(false)
            onAccepted: { s.commitTyped(text); focus = false; }
            onActiveFocusChanged: { _st(activeFocus); if (activeFocus) selectAll(); else text = Qt.binding(() => s.text); }
        }
        MouseArea {
            id: ma
            x: -6; width: track.width + 12; height: parent.height
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function setFromX(mx, immediate) {
                const f = Math.max(0, Math.min(1, (mx - 6) / track.width));
                s._liveFrac = f;
                let v = s.from + f * (s.to - s.from);
                v = Math.round(v / s.step) * s.step;
                v = Math.max(s.from, Math.min(s.to, v));
                if (immediate) {
                    emitTimer.stop();
                    s._hasPending = false;
                    if (Math.abs(v - s.value) > 1e-9) s.moved(v);
                } else if (Math.abs(v - s._pendingVal) > 1e-9 || Math.abs(v - s.value) > 1e-9) {
                    s._pendingVal = v;
                    s._hasPending = true;
                    if (!emitTimer.running) emitTimer.start();
                }
            }
            onPressed: (m) => setFromX(m.x, true)
            onPositionChanged: (m) => { if (pressed) setFromX(m.x, false); }
            onReleased: (m) => setFromX(m.x, true)
        }
    }

    component OWTextField: Rectangle {
        id: tf
        property string value: ""
        property string placeholder: ""
        property bool showSwatch: false
        signal edited(string v)
        implicitHeight: 28
        radius: 7
        color: "#0C101C"
        border.width: 1
        border.color: tfIn.activeFocus ? root.cGold : root.cLine
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Rectangle {
            visible: tf.showSwatch
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 2
            color: /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(tf.value) ? tf.value : "transparent"
            border.width: 1
            border.color: root.cLine
        }
        Text {
            visible: tf.placeholder !== "" && tfIn.text === "" && !tfIn.activeFocus
            x: tf.showSwatch ? 28 : 10
            anchors.verticalCenter: parent.verticalCenter
            text: tf.placeholder; color: root.cOff; font.family: root.mono; font.pixelSize: 11
        }
        TextInput {
            id: tfIn
            anchors.fill: parent
            anchors.leftMargin: tf.showSwatch ? 28 : 10
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            text: tf.value
            color: root.cCream
            font.family: root.mono
            font.pixelSize: 11
            property bool _ft: false
            function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
            Component.onDestruction: _st(false)
            onAccepted: { tf.edited(text); focus = false; }
            onActiveFocusChanged: { _st(activeFocus); if (!activeFocus) { if (text !== tf.value) tf.edited(text); text = Qt.binding(() => tf.value); } }
        }
    }

    component OWFileField: Row {
        id: ff
        property string value: ""
        property string title: "Select file"
        signal edited(string v)
        spacing: 6
        OWTextField {
            width: ff.width - browseBtn.width - 6
            placeholder: "/path/to/file"
            value: ff.value
            onEdited: (v) => ff.edited(v)
        }
        OWButton {
            id: browseBtn
            implicitHeight: 28; pad: 8; label: "BROWSE"
            onClicked: root.fileBrowseRequested(ff.title, "Images | *.png *.jpg *.jpeg *.webp *.gif", "*.png *.jpg *.jpeg *.webp *.gif", (path) => { if (path) ff.edited(path); })
        }
    }

    component OWDropdown: Column {
        id: dd
        property var model: []
        property var value: ""
        property string placeholder: "select..."
        property bool open: false
        signal selected(var v)

        function itemFor(v) {
            for (let i = 0; i < model.length; i++) {
                const it = model[i];
                const val = (typeof it === "object" && it !== null) ? it.value : it;
                if (val === v) return it;
            }
            return null;
        }
        function labelFor(v) {
            const it = itemFor(v);
            if (it !== null) return String((typeof it === "object") ? (it.label !== undefined ? it.label : it.value) : it);
            return v !== undefined && v !== "" ? String(v) : placeholder;
        }
        readonly property string curDot: {
            const it = itemFor(value);
            return (it && typeof it === "object" && it.dot) ? it.dot : "";
        }
        spacing: 4

        Rectangle {
            width: dd.width; height: 28; radius: 7
            color: ddMa.containsMouse ? "#141B2E" : "#0C101C"
            border.width: 1
            border.color: dd.open || ddMa.containsMouse ? root.cGold : root.cLine
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Rectangle {
                visible: dd.curDot !== ""
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: dd.curDot !== "" ? dd.curDot : "transparent"
            }
            Text {
                x: dd.curDot !== "" ? 24 : 10; width: parent.width - (dd.curDot !== "" ? 44 : 30)
                anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                text: dd.labelFor(dd.value); color: root.cCream
                font.family: root.mono; font.pixelSize: 11
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: dd.open ? "▴" : "▾"; color: dd.open ? root.cGold : root.cDim
                font.family: root.mono; font.pixelSize: 11
            }
            MouseArea { id: ddMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dd.open = !dd.open }
        }

        Rectangle {
            width: dd.width
            height: dd.open ? Math.min(180, dd.model.length * 28 + 8) : 0
            opacity: dd.open ? 1.0 : 0.0
            visible: height > 1
            radius: 7; color: "#090D18"; border.width: 1; border.color: "#55D4AF37"; clip: true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            ListView {
                id: ddList
                anchors.fill: parent; anchors.margins: 4
                model: dd.open ? dd.model : []; clip: true
                boundsBehavior: Flickable.StopAtBounds
                OWWheel { scrollTarget: ddList }
                delegate: Rectangle {
                    required property var modelData
                    readonly property var val: (typeof modelData === "object" && modelData !== null) ? modelData.value : modelData
                    readonly property string lbl: String((typeof modelData === "object" && modelData !== null) ? (modelData.label !== undefined ? modelData.label : modelData.value) : modelData)
                    readonly property string dot: (typeof modelData === "object" && modelData !== null && modelData.dot) ? modelData.dot : ""
                    readonly property bool cur: dd.value === val
                    width: ddList.width; height: 28; radius: 5
                    color: cur ? "#2ED4AF37" : (dItemMa.containsMouse ? "#1AD4AF37" : "transparent")
                    Rectangle {
                        visible: parent.dot !== ""
                        x: 8; anchors.verticalCenter: parent.verticalCenter
                        width: 8; height: 8; radius: 4
                        color: parent.dot !== "" ? parent.dot : "transparent"
                    }
                    Text {
                        x: parent.dot !== "" ? 22 : 8; width: parent.width - (parent.dot !== "" ? 30 : 16)
                        anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        text: parent.lbl; color: parent.cur ? root.cGold : root.cCream
                        font.family: root.mono; font.pixelSize: 11; font.bold: parent.cur
                    }
                    MouseArea {
                        id: dItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { dd.selected(parent.val); dd.open = false; }
                    }
                }
            }
        }
    }

    component OWFontPicker: Column {
        id: fp
        property string value: ""
        property string defaultValue: ""
        property bool allowBlank: true
        property bool open: false
        property string filter: ""
        signal edited(string v)

        readonly property var filteredFonts: {
            if (!open) return [];
            const q = filter.trim().toLowerCase();
            const out = [];
            if (allowBlank && (q === "" || "default".indexOf(q) >= 0)) out.push("");
            const all = root.systemFonts;
            for (let i = 0; i < all.length; i++) {
                if (q === "" || all[i].toLowerCase().indexOf(q) >= 0) out.push(all[i]);
            }
            return out;
        }
        spacing: 4

        Rectangle {
            width: fp.width; height: 28; radius: 7
            color: fpMa.containsMouse ? "#141B2E" : "#0C101C"
            border.width: 1
            border.color: fp.open || fpMa.containsMouse ? root.cGold : root.cLine
            Behavior on border.color { ColorAnimation { duration: 140 } }
            Text {
                x: 10; width: parent.width - (fpClr.visible ? 48 : 30)
                anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                text: fp.value !== "" ? fp.value : "default"
                color: fp.value !== "" ? root.cCream : root.cDim
                font.family: fp.value !== "" ? fp.value : root.mono; font.pixelSize: 11
            }
            MouseArea { id: fpMa; anchors.fill: parent; anchors.rightMargin: fpClr.visible ? 26 : 0; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { fp.open = !fp.open; if (fp.open) fp.filter = ""; } }
            Text {
                id: fpClr
                visible: fp.value !== fp.defaultValue
                anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                text: "↺"; color: fpClrMa.containsMouse ? root.cGold : root.cDim; font.pixelSize: 12
                MouseArea { id: fpClrMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { fp.edited(fp.defaultValue); fp.open = false; } }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: fp.open ? "▴" : "▾"; color: fp.open ? root.cGold : root.cDim; font.family: root.mono; font.pixelSize: 11
            }
        }

        Rectangle {
            width: fp.width
            height: fp.open ? 196 : 0
            opacity: fp.open ? 1.0 : 0.0
            visible: height > 1
            radius: 7; color: "#090D18"; border.width: 1; border.color: "#55D4AF37"; clip: true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Rectangle {
                id: fpSearchBox
                x: 6; y: 6; width: parent.width - 12; height: 26; radius: 5
                color: "#0E1424"; border.width: 1; border.color: fpSearchIn.activeFocus ? root.cGold : root.cLine
                Text {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    visible: fpSearchIn.text === "" && !fpSearchIn.activeFocus
                    text: "filter fonts..."; color: root.cOff; font.family: root.mono; font.pixelSize: 10
                }
                TextInput {
                    id: fpSearchIn
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter; clip: true
                    color: root.cCream; font.family: root.mono; font.pixelSize: 11
                    text: fp.filter
                    property bool _ft: false
                    function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
                    Component.onDestruction: _st(false)
                    onActiveFocusChanged: _st(activeFocus)
                    onTextChanged: fp.filter = text
                }
            }

            ListView {
                id: fpList
                x: 4; y: 36; width: parent.width - 8; height: Math.max(0, parent.height - 40)
                model: fp.open ? fp.filteredFonts : []; clip: true
                boundsBehavior: Flickable.StopAtBounds
                OWWheel { scrollTarget: fpList }
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool cur: fp.value === modelData
                    width: fpList.width; height: 26; radius: 5
                    color: cur ? "#2ED4AF37" : (fItemMa.containsMouse ? "#1AD4AF37" : "transparent")
                    Text {
                        x: 8; width: parent.width - 16; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                        text: modelData === "" ? "(default)" : modelData
                        color: parent.cur ? root.cGold : (modelData === "" ? root.cDim : root.cCream)
                        font.family: modelData === "" ? root.mono : modelData; font.pixelSize: 11
                    }
                    MouseArea {
                        id: fItemMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { fp.edited(modelData); fp.open = false; }
                    }
                }
            }
        }
    }

    component OWColorPicker: Column {
        id: cp
        property string value: ""
        property string defaultValue: ""
        property bool allowBlank: true
        property bool open: false
        signal edited(string v)

        readonly property bool isModified: String(value || "").toUpperCase() !== String(defaultValue || "").toUpperCase()
        property real h: 0.12
        property real s: 0.74
        property real v: 0.83
        property real a: 1.0
        property bool _busy: false

        readonly property var presets: ["#D4AF37", "#E6D5B8", "#FF7A45", "#7FB7C9", "#8FBF7A", "#D71921", "#E007080C", "#0E0E0E", "#F2F2F2"]

        function syncFromHex(hex) {
            if (_busy) return;
            const m = String(hex || "").trim().match(/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/);
            if (!m) return;
            const raw = m[1];
            let alpha = 1.0, off = 0;
            if (raw.length === 8) { alpha = parseInt(raw.slice(0, 2), 16) / 255.0; off = 2; }
            const r = parseInt(raw.slice(off, off + 2), 16) / 255.0;
            const g = parseInt(raw.slice(off + 2, off + 4), 16) / 255.0;
            const b = parseInt(raw.slice(off + 4, off + 6), 16) / 255.0;
            const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
            let hh = h;
            if (d > 1e-6) {
                if (mx === r) hh = ((g - b) / d + (g < b ? 6 : 0)) / 6;
                else if (mx === g) hh = ((b - r) / d + 2) / 6;
                else hh = ((r - g) / d + 4) / 6;
            }
            h = hh; s = mx > 1e-6 ? d / mx : 0; v = mx; a = alpha;
        }

        function emitHsv() {
            const i = Math.floor(h * 6), f = h * 6 - i;
            const p = v * (1 - s), q = v * (1 - f * s), t2 = v * (1 - (1 - f) * s);
            let r = 0, g = 0, b = 0;
            switch (i % 6) {
            case 0: r = v; g = t2; b = p; break;
            case 1: r = q; g = v; b = p; break;
            case 2: r = p; g = v; b = t2; break;
            case 3: r = p; g = q; b = v; break;
            case 4: r = t2; g = p; b = v; break;
            case 5: r = v; g = p; b = q; break;
            }
            function hx(x) { return Math.max(0, Math.min(255, Math.round(x * 255))).toString(16).padStart(2, "0").toUpperCase(); }
            const out = (a < 0.995 ? ("#" + hx(a)) : "#") + hx(r) + hx(g) + hx(b);
            _busy = true;
            edited(out);
            _busy = false;
        }

        onValueChanged: syncFromHex(value)
        Component.onCompleted: syncFromHex(value)
        spacing: 5

        Rectangle {
            width: cp.width; height: 28; radius: 7
            color: "#0C101C"; border.width: 1
            border.color: cp.open || cpIn.activeFocus ? root.cGold : root.cLine
            Behavior on border.color { ColorAnimation { duration: 140 } }

            Rectangle {
                id: swBox
                x: 6; anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16; radius: 4
                color: /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(cp.value) ? cp.value : "transparent"
                border.width: 1; border.color: root.cGold
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: cp.open = !cp.open }
            }
            TextInput {
                id: cpIn
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: cpRst.visible ? 44 : 26
                verticalAlignment: TextInput.AlignVCenter
                clip: true; selectByMouse: true
                text: cp.value
                color: root.cCream; font.family: root.mono; font.pixelSize: 11
                property bool _ft: false
                function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
                Component.onDestruction: _st(false)
                onAccepted: { cp.edited(text.trim()); focus = false; }
                onActiveFocusChanged: { _st(activeFocus); if (!activeFocus) { if (text.trim() !== cp.value) cp.edited(text.trim()); text = Qt.binding(() => cp.value); } }
            }
            Text {
                visible: cp.value === "" && !cpIn.activeFocus
                x: 28; anchors.verticalCenter: parent.verticalCenter
                text: "default"; color: root.cOff; font.family: root.mono; font.pixelSize: 11
            }
            Text {
                id: cpRst
                visible: cp.isModified
                anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                text: "↺"; color: cpRstMa.containsMouse ? root.cGold : root.cDim; font.pixelSize: 12
                MouseArea {
                    id: cpRstMa; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { cp.syncFromHex(cp.defaultValue); cp.edited(cp.defaultValue); if (cp.defaultValue === "") cp.open = false; }
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                text: cp.open ? "▴" : "▾"; color: cp.open ? root.cGold : root.cDim; font.family: root.mono; font.pixelSize: 11
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: cp.open = !cp.open }
            }
        }

        Rectangle {
            width: cp.width
            height: cp.open ? (cpBody.height + 16) : 0
            opacity: cp.open ? 1.0 : 0.0
            visible: height > 1
            radius: 8; color: "#090D18"; border.width: 1; border.color: "#55D4AF37"; clip: true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140 } }

            Column {
                id: cpBody
                x: 8; y: 8; width: parent.width - 16; spacing: 8

                Rectangle {
                    id: svPad
                    width: parent.width; height: 100; radius: 6; clip: true
                    color: Qt.hsva(cp.h, 1, 1, 1)
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#FFFFFFFF" }
                            GradientStop { position: 1.0; color: "#00FFFFFF" }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#00000000" }
                            GradientStop { position: 1.0; color: "#FF000000" }
                        }
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 6
                        x: cp.s * svPad.width - 6; y: (1 - cp.v) * svPad.height - 6
                        color: "transparent"; border.width: 2; border.color: "#FFFFFF"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.CrossCursor
                        function pick(mx, my) {
                            cp.s = Math.max(0, Math.min(1, mx / svPad.width));
                            cp.v = Math.max(0, Math.min(1, 1 - my / svPad.height));
                            cp.emitHsv();
                        }
                        onPressed: (m) => pick(m.x, m.y)
                        onPositionChanged: (m) => { if (pressed) pick(m.x, m.y) }
                    }
                }

                Rectangle {
                    id: hueBar
                    width: parent.width; height: 12; radius: 6
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.00; color: "#FF0000" }
                        GradientStop { position: 0.17; color: "#FFFF00" }
                        GradientStop { position: 0.33; color: "#00FF00" }
                        GradientStop { position: 0.50; color: "#00FFFF" }
                        GradientStop { position: 0.67; color: "#0000FF" }
                        GradientStop { position: 0.83; color: "#FF00FF" }
                        GradientStop { position: 1.00; color: "#FF0000" }
                    }
                    Rectangle {
                        width: 10; height: 14; radius: 4
                        x: cp.h * (hueBar.width - width); anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"; border.width: 1; border.color: "#000000"
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        function pick(mx) { cp.h = Math.max(0, Math.min(0.999, mx / hueBar.width)); cp.emitHsv(); }
                        onPressed: (m) => pick(m.x)
                        onPositionChanged: (m) => { if (pressed) pick(m.x) }
                    }
                }

                Row {
                    width: parent.width; spacing: 8
                    Rectangle {
                        id: alphaBar
                        width: parent.width - 38; height: 12; radius: 6; anchors.verticalCenter: parent.verticalCenter
                        color: "#1B2030"; border.width: 1; border.color: root.cLine
                        Rectangle {
                            anchors.fill: parent; radius: 6
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.hsva(cp.h, cp.s, cp.v, 0.0) }
                                GradientStop { position: 1.0; color: Qt.hsva(cp.h, cp.s, cp.v, 1.0) }
                            }
                        }
                        Rectangle {
                            width: 10; height: 14; radius: 4
                            x: cp.a * (alphaBar.width - width); anchors.verticalCenter: parent.verticalCenter
                            color: "#FFFFFF"; border.width: 1; border.color: "#000000"
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            function pick(mx) { cp.a = Math.max(0, Math.min(1, mx / alphaBar.width)); cp.emitHsv(); }
                            onPressed: (m) => pick(m.x)
                            onPositionChanged: (m) => { if (pressed) pick(m.x) }
                        }
                    }
                    Text {
                        width: 30; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(cp.a * 100) + "%"
                        color: root.cDim; font.family: root.mono; font.pixelSize: 10
                    }
                }

                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: cp.presets
                        Rectangle {
                            required property string modelData
                            width: 18; height: 18; radius: 4; color: modelData
                            border.width: cp.value.toUpperCase() === modelData.toUpperCase() ? 2 : 1
                            border.color: cp.value.toUpperCase() === modelData.toUpperCase() ? "#FFFFFF" : root.cLine
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { cp.syncFromHex(parent.modelData); cp.edited(parent.modelData); }
                            }
                        }
                    }
                    OWButton {
                        visible: cp.isModified
                        implicitHeight: 18; pad: 6; label: "↺ DEFAULT"
                        onClicked: { cp.syncFromHex(cp.defaultValue); cp.edited(cp.defaultValue); if (cp.defaultValue === "") cp.open = false; }
                    }
                }
            }
        }
    }

    component SearchBox: Rectangle {
        id: sb
        property alias text: ti.text
        property string placeholder: "search"
        implicitHeight: 30
        radius: 8
        color: "#0C101C"
        border.width: 1
        border.color: ti.activeFocus ? root.cGold : root.cLine
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Text {
            x: 10; anchors.verticalCenter: parent.verticalCenter
            visible: ti.text === "" && !ti.activeFocus
            text: "⌕  " + sb.placeholder; color: root.cOff; font.family: root.mono; font.pixelSize: 11
        }
        TextInput {
            id: ti
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 26
            verticalAlignment: TextInput.AlignVCenter
            color: root.cCream; selectionColor: root.cGold; font.family: root.mono; font.pixelSize: 12; clip: true
            property bool _ft: false
            function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
            Component.onDestruction: _st(false)
            onActiveFocusChanged: _st(activeFocus)
            Keys.onEscapePressed: (event) => { if (ti.text !== "") { ti.text = ""; event.accepted = true; } else event.accepted = false; }
        }
        Text {
            visible: ti.text !== ""
            anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
            text: "✕"; color: root.cDim; font.pixelSize: 11
            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: ti.text = "" }
        }
    }

    component TabButton: Item {
        id: tb
        property string label: ""
        property string key: ""
        readonly property bool on: root.tab === key
        width: tl.implicitWidth + 28
        height: 30
        Rectangle {
            anchors.fill: parent; anchors.margins: 2; radius: 7
            color: tb.on ? "#24D4AF37" : (tma.containsMouse ? "#15D4AF37" : "transparent")
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        Text {
            id: tl; anchors.centerIn: parent; text: tb.label
            color: tb.on ? root.cGold : (tma.containsMouse ? root.cCream : root.cDim)
            font.family: root.mono; font.pixelSize: 11; font.bold: tb.on; font.letterSpacing: 2
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Rectangle {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            width: tb.on ? parent.width - 14 : 0; height: 2; radius: 1; color: root.cGold
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTab(tb.key) }
    }

    component OptAccordion: Column {
        id: acc
        property string optKey: ""
        property string title: ""
        property string subtitle: ""
        property bool hasSwitch: false
        property bool switchOn: false
        signal switchToggled(bool v)
        default property alias bodyContent: accCol.data
        readonly property bool open: root.optOpen[optKey] === true
        width: parent ? parent.width : 0
        spacing: open ? 4 : 0

        Rectangle {
            width: acc.width; height: 48; radius: 8
            color: acc.open ? "#20D4AF37" : (accHov.hovered ? "#15D4AF37" : "#0D1322")
            border.width: 1; border.color: acc.open ? "#55D4AF37" : root.cLine
            Behavior on color { ColorAnimation { duration: 140 } }
            HoverHandler { id: accHov }
            MouseArea { anchors.fill: parent; anchors.rightMargin: acc.hasSwitch ? 46 : 0; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt(acc.optKey) }
            Column {
                x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - (acc.hasSwitch ? 66 : 24); spacing: 2
                Text { text: (acc.open ? "▾  " : "▸  ") + acc.title; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: acc.open }
                Text { width: parent.width; elide: Text.ElideRight; text: acc.subtitle; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
            }
            OWSwitch {
                visible: acc.hasSwitch
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                on: acc.switchOn; onToggled: (v) => acc.switchToggled(v)
            }
        }
        Rectangle {
            width: acc.width
            height: acc.open ? (accCol.height + 20) : 0
            opacity: acc.open ? 1.0 : 0.0
            visible: height > 1
            radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"; clip: true
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Column { id: accCol; x: 12; y: 10; width: parent.width - 24; spacing: 7 }
        }
    }

    // =====================================================================
    //  MAIN CONTROL CENTRE (right strip, slides in/out smoothly)
    // =====================================================================
    Rectangle {
        id: mainPanel
        z: 2
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: -(1.0 - root.panelSlide) * 440
        width: 420
        opacity: root.panelSlide
        layer.enabled: root.panelSlide > 0.001 && root.panelSlide < 0.999
        color: "#F5070911"
        radius: 12
        clip: true
        border.color: "#66D4AF37"
        border.width: 1

        OWBrackets { }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F50E1324" }
                GradientStop { position: 0.45; color: "#F5070911" }
                GradientStop { position: 1.0; color: "#F504050B" }
            }
        }

        // ---------------- header + tabs ----------------
        Item {
            id: head
            x: 18; y: 14
            width: parent.width - 36
            height: 40

            Text {
                text: "CONTROL CENTRE"
                color: root.cCream
                font.family: root.mono; font.bold: true; font.pixelSize: 16; font.letterSpacing: 3
            }
            Text {
                y: 24
                text: root.tab === "widgets" ? (root.widgetCount + " ON PLANETS" + (WidgetConfig.pinnedCount > 0 ? "  ·  " + WidgetConfig.pinnedCount + " PINNED" : "") + (root.offCount > 0 ? "  ·  " + root.offCount + " OFF" : ""))
                    : (root.tab === "keys" ? "CLICK A KEY TO CHANGE IT" : "HUD, THEMES, PRESETS & RESETS")
                color: root.cDim; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1.5
            }
            OWButton {
                anchors.right: parent.right; label: "✕"; pad: 8
                onClicked: root.closeRequested()
            }
        }

        Row {
            id: tabs
            x: 10; y: 58
            TabButton { label: "WIDGETS"; key: "widgets" }
            TabButton { label: "KEYS"; key: "keys" }
            TabButton { label: "OPTIONS"; key: "options" }
        }
        Rectangle { x: 18; y: 88; width: parent.width - 36; height: 1; color: root.cLine }

        // =====================================================================
        //  WIDGETS TAB
        // =====================================================================
        Item {
            id: widgetsTab
            opacity: root.tab === "widgets" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.tab === "widgets"
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            x: 0; y: 96
            width: parent.width
            height: parent.height - 96

            Item {
                id: toolbar
                x: 18
                width: parent.width - 36
                height: 82

                SearchBox {
                    width: parent.width - 178
                    placeholder: "search widgets or planets"
                    text: root.query
                    onTextChanged: root.query = text
                }
                OWButton {
                    anchors.right: parent.right
                    label: "+ ADD"
                    active: true
                    onClicked: root.startPick("add", "")
                }
                OWButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 64
                    label: root.confirmAll ? "SURE?" : "REMOVE ALL"
                    danger: root.confirmAll
                    onClicked: {
                        if (root.confirmAll) { WidgetConfig.removeAll(); root.expandedId = ""; root.confirmAll = false; }
                        else root.confirmAll = true;
                    }
                }
                Timer { interval: 3000; running: root.confirmAll; onTriggered: root.confirmAll = false }
                FieldHeader {
                    y: 36; width: parent.width; label: "ALL ORBITS"
                    modified: WidgetConfig.isUiModified("globalSpeed")
                    onResetClicked: WidgetConfig.resetUiOption("globalSpeed")
                }
                OWSlider {
                    y: 52; width: parent.width
                    from: 0; to: 10; step: 0.05
                    value: WidgetConfig.globalSpeed
                    text: WidgetConfig.globalSpeed.toFixed(2) + "×"
                    onMoved: (v) => WidgetConfig.setGlobalSpeed(v)
                }
            }

            Column {
                id: statusBars
                x: 18; y: toolbar.height + 2
                width: parent.width - 36
                spacing: 4

                Rectangle {
                    visible: WidgetConfig.pinnedCount > 0
                    width: parent.width; height: visible ? 30 : 0; radius: 6
                    color: "#20D4AF37"; border.width: 1; border.color: "#55D4AF37"
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        text: "◈  " + WidgetConfig.pinnedCount + " pinned" + (WidgetConfig.lockedPinCount > 0 ? " (" + WidgetConfig.lockedPinCount + " locked)" : "") + "  ·  others dimmed"
                        color: root.cGold; font.family: root.mono; font.pixelSize: 10
                    }
                    OWButton {
                        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 22; pad: 8; label: "UNPIN ALL"
                        onClicked: WidgetConfig.unpinAll()
                    }
                }

                Rectangle {
                    visible: root.offCount > 0
                    width: parent.width; height: visible ? 30 : 0; radius: 6
                    color: "#14D4AF37"; border.width: 1; border.color: root.cLine
                    Text {
                        x: 10; anchors.verticalCenter: parent.verticalCenter
                        text: root.offCount + " switched off, still on planets"
                        color: root.cDim; font.family: root.mono; font.pixelSize: 10
                    }
                    OWButton {
                        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 22; pad: 8
                        label: root.confirmClean ? "SURE?" : "REMOVE THEM"
                        danger: root.confirmClean
                        onClicked: {
                            if (root.confirmClean) { WidgetConfig.removeDisabled(); root.expandedId = ""; root.confirmClean = false; }
                            else root.confirmClean = true;
                        }
                    }
                    Timer { interval: 3000; running: root.confirmClean; onTriggered: root.confirmClean = false }
                }
            }

            Flickable {
                id: flick
                x: 18
                y: toolbar.height + (statusBars.height > 0 ? statusBars.height + 8 : 8)
                width: parent.width - 46
                height: parent.height - y - 10
                contentWidth: width
                contentHeight: listCol.height + 12
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                OWWheel { scrollTarget: flick }

                Column {
                    id: listCol
                    width: flick.width - 10
                    spacing: 0

                    Repeater {
                        model: root.structure
                        delegate: Item {
                            id: del
                            required property var modelData
                            width: listCol.width
                            height: loader.item ? loader.item.height : 0

                            Loader {
                                id: loader
                                width: parent.width
                                sourceComponent: del.modelData.kind === "header" ? headerComp : rowComp
                            }

                            Component {
                                id: headerComp
                                Item {
                                    id: hdr
                                    width: del.width
                                    height: 38
                                    readonly property bool empty: del.modelData.count === 0
                                    HoverHandler { id: hdrHover }
                                    Rectangle {
                                        anchors.fill: parent; anchors.topMargin: 6; radius: 7
                                        color: hdrHover.hovered ? "#1CD4AF37" : "transparent"
                                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    }
                                    Rectangle {
                                        x: 4; anchors.bottom: parent.bottom; anchors.bottomMargin: 11
                                        width: 7; height: 7; radius: 4
                                        color: WidgetConfig.planetColor(del.modelData.planet)
                                        opacity: hdr.empty ? 0.35 : 0.95
                                    }
                                    Text {
                                        x: 17
                                        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                        text: (del.modelData.collapsed ? "▸  " : "▾  ") + WidgetConfig.planetName(del.modelData.planet).toUpperCase()
                                              + "  (" + del.modelData.count + ")"
                                        color: hdr.empty ? root.cOff : root.cGold
                                        font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.8
                                    }
                                    MouseArea {
                                        anchors.fill: parent; anchors.rightMargin: 40; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleCollapse(del.modelData.planet)
                                    }
                                    Text {
                                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                                        text: "+"; color: plusMa.containsMouse ? root.cCream : root.cGold
                                        font.family: root.mono; font.pixelSize: 16; font.bold: true
                                        MouseArea {
                                            id: plusMa; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.startPick("add", "", del.modelData.planet)
                                        }
                                    }
                                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cLine }
                                }
                            }

                            Component {
                                id: rowComp
                                Item {
                                    id: row
                                    readonly property string wid: del.modelData.id
                                    readonly property var d: WidgetConfig.entry(wid)
                                    readonly property bool open: root.expandedId === wid
                                    readonly property bool pinned: WidgetConfig.isPinned(wid)
                                    readonly property bool pinLocked: WidgetConfig.isPinLocked(wid)
                                    readonly property bool supportsOrbit: d !== null && WidgetConfig.supportsPinOrbit(d.source)
                                    readonly property bool orbitOn: WidgetConfig.pinOrbitEnabled(wid)
                                    readonly property bool modified: d !== null && (WidgetConfig.overrides[wid] !== undefined || d._extra)
                                    width: del.width
                                    height: rowHead.height + 2

                                    Rectangle {
                                        id: rowHead
                                        width: parent.width; height: 36; radius: 8
                                        color: row.open ? "#24D4AF37" : (rowHover.hovered ? "#18D4AF37" : "transparent")
                                        border.width: row.open ? 1 : 0; border.color: "#44D4AF37"
                                        Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        HoverHandler { id: rowHover }
                                        Rectangle {
                                            x: 2; anchors.verticalCenter: parent.verticalCenter
                                            width: 3; height: row.open ? 20 : (rowHover.hovered ? 14 : 0); radius: 2; color: root.cGold
                                            opacity: (row.open || rowHover.hovered) ? 1.0 : 0.0
                                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                            Behavior on opacity { NumberAnimation { duration: 140 } }
                                        }

                                        OWSwitch {
                                            x: 8; anchors.verticalCenter: parent.verticalCenter
                                            on: row.d !== null && row.d.enabled
                                            onToggled: (v) => WidgetConfig.setField(row.wid, "enabled", v)
                                        }
                                        Text {
                                            x: 46; anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 46 - (row.supportsOrbit ? 114 : 92)
                                            text: row.d ? WidgetConfig.widgetName(row.d) : ""
                                            elide: Text.ElideRight
                                            color: row.d && row.d.enabled ? root.cCream : root.cOff
                                            font.family: root.mono; font.pixelSize: 12
                                        }
                                        MouseArea {
                                            anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: row.supportsOrbit ? 104 : 82
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleExpand(row.wid)
                                        }
                                        // Orbit progress toggle icon (only for applicable widgets)
                                        Text {
                                            visible: row.supportsOrbit && (row.pinned || rowHover.hovered || row.open)
                                            anchors.right: parent.right; anchors.rightMargin: 78; anchors.verticalCenter: parent.verticalCenter
                                            text: row.orbitOn ? "◎" : "○"
                                            color: row.orbitOn ? (row.pinLocked ? WidgetConfig.pinLockOutlineColor : root.cGold) : (orbMa.containsMouse ? root.cCream : root.cDim)
                                            font.family: root.mono; font.pixelSize: 13
                                            MouseArea {
                                                id: orbMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: WidgetConfig.togglePinOrbit(row.wid)
                                            }
                                        }
                                        // Pin toggle icon
                                        Text {
                                            visible: row.pinned || rowHover.hovered || row.open
                                            anchors.right: parent.right; anchors.rightMargin: 56; anchors.verticalCenter: parent.verticalCenter
                                            text: row.pinLocked ? "❖" : (row.pinned ? "◈" : "◇")
                                            color: row.pinLocked ? WidgetConfig.pinLockOutlineColor : (row.pinned ? root.cGold : (pinMa.containsMouse ? root.cCream : root.cDim))
                                            font.family: root.mono; font.pixelSize: 13
                                            MouseArea {
                                                id: pinMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: WidgetConfig.cyclePin(row.wid)
                                            }
                                        }
                                        // Remove icon
                                        Text {
                                            visible: rowHover.hovered || row.open
                                            anchors.right: parent.right; anchors.rightMargin: 34; anchors.verticalCenter: parent.verticalCenter
                                            text: "✕"; color: rmMa.containsMouse ? root.cDanger : root.cDim; font.pixelSize: 12
                                            MouseArea {
                                                id: rmMa; anchors.fill: parent; anchors.margins: -7; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { WidgetConfig.removeWidget(row.wid); if (root.expandedId === row.wid) root.expandedId = ""; }
                                            }
                                        }
                                        Text {
                                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                            text: (row.modified ? "● " : "") + (row.open ? "◂" : "▸")
                                            color: row.modified ? root.cGold : root.cDim
                                            font.family: root.mono; font.pixelSize: 11
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -8
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleExpand(row.wid)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.structure.length === 0
                        width: listCol.width; topPadding: 24; horizontalAlignment: Text.AlignHCenter
                        text: root.query !== "" ? "Nothing matches '" + root.query + "'." : "No widgets on any planet. Use + ADD."
                        color: root.cDim; font.family: root.mono; font.pixelSize: 11
                    }
                }
            }

            OWScroll { target: flick }
        }

        // =====================================================================
        //  KEYS TAB
        // =====================================================================
        Item {
            id: keysTab
            opacity: root.tab === "keys" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.tab === "keys"
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            x: 0; y: 96
            width: parent.width
            height: parent.height - 96

            Rectangle {
                id: keyBanner
                x: 18; y: 6; width: parent.width - 36; height: 30; radius: 6
                color: root.keyMsg !== "" ? "#22D9694A" : (root.capturing !== "" ? "#22D4AF37" : "transparent")
                border.width: (root.keyMsg !== "" || root.capturing !== "") ? 1 : 0
                border.color: root.keyMsg !== "" ? root.cDanger : root.cGold
                Text {
                    anchors.centerIn: parent; width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: root.keyMsg !== "" ? root.keyMsg
                        : (root.capturing !== "" ? "Press key for “" + Keybinds.labelOf(root.capturing) + "”" + (root.capHeld !== "" ? "  " + root.capHeld + " + …" : "") + "  ·  Esc cancels" : "")
                    color: root.keyMsg !== "" ? root.cDanger : root.cGold
                    font.family: root.mono; font.pixelSize: 11
                }
            }

            Flickable {
                id: keyFlick
                x: 18; y: 44; width: parent.width - 46; height: parent.height - y - 52
                contentWidth: width; contentHeight: keyCol.height + 12; clip: true
                boundsBehavior: Flickable.StopAtBounds

                OWWheel { scrollTarget: keyFlick }

                Column {
                    id: keyCol
                    width: keyFlick.width - 10

                    Repeater {
                        model: Keybinds.actions
                        delegate: Item {
                            id: kr
                            required property var modelData
                            required property int index
                            readonly property bool newGroup: index === 0 || Keybinds.actions[index - 1].group !== modelData.group
                            readonly property bool capt: root.capturing === modelData.id
                            readonly property bool custom: Keybinds.isCustom(modelData.id)
                            width: keyCol.width
                            height: (newGroup ? 34 : 0) + 38

                            Item {
                                visible: kr.newGroup; width: parent.width; height: 34
                                Text {
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                                    text: kr.modelData.group.toUpperCase(); color: root.cGold
                                    font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cLine }
                            }
                            Rectangle {
                                y: kr.newGroup ? 34 : 0; width: parent.width; height: 38; radius: 8
                                color: kr.capt ? "#24D4AF37" : (krHover.hovered ? "#15D4AF37" : "transparent")
                                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                HoverHandler { id: krHover }
                                Rectangle {
                                    x: 2; anchors.verticalCenter: parent.verticalCenter; width: 3; radius: 2; color: root.cGold
                                    height: kr.capt ? 20 : (krHover.hovered ? 14 : 0)
                                    opacity: (kr.capt || krHover.hovered) ? 1.0 : 0.0
                                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: 140 } }
                                }
                                Column {
                                    x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: kr.modelData.label; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                                    Text { visible: kr.modelData.hint !== ""; text: kr.modelData.hint; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                                }
                                Row {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                                    OWResetBtn {
                                        anchors.verticalCenter: parent.verticalCenter
                                        shown: kr.custom && !kr.capt
                                        onClicked: { WidgetConfig.resetKey(kr.modelData.id); root.keyMsg = ""; }
                                    }
                                    OWButton {
                                        visible: Keybinds.seq(kr.modelData.id) !== "" && !kr.capt
                                        pad: 7; implicitHeight: 26; label: "✕"
                                        onClicked: { Keybinds.unbind(kr.modelData.id); root.keyMsg = ""; }
                                    }
                                    OWButton {
                                        readonly property string curSeq: Keybinds.seq(kr.modelData.id)
                                        pad: 10; implicitHeight: 26
                                        label: kr.capt ? "PRESS A KEY…" : (curSeq === "" ? "NONE" : Keybinds.pretty(curSeq))
                                        dim: curSeq === "" && !kr.capt
                                        active: kr.capt || kr.custom
                                        onClicked: { if (kr.capt) { root.capturing = ""; root.keyMsg = ""; } else root.startCapture(kr.modelData.id); }
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: Keybinds.reference
                        delegate: Column {
                            id: refGroup
                            required property var modelData
                            width: keyCol.width
                            Item {
                                width: parent.width; height: 40
                                Text {
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                                    text: refGroup.modelData.group.toUpperCase(); color: root.cDim
                                    font.family: root.mono; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2
                                }
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cLine }
                            }
                            Repeater {
                                model: refGroup.modelData.rows
                                delegate: Item {
                                    required property var modelData
                                    width: keyCol.width; height: 26
                                    Text { width: 118; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: root.cCream; font.family: root.mono; font.pixelSize: 11; elide: Text.ElideRight }
                                    Text { x: 126; width: parent.width - 126; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: root.cDim; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                                }
                            }
                        }
                    }

                    Text {
                        width: keyCol.width; topPadding: 18; wrapMode: Text.Wrap
                        text: "These are the shell's own keys; they work while the scene has keyboard focus. Hyprland-level binds (outerwilds.lua) are separate: use qs -c outerwilds ipc call map | rumor | hud | keys | settings | launcher toggle."
                        color: root.cOff; font.family: root.mono; font.pixelSize: 10
                    }
                }
            }
            OWScroll { target: keyFlick }

            Item {
                x: 18; y: parent.height - 40; width: parent.width - 36; height: 28
                OWButton { label: "RESET ALL KEYS"; onClicked: { WidgetConfig.resetKeys(); root.keyMsg = ""; root.capturing = ""; } }
            }
        }

        // =====================================================================
        //  OPTIONS TAB (smooth accordions + per-option resets + HUD + presets)
        // =====================================================================
        Item {
            id: optionsTab
            opacity: root.tab === "options" ? 1.0 : 0.0
            visible: opacity > 0.01
            enabled: root.tab === "options"
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            x: 0; y: 96
            width: parent.width
            height: parent.height - 96

            Flickable {
                id: optFlick
                x: 18; y: 4
                width: parent.width - 46
                height: parent.height - 12
                contentWidth: width
                contentHeight: optCol.height + 16
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                OWWheel { scrollTarget: optFlick }

                Column {
                    id: optCol
                    width: optFlick.width - 10
                    spacing: 6

                    // ---- 1. SATELLITE HUD (master + individual element options) ----
                    OptAccordion {
                        optKey: "hud"; title: "Satellite HUD"; subtitle: "Gauges, audio globe, thrust & prompts"
                        hasSwitch: true; switchOn: WidgetConfig.showHud
                        onSwitchToggled: (v) => WidgetConfig.setShowHud(v)

                        FieldHeader { label: "MASTER OPACITY"; modified: WidgetConfig.isUiModified("hudOpacity"); onResetClicked: WidgetConfig.resetUiOption("hudOpacity") }
                        OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.hudOpacity; text: Math.round(WidgetConfig.hudOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setHudOpacity(v) }
                        FieldHeader { label: "MASTER SCALE"; modified: WidgetConfig.isUiModified("hudScale"); onResetClicked: WidgetConfig.resetUiOption("hudScale") }
                        OWSlider { width: parent.width; from: 0.5; to: 1.5; step: 0.05; value: WidgetConfig.hudScale; text: WidgetConfig.hudScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setHudScale(v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "GAUGE CLUSTER"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        OWToggleRow { label: "Show gauges (RAM / CPU / GPU)"; on: WidgetConfig.hudShowGauges; modified: WidgetConfig.isUiModified("hudShowGauges"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowGauges", v); onResetClicked: WidgetConfig.resetUiOption("hudShowGauges") }
                        OWToggleRow { label: "Show astronaut silhouette"; on: WidgetConfig.hudShowAstronaut; modified: WidgetConfig.isUiModified("hudShowAstronaut"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowAstronaut", v); onResetClicked: WidgetConfig.resetUiOption("hudShowAstronaut") }
                        OWToggleRow { label: "Show percentage labels"; on: WidgetConfig.hudShowGaugeLabels; modified: WidgetConfig.isUiModified("hudShowGaugeLabels"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowGaugeLabels", v); onResetClicked: WidgetConfig.resetUiOption("hudShowGaugeLabels") }
                        FieldHeader { label: "GAUGE SCALE"; modified: WidgetConfig.isUiModified("hudGaugeScale"); onResetClicked: WidgetConfig.resetUiOption("hudGaugeScale") }
                        OWSlider { width: parent.width; from: 0.5; to: 1.8; step: 0.05; value: WidgetConfig.hudGaugeScale; text: WidgetConfig.hudGaugeScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("hudGaugeScale", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "AUDIO GLOBE"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        OWToggleRow { label: "Show audio globe"; on: WidgetConfig.hudShowGlobe; modified: WidgetConfig.isUiModified("hudShowGlobe"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowGlobe", v); onResetClicked: WidgetConfig.resetUiOption("hudShowGlobe") }
                        OWToggleRow { label: "Show stand beam"; on: WidgetConfig.hudShowGlobeStand; modified: WidgetConfig.isUiModified("hudShowGlobeStand"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowGlobeStand", v); onResetClicked: WidgetConfig.resetUiOption("hudShowGlobeStand") }
                        FieldHeader { label: "GLOBE SCALE"; modified: WidgetConfig.isUiModified("hudGlobeScale"); onResetClicked: WidgetConfig.resetUiOption("hudGlobeScale") }
                        OWSlider { width: parent.width; from: 0.5; to: 1.8; step: 0.05; value: WidgetConfig.hudGlobeScale; text: WidgetConfig.hudGlobeScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("hudGlobeScale", v) }
                        FieldHeader { label: "GLOBE TINT"; modified: WidgetConfig.isUiModified("hudGlobeColor"); onResetClicked: WidgetConfig.resetUiOption("hudGlobeColor") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#6FEAEE"; value: WidgetConfig.hudGlobeColor; onEdited: (v) => WidgetConfig.setUiOpt("hudGlobeColor", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "THRUST INDICATOR"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        OWToggleRow { label: "Show thrust axes"; on: WidgetConfig.hudShowThrust; modified: WidgetConfig.isUiModified("hudShowThrust"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowThrust", v); onResetClicked: WidgetConfig.resetUiOption("hudShowThrust") }
                        OWToggleRow { label: "Show speed readout"; on: WidgetConfig.hudShowSpeed; modified: WidgetConfig.isUiModified("hudShowSpeed"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowSpeed", v); onResetClicked: WidgetConfig.resetUiOption("hudShowSpeed") }
                        FieldHeader { label: "THRUST SCALE"; modified: WidgetConfig.isUiModified("hudThrustScale"); onResetClicked: WidgetConfig.resetUiOption("hudThrustScale") }
                        OWSlider { width: parent.width; from: 0.5; to: 1.8; step: 0.05; value: WidgetConfig.hudThrustScale; text: WidgetConfig.hudThrustScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("hudThrustScale", v) }
                        FieldHeader { label: "THRUST COLOUR"; modified: WidgetConfig.isUiModified("hudThrustColor"); onResetClicked: WidgetConfig.resetUiOption("hudThrustColor") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#C6F6F1"; value: WidgetConfig.hudThrustColor; onEdited: (v) => WidgetConfig.setUiOpt("hudThrustColor", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "PROMPTS & TYPOGRAPHY"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        OWToggleRow { label: "Show top-right key prompts"; on: WidgetConfig.hudShowPrompts; modified: WidgetConfig.isUiModified("hudShowPrompts"); onToggled: (v) => WidgetConfig.setUiOpt("hudShowPrompts", v); onResetClicked: WidgetConfig.resetUiOption("hudShowPrompts") }
                        FieldHeader { label: "HUD TEXT COLOUR"; modified: WidgetConfig.isUiModified("hudTextColor"); onResetClicked: WidgetConfig.resetUiOption("hudTextColor") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#F2EBDD"; value: WidgetConfig.hudTextColor; onEdited: (v) => WidgetConfig.setUiOpt("hudTextColor", v) }
                        FieldHeader { label: "HUD FONT"; modified: WidgetConfig.isUiModified("hudFont"); onResetClicked: WidgetConfig.resetUiOption("hudFont") }
                        OWFontPicker { width: parent.width; allowBlank: false; defaultValue: "monospace"; value: WidgetConfig.hudFont; onEdited: (v) => WidgetConfig.setUiOpt("hudFont", v) }
                    }

                    // ---- 2. LOOP / SPEED PANEL ----
                    OptAccordion {
                        optKey: "loop"; title: "Loop / speed panel"
                        subtitle: "Bottom-right box  ·  Key: " + (Keybinds.pretty(Keybinds.seq("hud")) || "NONE")
                        hasSwitch: true; switchOn: WidgetConfig.showLoopPanel
                        onSwitchToggled: (v) => WidgetConfig.setShowLoopPanel(v)

                        FieldHeader { label: "OPACITY"; modified: WidgetConfig.isUiModified("loopPanelOpacity"); onResetClicked: WidgetConfig.resetUiOption("loopPanelOpacity") }
                        OWSlider { width: parent.width; from: 0.2; to: 1.0; step: 0.05; value: WidgetConfig.loopPanelOpacity; text: Math.round(WidgetConfig.loopPanelOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setLoopPanelOpacity(v) }
                        FieldHeader { label: "SCALE"; modified: WidgetConfig.isUiModified("loopPanelScale"); onResetClicked: WidgetConfig.resetUiOption("loopPanelScale") }
                        OWSlider { width: parent.width; from: 0.6; to: 1.5; step: 0.05; value: WidgetConfig.loopPanelScale; text: WidgetConfig.loopPanelScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setLoopPanelScale(v) }
                    }

                    // ---- 3. ORBIT LINES ----
                    OptAccordion {
                        optKey: "orbits"; title: "Orbit lines"; subtitle: "Elliptical planet paths in the background"
                        hasSwitch: true; switchOn: WidgetConfig.showOrbits
                        onSwitchToggled: (v) => WidgetConfig.setShowOrbits(v)

                        FieldHeader { label: "OPACITY"; modified: WidgetConfig.isUiModified("orbitOpacity"); onResetClicked: WidgetConfig.resetUiOption("orbitOpacity") }
                        OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.orbitOpacity; text: Math.round(WidgetConfig.orbitOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setOrbitOpacity(v) }
                        FieldHeader { label: "LINE WIDTH"; modified: WidgetConfig.isUiModified("orbitWidth"); onResetClicked: WidgetConfig.resetUiOption("orbitWidth") }
                        OWSlider { width: parent.width; from: 0.5; to: 4.0; step: 0.1; value: WidgetConfig.orbitWidth; text: WidgetConfig.orbitWidth.toFixed(1) + " px"; onMoved: (v) => WidgetConfig.setOrbitWidth(v) }
                    }

                    // ---- 4. PLANET LABELS ----
                    OptAccordion {
                        optKey: "labels"; title: "Planet labels"; subtitle: "Planet names and lock-on distances"
                        hasSwitch: true; switchOn: WidgetConfig.showLabels
                        onSwitchToggled: (v) => WidgetConfig.setShowLabels(v)

                        FieldHeader { label: "TEXT SIZE"; modified: WidgetConfig.isUiModified("labelSize"); onResetClicked: WidgetConfig.resetUiOption("labelSize") }
                        OWSlider { width: parent.width; from: 0.6; to: 2.0; step: 0.05; value: WidgetConfig.labelSize; text: WidgetConfig.labelSize.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setLabelSize(v) }
                        FieldHeader { label: "MAX DISTANCE"; modified: WidgetConfig.isUiModified("labelDist"); onResetClicked: WidgetConfig.resetUiOption("labelDist") }
                        OWSlider { width: parent.width; from: 500; to: 6000; step: 100; value: WidgetConfig.labelDist; text: Math.round(WidgetConfig.labelDist) + " m"; onMoved: (v) => WidgetConfig.setLabelDist(v) }
                    }

                    // ---- 5. TARGET / LOCK RETICLES ----
                    OptAccordion {
                        optKey: "reticles"; title: "Target / lock reticles"; subtitle: "Hover and lock-on brackets around planets"
                        hasSwitch: true; switchOn: WidgetConfig.showReticles
                        onSwitchToggled: (v) => WidgetConfig.setShowReticles(v)

                        FieldHeader { label: "OPACITY"; modified: WidgetConfig.isUiModified("reticleOpacity"); onResetClicked: WidgetConfig.resetUiOption("reticleOpacity") }
                        OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.reticleOpacity; text: Math.round(WidgetConfig.reticleOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setReticleOpacity(v) }
                        FieldHeader { label: "STROKE WIDTH"; modified: WidgetConfig.isUiModified("reticleWidth"); onResetClicked: WidgetConfig.resetUiOption("reticleWidth") }
                        OWSlider { width: parent.width; from: 0.5; to: 3.0; step: 0.1; value: WidgetConfig.reticleWidth; text: WidgetConfig.reticleWidth.toFixed(1) + "×"; onMoved: (v) => WidgetConfig.setReticleWidth(v) }
                    }

                    // ---- 6. RENDERING & PERFORMANCE ----
                    OptAccordion {
                        optKey: "render"; title: "Rendering & performance"; subtitle: "Quality / Balanced / Performance presets, FPS caps, planet resolution"

                        FieldHeader { label: "PERFORMANCE PRESET" }
                        Row {
                            spacing: 6
                            Repeater {
                                model: ["quality", "balanced", "performance"]
                                delegate: OWButton {
                                    required property string modelData
                                    label: modelData.toUpperCase(); pad: 10
                                    active: WidgetConfig.perfMode === modelData
                                    onClicked: WidgetConfig.setPerfMode(modelData)
                                }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            color: root.cDim; font.family: root.mono; font.pixelSize: 10
                            text: WidgetConfig.perfMode === "quality" ? "Everything native: 30 fps idle, 1024 px planet textures, planets at full resolution. The picture is unchanged."
                                : WidgetConfig.perfMode === "balanced" ? "20 fps idle, sensors every 3 s, big planets drawn at 85% resolution. Hard to tell apart from Quality."
                                : WidgetConfig.perfMode === "performance" ? "15 fps idle (orbits look steppier), 512 px textures, sensors every 5 s, big planets at 60% (slightly soft). Roughly 2-3x cheaper."
                                : "Custom: you changed a knob below by hand. Pick a preset to set them all."
                        }

                        OWToggleRow { label: "Shrink widgets when far away"; on: WidgetConfig.shrinkFar; modified: WidgetConfig.isUiModified("shrinkFar"); onToggled: (v) => WidgetConfig.setShrinkFar(v); onResetClicked: WidgetConfig.resetUiOption("shrinkFar") }
                        FieldHeader { label: "PLANET TEXTURE RESOLUTION"; modified: WidgetConfig.isUiModified("bakeW"); onResetClicked: WidgetConfig.resetUiOption("bakeW") }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [512, 1024, 2048]
                                delegate: OWButton {
                                    required property int modelData
                                    label: modelData + " px"; pad: 10
                                    active: WidgetConfig.bakeW === modelData
                                    onClicked: WidgetConfig.setBakeW(modelData)
                                }
                            }
                        }
                        FieldHeader { label: "ACTIVE FPS CAP"; modified: WidgetConfig.isUiModified("fpsActive"); onResetClicked: WidgetConfig.resetUiOption("fpsActive") }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [30, 60, 90, 120, 0]
                                delegate: OWButton {
                                    required property int modelData
                                    label: modelData === 0 ? "OFF" : (modelData + " fps"); pad: 8
                                    active: WidgetConfig.fpsActive === modelData
                                    onClicked: WidgetConfig.setUiOpt("fpsActive", modelData)
                                }
                            }
                        }
                        FieldHeader { label: "IDLE FPS CAP"; modified: WidgetConfig.isUiModified("fpsIdle"); onResetClicked: WidgetConfig.resetUiOption("fpsIdle") }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [15, 20, 30, 60, 0]
                                delegate: OWButton {
                                    required property int modelData
                                    label: modelData === 0 ? "OFF" : (modelData + " fps"); pad: 10
                                    active: WidgetConfig.fpsIdle === modelData
                                    onClicked: WidgetConfig.setFpsIdle(modelData)
                                }
                            }
                        }
                        FieldHeader { label: "SENSOR POLLING"; modified: WidgetConfig.isUiModified("sensorMs"); onResetClicked: WidgetConfig.resetUiOption("sensorMs") }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [2000, 3000, 5000]
                                delegate: OWButton {
                                    required property int modelData
                                    label: (modelData / 1000) + " s"; pad: 10
                                    active: WidgetConfig.sensorMs === modelData
                                    onClicked: WidgetConfig.setUiOpt("sensorMs", modelData)
                                }
                            }
                        }
                        FieldHeader { label: "BIG PLANET RENDER SCALE"; modified: WidgetConfig.isUiModified("planetScale"); onResetClicked: WidgetConfig.resetUiOption("planetScale") }
                        Row {
                            spacing: 6
                            Repeater {
                                model: [100, 85, 70, 60, 50]
                                delegate: OWButton {
                                    required property int modelData
                                    label: modelData + "%"; pad: 10
                                    active: Math.round(WidgetConfig.planetScale * 100) === modelData
                                    onClicked: WidgetConfig.setUiOpt("planetScale", modelData / 100)
                                }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            color: root.cDim; font.family: root.mono; font.pixelSize: 10
                            text: "Below 100% a large planet is drawn smaller and stretched: cheaper, a little softer. 100% is untouched."
                        }
                        OWToggleRow { label: "Performance values while on battery"; on: WidgetConfig.autoBattery; modified: WidgetConfig.isUiModified("autoBattery"); onToggled: (v) => WidgetConfig.setUiOpt("autoBattery", v); onResetClicked: WidgetConfig.resetUiOption("autoBattery") }
                        OWToggleRow { label: "FPS / CPU / GPU readout (top right)"; on: WidgetConfig.showDiag; modified: WidgetConfig.isUiModified("showDiag"); onToggled: (v) => WidgetConfig.setUiOpt("showDiag", v); onResetClicked: WidgetConfig.resetUiOption("showDiag") }
                    }

                    // ---- 6a. BACKUP & RESET A PLANET ----
                    OptAccordion {
                        optKey: "backup"; title: "Backup & reset a planet"; subtitle: "Back up widgets.json, reset the widgets of one planet"

                        FieldHeader { label: "BACKUP" }
                        OWButton { label: "BACK UP widgets.json"; onClicked: WidgetConfig.backupRequested() }
                        Text { visible: WidgetConfig.backupMsg !== ""; width: parent.width; wrapMode: Text.Wrap; text: WidgetConfig.backupMsg; color: root.cGold; font.family: root.mono; font.pixelSize: 10 }
                        FieldHeader { label: "RESET ONE PLANET" }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            color: root.cDim; font.family: root.mono; font.pixelSize: 10
                            text: "Click a planet twice: its widgets go back to the defaults and widgets you added there are deleted."
                        }
                        Flow {
                            width: parent.width; spacing: 6
                            Repeater {
                                model: WidgetConfig.planets
                                delegate: OWButton {
                                    required property var modelData
                                    label: root.confirmPlanet === modelData.id ? "SURE? " + modelData.name : modelData.name
                                    pad: 8
                                    danger: root.confirmPlanet === modelData.id
                                    onClicked: {
                                        if (root.confirmPlanet === modelData.id) { WidgetConfig.resetPlanet(modelData.id); root.expandedId = ""; root.confirmPlanet = ""; }
                                        else root.confirmPlanet = modelData.id;
                                    }
                                }
                            }
                        }
                        Timer { interval: 3000; running: root.confirmPlanet !== ""; onTriggered: root.confirmPlanet = "" }
                    }

                    // ---- 6b. FLIGHT & CAMERA ----
                    OptAccordion {
                        optKey: "flight"; title: "Flight & camera"; subtitle: "Space drift, cruise speed, orbit & look sensitivity"

                        OWToggleRow { label: "Space drift (6-DOF coasting)"; on: WidgetConfig.spaceDrift; modified: WidgetConfig.isUiModified("spaceDrift"); onToggled: (v) => WidgetConfig.setUiOpt("spaceDrift", v); onResetClicked: WidgetConfig.resetUiOption("spaceDrift") }
                        FieldHeader { label: "DRIFT CRUISE SPEED"; modified: WidgetConfig.isUiModified("driftCruise"); onResetClicked: WidgetConfig.resetUiOption("driftCruise") }
                        OWSlider { width: parent.width; from: 20; to: 250; step: 5; value: WidgetConfig.driftCruise; text: Math.round(WidgetConfig.driftCruise) + " u/s"; onMoved: (v) => WidgetConfig.setUiOpt("driftCruise", v) }
                        FieldHeader { label: "LOCK-ON ORBIT DISTANCE"; modified: WidgetConfig.isUiModified("lockOrbitK"); onResetClicked: WidgetConfig.resetUiOption("lockOrbitK") }
                        OWSlider { width: parent.width; from: 3.0; to: 12.0; step: 0.5; value: WidgetConfig.lockOrbitK; text: WidgetConfig.lockOrbitK.toFixed(1) + " radii"; onMoved: (v) => WidgetConfig.setUiOpt("lockOrbitK", v) }
                        FieldHeader { label: "MOUSE LOOK SENSITIVITY"; modified: WidgetConfig.isUiModified("lookSens"); onResetClicked: WidgetConfig.resetUiOption("lookSens") }
                        OWSlider { width: parent.width; from: 0.3; to: 2.5; step: 0.05; value: WidgetConfig.lookSens; text: WidgetConfig.lookSens.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("lookSens", v) }
                        FieldHeader { label: "UI SCROLL SENSITIVITY"; modified: WidgetConfig.isUiModified("uiScrollSens"); onResetClicked: WidgetConfig.resetUiOption("uiScrollSens") }
                        OWSlider { width: parent.width; from: 0.3; to: 4.0; step: 0.1; value: WidgetConfig.uiScrollSens; text: WidgetConfig.uiScrollSens.toFixed(1) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("uiScrollSens", v) }
                        FieldHeader { label: "DEFAULT LOOP SPEED"; modified: WidgetConfig.isUiModified("defaultTimeScale"); onResetClicked: WidgetConfig.resetUiOption("defaultTimeScale") }
                        OWSlider { width: parent.width; from: 1; to: 50; step: 1; value: WidgetConfig.defaultTimeScale; text: Math.round(WidgetConfig.defaultTimeScale) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("defaultTimeScale", v) }
                    }

                    // ---- 7. WIDGETS (GLOBAL DEFAULTS + PINNING) ----
                    OptAccordion {
                        optKey: "wglobal"; title: "Widgets (global defaults)"; subtitle: "Default opacity, radius, accent & pin dimming"

                        FieldHeader { label: "GLOBAL OPACITY"; modified: WidgetConfig.isUiModified("widgetOpacity"); onResetClicked: WidgetConfig.resetUiOption("widgetOpacity") }
                        OWSlider { width: parent.width; from: 0.2; to: 1.0; step: 0.05; value: WidgetConfig.widgetOpacity; text: Math.round(WidgetConfig.widgetOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setWidgetOpacity(v) }
                        FieldHeader { label: "DEFAULT CORNER RADIUS"; modified: WidgetConfig.isUiModified("widgetRadius"); onResetClicked: WidgetConfig.resetUiOption("widgetRadius") }
                        OWSlider { width: parent.width; from: 0; to: 24; step: 1; value: WidgetConfig.widgetRadius; text: Math.round(WidgetConfig.widgetRadius) + " px"; onMoved: (v) => WidgetConfig.setWidgetRadius(v) }
                        FieldHeader { label: "DEFAULT ACCENT COLOUR"; modified: WidgetConfig.isUiModified("widgetAccent"); onResetClicked: WidgetConfig.resetUiOption("widgetAccent") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#D4AF37"; value: WidgetConfig.widgetAccent; onEdited: (v) => WidgetConfig.setWidgetAccent(v) }
                        OWToggleRow { label: "Show corner brackets"; on: WidgetConfig.widgetBrackets; modified: WidgetConfig.isUiModified("widgetBrackets"); onToggled: (v) => WidgetConfig.setWidgetBrackets(v); onResetClicked: WidgetConfig.resetUiOption("widgetBrackets") }
                        OWToggleRow { label: "Pause orbit on hover"; on: WidgetConfig.widgetHoldOnHover; modified: WidgetConfig.isUiModified("widgetHoldOnHover"); onToggled: (v) => WidgetConfig.setWidgetHoldOnHover(v); onResetClicked: WidgetConfig.resetUiOption("widgetHoldOnHover") }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        FieldHeader { label: "PINNED SCALE"; modified: WidgetConfig.isUiModified("pinScale"); onResetClicked: WidgetConfig.resetUiOption("pinScale") }
                        OWSlider { width: parent.width; from: 1.0; to: 2.0; step: 0.05; value: WidgetConfig.pinScale; text: WidgetConfig.pinScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("pinScale", v) }
                        OWToggleRow { label: "Dim unpinned widgets"; on: WidgetConfig.pinDimEnabled; modified: WidgetConfig.isUiModified("pinDimEnabled"); onToggled: (v) => WidgetConfig.setUiOpt("pinDimEnabled", v); onResetClicked: WidgetConfig.resetUiOption("pinDimEnabled") }
                        FieldHeader { visible: WidgetConfig.pinDimEnabled; label: "DIM SCOPE"; modified: WidgetConfig.isUiModified("pinDimScope"); onResetClicked: WidgetConfig.resetUiOption("pinDimScope") }
                        Row {
                            visible: WidgetConfig.pinDimEnabled; spacing: 6
                            OWButton { label: "HOST PLANET"; active: WidgetConfig.pinDimScope === "planet"; onClicked: WidgetConfig.setUiOpt("pinDimScope", "planet") }
                            OWButton { label: "EVERYWHERE"; active: WidgetConfig.pinDimScope === "everywhere"; onClicked: WidgetConfig.setUiOpt("pinDimScope", "everywhere") }
                        }
                        FieldHeader { visible: WidgetConfig.pinDimEnabled; label: "UNPINNED DIM OPACITY"; modified: WidgetConfig.isUiModified("pinDimOpacity"); onResetClicked: WidgetConfig.resetUiOption("pinDimOpacity") }
                        OWSlider { visible: WidgetConfig.pinDimEnabled; width: parent.width; from: 0.05; to: 1.0; step: 0.05; value: WidgetConfig.pinDimOpacity; text: Math.round(WidgetConfig.pinDimOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setUiOpt("pinDimOpacity", v) }
                        FieldHeader { label: "PIN OUTLINE COLOUR"; modified: WidgetConfig.isUiModified("pinOutlineColor"); onResetClicked: WidgetConfig.resetUiOption("pinOutlineColor") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#D4AF37"; value: WidgetConfig.pinOutlineColor; onEdited: (v) => WidgetConfig.setUiOpt("pinOutlineColor", v) }
                        FieldHeader { label: "LOCKED PIN OUTLINE COLOUR"; modified: WidgetConfig.isUiModified("pinLockOutlineColor"); onResetClicked: WidgetConfig.resetUiOption("pinLockOutlineColor") }
                        OWColorPicker { width: parent.width; allowBlank: false; defaultValue: "#6FEAEE"; value: WidgetConfig.pinLockOutlineColor; onEdited: (v) => WidgetConfig.setUiOpt("pinLockOutlineColor", v) }
                        OWToggleRow { label: "Progress orbits on pinned widgets"; on: WidgetConfig.pinOrbitDefault; modified: WidgetConfig.isUiModified("pinOrbitDefault"); onToggled: (v) => WidgetConfig.setUiOpt("pinOrbitDefault", v); onResetClicked: WidgetConfig.resetUiOption("pinOrbitDefault") }
                        Text {
                            width: parent.width; wrapMode: Text.Wrap
                            text: "Double-click pins a widget. Tab + double-click a pinned widget to lock it in place. Pin icon cycles: pin → lock → unpin."
                            color: root.cDim; font.family: root.mono; font.pixelSize: 10
                        }
                    }

                    // ---- 7b. NOTIFICATIONS (SHIP LOG) ----
                    OptAccordion {
                        optKey: "notifications"; title: "Notifications (Ship Log)"; subtitle: "Popup auto-hide, aging archives & clear log"

                        OWToggleRow { label: "Auto-hide notification popups"; on: WidgetConfig.notifAutoHide; modified: WidgetConfig.isUiModified("notifAutoHide"); onToggled: (v) => WidgetConfig.setUiOpt("notifAutoHide", v); onResetClicked: WidgetConfig.resetUiOption("notifAutoHide") }
                        FieldHeader { visible: WidgetConfig.notifAutoHide; label: "POPUP DURATION"; modified: WidgetConfig.isUiModified("notifHideSec"); onResetClicked: WidgetConfig.resetUiOption("notifHideSec") }
                        OWSlider { visible: WidgetConfig.notifAutoHide; width: parent.width; from: 1.0; to: 10.0; step: 0.2; value: WidgetConfig.notifHideSec; text: WidgetConfig.notifHideSec.toFixed(1) + " s"; onMoved: (v) => WidgetConfig.setUiOpt("notifHideSec", v) }
                        Text {
                            visible: !WidgetConfig.notifAutoHide
                            width: parent.width; wrapMode: Text.Wrap
                            text: "Popups stay visible until you click them, dismiss them, or open the Ship Log."
                            color: root.cDim; font.family: root.mono; font.pixelSize: 10
                        }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        OWToggleRow { label: "Auto-archive old read rumors"; on: WidgetConfig.notifAutoArchive; modified: WidgetConfig.isUiModified("notifAutoArchive"); onToggled: (v) => WidgetConfig.setUiOpt("notifAutoArchive", v); onResetClicked: WidgetConfig.resetUiOption("notifAutoArchive") }
                        FieldHeader { visible: WidgetConfig.notifAutoArchive; label: "ARCHIVE AFTER"; modified: WidgetConfig.isUiModified("notifArchiveHours"); onResetClicked: WidgetConfig.resetUiOption("notifArchiveHours") }
                        OWSlider { visible: WidgetConfig.notifAutoArchive; width: parent.width; from: 1; to: 168; step: 1; value: WidgetConfig.notifArchiveHours; text: Math.round(WidgetConfig.notifArchiveHours) + " h"; onMoved: (v) => WidgetConfig.setUiOpt("notifArchiveHours", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        OWButton {
                            label: root.confirmClearNotifs ? "SURE? CLICK AGAIN" : ("CLEAR ALL NOTIFICATIONS (" + RumorData.notifications.length + ")")
                            danger: root.confirmClearNotifs
                            dim: RumorData.notifications.length === 0 && !root.confirmClearNotifs
                            onClicked: {
                                if (RumorData.notifications.length === 0) return;
                                if (root.confirmClearNotifs) { RumorData.clear(); root.confirmClearNotifs = false; }
                                else root.confirmClearNotifs = true;
                            }
                        }
                        Timer { interval: 3000; running: root.confirmClearNotifs; onTriggered: root.confirmClearNotifs = false }
                    }

                    // ---- 8. WIDGET PACK THEMES ----
                    OptAccordion {
                        optKey: "packthemes"; title: "Widget pack themes"; subtitle: "Global Outer Wilds, Glyph, Lucid & Serpantinum colours"

                        Text { text: "OUTER WILDS (NATIVE)  (blank = default)"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        OWToggleRow { label: "Tint colours by host planet"; on: WidgetConfig.nativePlanetTheme; modified: WidgetConfig.isUiModified("nativePlanetTheme"); onToggled: (v) => WidgetConfig.setPackTheme("nativePlanetTheme", v); onResetClicked: WidgetConfig.resetUiOption("nativePlanetTheme") }
                        OWToggleRow { label: "Layered instrument depth"; on: WidgetConfig.nativeLayers; modified: WidgetConfig.isUiModified("nativeLayers"); onToggled: (v) => WidgetConfig.setPackTheme("nativeLayers", v); onResetClicked: WidgetConfig.resetUiOption("nativeLayers") }
                        FieldHeader { label: "CARD OPACITY"; modified: WidgetConfig.isUiModified("nativeOpacity"); onResetClicked: WidgetConfig.resetUiOption("nativeOpacity") }
                        OWSlider { width: parent.width; from: 0.2; to: 1.0; step: 0.05; value: WidgetConfig.nativeOpacity; text: Math.round(WidgetConfig.nativeOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setPackTheme("nativeOpacity", v) }
                        FieldHeader { label: "CARD FILL"; modified: WidgetConfig.isUiModified("nativeBg"); onResetClicked: WidgetConfig.resetUiOption("nativeBg") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.nativeBg; onEdited: (v) => WidgetConfig.setPackTheme("nativeBg", v) }
                        FieldHeader { label: "INNER LAYER FILL"; modified: WidgetConfig.isUiModified("nativeSurface"); onResetClicked: WidgetConfig.resetUiOption("nativeSurface") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.nativeSurface; onEdited: (v) => WidgetConfig.setPackTheme("nativeSurface", v) }
                        FieldHeader { label: "PRIMARY TEXT"; modified: WidgetConfig.isUiModified("nativeText"); onResetClicked: WidgetConfig.resetUiOption("nativeText") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.nativeText; onEdited: (v) => WidgetConfig.setPackTheme("nativeText", v) }
                        FieldHeader { label: "SECONDARY TEXT"; modified: WidgetConfig.isUiModified("nativeDim"); onResetClicked: WidgetConfig.resetUiOption("nativeDim") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.nativeDim; onEdited: (v) => WidgetConfig.setPackTheme("nativeDim", v) }
                        FieldHeader { label: "ACCENT OVERRIDE"; modified: WidgetConfig.isUiModified("nativeAccent"); onResetClicked: WidgetConfig.resetUiOption("nativeAccent") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.nativeAccent; onEdited: (v) => WidgetConfig.setPackTheme("nativeAccent", v) }
                        FieldHeader { label: "FONT"; modified: WidgetConfig.isUiModified("nativeFont"); onResetClicked: WidgetConfig.resetUiOption("nativeFont") }
                        OWFontPicker { width: parent.width; value: WidgetConfig.nativeFont; onEdited: (v) => WidgetConfig.setPackTheme("nativeFont", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "GLYPH  (blank = default)"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        FieldHeader { label: "CARD FILL"; modified: WidgetConfig.isUiModified("glyphBg"); onResetClicked: WidgetConfig.resetUiOption("glyphBg") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.glyphBg; onEdited: (v) => WidgetConfig.setPackTheme("glyphBg", v) }
                        FieldHeader { label: "LIT DOTS / TEXT"; modified: WidgetConfig.isUiModified("glyphFg"); onResetClicked: WidgetConfig.resetUiOption("glyphFg") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.glyphFg; onEdited: (v) => WidgetConfig.setPackTheme("glyphFg", v) }
                        FieldHeader { label: "LIVE ACCENT (DEFAULT RED)"; modified: WidgetConfig.isUiModified("glyphAccent"); onResetClicked: WidgetConfig.resetUiOption("glyphAccent") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.glyphAccent; onEdited: (v) => WidgetConfig.setPackTheme("glyphAccent", v) }
                        FieldHeader { label: "UNLIT DOTS"; modified: WidgetConfig.isUiModified("glyphOff"); onResetClicked: WidgetConfig.resetUiOption("glyphOff") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.glyphOff; onEdited: (v) => WidgetConfig.setPackTheme("glyphOff", v) }
                        FieldHeader { label: "FONT"; modified: WidgetConfig.isUiModified("glyphFont"); onResetClicked: WidgetConfig.resetUiOption("glyphFont") }
                        OWFontPicker { width: parent.width; value: WidgetConfig.glyphFont; onEdited: (v) => WidgetConfig.setPackTheme("glyphFont", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "LUCID  (blank = default)"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        FieldHeader { label: "SURFACE"; modified: WidgetConfig.isUiModified("lucidBg"); onResetClicked: WidgetConfig.resetUiOption("lucidBg") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.lucidBg; onEdited: (v) => WidgetConfig.setPackTheme("lucidBg", v) }
                        FieldHeader { label: "TEXT"; modified: WidgetConfig.isUiModified("lucidText"); onResetClicked: WidgetConfig.resetUiOption("lucidText") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.lucidText; onEdited: (v) => WidgetConfig.setPackTheme("lucidText", v) }
                        FieldHeader { label: "ACCENT"; modified: WidgetConfig.isUiModified("lucidAccent"); onResetClicked: WidgetConfig.resetUiOption("lucidAccent") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.lucidAccent; onEdited: (v) => WidgetConfig.setPackTheme("lucidAccent", v) }
                        FieldHeader { label: "FONT"; modified: WidgetConfig.isUiModified("lucidFont"); onResetClicked: WidgetConfig.resetUiOption("lucidFont") }
                        OWFontPicker { width: parent.width; value: WidgetConfig.lucidFont; onEdited: (v) => WidgetConfig.setPackTheme("lucidFont", v) }

                        Rectangle { width: parent.width; height: 1; color: root.cLine }
                        Text { text: "SERPANTINUM / ANSERIN  (blank = default)"; color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2 }
                        FieldHeader { label: "SURFACE"; modified: WidgetConfig.isUiModified("serpSurface"); onResetClicked: WidgetConfig.resetUiOption("serpSurface") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.serpSurface; onEdited: (v) => WidgetConfig.setPackTheme("serpSurface", v) }
                        FieldHeader { label: "TEXT"; modified: WidgetConfig.isUiModified("serpText"); onResetClicked: WidgetConfig.resetUiOption("serpText") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.serpText; onEdited: (v) => WidgetConfig.setPackTheme("serpText", v) }
                        FieldHeader { label: "ACCENT"; modified: WidgetConfig.isUiModified("serpAccent"); onResetClicked: WidgetConfig.resetUiOption("serpAccent") }
                        OWColorPicker { width: parent.width; value: WidgetConfig.serpAccent; onEdited: (v) => WidgetConfig.setPackTheme("serpAccent", v) }
                        FieldHeader { label: "CARD OPACITY"; modified: WidgetConfig.isUiModified("serpOpacity"); onResetClicked: WidgetConfig.resetUiOption("serpOpacity") }
                        OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.serpOpacity; text: Math.round(WidgetConfig.serpOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setPackTheme("serpOpacity", v) }
                        FieldHeader { label: "CORNER RADIUS"; modified: WidgetConfig.isUiModified("serpRadius"); onResetClicked: WidgetConfig.resetUiOption("serpRadius") }
                        OWSlider { width: parent.width; from: 0; to: 28; step: 1; value: WidgetConfig.serpRadius; text: Math.round(WidgetConfig.serpRadius) + " px"; onMoved: (v) => WidgetConfig.setPackTheme("serpRadius", v) }
                        FieldHeader { label: "FONT"; modified: WidgetConfig.isUiModified("serpFont"); onResetClicked: WidgetConfig.resetUiOption("serpFont") }
                        OWFontPicker { width: parent.width; value: WidgetConfig.serpFont; onEdited: (v) => WidgetConfig.setPackTheme("serpFont", v) }

                        OWButton { label: "RESET PACK THEMES"; onClicked: WidgetConfig.resetPackThemes() }
                    }

                    // ---- 9. LAYOUT PRESETS (save / load / import / export) ----
                    OptAccordion {
                        optKey: "presets"; title: "Layout presets"; subtitle: "Save, switch, import & export desktop setups"

                        Row {
                            width: parent.width; spacing: 6
                            Rectangle {
                                width: parent.width - savePBtn.width - 6; height: 28; radius: 7
                                color: "#0C101C"; border.width: 1; border.color: presetNameIn.activeFocus ? root.cGold : root.cLine
                                Text {
                                    x: 10; anchors.verticalCenter: parent.verticalCenter
                                    visible: presetNameIn.text === "" && !presetNameIn.activeFocus
                                    text: "new preset name..."; color: root.cOff; font.family: root.mono; font.pixelSize: 11
                                }
                                TextInput {
                                    id: presetNameIn
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter; clip: true
                                    color: root.cCream; font.family: root.mono; font.pixelSize: 11
                                    property bool _ft: false
                                    function _st(v) { if (v && !_ft) { _ft = true; root.textFocusCount++; } else if (!v && _ft) { _ft = false; root.textFocusCount = Math.max(0, root.textFocusCount - 1); } }
                                    Component.onDestruction: _st(false)
                                    onActiveFocusChanged: _st(activeFocus)
                                    onAccepted: {
                                        if (WidgetConfig.savePreset(text)) { root.presetMsg = "Saved '" + text.trim() + "'"; text = ""; focus = false; }
                                    }
                                }
                            }
                            OWButton {
                                id: savePBtn; implicitHeight: 28; pad: 10; label: "SAVE"; active: true
                                onClicked: {
                                    if (WidgetConfig.savePreset(presetNameIn.text)) { root.presetMsg = "Saved '" + presetNameIn.text.trim() + "'"; presetNameIn.text = ""; }
                                    else root.presetMsg = "Enter a preset name first.";
                                }
                            }
                        }

                        Row {
                            spacing: 6
                            OWButton { label: "IMPORT JSON"; pad: 9; onClicked: root.presetImportRequested() }
                            OWButton { label: "EXPORT CURRENT"; pad: 9; onClicked: root.presetExportRequested("outerwilds-layout", WidgetConfig.exportPresetJson("")) }
                        }

                        Text {
                            visible: root.presetMsg !== ""
                            width: parent.width; wrapMode: Text.Wrap
                            text: root.presetMsg; color: root.cGold; font.family: root.mono; font.pixelSize: 10
                        }

                        Column {
                            width: parent.width; spacing: 4
                            readonly property var names: WidgetConfig.presetNames()
                            Text {
                                visible: parent.names.length === 0
                                text: "No saved presets yet."
                                color: root.cOff; font.family: root.mono; font.pixelSize: 10
                            }
                            Repeater {
                                model: parent.names
                                delegate: Rectangle {
                                    required property string modelData
                                    width: parent.width; height: 32; radius: 6
                                    color: "#0E1424"; border.width: 1; border.color: root.cLine
                                    Text {
                                        x: 10; width: parent.width - 134; anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight; text: modelData
                                        color: root.cCream; font.family: root.mono; font.pixelSize: 11
                                    }
                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                                        OWButton { implicitHeight: 22; pad: 7; label: "LOAD"; onClicked: { WidgetConfig.loadPreset(modelData); root.presetMsg = "Loaded '" + modelData + "'"; } }
                                        OWButton { implicitHeight: 22; pad: 7; label: "EXP"; onClicked: root.presetExportRequested(modelData, WidgetConfig.exportPresetJson(modelData)) }
                                        OWButton { implicitHeight: 22; pad: 6; label: "✕"; danger: true; onClicked: { WidgetConfig.deletePreset(modelData); root.presetMsg = "Deleted '" + modelData + "'"; } }
                                    }
                                }
                            }
                        }
                    }

                    // ---- 9b. 3D BUBBLES ----
                    OptAccordion {
                        optKey: "bubbles3d"; title: "3D Bubbles"; subtitle: "Cluster gravity, hub spacing, process cap & family grouping"

                        Row {
                            spacing: 6
                            OWButton {
                                label: BubbleState.open ? "HIDE 3D BUBBLES" : "SHOW 3D BUBBLES"
                                active: BubbleState.open
                                onClicked: BubbleState.open = !BubbleState.open
                            }
                            OWButton {
                                visible: BubbleState.open
                                label: "SUMMON"
                                onClicked: BubbleState.recenterSeq++
                            }
                        }

                        FieldHeader { label: "MAX PROCESS BUBBLES"; modified: WidgetConfig.isUiModified("bubbleMaxProcs"); onResetClicked: WidgetConfig.resetUiOption("bubbleMaxProcs") }
                        OWSlider { width: parent.width; from: 8; to: 64; step: 2; value: WidgetConfig.bubbleMaxProcs; text: Math.round(WidgetConfig.bubbleMaxProcs) + " procs"; onMoved: (v) => WidgetConfig.setUiOpt("bubbleMaxProcs", v) }

                        FieldHeader { label: "HUB SPACING (CPU / RAM / TEMP / NET / DISK)"; modified: WidgetConfig.isUiModified("bubbleHubSpacing"); onResetClicked: WidgetConfig.resetUiOption("bubbleHubSpacing") }
                        OWSlider { width: parent.width; from: 80; to: 320; step: 5; value: WidgetConfig.bubbleHubSpacing; text: Math.round(WidgetConfig.bubbleHubSpacing) + " u"; onMoved: (v) => WidgetConfig.setUiOpt("bubbleHubSpacing", v) }

                        FieldHeader { label: "ORBIT PULL (PROCS AROUND METRIC HUBS)"; modified: WidgetConfig.isUiModified("bubbleOrbitPull"); onResetClicked: WidgetConfig.resetUiOption("bubbleOrbitPull") }
                        OWSlider { width: parent.width; from: 0.0; to: 1.8; step: 0.05; value: WidgetConfig.bubbleOrbitPull; text: WidgetConfig.bubbleOrbitPull.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("bubbleOrbitPull", v) }

                        FieldHeader { label: "CLUSTER GRAVITY"; modified: WidgetConfig.isUiModified("bubbleGravity"); onResetClicked: WidgetConfig.resetUiOption("bubbleGravity") }
                        OWSlider { width: parent.width; from: 0.0; to: 1.2; step: 0.02; value: WidgetConfig.bubbleGravity; text: WidgetConfig.bubbleGravity.toFixed(2); onMoved: (v) => WidgetConfig.setUiOpt("bubbleGravity", v) }

                        FieldHeader { label: "SIMILAR PROCESS GROUPING"; modified: WidgetConfig.isUiModified("bubbleGroupAttract"); onResetClicked: WidgetConfig.resetUiOption("bubbleGroupAttract") }
                        OWSlider { width: parent.width; from: 0.0; to: 1.8; step: 0.05; value: WidgetConfig.bubbleGroupAttract; text: WidgetConfig.bubbleGroupAttract.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("bubbleGroupAttract", v) }

                        FieldHeader { label: "SPHERE SCALE"; modified: WidgetConfig.isUiModified("bubbleSphereSize"); onResetClicked: WidgetConfig.resetUiOption("bubbleSphereSize") }
                        OWSlider { width: parent.width; from: 0.6; to: 1.8; step: 0.05; value: WidgetConfig.bubbleSphereSize; text: WidgetConfig.bubbleSphereSize.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setUiOpt("bubbleSphereSize", v) }
                    }

                    // ---- 10. RESET ----
                    Rectangle {
                        width: parent.width; height: 92; radius: 8; color: "#0D1322"; border.width: 1; border.color: root.cLine
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; spacing: 6
                            Text { text: "Reset"; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: "Puts every widget back where it started and keeps your keys."
                                color: root.cDim; font.family: root.mono; font.pixelSize: 10
                            }
                            OWButton {
                                label: root.confirmReset ? "SURE? CLICK AGAIN" : "RESET ALL WIDGETS"
                                danger: root.confirmReset
                                onClicked: {
                                    if (root.confirmReset) { WidgetConfig.resetAll(); root.expandedId = ""; root.confirmReset = false; }
                                    else root.confirmReset = true;
                                }
                            }
                        }
                        Timer { interval: 3000; running: root.confirmReset; onTriggered: root.confirmReset = false }
                    }
                }
            }
            OWScroll { target: optFlick }
        }

        // ---------------- widget picker overlay (add / swap / restore) ----------------
        Rectangle {
            id: picker
            visible: root.picking
            anchors.fill: parent
            radius: mainPanel.radius
            color: "#070911"
            z: 10

            MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: (w) => { w.accepted = true; } }

            Text {
                x: 18; y: 18
                text: root.pickMode === "add" ? "ADD A WIDGET" : "CHANGE WIDGET TYPE"
                color: root.cCream; font.family: root.mono; font.bold: true; font.pixelSize: 14; font.letterSpacing: 3
            }
            OWButton { x: parent.width - width - 18; y: 14; label: "CANCEL"; onClicked: root.picking = false }
            Text {
                x: 18; y: 44; width: parent.width - 36; wrapMode: Text.Wrap
                text: root.pickMode === "add"
                      ? "Goes on " + WidgetConfig.planetName(root.lastHost) + (root.pickFromFocus ? " (focused planet)" : "") + ". Dimmed = already on a planet: MOVE HERE relocates it, + COPY adds another."
                      : "Keeps this widget's planet, orbit and size."
                color: root.cDim; font.family: root.mono; font.pixelSize: 10
            }
            SearchBox {
                x: 18; y: 78; width: parent.width - 36
                placeholder: "search"
                text: root.pickQuery; onTextChanged: root.pickQuery = text
            }

            Flow {
                id: groupFlow
                visible: root.pickMode === "add" && root.pickGroups.length > 1
                x: 18; y: 116; width: parent.width - 36; spacing: 6
                OWButton { label: "ALL"; pad: 8; active: root.pickGroup === ""; onClicked: root.pickGroup = "" }
                Repeater {
                    model: root.pickGroups
                    delegate: OWButton {
                        required property string modelData
                        label: modelData.toUpperCase(); pad: 8
                        active: root.pickGroup === modelData
                        onClicked: root.pickGroup = (root.pickGroup === modelData ? "" : modelData)
                    }
                }
            }

            Flickable {
                id: pickFlick
                x: 18; y: groupFlow.visible ? groupFlow.y + groupFlow.height + 8 : 116; width: parent.width - 46; height: parent.height - y - 12
                contentHeight: pickCol.height + 12; clip: true
                boundsBehavior: Flickable.StopAtBounds

                OWWheel { scrollTarget: pickFlick }

                Column {
                    id: pickCol
                    width: parent.width - 8
                    Repeater {
                        model: root.pickModel
                        delegate: Item {
                            id: pe
                            required property var modelData
                            width: pickCol.width
                            readonly property bool placed: modelData.kind === "item" && modelData.where !== undefined && modelData.where.length > 0
                            height: modelData.kind === "group" ? 30 : (placed ? 46 : 28)

                            Text {
                                visible: pe.modelData.kind === "group"
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                                text: pe.modelData.text || ""; color: root.cGold
                                font.family: root.mono; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2
                            }
                            Rectangle {
                                visible: pe.modelData.kind !== "group"
                                width: parent.width; height: pe.placed ? 42 : 30; radius: 7
                                color: pma.containsMouse && !pe.placed ? "#1CD4AF37" : "transparent"
                                Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Column {
                                    x: 8; anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16 - (pe.placed ? 168 : 0); spacing: 2
                                    Text {
                                        width: parent.width; elide: Text.ElideRight
                                        text: pe.modelData.kind === "restore"
                                              ? pe.modelData.name + "   ·   " + WidgetConfig.planetName(pe.modelData.planet)
                                              : (pe.modelData.name || "")
                                        color: pe.modelData.kind === "restore" ? root.cGold : (pe.placed ? root.cDim : root.cCream)
                                        font.family: root.mono; font.pixelSize: 12
                                    }
                                    Text {
                                        visible: pe.placed; width: parent.width; elide: Text.ElideRight
                                        text: pe.placed ? "ON: " + pe.modelData.where.join(", ") : ""
                                        color: root.cGold; opacity: 0.75
                                        font.family: root.mono; font.pixelSize: 9; font.letterSpacing: 1
                                    }
                                }
                                Row {
                                    visible: pe.placed
                                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    OWButton { visible: pe.modelData.canMove === true; label: "MOVE HERE"; pad: 8; onClicked: root.pickMove(pe.modelData.source) }
                                    OWButton { label: "+ COPY"; pad: 8; onClicked: root.pickChosen(pe.modelData.source) }
                                }
                                MouseArea {
                                    id: pma; anchors.fill: parent; enabled: !pe.placed; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (pe.modelData.kind === "restore") root.pickRestore(pe.modelData.id);
                                        else if (pe.modelData.kind === "item") root.pickChosen(pe.modelData.source);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            OWScroll { target: pickFlick }
        }
    } // end mainPanel

    // =====================================================================
    //  DETACHED POP-OUT WIDGET INSPECTOR (left of Control Centre)
    // =====================================================================
    Rectangle {
        id: inspectorPanel
        z: 1
        property real slide: (root.inspectorOpen && WidgetConfig.panelOpen) ? 1.0 : 0.0
        Behavior on slide { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        visible: (root.inspectorOpen && WidgetConfig.panelOpen) || slide > 0.01
        opacity: slide
        layer.enabled: slide > 0.001 && slide < 0.999
        enabled: root.inspectorOpen && WidgetConfig.panelOpen
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: mainPanel.left
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        anchors.rightMargin: 10 - (1.0 - slide) * 48
        width: 380
        radius: 12
        clip: true
        color: "#F5070911"
        border.width: 1
        border.color: "#66D4AF37"

        OWBrackets { }

        property var cachedEntry: null
        Connections {
            target: root
            function onInspEntryChanged() { if (root.inspEntry) inspectorPanel.cachedEntry = root.inspEntry; }
        }
        readonly property var d: root.inspEntry || cachedEntry
        readonly property string wid: root.expandedId !== "" ? root.expandedId : (cachedEntry ? cachedEntry.id : "")
        readonly property bool modified: d !== null && (WidgetConfig.overrides[wid] !== undefined || d._extra)
        readonly property string keyAction: d ? Keybinds.forWidget(d.source) : ""
        readonly property string sourcePath: d ? String(d.source || "") : ""
        readonly property var schema: sourcePath !== "" ? WidgetConfig.settingsSchema(sourcePath) : []
        Connections {
            target: root
            function onInspectorTabChanged() { inspFlick.contentY = 0; }
        }

        Rectangle {
            anchors.fill: parent; radius: parent.radius; z: -1
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#F50E1324" }
                GradientStop { position: 0.45; color: "#F5070911" }
                GradientStop { position: 1.0; color: "#F504050B" }
            }
        }

        Item {
            id: inspHead
            x: 16; y: 14; width: parent.width - 32; height: 38
            Text {
                width: parent.width - (inspOrbBtn.visible ? 106 : 72); elide: Text.ElideRight
                text: inspectorPanel.d ? WidgetConfig.widgetName(inspectorPanel.d).toUpperCase() : ""
                color: root.cCream; font.family: root.mono; font.bold: true; font.pixelSize: 13; font.letterSpacing: 2
            }
            Row {
                y: 20; spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 4
                    color: inspectorPanel.d ? WidgetConfig.planetColor(inspectorPanel.d.host) : root.cGold
                }
                Text {
                    text: inspectorPanel.d ? WidgetConfig.planetName(inspectorPanel.d.host).toUpperCase() : ""
                    color: root.cGold; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 2
                }
            }
            OWButton {
                id: inspOrbBtn
                visible: inspectorPanel.d !== null && WidgetConfig.supportsPinOrbit(inspectorPanel.d.source)
                anchors.right: inspPinBtn.left; anchors.rightMargin: 6
                pad: 7; label: WidgetConfig.pinOrbitEnabled(inspectorPanel.wid) ? "◎" : "○"
                active: WidgetConfig.pinOrbitEnabled(inspectorPanel.wid)
                onClicked: WidgetConfig.togglePinOrbit(inspectorPanel.wid)
            }
            OWButton {
                id: inspPinBtn
                anchors.right: inspCloseBtn.left; anchors.rightMargin: 6
                pad: 7; label: WidgetConfig.isPinLocked(inspectorPanel.wid) ? "❖" : (WidgetConfig.isPinned(inspectorPanel.wid) ? "◈" : "◇")
                active: WidgetConfig.isPinned(inspectorPanel.wid)
                onClicked: WidgetConfig.cyclePin(inspectorPanel.wid)
            }
            OWButton {
                id: inspCloseBtn
                anchors.right: parent.right; label: "✕"; pad: 7
                onClicked: { root.expandedId = ""; WidgetConfig.previewId = ""; }
            }
        }

        Row {
            id: inspTabs; x: 16; y: 56; spacing: 6
            OWButton { label: "ORBIT"; active: root.inspectorTab === "orbit"; onClicked: root.inspectorTab = "orbit" }
            OWButton { label: "CARD"; active: root.inspectorTab === "card"; onClicked: root.inspectorTab = "card" }
            OWButton {
                label: "OPTIONS" + (inspectorPanel.schema.length > 0 ? " (" + inspectorPanel.schema.length + ")" : "")
                active: root.inspectorTab === "options"
                onClicked: root.inspectorTab = "options"
            }
        }
        Rectangle { x: 16; y: 88; width: parent.width - 32; height: 1; color: root.cLine }

        Flickable {
            id: inspFlick
            x: 16; y: 96
            width: parent.width - 40
            height: parent.height - 96 - 48
            contentWidth: width
            contentHeight: inspCol.height + 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            OWWheel { scrollTarget: inspFlick }

            Column {
                id: inspCol
                width: inspFlick.width - 6
                spacing: 8

                // ---- SUB-TAB 1: ORBIT (grouped cards + per-option resets) ----
                Column {
                    visible: root.inspectorTab === "orbit"
                    width: parent.width; spacing: 8

                    InsetCard {
                        width: parent.width; heading: "PLACEMENT"

                        FieldHeader { label: "WIDGET TYPE"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "source"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "source") }
                        OWButton {
                            label: (inspectorPanel.d ? WidgetConfig.widgetName(inspectorPanel.d) : "") + "   ▾ change"
                            onClicked: root.startPick("swap", inspectorPanel.wid)
                        }

                        FieldHeader { label: "PLANET"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "host"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "host") }
                        OWDropdown {
                            width: parent.width
                            model: root.planetChoices
                            value: inspectorPanel.d ? inspectorPanel.d.host : ""
                            onSelected: (v) => { WidgetConfig.setField(inspectorPanel.wid, "host", v); root.lastHost = v; root.flyRequested(v); }
                        }

                        FieldHeader { label: "VISIBLE"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "show"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "show") }
                        Row {
                            spacing: 6
                            OWButton { label: "NEAR PLANET"; active: inspectorPanel.d !== null && inspectorPanel.d.show !== "always"; onClicked: WidgetConfig.setField(inspectorPanel.wid, "show", "focus") }
                            OWButton { label: "ALWAYS"; active: inspectorPanel.d !== null && inspectorPanel.d.show === "always"; onClicked: WidgetConfig.setField(inspectorPanel.wid, "show", "always") }
                        }
                    }

                    InsetCard {
                        width: parent.width; heading: "ORBIT & SCALE"

                        FieldHeader { label: "SIZE"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "size"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "size") }
                        OWSlider {
                            width: parent.width; from: 0.1; to: 5.0; step: 0.05
                            value: inspectorPanel.d ? inspectorPanel.d.size : 1
                            text: (inspectorPanel.d ? inspectorPanel.d.size : 1).toFixed(2) + "×"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "size", v)
                        }

                        FieldHeader { label: "SPEED (− = reverse, 0 = parked)"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "speed"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "speed") }
                        OWSlider {
                            width: parent.width; from: -2.0; to: 2.0; step: 0.01; bipolar: true
                            value: inspectorPanel.d ? inspectorPanel.d.orbit.speed : 0
                            text: inspectorPanel.d ? root.fmtSpeed(inspectorPanel.d.orbit.speed) : ""
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "speed", Math.abs(v) < 0.015 ? 0 : v)
                        }

                        FieldHeader { label: "DISTANCE"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "k"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "k") }
                        OWSlider {
                            width: parent.width; from: 0.5; to: 10.0; step: 0.05
                            value: inspectorPanel.d ? inspectorPanel.d.orbit.k : 2
                            text: (inspectorPanel.d ? inspectorPanel.d.orbit.k : 2).toFixed(2) + " radii"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "k", v)
                        }

                        OWToggleRow {
                            label: "Pause orbit on hover"
                            on: inspectorPanel.d !== null && inspectorPanel.d.holdOnHover !== false
                            modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "holdOnHover")
                            onToggled: (v) => WidgetConfig.setField(inspectorPanel.wid, "holdOnHover", v)
                            onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "holdOnHover")
                        }
                    }

                    InsetCard {
                        width: parent.width; heading: "AXIS"

                        FieldHeader { label: "TILT"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "tilt"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "tilt") }
                        OWSlider {
                            width: parent.width; from: -3.14; to: 3.14; step: 0.05; typedScale: 57.2958
                            value: inspectorPanel.d ? inspectorPanel.d.orbit.tilt : 0
                            text: Math.round((inspectorPanel.d ? inspectorPanel.d.orbit.tilt : 0) * 57.2958) + "°"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "tilt", v)
                        }

                        FieldHeader { label: "TURN"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "node"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "node") }
                        OWSlider {
                            width: parent.width; from: 0; to: 6.28; step: 0.05; typedScale: 57.2958
                            value: inspectorPanel.d ? (inspectorPanel.d.orbit.node || 0) : 0
                            text: Math.round((inspectorPanel.d ? (inspectorPanel.d.orbit.node || 0) : 0) * 57.2958) + "°"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "node", v)
                        }
                    }

                    InsetCard {
                        visible: inspectorPanel.keyAction !== ""
                        width: parent.width; heading: "SHORTCUT KEY"
                        Row {
                            spacing: 8
                            OWButton {
                                readonly property string curSeq: Keybinds.seq(inspectorPanel.keyAction)
                                label: root.capturing === inspectorPanel.keyAction ? "PRESS A KEY…" : (curSeq === "" ? "NONE" : Keybinds.pretty(curSeq))
                                dim: curSeq === "" && root.capturing !== inspectorPanel.keyAction
                                active: root.capturing === inspectorPanel.keyAction || Keybinds.isCustom(inspectorPanel.keyAction)
                                onClicked: { if (root.capturing === inspectorPanel.keyAction) { root.capturing = ""; root.keyMsg = ""; } else root.startCapture(inspectorPanel.keyAction); }
                            }
                            OWButton {
                                visible: Keybinds.seq(inspectorPanel.keyAction) !== "" && root.capturing !== inspectorPanel.keyAction
                                label: "NONE"; pad: 7
                                onClicked: { Keybinds.unbind(inspectorPanel.keyAction); root.keyMsg = ""; }
                            }
                            OWResetBtn {
                                anchors.verticalCenter: parent.verticalCenter
                                shown: Keybinds.isCustom(inspectorPanel.keyAction)
                                onClicked: WidgetConfig.resetKey(inspectorPanel.keyAction)
                            }
                        }
                    }
                }

                // ---- SUB-TAB 2: CARD APPEARANCE (grouped cards + per-option resets) ----
                Column {
                    visible: root.inspectorTab === "card"
                    width: parent.width; spacing: 8

                    InsetCard {
                        width: parent.width; heading: "SHAPE & TITLE"

                        FieldHeader { label: "OPACITY"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "opacity"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "opacity") }
                        OWSlider {
                            width: parent.width; from: 0.1; to: 1.0; step: 0.05
                            value: inspectorPanel.d ? inspectorPanel.d.opacity : 1.0
                            text: Math.round((inspectorPanel.d ? inspectorPanel.d.opacity : 1.0) * 100) + "%"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "opacity", v)
                        }

                        FieldHeader { label: "CORNER RADIUS (-1 = global)"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "cardRadius"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "cardRadius") }
                        OWSlider {
                            width: parent.width; from: -1; to: 24; step: 1
                            value: inspectorPanel.d ? inspectorPanel.d.cardRadius : -1
                            text: (inspectorPanel.d && inspectorPanel.d.cardRadius >= 0) ? Math.round(inspectorPanel.d.cardRadius) + " px" : "global"
                            onMoved: (v) => WidgetConfig.setField(inspectorPanel.wid, "cardRadius", Math.round(v))
                        }

                        OWToggleRow {
                            label: "Show corner brackets"
                            on: inspectorPanel.d !== null && inspectorPanel.d.showBrackets !== false
                            modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "showBrackets")
                            onToggled: (v) => WidgetConfig.setField(inspectorPanel.wid, "showBrackets", v)
                            onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "showBrackets")
                        }

                        FieldHeader { label: "CUSTOM TITLE"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "customTitle"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "customTitle") }
                        OWTextField {
                            width: parent.width; placeholder: "default"
                            value: inspectorPanel.d ? (inspectorPanel.d.customTitle || "") : ""
                            onEdited: (v) => WidgetConfig.setField(inspectorPanel.wid, "customTitle", v)
                        }
                    }

                    InsetCard {
                        width: parent.width; heading: "COLOURS"

                        FieldHeader { label: "BACKGROUND"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "cardBg"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "cardBg") }
                        OWColorPicker {
                            width: parent.width
                            value: inspectorPanel.d ? (inspectorPanel.d.cardBg || "") : ""
                            onEdited: (v) => WidgetConfig.setField(inspectorPanel.wid, "cardBg", v)
                        }

                        FieldHeader { label: "ACCENT / BRACKETS"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "cardAccent"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "cardAccent") }
                        OWColorPicker {
                            width: parent.width
                            value: inspectorPanel.d ? (inspectorPanel.d.cardAccent || "") : ""
                            onEdited: (v) => WidgetConfig.setField(inspectorPanel.wid, "cardAccent", v)
                        }

                        FieldHeader { label: "BORDER"; modified: WidgetConfig.fieldIsModified(inspectorPanel.wid, "cardBorder"); onResetClicked: WidgetConfig.resetField(inspectorPanel.wid, "cardBorder") }
                        OWColorPicker {
                            width: parent.width
                            value: inspectorPanel.d ? (inspectorPanel.d.cardBorder || "") : ""
                            onEdited: (v) => WidgetConfig.setField(inspectorPanel.wid, "cardBorder", v)
                        }
                    }
                }

                // ---- SUB-TAB 3: WIDGET-SPECIFIC OPTIONS ----
                Column {
                    visible: root.inspectorTab === "options"
                    width: parent.width; spacing: 8

                    Text {
                        visible: inspectorPanel.schema.length === 0
                        width: parent.width; wrapMode: Text.Wrap; topPadding: 12
                        text: "No extra widget options. Use ORBIT and CARD to customise placement and style."
                        color: root.cDim; font.family: root.mono; font.pixelSize: 11
                    }

                    InsetCard {
                        visible: inspectorPanel.schema.length > 0
                        width: parent.width; heading: "WIDGET SETTINGS"

                        Repeater {
                            model: root.inspectorTab === "options" ? inspectorPanel.schema : []
                            delegate: Column {
                                id: opt
                                required property var modelData
                                readonly property var s: modelData
                                readonly property var cur: (inspectorPanel.d && inspectorPanel.d.cfg && inspectorPanel.d.cfg[s.key] !== undefined) ? inspectorPanel.d.cfg[s.key] : s.default
                                readonly property string lbl: String(s.label || s.key)
                                readonly property bool mod: WidgetConfig.settingIsModified(inspectorPanel.wid, s.key)
                                width: parent.width; spacing: 4

                                FieldHeader {
                                    visible: opt.s.type !== "toggle"
                                    label: opt.lbl.toUpperCase(); modified: opt.mod
                                    onResetClicked: WidgetConfig.resetSetting(inspectorPanel.wid, opt.s.key)
                                }

                                Loader {
                                    width: opt.width
                                    sourceComponent: {
                                        switch (opt.s.type) {
                                        case "toggle": return optToggleComp;
                                        case "number": return optNumberComp;
                                        case "choice": return (!!opt.s.choices && opt.s.choices.length > 3) ? optDropdownComp : optChoiceFlowComp;
                                        case "color":  return optColorComp;
                                        case "font":   return optFontComp;
                                        case "file":   return optFileComp;
                                        default:       return optTextComp;
                                        }
                                    }
                                }

                                Component {
                                    id: optToggleComp
                                    OWToggleRow {
                                        width: opt.width
                                        label: opt.lbl; on: opt.cur === true; modified: opt.mod
                                        onToggled: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                        onResetClicked: WidgetConfig.resetSetting(inspectorPanel.wid, opt.s.key)
                                    }
                                }

                                Component {
                                    id: optNumberComp
                                    OWSlider {
                                        width: opt.width
                                        from: opt.s.min !== undefined ? opt.s.min : 0
                                        to: opt.s.max !== undefined ? opt.s.max : 100
                                        step: opt.s.step !== undefined ? opt.s.step : 1
                                        value: Number(opt.cur)
                                        text: String(Math.round(Number(opt.cur) * 1000) / 1000) + (opt.s.unit ? " " + opt.s.unit : "")
                                        onMoved: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }

                                Component {
                                    id: optChoiceFlowComp
                                    Flow {
                                        width: opt.width; spacing: 5
                                        Repeater {
                                            model: (!!opt.s.choices && opt.s.choices.length > 0) ? opt.s.choices : []
                                            delegate: OWButton {
                                                required property var modelData
                                                readonly property var val: (typeof modelData === "object") ? modelData.value : modelData
                                                label: String((typeof modelData === "object") ? (modelData.label !== undefined ? modelData.label : modelData.value) : modelData)
                                                pad: 7; active: opt.cur === val
                                                onClicked: WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, val)
                                            }
                                        }
                                    }
                                }

                                Component {
                                    id: optDropdownComp
                                    OWDropdown {
                                        width: opt.width
                                        model: !!opt.s.choices ? opt.s.choices : []
                                        value: opt.cur
                                        onSelected: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }

                                Component {
                                    id: optColorComp
                                    OWColorPicker {
                                        width: opt.width
                                        allowBlank: opt.s.default === ""
                                        defaultValue: String(opt.s.default !== undefined ? opt.s.default : "")
                                        value: String(opt.cur)
                                        onEdited: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }

                                Component {
                                    id: optFontComp
                                    OWFontPicker {
                                        width: opt.width
                                        allowBlank: opt.s.default === ""
                                        defaultValue: String(opt.s.default !== undefined ? opt.s.default : "")
                                        value: String(opt.cur)
                                        onEdited: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }

                                Component {
                                    id: optFileComp
                                    OWFileField {
                                        width: opt.width
                                        title: opt.lbl; value: String(opt.cur)
                                        onEdited: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }

                                Component {
                                    id: optTextComp
                                    OWTextField {
                                        width: opt.width
                                        value: String(opt.cur)
                                        onEdited: (v) => WidgetConfig.setSetting(inspectorPanel.wid, opt.s.key, v)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        OWScroll { target: inspFlick }

        Rectangle { x: 16; y: parent.height - 44; width: parent.width - 32; height: 1; color: root.cLine }
        Row {
            x: 16; y: parent.height - 36; spacing: 6
            OWButton { label: "SHOW PLANET"; onClicked: root.flyRequested(inspectorPanel.d ? inspectorPanel.d.host : "") }
            OWButton { label: "RESET"; dim: !inspectorPanel.modified; onClicked: WidgetConfig.resetWidget(inspectorPanel.wid) }
            OWButton { label: "REMOVE"; danger: true; onClicked: { WidgetConfig.removeWidget(inspectorPanel.wid); root.expandedId = ""; } }
        }
    }
}
