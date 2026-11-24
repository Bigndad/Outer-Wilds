import QtQuick
import ".."

WidgetCard {
    id: w
    title: "CALCULATOR"
    designW: 236
    designH: 258

    property var cfg: ({ font: "monospace" })
    readonly property string effCalcFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont
    property string expr: ""
    property string display: "0"

    function press(k) {
        if (k === "C") { expr = ""; display = "0"; return; }
        if (k === "⌫") { expr = expr.slice(0, -1); display = expr === "" ? "0" : expr; return; }
        if (k === "=") {
            if (!expr) return;
            try {
                const safe = expr.replace(/×/g, "*").replace(/÷/g, "/").replace(/[^0-9+\-*/.%() ]/g, "");
                const val = Function('"use strict"; return (' + safe + ')')();
                if (typeof val === "number" && isFinite(val)) {
                    display = String(Math.round(val * 1e8) / 1e8);
                    expr = display;
                } else display = "ERR";
            } catch (e) { display = "ERR"; }
            return;
        }
        if (display === "ERR") expr = "";
        expr += k;
        display = expr;
    }

    Column {
        anchors.fill: parent
        spacing: 6 * w.ui

        Rectangle {
            width: parent.width
            height: 40 * w.ui
            radius: 4 * w.ui
            color: "#2B000000"
            border.width: Math.max(1, Math.round(w.ui))
            border.color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.25)

            Text {
                anchors.fill: parent; anchors.margins: 8 * w.ui
                horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                elide: Text.ElideLeft
                text: w.display
                color: w.cCream
                font.family: w.effCalcFont; font.bold: true
                font.pixelSize: Math.max(10, Math.round(18 * w.ui))
            }
        }

        Grid {
            width: parent.width
            columns: 4
            rowSpacing: 5 * w.ui
            columnSpacing: 5 * w.ui
            readonly property real bw: (width - 15 * w.ui) / 4
            readonly property real bh: (w.innerH - 46 * w.ui - 20 * w.ui) / 5

            Repeater {
                model: ["C", "⌫", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "-", "1", "2", "3", "+", "(", "0", ".", "="]
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool isOp: "÷×-+%".indexOf(modelData) >= 0
                    readonly property bool isEq: modelData === "="
                    width: parent.bw; height: parent.bh; radius: 4 * w.ui
                    color: isEq ? w.accent : (isOp ? Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.16) : "#22000000")
                    border.width: Math.max(1, Math.round(w.ui))
                    border.color: isEq ? w.accent : Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: isEq ? "#0B0C10" : (isOp ? w.accent : w.cCream)
                        font.family: w.effCalcFont; font.bold: true
                        font.pixelSize: Math.max(9, Math.round(12 * w.ui))
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: w.press(modelData) }
                }
            }
        }
    }
}
