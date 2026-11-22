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
    property bool picking: false
    property string pickMode: "add"       // "add" | "swap"
    property string pickTarget: ""        // widget id when swapping
    property string pickQuery: ""
    property bool confirmReset: false
    property bool confirmClean: false
    property string lastHost: "timber_hearth"
    property string capturing: ""         // action id whose key is being recorded
    property string capLone: ""           // a modifier pressed on its own so far ("Ctrl"...): becomes the key if released alone
    property string capHeld: ""           // modifiers held right now, for the banner
    onCapturingChanged: { WidgetConfig.capturingKeys = (capturing !== ""); capLone = ""; capHeld = ""; }
    property string keyMsg: ""

    color: "#F207080C"
    border.color: "#55D4AF37"
    border.width: 1
    focus: true

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
    component OWButton: Rectangle {
        id: b
        property string label: ""
        property bool active: false
        property bool danger: false
        property bool dim: false
        property int pad: 10
        signal clicked()
        implicitWidth: t.implicitWidth + pad * 2
        implicitHeight: 24
        radius: 3
        color: b.active ? "#33D4AF37" : (ma.containsMouse ? root.cHover : "transparent")
        border.width: 1
        border.color: b.danger ? root.cDanger : (b.active ? root.cGold : root.cLine)
        opacity: b.dim ? 0.5 : 1
        Text {
            id: t
            anchors.centerIn: parent
            text: b.label
            color: b.danger ? root.cDanger : (b.active ? root.cGold : root.cCream)
            font.family: root.mono
            font.pixelSize: 11
            font.letterSpacing: 1
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }

    component OWSwitch: Rectangle {
        id: sw
        property bool on: false
        signal toggled(bool v)
        width: 28; height: 15; radius: 8
        color: sw.on ? "#55D4AF37" : "transparent"
        border.width: 1
        border.color: sw.on ? root.cGold : root.cOff
        Rectangle {
            width: 9; height: 9; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            x: sw.on ? parent.width - width - 3 : 3
            color: sw.on ? root.cGold : root.cOff
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
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
        signal moved(real v)
        readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
        implicitHeight: 26

        Rectangle {
            id: track
            x: 0
            width: s.width - 112
            height: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.cOff
            Rectangle {          // fills from the left edge, or outward from the centre for a +/- slider
                x: s.bipolar ? parent.width * Math.min(s.frac, 0.5) : 0
                width: s.bipolar ? parent.width * Math.abs(s.frac - 0.5) : parent.width * s.frac
                height: parent.height
                color: root.cGold
            }
            Rectangle {
                width: 10; height: 10; rotation: 45
                x: parent.width * s.frac - 5
                anchors.verticalCenter: parent.verticalCenter
                color: ma.pressed ? root.cCream : root.cGold
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            horizontalAlignment: Text.AlignRight
            text: s.text
            color: root.cCream
            font.family: root.mono
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        MouseArea {
            id: ma
            x: -6; width: track.width + 12; height: parent.height
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
        implicitHeight: 28
        radius: 3
        color: "#0D0F14"
        border.width: 1
        border.color: ti.activeFocus ? root.cGold : root.cLine
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
        Text {
            id: tl
            anchors.centerIn: parent
            text: tb.label
            color: tb.on ? root.cGold : (tma.containsMouse ? root.cCream : root.cDim)
            font.family: root.mono
            font.pixelSize: 11
            font.bold: tb.on
            font.letterSpacing: 2
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: tb.on ? root.cGold : "transparent" }
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
                width: parent.width - 96
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
            FieldLabel { y: 38; text: "ALL ORBITS" }
            OWSlider {
                y: 50
                width: parent.width
                from: 0; to: 3; step: 0.05
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
            width: parent.width - 36
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
                                Rectangle { anchors.fill: parent; anchors.topMargin: 6; color: hdrHover.hovered ? root.cHover : "transparent" }
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
                                    height: 34
                                    color: row.open ? "#1FD4AF37" : (rowHover.hovered ? root.cHover : "transparent")
                                    HoverHandler { id: rowHover }

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
                                                from: 0.3; to: 3.0; step: 0.05
                                                value: row.d ? row.d.size : 1
                                                text: (row.d ? row.d.size : 1).toFixed(2) + "×"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "size", v)
                                            }

                                            FieldLabel { text: "ORBIT SPEED  (− = other way, 0 = parked)" }
                                            OWSlider {
                                                width: parent.width
                                                from: -0.8; to: 0.8; step: 0.01
                                                bipolar: true
                                                value: row.d ? row.d.orbit.speed : 0
                                                text: row.d ? root.fmtSpeed(row.d.orbit.speed) : ""
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "speed", Math.abs(v) < 0.015 ? 0 : v)
                                            }

                                            FieldLabel { text: "ORBIT DISTANCE" }
                                            OWSlider {
                                                width: parent.width
                                                from: 1.1; to: 4.5; step: 0.05
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
                                                from: -1.5; to: 1.5; step: 0.05
                                                value: row.d ? row.d.orbit.tilt : 0
                                                text: "tilt " + Math.round((row.d ? row.d.orbit.tilt : 0) * 57.2958) + "°"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "tilt", v)
                                            }
                                            OWSlider {
                                                width: parent.width
                                                from: 0; to: 6.28; step: 0.05
                                                value: row.d ? (row.d.orbit.node || 0) : 0
                                                text: "turn " + Math.round((row.d ? (row.d.orbit.node || 0) : 0) * 57.2958) + "°"
                                                onMoved: (v) => WidgetConfig.setField(row.wid, "node", v)
                                            }

                                            FieldLabel { visible: row.keyAction !== ""; text: "KEY"; topPadding: 4 }
                                            Row {
                                                visible: row.keyAction !== ""
                                                spacing: 10
                                                OWButton {
                                                    label: root.capturing === row.keyAction ? "PRESS A KEY…" : Keybinds.pretty(Keybinds.seq(row.keyAction))
                                                    active: root.capturing === row.keyAction || Keybinds.isCustom(row.keyAction)
                                                    onClicked: { if (root.capturing === row.keyAction) { root.capturing = ""; root.keyMsg = ""; } else root.startCapture(row.keyAction); }
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.keyMsg !== "" ? root.keyMsg : (root.capturing === row.keyAction ? "Esc cancels  ·  Del unbinds" : Keybinds.labelOf(row.keyAction))
                                                    color: root.keyMsg !== "" ? root.cDanger : root.cDim
                                                    font.family: root.mono
                                                    font.pixelSize: 10
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

        // thin scrollbar
        Rectangle {
            visible: flick.contentHeight > flick.height
            x: flick.x + flick.width - 3
            y: flick.y + flick.height * (flick.contentY / flick.contentHeight)
            width: 3
            height: flick.height * (flick.height / flick.contentHeight)
            color: "#66D4AF37"
            radius: 1
        }
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
            width: parent.width - 36
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
                        Item {
                            y: kr.newGroup ? 34 : 0
                            width: parent.width; height: 38
                            Column {
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
                                    pad: 12
                                    implicitHeight: 26
                                    label: kr.capt ? "PRESS A KEY…" : Keybinds.pretty(Keybinds.seq(kr.modelData.id))
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

        Item {
            x: 18
            y: parent.height - 40
            width: parent.width - 36
            height: 28
            OWButton { label: "RESET ALL KEYS"; onClicked: { WidgetConfig.resetKeys(); root.keyMsg = ""; root.capturing = ""; } }
        }
    }

    // =====================================================================
    //  OPTIONS TAB
    // =====================================================================
    Item {
        id: optionsTab
        visible: root.tab === "options"
        x: 18; y: 100
        width: parent.width - 36
        height: parent.height - 100

        Column {
            width: parent.width
            spacing: 0

            Item {
                width: parent.width; height: 64
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    spacing: 3
                    Text { text: "Shrink widgets when far away"; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "On: widgets get much smaller when you click a planet from far off. Off: they stay at the larger size."
                        color: root.cDim; font.family: root.mono; font.pixelSize: 10
                    }
                }
                OWSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: WidgetConfig.shrinkFar
                    onToggled: (v) => WidgetConfig.setShrinkFar(v)
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.cLine }

            Item {
                width: parent.width; height: 64
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    spacing: 3
                    Text { text: "Loop / speed panel"; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "The box in the bottom right: loop clock, speed slider, reset buttons.   Key: " + Keybinds.pretty(Keybinds.seq("hud"))
                        color: root.cDim; font.family: root.mono; font.pixelSize: 10
                    }
                }
                OWSwitch {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: WidgetConfig.showLoopPanel
                    onToggled: (v) => WidgetConfig.setShowLoopPanel(v)
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.cLine }

            Item {
                width: parent.width; height: 84
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 8
                    Text { text: "Reset"; color: root.cCream; font.family: root.mono; font.pixelSize: 12 }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "RESET ALL WIDGETS puts every widget back where it started (removed ones return, added ones go) and keeps your keys."
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

    // ---------------- widget picker (add / change type / restore) ----------------
    Rectangle {
        id: picker
        visible: root.picking
        anchors.fill: parent
        color: "#07080C"
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
            width: parent.width - 36
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
                            height: 28
                            color: pma.containsMouse ? root.cHover : "transparent"
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
    }
}
