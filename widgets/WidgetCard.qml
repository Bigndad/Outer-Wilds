import QtQuick
import ".."

// Outer Wilds x Glyph hybrid instrument panel. Every built-in native widget is a WidgetCard.
// `minLayoutUi: 1.0` keeps internal layout and fonts at 1x while WidgetSlot scales down smoothly on zoom-out.
Item {
    id: card

    property real ui: 1.0
    readonly property real minLayoutUi: 1.0
    property var rig: null
    property string title: ""
    property real designW: 280
    property real designH: 140
    default property alias content: body.data

    property var cardStyle: ({})
    readonly property string hostId: (cardStyle && cardStyle.host) ? String(cardStyle.host) : ""
    readonly property var wcfg: (cardStyle && cardStyle.cfg) ? cardStyle.cfg : ({})
    readonly property bool usePlanetTheme: WidgetConfig.nativePlanetTheme && wcfg.planetTheme !== false && hostId !== ""
    readonly property var pTheme: usePlanetTheme ? WidgetConfig.planetTheme(hostId) : null

    readonly property color cCream: WidgetConfig.nativeText !== "" ? WidgetConfig.nativeText : (pTheme ? pTheme.cream : "#E6D5B8")
    readonly property color cGold: WidgetConfig.nativeAccent !== "" ? WidgetConfig.nativeAccent : (pTheme ? pTheme.accent : "#D4AF37")
    readonly property color cDim: WidgetConfig.nativeDim !== "" ? WidgetConfig.nativeDim : (pTheme ? pTheme.dim : "#8A7F66")
    readonly property color cBg: WidgetConfig.nativeBg !== "" ? WidgetConfig.nativeBg : (pTheme ? pTheme.bg : "#EE0B0C10")
    readonly property color cSurface: WidgetConfig.nativeSurface !== "" ? WidgetConfig.nativeSurface : (pTheme ? pTheme.surface : "#FF13151C")
    readonly property color cBorder: (cardStyle && cardStyle.border) ? cardStyle.border : (pTheme ? pTheme.border : "#2EE6D5B8")
    readonly property string effFont: WidgetConfig.nativeFont !== "" ? WidgetConfig.nativeFont : "monospace"

    readonly property string effTitle: (cardStyle && cardStyle.title) ? cardStyle.title : title
    readonly property bool showHeader: effTitle !== "" && wcfg.showHeader !== false
    readonly property bool showLayers: WidgetConfig.nativeLayers !== false
    readonly property bool showGrid: showLayers && wcfg.showGrid !== false
    readonly property bool effBrackets: (cardStyle && cardStyle.brackets !== undefined) ? cardStyle.brackets : WidgetConfig.widgetBrackets
    property color accent: (cardStyle && cardStyle.accent) ? cardStyle.accent : (WidgetConfig.nativeAccent !== "" ? WidgetConfig.nativeAccent : (pTheme ? pTheme.accent : WidgetConfig.widgetAccent))
    readonly property real effRadius: ((cardStyle && cardStyle.radius >= 0) ? cardStyle.radius : WidgetConfig.widgetRadius) * ui
    readonly property real effBgOpacity: Math.max(0.15, Math.min(1.0, WidgetConfig.nativeOpacity * (wcfg.bgOpacity !== undefined ? wcfg.bgOpacity : 1.0)))

    readonly property real innerW: width - 28 * ui
    readonly property real innerH: height - (showHeader ? 48 : 28) * ui

    width: Math.round(designW * ui)
    height: Math.round(designH * ui)

    // Layer 1: Matte outer chassis
    Rectangle {
        id: chassis
        anchors.fill: parent
        radius: card.effRadius
        color: (card.cardStyle && card.cardStyle.bg) ? card.cardStyle.bg : card.cBg
        opacity: card.effBgOpacity
        border.color: card.cBorder
        border.width: Math.max(1, Math.round(card.ui))
        clip: true

        // Layer 2: Depth gradient sheen
        Rectangle {
            visible: card.showLayers
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.08) }
                GradientStop { position: 0.35; color: "#05FFFFFF" }
                GradientStop { position: 1.0; color: "#1A000000" }
            }
        }

        // Layer 2b: Inner hairline bevel
        Rectangle {
            visible: card.showLayers
            anchors.fill: parent
            anchors.margins: Math.max(1, Math.round(card.ui))
            radius: Math.max(0, parent.radius - Math.max(1, Math.round(card.ui)))
            color: "transparent"
            border.color: "#14FFFFFF"
            border.width: Math.max(1, Math.round(card.ui))
        }

        // Layer 3: Header band
        Rectangle {
            visible: card.showHeader && card.showLayers
            x: Math.max(1, Math.round(card.ui))
            y: Math.max(1, Math.round(card.ui))
            width: parent.width - Math.max(2, Math.round(2 * card.ui))
            height: 25 * card.ui
            color: "#22000000"
        }
    }

    // Layer 3b: Header title + Glyph telemetry pips
    Item {
        visible: card.showHeader
        x: 12 * card.ui
        y: 6 * card.ui
        width: card.width - 24 * card.ui
        height: 18 * card.ui

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * card.ui

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(7, Math.round(8 * card.ui))
                height: width
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: width; radius: width / 2
                    color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.28)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(3, Math.round(4 * card.ui)); height: width; radius: width / 2
                    color: card.accent
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.effTitle
                color: card.cDim
                font.family: card.effFont
                font.pixelSize: Math.max(8, Math.round(10 * card.ui))
                font.bold: true
                font.letterSpacing: 2 * card.ui
            }
        }

        Row {
            visible: card.showLayers && card.width >= 150 * card.ui
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * card.ui
            Repeater {
                model: 3
                Rectangle {
                    width: Math.max(2, Math.round(3 * card.ui))
                    height: width; radius: width / 2
                    color: index === 2 ? card.accent : card.cDim
                    opacity: index === 2 ? 0.85 : 0.35
                }
            }
        }
    }

    Rectangle {
        visible: card.showHeader
        x: 10 * card.ui
        y: 26 * card.ui
        width: card.width - 20 * card.ui
        height: Math.max(1, Math.round(card.ui))
        color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.22)
    }

    // Layer 4: Recessed inner display bay + subtle dot-grid
    Rectangle {
        id: innerBay
        visible: card.showLayers
        x: 8 * card.ui
        y: card.showHeader ? 30 * card.ui : 8 * card.ui
        width: Math.max(0, card.width - 16 * card.ui)
        height: Math.max(0, card.height - y - 8 * card.ui)
        radius: Math.max(2 * card.ui, card.effRadius - 3 * card.ui)
        color: card.cSurface
        opacity: 0.72 * card.effBgOpacity
        border.width: Math.max(1, Math.round(card.ui))
        border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.14)
        clip: true

        Canvas {
            id: gridCanvas
            anchors.fill: parent
            visible: card.showGrid && width > 20 && height > 20
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()
            Component.onCompleted: if (visible) requestPaint()
            Connections {
                target: card
                function onUiChanged() { if (gridCanvas.visible) gridCanvas.requestPaint(); }
                function onCCreamChanged() { if (gridCanvas.visible) gridCanvas.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const step = Math.max(8, Math.round(12 * card.ui));
                const r = Math.max(0.7, 0.9 * card.ui);
                ctx.fillStyle = Qt.rgba(card.cCream.r, card.cCream.g, card.cCream.b, 0.08);
                for (let gy = step * 0.6; gy < height - 2; gy += step) {
                    for (let gx = step * 0.6; gx < width - 2; gx += step) {
                        ctx.fillRect(gx - r * 0.5, gy - r * 0.5, r, r);
                    }
                }
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 14 * card.ui
        anchors.topMargin: card.showHeader ? 34 * card.ui : 14 * card.ui
        scale: card.wcfg.contentScale !== undefined ? card.wcfg.contentScale : 1.0
        transformOrigin: Item.Center
    }

    // Layer 5: Radius-aware curved outer brackets
    Canvas {
        id: bracketCanvas
        anchors.fill: parent
        visible: card.effBrackets
        z: 10
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        Component.onCompleted: if (visible) requestPaint()
        Connections {
            target: card
            function onEffRadiusChanged() { if (bracketCanvas.visible) bracketCanvas.requestPaint(); }
            function onAccentChanged() { if (bracketCanvas.visible) bracketCanvas.requestPaint(); }
            function onUiChanged() { if (bracketCanvas.visible) bracketCanvas.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 2 || height <= 2) return;

            const lw = Math.max(1.25, 1.75 * card.ui);
            const ins = lw * 0.5;
            const w = width, h = height;
            const r = Math.max(0, Math.min(card.effRadius - ins, w * 0.4, h * 0.4));
            const extra = Math.max(5 * card.ui, (11 - r * 0.22) * card.ui);
            const ax = Math.min(w * 0.44, Math.max(ins + r, ins + r + extra));
            const ay = Math.min(h * 0.44, Math.max(ins + r, ins + r + extra));

            ctx.strokeStyle = card.accent;
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.globalAlpha = 0.92;

            ctx.beginPath();
            ctx.moveTo(ins, ay);
            ctx.lineTo(ins, ins + r);
            if (r > 0.5) ctx.arcTo(ins, ins, ins + r, ins, r);
            else ctx.lineTo(ins, ins);
            ctx.lineTo(ax, ins);

            ctx.moveTo(w - ax, ins);
            ctx.lineTo(w - ins - r, ins);
            if (r > 0.5) ctx.arcTo(w - ins, ins, w - ins, ins + r, r);
            else ctx.lineTo(w - ins, ins);
            ctx.lineTo(w - ins, ay);

            ctx.moveTo(w - ins, h - ay);
            ctx.lineTo(w - ins, h - ins - r);
            if (r > 0.5) ctx.arcTo(w - ins, h - ins, w - ins - r, h - ins, r);
            else ctx.lineTo(w - ins, h - ins);
            ctx.lineTo(w - ax, h - ins);

            ctx.moveTo(ax, h - ins);
            ctx.lineTo(ins + r, h - ins);
            if (r > 0.5) ctx.arcTo(ins, h - ins, ins, h - ins - r, r);
            else ctx.lineTo(ins, h - ins);
            ctx.lineTo(ins, h - ay);
            ctx.stroke();
        }
    }
}
