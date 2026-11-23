import QtQuick
import ".."

// CONTROL CENTRE (the slide-in panel on the right edge). Three tabs:
//   WIDGETS  every orbiting widget, grouped by planet. Search, collapse a planet, "+" on a planet adds a widget THERE,
//            x removes a widget from its planet (it stays in the catalog: "+ ADD" offers it again, removed defaults can be restored).
//   KEYS     every key in the shell. Click a key to rebind it; fixed keys are listed for reference.
//   OPTIONS  show / hide the bottom-right loop and speed panel, reset buttons.
// Everything goes through WidgetConfig (live preview in the scene, saved to widgets.json by WidgetConfigStore).
// Plain QtQuick only (no Quickshell import), so it also runs in `qml` on the Mint laptop.
Rectangle {
    id: root

    signal closeRequested()
    signal flyRequested(string planetId)

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
    property string pickMode: "add"       // "add" | "swap"
    property string pickTarget: ""        // widget id when swapping
    property string pickQuery: ""
    property bool confirmReset: false
    property bool confirmClean: false
    property bool confirmAll: false
    property string lastHost: "timber_hearth"
    property string capturing: ""         // action id whose key is being recorded
    property string capLone: ""           // a modifier pressed on its own so far ("Ctrl"...): becomes the key if released alone
    property string capHeld: ""           // modifiers held right now, for the banner
    onCapturingChanged: { WidgetConfig.capturingKeys = (capturing !== ""); capLone = ""; capHeld = ""; }
    property string keyMsg: ""

    color: "#F5070911"
    radius: 12
    clip: true
    border.color: "#66D4AF37"
    border.width: 1
    focus: true

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

    Keys.onPressed: (event) => {
        if (root.capturing !== "") {
            event.accepted = true;
            root.capHeld = root.modsText(event.modifiers);
            const lone = Keybinds.loneOf(event);
            if (lone !== "") { root.capLone = lone; return; }      // Ctrl / Shift / Alt / Super: wait; alone-and-released it becomes the key
            root.capLone = "";
            if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_Escape) { root.capturing = ""; root.keyMsg = ""; return; }
            if (event.modifiers === Qt.NoModifier && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {      // take the key off
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
            if (picking) picking = false; else root.closeRequested();
        }
    }

    Keys.onReleased: (event) => {
        if (root.capturing === "") return;
        event.accepted = true;
        root.capHeld = root.modsText(event.modifiers);
        const lone = Keybinds.loneOf(event);
        if (lone !== "" && lone === root.capLone) {          // pressed and released with nothing in between: the modifier itself
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
    // Rebuilt only when the SET of rows changes (added / removed / moved / searched / collapsed),
    // never while a slider is dragged, so the row under the mouse keeps existing.
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
        for (const h in byHost) if (hosts.indexOf(h) < 0) hosts.push(h);     // a host the panel does not know (typo in a def): still listed
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

    Connections {
        target: WidgetConfig
        function onRevisionChanged() { root.buildStructure(); root.buildPick(); }
        function onPanelOpenChanged() { if (!WidgetConfig.panelOpen) root.capturing = ""; }
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
        if (expandedId === id) { expandedId = ""; WidgetConfig.previewId = ""; }
        else { expandedId = id; WidgetConfig.previewId = id; const e = WidgetConfig.entry(id); if (e) lastHost = e.host; }
    }

    // ---------------- picker (add / change type) ----------------
    property var pickModel: []

    function buildPick() {
        const q = pickQuery.toLowerCase();
        const out = [];
        if (pickMode === "add") {
            const rem = WidgetConfig.removedEntries();
            const l = [];
            for (let i = 0; i < rem.length; i++) {
                const name = WidgetConfig.widgetName(rem[i]);
                if (q === "" || name.toLowerCase().indexOf(q) >= 0 || WidgetConfig.planetName(rem[i].baseHost).toLowerCase().indexOf(q) >= 0)
                    l.push({ kind: "restore", id: rem[i].id, name: name, planet: rem[i].baseHost });
            }
            if (l.length > 0) {
                out.push({ kind: "group", text: "REMOVED FROM A PLANET  ·  CLICK TO PUT BACK" });
                for (let i = 0; i < l.length; i++) out.push(l[i]);
            }
        }
        const cat = WidgetConfig.catalog;
        let lastGroup = "";
        for (let i = 0; i < cat.length; i++) {
            if (q !== "" && cat[i].name.toLowerCase().indexOf(q) < 0 && cat[i].group.toLowerCase().indexOf(q) < 0) continue;
            if (cat[i].group !== lastGroup) { out.push({ kind: "group", text: cat[i].group.toUpperCase() }); lastGroup = cat[i].group; }
            out.push({ kind: "item", source: cat[i].source, name: cat[i].name });
        }
        pickModel = out;
    }
    onPickQueryChanged: buildPick()
    onPickModeChanged: buildPick()

    // host: the planet a NEW widget goes to. "" = the planet you are focused on in the scene, else the last one used.
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
    // scrollbar for a Flickable that is a direct child of the same parent: click the track or drag the knob.
    // Place it right after the Flickable and leave 10 px free on the Flickable's right.
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

    component OWSlider: Item {
        id: s
        property real from: 0
        property real to: 1
        property real value: 0
        property real step: 0.01
        property string text: ""
        property bool bipolar: false
        property real typedScale: 1.0      // shown number = value * typedScale (degrees for tilt / turn)
        signal moved(real v)
        // the number at the right is a text box: type any value, nothing clamps it (only the drag is limited to from..to)
        function commitTyped(str) {
            const m = String(str).match(/-?\d+(?:\.\d+)?|-?\.\d+/);
            if (!m) return;
            const v = parseFloat(m[0]) / s.typedScale;
            if (isFinite(v)) s.moved(v);
        }
        readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
        implicitHeight: 26

        Rectangle {
            id: track
            x: 0
            width: s.width - 112
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: "#22D4AF37"
            Rectangle {          // fills from the left edge, or outward from the centre for a +/- slider
                x: s.bipolar ? parent.width * Math.min(s.frac, 0.5) : 0
                width: s.bipolar ? parent.width * Math.abs(s.frac - 0.5) : parent.width * s.frac
                height: parent.height
                radius: 2
                color: root.cGold
            }
            Rectangle {
                width: 11; height: 11; radius: 3; rotation: 45
                x: parent.width * s.frac - 5.5
                anchors.verticalCenter: parent.verticalCenter
                color: ma.pressed ? root.cCream : root.cGold
                scale: (ma.pressed || ma.containsMouse) ? 1.25 : 1.0
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
        TextInput {
            id: valBox
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            horizontalAlignment: TextInput.AlignRight
            text: s.text
            color: activeFocus ? root.cGold : root.cCream
            font.family: root.mono
            font.pixelSize: 11
            selectByMouse: true
            clip: true
            onAccepted: { s.commitTyped(text); focus = false; }
            onActiveFocusChanged: { if (activeFocus) selectAll(); else text = Qt.binding(() => s.text); }
        }
        MouseArea {
            id: ma
            x: -6; width: track.width + 12; height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function setFromX(mx) {
                const f = Math.max(0, Math.min(1, (mx - 6) / track.width));
                let v = s.from + f * (s.to - s.from);
                v = Math.round(v / s.step) * s.step;
                v = Math.max(s.from, Math.min(s.to, v));
                if (Math.abs(v - s.value) > 1e-9) s.moved(v);
            }
            onPressed: (m) => setFromX(m.x)
            onPositionChanged: (m) => { if (pressed) setFromX(m.x); }
        }
    }

    component OWTextField: Rectangle {
        id: tf
        property string value: ""
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
            onAccepted: { tf.edited(text); focus = false; }
            onActiveFocusChanged: { if (!activeFocus) { if (text !== tf.value) tf.edited(text); text = Qt.binding(() => tf.value); } }
        }
    }

    component FieldLabel: Text {
        color: root.cDim
        font.family: root.mono
        font.pixelSize: 10
        font.letterSpacing: 2
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
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: ti.text === "" && !ti.activeFocus
            text: "⌕  " + sb.placeholder
            color: root.cOff
            font.family: root.mono
            font.pixelSize: 11
        }
        TextInput {
            id: ti
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 26
            verticalAlignment: TextInput.AlignVCenter
            color: root.cCream
            selectionColor: root.cGold
            font.family: root.mono
            font.pixelSize: 12
            clip: true
            Keys.onEscapePressed: (event) => { if (ti.text !== "") { ti.text = ""; event.accepted = true; } else event.accepted = false; }
        }
        Text {
            visible: ti.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            color: root.cDim
            font.pixelSize: 11
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
            anchors.fill: parent
            anchors.margins: 2
            radius: 7
            color: tb.on ? "#24D4AF37" : (tma.containsMouse ? "#15D4AF37" : "transparent")
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
        Text {
            id: tl
            anchors.centerIn: parent
            text: tb.label
            color: tb.on ? root.cGold : (tma.containsMouse ? root.cCream : root.cDim)
            font.family: root.mono
            font.pixelSize: 11
            font.bold: tb.on
            font.letterSpacing: 2
            Behavior on color { ColorAnimation { duration: 140 } }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: tb.on ? parent.width - 14 : 0
            height: 2
            radius: 1
            color: root.cGold
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTab(tb.key) }
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
            font.family: root.mono
            font.bold: true
            font.pixelSize: 16
            font.letterSpacing: 3
        }
        Text {
            y: 24
            text: root.tab === "widgets" ? (root.widgetCount + " ON PLANETS" + (root.offCount > 0 ? "  ·  " + root.offCount + " SWITCHED OFF" : ""))
                : (root.tab === "keys" ? "CLICK A KEY TO CHANGE IT" : "SHOW / HIDE AND RESETS")
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 10
            font.letterSpacing: 2
        }
        OWButton {
            anchors.right: parent.right
            label: "✕"
            pad: 8
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
        visible: root.tab === "widgets"
        x: 0; y: 96
        width: parent.width
        height: parent.height - 96

        Item {
            id: toolbar
            x: 18
            width: parent.width - 36
            height: 82

            SearchBox {
                width: parent.width - 190
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
            OWButton {                      // two clicks: the first arms it for 3 s
                anchors.right: parent.right
                anchors.rightMargin: 66
                label: root.confirmAll ? "SURE?" : "REMOVE ALL"
                danger: root.confirmAll
                onClicked: {
                    if (root.confirmAll) { WidgetConfig.removeAll(); root.expandedId = ""; root.confirmAll = false; }
                    else root.confirmAll = true;
                }
            }
            Timer { interval: 3000; running: root.confirmAll; onTriggered: root.confirmAll = false }
            FieldLabel { y: 38; text: "ALL ORBITS" }
            OWSlider {
                y: 50
                width: parent.width
                from: 0; to: 10; step: 0.05
                value: WidgetConfig.globalSpeed
                text: WidgetConfig.globalSpeed.toFixed(2) + "×"
                onMoved: (v) => WidgetConfig.setGlobalSpeed(v)
            }
        }

        // switched-off widgets still occupy their planet: one click clears them (they stay in the + ADD list)
        Rectangle {
            id: cleanBar
            visible: root.offCount > 0
            x: 18; y: toolbar.height + 2
            width: parent.width - 36
            height: visible ? 30 : 0
            radius: 3
            color: "#14D4AF37"
            border.width: 1
            border.color: root.cLine
            Text {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: root.offCount + " switched off, still on their planets"
                color: root.cDim
                font.family: root.mono
                font.pixelSize: 10
            }
            OWButton {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 22
                label: root.confirmClean ? "SURE? CLICK AGAIN" : "REMOVE THEM"
                danger: root.confirmClean
                onClicked: {
                    if (root.confirmClean) { WidgetConfig.removeDisabled(); root.expandedId = ""; root.confirmClean = false; }
                    else root.confirmClean = true;
                }
            }
            Timer { interval: 3000; running: root.confirmClean; onTriggered: root.confirmClean = false }
        }

        Flickable {
            id: flick
            x: 18
            y: toolbar.height + (cleanBar.visible ? 38 : 8)
            width: parent.width - 46            // 10 px free on the right for the scrollbar
            height: parent.height - y - 10
            contentWidth: width
            contentHeight: listCol.height + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y;
                    const f = flick;
                    f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY - dy));
                }
            }

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
                                Text {
                                    x: 4
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 8
                                    text: (del.modelData.collapsed ? "▸  " : "▾  ") + WidgetConfig.planetName(del.modelData.planet).toUpperCase()
                                          + "  (" + del.modelData.count + ")"
                                    color: hdr.empty ? root.cOff : root.cGold
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.bold: true
                                    font.letterSpacing: 2
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.rightMargin: 40
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleCollapse(del.modelData.planet)
                                }
                                Text {            // "+" = add a widget ON this planet
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 6
                                    text: "+"
                                    color: plusMa.containsMouse ? root.cCream : root.cGold
                                    font.family: root.mono
                                    font.pixelSize: 16
                                    font.bold: true
                                    MouseArea {
                                        id: plusMa
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
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
                                readonly property bool modified: d !== null && (WidgetConfig.overrides[wid] !== undefined || d._extra)
                                readonly property string keyAction: d ? Keybinds.forWidget(d.source) : ""
                                width: del.width
                                height: rowHead.height + (open ? editor.height + 8 : 0)

                                // ---- row head ----
                                Rectangle {
                                    id: rowHead
                                    width: parent.width
                                    height: 36
                                    radius: 8
                                    color: row.open ? "#24D4AF37" : (rowHover.hovered ? "#18D4AF37" : "transparent")
                                    border.width: row.open ? 1 : 0
                                    border.color: "#44D4AF37"
                                    Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    HoverHandler { id: rowHover }
                                    Rectangle {
                                        x: 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 3
                                        height: row.open ? 20 : (rowHover.hovered ? 14 : 0)
                                        radius: 2
                                        color: root.cGold
                                        opacity: (row.open || rowHover.hovered) ? 1.0 : 0.0
                                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { NumberAnimation { duration: 140 } }
                                    }

                                    OWSwitch {
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        on: row.d !== null && row.d.enabled
                                        onToggled: (v) => WidgetConfig.setField(row.wid, "enabled", v)
                                    }
                                    Text {
                                        x: 46
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 46 - 76
                                        text: row.d ? WidgetConfig.widgetName(row.d) : ""
                                        elide: Text.ElideRight
                                        color: row.d && row.d.enabled ? root.cCream : root.cOff
                                        font.family: root.mono
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: headMa
                                        anchors.fill: parent
                                        anchors.leftMargin: 40
                                        anchors.rightMargin: 62
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleExpand(row.wid)
                                    }
                                    Text {                         // remove from this planet (shown on hover / while open)
                                        visible: rowHover.hovered || row.open
                                        anchors.right: parent.right
                                        anchors.rightMargin: 34
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "✕"
                                        color: rmMa.containsMouse ? root.cDanger : root.cDim
                                        font.pixelSize: 12
                                        MouseArea {
                                            id: rmMa
                                            anchors.fill: parent
                                            anchors.margins: -7
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { WidgetConfig.removeWidget(row.wid); if (root.expandedId === row.wid) root.expandedId = ""; }
                                        }
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (row.modified ? "● " : "") + (row.open ? "▾" : "▸")
                                        color: row.modified ? root.cGold : root.cDim
                                        font.family: root.mono
                                        font.pixelSize: 11
                                    }
                                }

                                // ---- editor (created only while the row is open) ----
                                Loader {
                                    id: editor
                                    active: row.open && row.d !== null
                                    y: rowHead.height + 6
                                    x: 8
                                    width: parent.width - 16
                                    sourceComponent: editorComp
                                }

                                Component {
                                    id: editorComp
                                    Item {
                                        id: editorItem
                                        width: editor.width
                                        height: edCol.height

                                        Column {
                                            id: edCol
                                            width: parent.width
                                            spacing: 6

                                            FieldLabel { text: "WIDGET" }
                                            OWButton {
                                                label: (row.d ? WidgetConfig.widgetName(row.d) : "") + "   ▾ change"
                                                onClicked: root.startPick("swap", row.wid)
                                            }

                                            FieldLabel { text: "PLANET"; topPadding: 4 }
                                            Flow {
                                                width: parent.width
                                                spacing: 5
                                                Repeater {
                                                    model: WidgetConfig.planets
                                                    delegate: OWButton {
                                                        required property var modelData
                                                        label: modelData.name
                                                        pad: 7
                                                        active: row.d !== null && row.d.host === modelData.id
                                                        onClicked: { WidgetConfig.setField(row.wid, "host", modelData.id); root.lastHost = modelData.id; root.flyRequested(modelData.id); }
                                                    }
                                                }
                                            }

                                            FieldLabel { text: "SIZE"; topPadding: 4 }
                                            OWSlider {
                                                width: parent.width
                                                from: 0.1; to: 5.0; step: 0.05
                                                value: row.d ? row.d.size : 1
                                                text: (row.d ? row.d.size : 1).toFixed(2) + "×"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "size", v)
                                            }

                                            FieldLabel { text: "ORBIT SPEED  (− = other way, 0 = parked)" }
                                            OWSlider {
                                                width: parent.width
                                                from: -2.0; to: 2.0; step: 0.01
                                                bipolar: true
                                                value: row.d ? row.d.orbit.speed : 0
                                                text: row.d ? root.fmtSpeed(row.d.orbit.speed) : ""
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "speed", Math.abs(v) < 0.015 ? 0 : v)
                                            }

                                            FieldLabel { text: "ORBIT DISTANCE" }
                                            OWSlider {
                                                width: parent.width
                                                from: 0.5; to: 10.0; step: 0.05
                                                value: row.d ? row.d.orbit.k : 2
                                                text: (row.d ? row.d.orbit.k : 2).toFixed(2) + " radii"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "k", v)
                                            }

                                            FieldLabel { text: "VISIBLE" }
                                            Row {
                                                spacing: 6
                                                OWButton { label: "NEAR PLANET"; active: row.d !== null && row.d.show !== "always"; onClicked: WidgetConfig.setField(row.wid, "show", "focus") }
                                                OWButton { label: "ALWAYS"; active: row.d !== null && row.d.show === "always"; onClicked: WidgetConfig.setField(row.wid, "show", "always") }
                                            }

                                            FieldLabel { text: "ORBIT AXIS"; topPadding: 4 }
                                            OWSlider {
                                                width: parent.width
                                                from: -3.14; to: 3.14; step: 0.05
                                                typedScale: 57.2958
                                                value: row.d ? row.d.orbit.tilt : 0
                                                text: "tilt " + Math.round((row.d ? row.d.orbit.tilt : 0) * 57.2958) + "°"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "tilt", v)
                                            }
                                            OWSlider {
                                                width: parent.width
                                                from: 0; to: 6.28; step: 0.05
                                                typedScale: 57.2958
                                                value: row.d ? (row.d.orbit.node || 0) : 0
                                                text: "turn " + Math.round((row.d ? (row.d.orbit.node || 0) : 0) * 57.2958) + "°"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "node", v)
                                            }

                                            FieldLabel { visible: row.keyAction !== ""; text: "KEY"; topPadding: 4 }
                                            Row {
                                                visible: row.keyAction !== ""
                                                spacing: 10
                                                OWButton {
                                                    readonly property string curSeq: Keybinds.seq(row.keyAction)
                                                    label: root.capturing === row.keyAction ? "PRESS A KEY…" : (curSeq === "" ? "NONE" : Keybinds.pretty(curSeq))
                                                    dim: curSeq === "" && root.capturing !== row.keyAction
                                                    active: root.capturing === row.keyAction || Keybinds.isCustom(row.keyAction)
                                                    onClicked: { if (root.capturing === row.keyAction) { root.capturing = ""; root.keyMsg = ""; } else root.startCapture(row.keyAction); }
                                                }
                                                OWButton {
                                                    visible: Keybinds.seq(row.keyAction) !== "" && root.capturing !== row.keyAction
                                                    label: "NONE"
                                                    pad: 7
                                                    onClicked: { Keybinds.unbind(row.keyAction); root.keyMsg = ""; }
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.keyMsg !== "" ? root.keyMsg : (root.capturing === row.keyAction ? "Esc cancels  ·  Del unbinds" : Keybinds.labelOf(row.keyAction))
                                                    color: root.keyMsg !== "" ? root.cDanger : root.cDim
                                                    font.family: root.mono
                                                    font.pixelSize: 10
                                                }
                                            }

                                            Column {
                                                id: cfgCol
                                                width: parent.width
                                                spacing: 6
                                                readonly property var schema: {
                                                    const c = row.d ? WidgetConfig.catalogEntry(row.d.source) : null;
                                                    return c && Array.isArray(c.settings) ? c.settings : [];
                                                }
                                                visible: schema.length > 0

                                                FieldLabel { text: "WIDGET OPTIONS"; topPadding: 4 }

                                                Repeater {
                                                    model: cfgCol.schema
                                                    delegate: Column {
                                                        id: opt
                                                        required property var modelData
                                                        readonly property var s: modelData
                                                        readonly property var cur: (row.d && row.d.cfg && row.d.cfg[s.key] !== undefined) ? row.d.cfg[s.key] : s.default
                                                        readonly property string lbl: String(s.label || s.key)
                                                        width: cfgCol.width
                                                        spacing: 4

                                                        // toggle: switch + label on one line; every other type: label, then the control
                                                        Row {
                                                            visible: opt.s.type === "toggle"
                                                            spacing: 8
                                                            height: 18
                                                            OWSwitch { on: opt.cur === true; onToggled: (v) => WidgetConfig.setSetting(row.wid, opt.s.key, v) }
                                                            FieldLabel { anchors.verticalCenter: parent.verticalCenter; text: opt.lbl.toUpperCase() }
                                                        }
                                                        FieldLabel { visible: opt.s.type !== "toggle"; text: opt.lbl.toUpperCase() }

                                                        OWSlider {
                                                            visible: opt.s.type === "number"
                                                            width: opt.width
                                                            from: opt.s.min !== undefined ? opt.s.min : 0
                                                            to: opt.s.max !== undefined ? opt.s.max : 100
                                                            step: opt.s.step !== undefined ? opt.s.step : 1
                                                            value: Number(opt.cur)
                                                            text: String(Math.round(Number(opt.cur) * 1000) / 1000) + (opt.s.unit ? " " + opt.s.unit : "")
                                                            onMoved: (v) => WidgetConfig.setSetting(row.wid, opt.s.key, v)
                                                        }

                                                        Flow {
                                                            visible: opt.s.type === "choice"
                                                            width: opt.width
                                                            spacing: 5
                                                            Repeater {
                                                                model: opt.s.type === "choice" && Array.isArray(opt.s.choices) ? opt.s.choices : []
                                                                delegate: OWButton {
                                                                    required property var modelData
                                                                    readonly property var val: (typeof modelData === "object") ? modelData.value : modelData
                                                                    label: String((typeof modelData === "object") ? (modelData.label !== undefined ? modelData.label : modelData.value) : modelData)
                                                                    pad: 7
                                                                    active: opt.cur === val
                                                                    onClicked: WidgetConfig.setSetting(row.wid, opt.s.key, val)
                                                                }
                                                            }
                                                        }

                                                        OWTextField {
                                                            visible: opt.s.type === "text" || opt.s.type === "font" || opt.s.type === "file" || opt.s.type === "color"
                                                            width: opt.width
                                                            showSwatch: opt.s.type === "color"
                                                            value: String(opt.cur)
                                                            onEdited: (v) => WidgetConfig.setSetting(row.wid, opt.s.key, v)
                                                        }
                                                    }
                                                }
                                            }

                                            Row {
                                                spacing: 6
                                                topPadding: 6
                                                OWButton { label: "SHOW PLANET"; onClicked: root.flyRequested(row.d ? row.d.host : "") }
                                                OWButton { label: "RESET"; dim: !row.modified; onClicked: WidgetConfig.resetWidget(row.wid) }
                                                OWButton { label: "REMOVE"; danger: true; onClicked: { WidgetConfig.removeWidget(row.wid); root.expandedId = ""; } }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.structure.length === 0
                    width: listCol.width
                    topPadding: 24
                    horizontalAlignment: Text.AlignHCenter
                    text: root.query !== "" ? "Nothing matches \"" + root.query + "\"." : "No widgets on any planet. Use + ADD."
                    color: root.cDim
                    font.family: root.mono
                    font.pixelSize: 11
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
        visible: root.tab === "keys"
        x: 0; y: 96
        width: parent.width
        height: parent.height - 96

        Rectangle {
            id: keyBanner
            x: 18; y: 6
            width: parent.width - 36
            height: 30
            radius: 3
            color: root.keyMsg !== "" ? "#22D9694A" : (root.capturing !== "" ? "#22D4AF37" : "transparent")
            border.width: (root.keyMsg !== "" || root.capturing !== "") ? 1 : 0
            border.color: root.keyMsg !== "" ? root.cDanger : root.cGold
            Text {
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.keyMsg !== "" ? root.keyMsg
                    : (root.capturing !== "" ? "Press the key for “" + Keybinds.labelOf(root.capturing) + "”" + (root.capHeld !== "" ? "   " + root.capHeld + " + …" : "")
                                              + "   ·   Esc cancels   ·   Del unbinds" : "")
                color: root.keyMsg !== "" ? root.cDanger : root.cGold
                font.family: root.mono
                font.pixelSize: 11
            }
        }

        Flickable {
            id: keyFlick
            x: 18
            y: 44
            width: parent.width - 46
            height: parent.height - y - 52
            contentWidth: width
            contentHeight: keyCol.height + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y;
                    const f = keyFlick;
                    f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY - dy));
                }
            }

            Column {
                id: keyCol
                width: keyFlick.width - 10

                // ---- rebindable ----
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
                            visible: kr.newGroup
                            width: parent.width; height: 34
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: kr.modelData.group.toUpperCase()
                                color: root.cGold
                                font.family: root.mono
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 2
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cLine }
                        }
                        Rectangle {
                            y: kr.newGroup ? 34 : 0
                            width: parent.width; height: 38
                            radius: 8
                            color: kr.capt ? "#24D4AF37" : (krHover.hovered ? "#15D4AF37" : "transparent")
                            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            HoverHandler { id: krHover }
                            Rectangle {
                                x: 2; anchors.verticalCenter: parent.verticalCenter
                                width: 3; radius: 2; color: root.cGold
                                height: kr.capt ? 20 : (krHover.hovered ? 14 : 0)
                                opacity: (kr.capt || krHover.hovered) ? 1.0 : 0.0
                                Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                            Column {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text { text: kr.modelData.label; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                                Text { visible: kr.modelData.hint !== ""; text: kr.modelData.hint; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Text {
                                    visible: kr.custom && !kr.capt
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "↺"
                                    color: undoMa.containsMouse ? root.cCream : root.cDim
                                    font.pixelSize: 14
                                    MouseArea {
                                        id: undoMa
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { WidgetConfig.resetKey(kr.modelData.id); root.keyMsg = ""; }
                                    }
                                }
                                OWButton {
                                    visible: Keybinds.seq(kr.modelData.id) !== "" && !kr.capt
                                    pad: 7
                                    implicitHeight: 26
                                    label: "✕"
                                    onClicked: { Keybinds.unbind(kr.modelData.id); root.keyMsg = ""; }
                                }
                                OWButton {
                                    readonly property string curSeq: Keybinds.seq(kr.modelData.id)
                                    pad: 12
                                    implicitHeight: 26
                                    label: kr.capt ? "PRESS A KEY…" : (curSeq === "" ? "NONE" : Keybinds.pretty(curSeq))
                                    dim: curSeq === "" && !kr.capt
                                    active: kr.capt || kr.custom
                                    onClicked: { if (kr.capt) { root.capturing = ""; root.keyMsg = ""; } else root.startCapture(kr.modelData.id); }
                                }
                            }
                        }
                    }
                }

                // ---- fixed keys (reference) ----
                Repeater {
                    model: Keybinds.reference
                    delegate: Column {
                        id: refGroup
                        required property var modelData
                        width: keyCol.width
                        Item {
                            width: parent.width; height: 40
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: refGroup.modelData.group.toUpperCase()
                                color: root.cDim
                                font.family: root.mono
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 2
                            }
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.cLine }
                        }
                        Repeater {
                            model: refGroup.modelData.rows
                            delegate: Item {
                                required property var modelData
                                width: keyCol.width; height: 26
                                Text {
                                    width: 118
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[0]
                                    color: root.cCream
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                Text {
                                    x: 126
                                    width: parent.width - 126
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData[1]
                                    color: root.cDim
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Text {
                    width: keyCol.width
                    topPadding: 18
                    wrapMode: Text.Wrap
                    text: "These are the shell's own keys; they work while the scene has keyboard focus. Hyprland-level binds "
                        + "(outerwilds.lua) are separate: from there use  qs -c outerwilds ipc call  map | rumor | hud | keys | settings | launcher  toggle."
                    color: root.cOff
                    font.family: root.mono
                    font.pixelSize: 10
                }
            }
        }
        OWScroll { target: keyFlick }

        Item {
            x: 18
            y: parent.height - 40
            width: parent.width - 36
            height: 28
            OWButton { label: "RESET ALL KEYS"; onClicked: { WidgetConfig.resetKeys(); root.keyMsg = ""; root.capturing = ""; } }
        }
    }

    // =====================================================================
    //  OPTIONS TAB (collapsible dropdown sections)
    // =====================================================================
    Item {
        id: optionsTab
        visible: root.tab === "options"
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

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y;
                    const f = optFlick;
                    f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY - dy));
                }
            }

            Column {
                id: optCol
                width: optFlick.width - 10
                spacing: 6

                // ---- 1. SATELLITE HUD ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["hud"] === true
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hHud.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hHud }
                        MouseArea { anchors.fill: parent; anchors.rightMargin: 46; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("hud") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Satellite HUD"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Gauges, audio globe & thrust indicator"; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                        OWSwitch { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.showHud; onToggled: (v) => WidgetConfig.setShowHud(v) }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: hudBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: hudBody; x: 12; y: 10; width: parent.width - 24; spacing: 6
                            FieldLabel { text: "OPACITY" }
                            OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.hudOpacity; text: Math.round(WidgetConfig.hudOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setHudOpacity(v) }
                            FieldLabel { text: "SCALE" }
                            OWSlider { width: parent.width; from: 0.5; to: 1.5; step: 0.05; value: WidgetConfig.hudScale; text: WidgetConfig.hudScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setHudScale(v) }
                        }
                    }
                }

                // ---- 2. LOOP / SPEED PANEL ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["loop"] === true
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hLoop.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hLoop }
                        MouseArea { anchors.fill: parent; anchors.rightMargin: 46; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("loop") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Loop / speed panel"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Bottom-right box  ·  Key: " + (Keybinds.pretty(Keybinds.seq("hud")) || "NONE"); color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                        OWSwitch { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.showLoopPanel; onToggled: (v) => WidgetConfig.setShowLoopPanel(v) }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: loopBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: loopBody; x: 12; y: 10; width: parent.width - 24; spacing: 6
                            FieldLabel { text: "OPACITY" }
                            OWSlider { width: parent.width; from: 0.2; to: 1.0; step: 0.05; value: WidgetConfig.loopPanelOpacity; text: Math.round(WidgetConfig.loopPanelOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setLoopPanelOpacity(v) }
                            FieldLabel { text: "SCALE" }
                            OWSlider { width: parent.width; from: 0.6; to: 1.5; step: 0.05; value: WidgetConfig.loopPanelScale; text: WidgetConfig.loopPanelScale.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setLoopPanelScale(v) }
                        }
                    }
                }

                // ---- 3. ORBIT LINES ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["orbits"] === true
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hOrb.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hOrb }
                        MouseArea { anchors.fill: parent; anchors.rightMargin: 46; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("orbits") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Orbit lines"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Elliptical planet paths in the background"; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                        OWSwitch { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.showOrbits; onToggled: (v) => WidgetConfig.setShowOrbits(v) }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: orbBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: orbBody; x: 12; y: 10; width: parent.width - 24; spacing: 6
                            FieldLabel { text: "OPACITY" }
                            OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.orbitOpacity; text: Math.round(WidgetConfig.orbitOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setOrbitOpacity(v) }
                            FieldLabel { text: "LINE WIDTH" }
                            OWSlider { width: parent.width; from: 0.5; to: 4.0; step: 0.1; value: WidgetConfig.orbitWidth; text: WidgetConfig.orbitWidth.toFixed(1) + " px"; onMoved: (v) => WidgetConfig.setOrbitWidth(v) }
                        }
                    }
                }

                // ---- 4. PLANET LABELS ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["labels"] === true
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hLbl.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hLbl }
                        MouseArea { anchors.fill: parent; anchors.rightMargin: 46; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("labels") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Planet labels"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Planet names and lock-on distances"; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                        OWSwitch { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.showLabels; onToggled: (v) => WidgetConfig.setShowLabels(v) }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: lblBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: lblBody; x: 12; y: 10; width: parent.width - 24; spacing: 6
                            FieldLabel { text: "TEXT SIZE" }
                            OWSlider { width: parent.width; from: 0.6; to: 2.0; step: 0.05; value: WidgetConfig.labelSize; text: WidgetConfig.labelSize.toFixed(2) + "×"; onMoved: (v) => WidgetConfig.setLabelSize(v) }
                            FieldLabel { text: "MAX DISTANCE" }
                            OWSlider { width: parent.width; from: 500; to: 6000; step: 100; value: WidgetConfig.labelDist; text: Math.round(WidgetConfig.labelDist) + " m"; onMoved: (v) => WidgetConfig.setLabelDist(v) }
                        }
                    }
                }

                // ---- 5. TARGET / LOCK RETICLES ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["reticles"] === true
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hRet.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hRet }
                        MouseArea { anchors.fill: parent; anchors.rightMargin: 46; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("reticles") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Target / lock reticles"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Hover and lock-on brackets around planets"; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                        OWSwitch { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.showReticles; onToggled: (v) => WidgetConfig.setShowReticles(v) }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: retBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: retBody; x: 12; y: 10; width: parent.width - 24; spacing: 6
                            FieldLabel { text: "OPACITY" }
                            OWSlider { width: parent.width; from: 0.1; to: 1.0; step: 0.05; value: WidgetConfig.reticleOpacity; text: Math.round(WidgetConfig.reticleOpacity * 100) + "%"; onMoved: (v) => WidgetConfig.setReticleOpacity(v) }
                            FieldLabel { text: "STROKE WIDTH" }
                            OWSlider { width: parent.width; from: 0.5; to: 3.0; step: 0.1; value: WidgetConfig.reticleWidth; text: WidgetConfig.reticleWidth.toFixed(1) + "×"; onMoved: (v) => WidgetConfig.setReticleWidth(v) }
                        }
                    }
                }

                // ---- 6. RENDERING & WIDGETS ----
                Column {
                    width: parent.width; spacing: 4
                    readonly property bool open: root.optOpen["render"] !== false
                    Rectangle {
                        width: parent.width; height: 48; radius: 8
                        color: parent.open ? "#20D4AF37" : (hRen.hovered ? "#15D4AF37" : "#0D1322")
                        border.width: 1; border.color: parent.open ? "#55D4AF37" : root.cLine
                        Behavior on color { ColorAnimation { duration: 140 } }
                        HoverHandler { id: hRen }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleOpt("render") }
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; spacing: 2
                            Text { text: (parent.parent.parent.open ? "▾  " : "▸  ") + "Rendering & performance"; color: root.cCream; font.family: root.mono; font.pixelSize: 12; font.bold: parent.parent.parent.open }
                            Text { text: "Bake resolution, idle FPS cap & widget scaling"; color: root.cDim; font.family: root.mono; font.pixelSize: 10 }
                        }
                    }
                    Rectangle {
                        visible: parent.open; width: parent.width; height: renBody.height + 20; radius: 8; color: "#0B101D"; border.width: 1; border.color: "#2AD4AF37"
                        Column {
                            id: renBody; x: 12; y: 10; width: parent.width - 24; spacing: 10
                            Row {
                                width: parent.width
                                Text { width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; text: "Shrink widgets when far away"; color: root.cCream; font.family: root.mono; font.pixelSize: 11 }
                                OWSwitch { anchors.verticalCenter: parent.verticalCenter; on: WidgetConfig.shrinkFar; onToggled: (v) => WidgetConfig.setShrinkFar(v) }
                            }
                            Column {
                                width: parent.width; spacing: 5
                                FieldLabel { text: "PLANET TEXTURE RESOLUTION" }
                                Row {
                                    spacing: 6
                                    Repeater {
                                        model: [512, 1024, 2048]
                                        delegate: OWButton {
                                            required property int modelData
                                            label: modelData + " px"
                                            pad: 10
                                            active: WidgetConfig.bakeW === modelData
                                            onClicked: WidgetConfig.setBakeW(modelData)
                                        }
                                    }
                                }
                            }
                            Column {
                                width: parent.width; spacing: 5
                                FieldLabel { text: "IDLE FPS CAP" }
                                Row {
                                    spacing: 6
                                    Repeater {
                                        model: [15, 30, 60, 0]
                                        delegate: OWButton {
                                            required property int modelData
                                            label: modelData === 0 ? "OFF" : (modelData + " fps")
                                            pad: 10
                                            active: WidgetConfig.fpsIdle === modelData
                                            onClicked: WidgetConfig.setFpsIdle(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- 7. RESET ----
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

    // ---------------- widget picker (add / change type / restore) ----------------
    Rectangle {
        id: picker
        visible: root.picking
        anchors.fill: parent
        radius: root.radius
        color: "#070911"
        z: 10

        MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: (w) => { w.accepted = true; } }   // eat clicks / wheel behind it

        Text {
            x: 18; y: 18
            text: root.pickMode === "add" ? "ADD A WIDGET" : "CHANGE WIDGET TYPE"
            color: root.cCream
            font.family: root.mono
            font.bold: true
            font.pixelSize: 14
            font.letterSpacing: 3
        }
        OWButton { x: parent.width - width - 18; y: 14; label: "CANCEL"; onClicked: root.picking = false }
        Text {
            x: 18; y: 44
            width: parent.width - 36
            wrapMode: Text.Wrap
            text: root.pickMode === "add"
                  ? "It goes on " + WidgetConfig.planetName(root.lastHost) + (root.pickFromFocus ? " (the planet you are focused on)" : "") + "; move it afterwards. Every widget stays in this list, even after you remove it."
                  : "Keeps this widget's planet, orbit and size."
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 10
        }
        SearchBox {
            id: pickSearch
            x: 18; y: 82
            width: parent.width - 36
            placeholder: "search"
            text: root.pickQuery
            onTextChanged: root.pickQuery = text
        }

        Flickable {
            id: pickFlick
            x: 18; y: 120
            width: parent.width - 46
            height: parent.height - 120 - 12
            contentHeight: pickCol.height + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    const dy = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y;
                    const f = pickFlick;
                    f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY - dy));
                }
            }

            Column {
                id: pickCol
                width: parent.width - 8
                Repeater {
                    model: root.pickModel
                    delegate: Item {
                        id: pe
                        required property var modelData
                        width: pickCol.width
                        height: modelData.kind === "group" ? 30 : 28

                        Text {
                            visible: pe.modelData.kind === "group"
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            text: pe.modelData.text || ""
                            color: root.cGold
                            font.family: root.mono
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Rectangle {
                            visible: pe.modelData.kind !== "group"
                            width: parent.width
                            height: 30
                            radius: 7
                            color: pma.containsMouse ? "#1CD4AF37" : "transparent"
                            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 16
                                elide: Text.ElideRight
                                text: pe.modelData.kind === "restore"
                                      ? pe.modelData.name + "   ·   " + WidgetConfig.planetName(pe.modelData.planet)
                                      : (pe.modelData.name || "")
                                color: pe.modelData.kind === "restore" ? root.cGold : root.cCream
                                font.family: root.mono
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: pma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
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
}
