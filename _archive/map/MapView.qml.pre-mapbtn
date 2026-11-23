import QtQuick
import ".."

// =====================================================================
//  MapView: the heavy part of the Map View. Created by MapHost's Loader only while the map is open.
//  Two layers that cross-fade:
//    grid  - all planets, selected one centred with a crosshair, moons under their parents, outlines for planets
//            without live data. Wheel / + / - zooms out to the whole system.
//    page  - entry list (left), picture + action button (right), description box (bottom).
//  All state lives in MapData; this file only draws it and turns keys / clicks into MapData calls.
// =====================================================================
Item {
    id: view

    signal faded()                                  // fully transparent AND the map was closed: MapHost may destroy us

    readonly property real bu: Math.max(0.75, Math.round(height / 1080 * 16) / 16)
    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property color cDim: "#8A7F66"
    readonly property string fontFamily: "monospace"

    // ---------------- show / hide ----------------
    property bool _in: false
    readonly property bool wantShown: MapData.open && !MapData.rumorMode && _in
    opacity: wantShown ? 1 : 0
    visible: opacity > 0.005
    Behavior on opacity { NumberAnimation { duration: 160 } }
    onOpacityChanged: { if (opacity <= 0.001 && !MapData.open) faded(); }
    Component.onCompleted: _in = true

    // ---------------- camera ----------------
    readonly property var selBody: MapData.body(MapData.selectedId)
    property real zoom: MapData.zoomTarget
    Behavior on zoom { NumberAnimation { duration: 380; easing.type: Easing.InOutQuad } }
    property real selX: selBody ? selBody.x : 0
    property real selY: selBody ? selBody.y : 0
    Behavior on selX { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    Behavior on selY { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    // tuning knobs
    readonly property real closeGapK: 0.285         // column spacing in px / screen width at zoom 1 (about 3.5 columns across)
    readonly property real overviewGapK: 0.098      // ... at zoom 0 (the whole system fits)
    readonly property real overviewCx: 3.59         // world point the overview is centred on
    readonly property real overviewCy: 0.26
    readonly property real centerY: height * 0.47   // screen y of the selected planet

    readonly property real closeGap: width * closeGapK
    readonly property real overviewGap: width * overviewGapK
    readonly property real gapPx: overviewGap * Math.pow(closeGap / overviewGap, zoom)
    readonly property real camX: overviewCx + (selX - overviewCx) * zoom
    readonly property real camY: overviewCy + (selY - overviewCy) * zoom
    function sx(wx) { return width / 2 + (wx - camX) * gapPx; }
    function sy(wy) { return centerY + (wy - camY) * gapPx; }

    property string hoveredId: ""

    // ---------------- page data (derived, cheap) ----------------
    readonly property string selId: MapData.selectedId
    readonly property var entries: MapData.entriesFor(selId)
    readonly property int entryIndex: {
        for (let i = 0; i < entries.length; i++) if (entries[i].eid === MapData.entryId) return i;
        return entries.length > 0 ? 0 : -1;
    }
    readonly property var entry: entryIndex >= 0 ? entries[entryIndex] : null
    readonly property var detail: entry ? MapData.describe(selId, entry.eid) : null     // live values update here only
    readonly property var action: entry ? MapData.actionFor(selId, entry.eid) : null
    readonly property bool live: MapData.hasData(selId)
    readonly property var rows: {
        const r = [];
        let g = "\u0000";
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].group !== g) { g = entries[i].group; r.push({ kind: "g", title: g, idx: -1 }); }
            r.push({ kind: "e", title: entries[i].title, idx: i });
        }
        return r;
    }
    function rowOfEntry(i) {
        for (let r = 0; r < rows.length; r++) if (rows[r].kind === "e" && rows[r].idx === i) return r;
        return -1;
    }
    readonly property var paragraphs: {
        if (detail && detail.text.length > 0) return detail.text;
        const b = selBody;
        return ["NO SIGNAL.", (b ? b.role : "This planet") + " has nothing to show yet."];
    }

    function runAction() { if (entry) MapData.runAction(selId, entry.eid); }
    function moveEntry(delta) {
        if (entries.length === 0) return;
        const i = Math.max(0, Math.min(entries.length - 1, entryIndex + delta));
        MapData.entryId = entries[i].eid;
    }

    // ---------------- keys (MapHost forwards every key here and accepts it) ----------------
    function handleKey(event) {
        const k = event.key;
        if (k === Qt.Key_R) { if (!event.isAutoRepeat) MapData.enterRumor(); return; }
        if (MapData.pageOpen) {
            if (k === Qt.Key_Up)         moveEntry(-1);
            else if (k === Qt.Key_Down)  moveEntry(1);
            else if (k === Qt.Key_Left)  MapData.move("left");
            else if (k === Qt.Key_Right) MapData.move("right");
            else if (!event.isAutoRepeat && (k === Qt.Key_Return || k === Qt.Key_Enter)) runAction();
            else if (!event.isAutoRepeat && (k === Qt.Key_Escape || k === Qt.Key_Backspace)) MapData.closePage();
        } else {
            if (k === Qt.Key_Left)       MapData.move("left");
            else if (k === Qt.Key_Right) MapData.move("right");
            else if (k === Qt.Key_Up)    MapData.move("up");
            else if (k === Qt.Key_Down)  MapData.move("down");
            else if (k === Qt.Key_Plus || k === Qt.Key_Equal || k === Qt.Key_PageUp)    MapData.zoomBy(0.34);
            else if (k === Qt.Key_Minus || k === Qt.Key_Underscore || k === Qt.Key_PageDown) MapData.zoomBy(-0.34);
            else if (!event.isAutoRepeat && (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)) MapData.openPage();
            else if (!event.isAutoRepeat && k === Qt.Key_Escape) MapData.hide();
        }
    }

    // ---------------- backdrop + input sink ----------------
    Rectangle { anchors.fill: parent; color: "#F2060810" }

    MouseArea {
        // takes every button / move / wheel event so nothing reaches the camera rig underneath
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: (w) => {
            if (!MapData.pageOpen) MapData.zoomBy(w.angleDelta.y > 0 ? 0.34 : -0.34);
            w.accepted = true;
        }
    }

    // =================================================================
    //  GRID LAYER
    // =================================================================
    Item {
        id: gridLayer
        anchors.fill: parent
        opacity: MapData.pageOpen ? 0 : 1
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // faint world grid (fixed pool of lines, repositioned while the camera moves; nothing runs when it is still)
        Item {
            id: gridLines
            anchors.fill: parent
            readonly property real step: view.gapPx / 3
            readonly property real offX: (((view.sx(0)) % step) + step) % step
            readonly property real offY: (((view.sy(0)) % step) + step) % step
            Repeater {
                model: 44
                Rectangle {
                    required property int index
                    x: Math.round(gridLines.offX + index * gridLines.step)
                    width: 1
                    height: gridLines.height
                    color: "#16E6D5B8"
                    visible: x < gridLines.width
                }
            }
            Repeater {
                model: 28
                Rectangle {
                    required property int index
                    y: Math.round(gridLines.offY + index * gridLines.step)
                    height: 1
                    width: gridLines.width
                    color: "#16E6D5B8"
                    visible: y < gridLines.height
                }
            }
        }

        // crosshair through the selected planet
        Rectangle {
            x: 0
            y: Math.round(view.sy(view.selY))
            width: view.width
            height: Math.max(1, Math.round(view.bu))
            color: "#55D4AF37"
        }
        Rectangle {
            y: 0
            x: Math.round(view.sx(view.selX))
            height: view.height
            width: Math.max(1, Math.round(view.bu))
            color: "#55D4AF37"
        }

        // planets
        Repeater {
            model: MapData.catalog
            MapNode {
                required property var modelData
                info: modelData
                bu: view.bu
                zoom: view.zoom
                px: Math.max(14 * view.bu, modelData.d * view.gapPx)
                x: view.sx(modelData.x) - width / 2
                y: view.sy(modelData.y) - height / 2
                selected: MapData.selectedId === modelData.id
                hovered: view.hoveredId === modelData.id
                live: MapData.hasData(modelData.id)
                labelAbove: MapData.hasMoon(modelData.id)
                iconUrl: MapData.useIcons ? MapData.iconDir + modelData.id + ".png" : ""
                onHoverChanged: (over) => { view.hoveredId = over ? modelData.id : (view.hoveredId === modelData.id ? "" : view.hoveredId); }
                onClicked: {
                    if (MapData.selectedId === modelData.id) MapData.openPage();
                    else MapData.select(modelData.id);
                }
                onDoubleClicked: { MapData.select(modelData.id); MapData.openPage(); }
            }
        }

        // selection brackets around the selected planet
        Item {
            id: selBox
            readonly property real half: Math.max(Math.round(26 * view.bu), (view.selBody ? view.selBody.d * view.gapPx : 0) / 2 + Math.round(16 * view.bu))
            readonly property real len: Math.round(14 * view.bu)
            readonly property real th: Math.max(2, Math.round(2 * view.bu))
            x: view.sx(view.selX) - half
            y: view.sy(view.selY) - half
            width: half * 2
            height: half * 2
            Repeater {
                model: 4
                Item {
                    required property int index
                    readonly property bool r: index % 2 === 1
                    readonly property bool b: index >= 2
                    x: r ? selBox.width - selBox.len : 0
                    y: b ? selBox.height - selBox.len : 0
                    width: selBox.len
                    height: selBox.len
                    Rectangle { width: parent.width; height: selBox.th; y: b ? parent.height - height : 0; color: view.cGold }
                    Rectangle { height: parent.height; width: selBox.th; x: r ? parent.width - width : 0; color: view.cGold }
                }
            }
        }

        // header
        Column {
            x: Math.round(48 * view.bu)
            y: Math.round(36 * view.bu)
            spacing: Math.round(4 * view.bu)
            Text {
                text: view.selBody ? view.selBody.name : ""
                color: view.cGold
                font.family: view.fontFamily
                font.bold: true
                font.pixelSize: Math.round(36 * view.bu)
                font.letterSpacing: 3 * view.bu
            }
            Text {
                text: (view.selBody ? view.selBody.role.toUpperCase() : "") + "   -   " + (view.live ? view.entries.length + (view.entries.length === 1 ? " ENTRY" : " ENTRIES") : "NO SIGNAL")
                color: view.live ? view.cCream : view.cDim
                font.family: view.fontFamily
                font.pixelSize: Math.max(10, Math.round(15 * view.bu))
                font.letterSpacing: 2 * view.bu
            }
        }

        MapButton {
            x: view.width - width - Math.round(48 * view.bu)
            y: Math.round(40 * view.bu)
            bu: view.bu
            label: "Rumor Mode"
            hint: "R"
            onClicked: MapData.enterRumor()
        }
    }

    // =================================================================
    //  PAGE LAYER
    // =================================================================
    Item {
        id: pageLayer
        anchors.fill: parent
        opacity: MapData.pageOpen ? 1 : 0
        visible: opacity > 0.005
        Behavior on opacity { NumberAnimation { duration: 180 } }

        readonly property real m: Math.round(48 * view.bu)
        readonly property real gap: Math.round(16 * view.bu)
        readonly property real headerH: Math.round(124 * view.bu)
        readonly property real bottomM: Math.round(44 * view.bu)
        readonly property real descH: Math.round(view.height * 0.22)
        readonly property real btnH: Math.round(44 * view.bu)
        readonly property real listW: Math.round((view.width - 2 * m - gap) * 0.62)
        readonly property real listH: view.height - headerH - bottomM - descH - gap
        readonly property real picX: m + listW + gap
        readonly property real picW: view.width - m - picX
        readonly property real picH: listH - btnH - gap
        readonly property real ui: view.bu

        // title + buttons
        Text {
            x: pageLayer.m
            y: Math.round(34 * view.bu)
            text: view.selBody ? view.selBody.name : ""
            color: view.cGold
            font.family: view.fontFamily
            font.bold: true
            font.pixelSize: Math.round(42 * view.bu)
            font.letterSpacing: 3 * view.bu
        }
        Text {
            x: pageLayer.m
            y: Math.round(34 * view.bu) + Math.round(54 * view.bu)
            text: view.selBody ? view.selBody.role.toUpperCase() : ""
            color: view.cDim
            font.family: view.fontFamily
            font.pixelSize: Math.max(10, Math.round(15 * view.bu))
            font.letterSpacing: 2 * view.bu
        }
        Row {
            y: Math.round(36 * view.bu)
            x: view.width - width - pageLayer.m
            spacing: Math.round(14 * view.bu)
            MapButton { bu: view.bu; label: "Rumor Mode"; hint: "R"; onClicked: MapData.enterRumor() }
            MapButton { bu: view.bu; label: "Back to Map"; hint: "Esc"; onClicked: MapData.closePage() }
        }

        // ---- entry list ----
        WidgetCard {
            id: listCard
            x: pageLayer.m
            y: pageLayer.headerH
            ui: view.bu
            designW: pageLayer.listW / view.bu
            designH: pageLayer.listH / view.bu

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: view.rows
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: view.rowOfEntry(view.entryIndex)
                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool isEntry: modelData.kind === "e"
                    readonly property bool sel: isEntry && modelData.idx === view.entryIndex
                    width: ListView.view.width
                    height: Math.round(36 * view.bu)

                    Rectangle {
                        anchors.fill: parent
                        color: rowMa.containsMouse && row.isEntry ? "#18D4AF37" : "transparent"
                    }
                    Rectangle {                         // tree stub, like the game's list
                        x: Math.round((row.sel ? 22 : 4) * view.bu)
                        y: Math.round(row.height / 2)
                        width: Math.round((row.isEntry ? 30 : 16) * view.bu) - x + Math.round(4 * view.bu)
                        height: 1
                        color: row.sel ? view.cGold : view.cDim
                    }
                    Text {                              // chevron on the selected entry
                        visible: row.sel
                        x: Math.round(8 * view.bu)
                        anchors.verticalCenter: parent.verticalCenter
                        text: ">"
                        color: view.cGold
                        font.family: view.fontFamily
                        font.bold: true
                        font.pixelSize: Math.max(10, Math.round(20 * view.bu))
                    }
                    Text {
                        x: Math.round((row.isEntry ? 46 : 28) * view.bu)
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - Math.round(8 * view.bu)
                        elide: Text.ElideRight
                        text: row.modelData.title
                        color: row.isEntry ? (row.sel ? view.cGold : view.cCream) : view.cDim
                        font.family: view.fontFamily
                        font.bold: row.sel
                        font.pixelSize: Math.max(10, Math.round((row.isEntry ? 20 : 19) * view.bu))
                    }
                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.isEntry
                        acceptedButtons: Qt.LeftButton
                        onClicked: MapData.entryId = view.entries[row.modelData.idx].eid
                        onDoubleClicked: { MapData.entryId = view.entries[row.modelData.idx].eid; view.runAction(); }
                    }
                }
            }
            Text {                                      // empty list
                visible: view.rows.length === 0
                anchors.centerIn: parent
                text: "- no entries -"
                color: view.cDim
                font.family: view.fontFamily
                font.pixelSize: Math.max(10, Math.round(18 * view.bu))
            }
        }

        // ---- picture ----
        WidgetCard {
            id: picCard
            x: pageLayer.picX
            y: pageLayer.headerH
            ui: view.bu
            designW: pageLayer.picW / view.bu
            designH: pageLayer.picH / view.bu

            Item {
                anchors.fill: parent
                readonly property real s: Math.min(width, height)

                Image {
                    id: pic
                    anchors.centerIn: parent
                    width: parent.s
                    height: parent.s
                    source: view.detail ? view.detail.image : ""
                    asynchronous: true
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                Item {                                  // no picture: planet-coloured disc with a monogram (outline when unexplored)
                    anchors.centerIn: parent
                    width: parent.s * 0.7
                    height: width
                    visible: pic.status !== Image.Ready
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: view.live && view.selBody ? Qt.darker(view.selBody.fill, 1.5) : "transparent"
                        border.color: view.live && view.selBody ? view.selBody.ring : view.cCream
                        border.width: Math.max(2, Math.round(3 * view.bu))
                        opacity: 0.9
                    }
                    Text {
                        anchors.centerIn: parent
                        text: view.live && view.detail ? view.detail.glyph : "?"
                        color: view.cCream
                        font.family: view.fontFamily
                        font.bold: true
                        font.pixelSize: Math.round(parent.width * 0.3)
                    }
                }
            }
        }

        // ---- action button (under the picture) ----
        MapButton {
            visible: view.action !== null
            x: pageLayer.picX
            y: pageLayer.headerH + pageLayer.picH + pageLayer.gap
            width: pageLayer.picW
            height: pageLayer.btnH
            bu: view.bu
            primary: true
            enabled: view.action !== null && view.action.enabled
            label: view.action ? view.action.label + (view.action.enabled ? "" : "  (read-only)") : ""
            hint: view.action && view.action.enabled ? "Enter" : ""
            onClicked: view.runAction()
        }

        // ---- description ----
        WidgetCard {
            id: descCard
            x: pageLayer.m
            y: pageLayer.headerH + pageLayer.listH + pageLayer.gap
            ui: view.bu
            designW: (view.width - 2 * pageLayer.m) / view.bu
            designH: pageLayer.descH / view.bu

            Flickable {
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: descCol.height
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: descCol
                    width: parent.width
                    spacing: Math.round(8 * view.bu)
                    Repeater {
                        model: view.paragraphs
                        Item {
                            required property string modelData
                            width: descCol.width
                            height: ptxt.implicitHeight
                            Rectangle { x: 0; y: Math.round(ptxt.font.pixelSize * 0.62); width: Math.round(14 * view.bu); height: 1; color: view.cDim }
                            Text {
                                id: ptxt
                                x: Math.round(24 * view.bu)
                                width: parent.width - x
                                text: modelData
                                wrapMode: Text.WordWrap
                                color: view.cCream
                                font.family: view.fontFamily
                                font.pixelSize: Math.max(11, Math.round(20 * view.bu))
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------- hint bar ----------------
    Text {
        x: Math.round(48 * view.bu)
        y: view.height - Math.round(34 * view.bu)
        color: view.cDim
        font.family: view.fontFamily
        font.pixelSize: Math.max(9, Math.round(13 * view.bu))
        font.letterSpacing: 1 * view.bu
        text: MapData.pageOpen
              ? "UP / DOWN  entry     LEFT / RIGHT  planet     ENTER  action     R  rumor mode     ESC  back to map     N  close"
              : "ARROWS  move     ENTER  open     + / -  zoom     R  rumor mode     N / ESC  close"
    }
}
