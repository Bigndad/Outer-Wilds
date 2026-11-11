import QtQuick
import ".."

// Widget control panel: every orbiting widget in one list, grouped by planet.
// Click a row to edit it: widget type, planet, size, orbit speed / direction, orbit distance, when it shows, axis.
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

    property string expandedId: ""
    property bool picking: false
    property string pickMode: "add"       // "add" | "swap"
    property string pickTarget: ""        // widget id when swapping
    property bool confirmReset: false
    property string lastHost: "timber_hearth"

    color: "#F207080C"
    border.color: "#55D4AF37"
    border.width: 1
    focus: true
    Keys.onEscapePressed: { if (picking) picking = false; else root.closeRequested(); }

    // ---------------- list structure ----------------
    // Rebuilt only when the SET of rows changes (a widget added / removed / moved to another planet),
    // never while a slider is dragged, so the row under the mouse keeps existing.
    property var structure: []
    property string _structKey: ""
    property int widgetCount: 0

    function buildStructure() {
        const all = WidgetConfig.entries();
        const byHost = {};
        for (let i = 0; i < all.length; i++) {
            const h = all[i].host;
            if (!byHost[h]) byHost[h] = [];
            byHost[h].push(all[i]);
        }
        const out = [];
        const known = {};
        for (let p = 0; p < WidgetConfig.planets.length; p++) {
            const id = WidgetConfig.planets[p].id;
            known[id] = true;
            const l = byHost[id];
            if (!l) continue;
            out.push({ kind: "header", planet: id, count: l.length });
            for (let j = 0; j < l.length; j++) out.push({ kind: "row", id: l[j].id });
        }
        for (const h in byHost) {                     // a host id the panel does not know (typo in a def): still listed
            if (known[h]) continue;
            out.push({ kind: "header", planet: h, count: byHost[h].length });
            for (let j = 0; j < byHost[h].length; j++) out.push({ kind: "row", id: byHost[h][j].id });
        }
        widgetCount = all.length;
        const key = JSON.stringify(out);
        if (key !== _structKey) { _structKey = key; structure = out; }
    }

    Connections {
        target: WidgetConfig
        function onRevisionChanged() { root.buildStructure(); }
    }
    Component.onCompleted: buildStructure()

    function toggleExpand(id) {
        if (expandedId === id) { expandedId = ""; WidgetConfig.previewId = ""; }
        else { expandedId = id; WidgetConfig.previewId = id; const e = WidgetConfig.entry(id); if (e) lastHost = e.host; }
    }

    function startPick(mode, target) { pickMode = mode; pickTarget = target; picking = true; }

    function pickChosen(source) {
        picking = false;
        if (pickMode === "add") {
            const id = WidgetConfig.addWidget(source, lastHost);
            expandedId = id;
        } else {
            WidgetConfig.setField(pickTarget, "source", source);
        }
    }

    function fmtSpeed(v) {
        if (Math.abs(v) < 0.005) return "parked";
        return (v > 0 ? "+" : "-") + Math.abs(v).toFixed(2) + "  ·  " + Math.round(2 * Math.PI / Math.abs(v)) + " s";
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

    // ---------------- header ----------------
    Item {
        id: head
        x: 18; y: 14
        width: parent.width - 36
        height: 52

        Text {
            text: "WIDGET CONTROL"
            color: root.cCream
            font.family: root.mono
            font.bold: true
            font.pixelSize: 16
            font.letterSpacing: 3
        }
        Text {
            y: 24
            text: root.widgetCount + " WIDGETS  ·  CLICK ONE TO EDIT"
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

    // gold hairline under the header
    Rectangle { x: 18; y: 70; width: parent.width - 36; height: 1; color: root.cLine }

    // ---------------- global controls ----------------
    Item {
        id: globalRow
        x: 18; y: 80
        width: parent.width - 36
        height: 58
        FieldLabel { text: "ALL ORBITS" }
        OWSlider {
            y: 14
            width: parent.width
            from: 0; to: 3; step: 0.05
            value: WidgetConfig.globalSpeed
            text: WidgetConfig.globalSpeed.toFixed(2) + "×"
            onMoved: (v) => WidgetConfig.setGlobalSpeed(v)
        }
        Row {
            y: 34
            spacing: 8
            OWButton { label: "+ ADD WIDGET"; onClicked: root.startPick("add", "") }
            OWButton {
                label: root.confirmReset ? "SURE? CLICK AGAIN" : "RESET ALL"
                danger: root.confirmReset
                onClicked: {
                    if (root.confirmReset) { WidgetConfig.resetAll(); root.expandedId = ""; root.confirmReset = false; }
                    else root.confirmReset = true;
                }
            }
        }
        Timer { interval: 3000; running: root.confirmReset; onTriggered: root.confirmReset = false }
    }

    // ---------------- the list ----------------
    Flickable {
        id: flick
        x: 18
        y: 148
        width: parent.width - 36
        height: parent.height - 148 - 12
        contentWidth: width
        contentHeight: listCol.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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
                            width: del.width
                            height: 36
                            Text {
                                x: 0
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: WidgetConfig.planetName(del.modelData.planet).toUpperCase() + "  (" + del.modelData.count + ")"
                                color: root.cGold
                                font.family: root.mono
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 2
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
                            width: del.width
                            height: rowHead.height + (open ? editor.height + 8 : 0)

                            // ---- row head ----
                            Rectangle {
                                id: rowHead
                                width: parent.width
                                height: 34
                                color: row.open ? "#1FD4AF37" : (headMa.containsMouse ? root.cHover : "transparent")

                                Rectangle {          // enabled switch
                                    id: sw
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 26; height: 14; radius: 7
                                    color: row.d && row.d.enabled ? "#55D4AF37" : "transparent"
                                    border.width: 1
                                    border.color: row.d && row.d.enabled ? root.cGold : root.cOff
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: row.d && row.d.enabled ? parent.width - width - 3 : 3
                                        color: row.d && row.d.enabled ? root.cGold : root.cOff
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: WidgetConfig.setField(row.wid, "enabled", !(row.d && row.d.enabled))
                                    }
                                }
                                Text {
                                    x: 46
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 46 - 100
                                    text: row.d ? WidgetConfig.widgetName(row.d) : ""
                                    elide: Text.ElideRight
                                    color: row.d && row.d.enabled ? root.cCream : root.cOff
                                    font.family: root.mono
                                    font.pixelSize: 12
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
                                MouseArea {
                                    id: headMa
                                    anchors.fill: parent
                                    anchors.leftMargin: 40
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleExpand(row.wid)
                                }
                            }

                            // ---- editor ----
                            // created only while the row is open (27 closed rows would otherwise carry 27 full editors)
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

                                    Row {
                                        spacing: 6
                                        topPadding: 6
                                        OWButton { label: "SHOW PLANET"; onClicked: root.flyRequested(row.d ? row.d.host : "") }
                                        OWButton { label: "RESET"; dim: !row.modified; onClicked: WidgetConfig.resetWidget(row.wid) }
                                        OWButton { visible: row.d !== null && row.d._extra; label: "REMOVE"; danger: true; onClicked: { WidgetConfig.removeWidget(row.wid); root.expandedId = ""; } }
                                    }
                                }
                                }
                            }
                        }
                    }
                }
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

    // ---------------- widget picker (add / change type) ----------------
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
                  ? "It starts on " + WidgetConfig.planetName(root.lastHost) + "; move it afterwards."
                  : "Keeps this widget's planet, orbit and size."
            color: root.cDim
            font.family: root.mono
            font.pixelSize: 10
        }

        Flickable {
            x: 18; y: 74
            width: parent.width - 36
            height: parent.height - 74 - 12
            contentHeight: pickCol.height + 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pickCol
                width: parent.width - 8
                Repeater {
                    model: WidgetConfig.catalog
                    delegate: Item {
                        id: pe
                        required property var modelData
                        required property int index
                        readonly property bool newGroup: index === 0 || WidgetConfig.catalog[index - 1].group !== modelData.group
                        width: pickCol.width
                        height: (newGroup ? 28 : 0) + 30

                        Text {
                            visible: pe.newGroup
                            y: 8
                            text: pe.modelData.group.toUpperCase()
                            color: root.cGold
                            font.family: root.mono
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Rectangle {
                            y: pe.newGroup ? 28 : 0
                            width: parent.width
                            height: 28
                            color: pma.containsMouse ? root.cHover : "transparent"
                            Text {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: pe.modelData.name
                                color: root.cCream
                                font.family: root.mono
                                font.pixelSize: 12
                            }
                            MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pickChosen(pe.modelData.source) }
                        }
                    }
                }
            }
        }
    }
}
