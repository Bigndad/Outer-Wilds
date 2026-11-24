import QtQuick
import ".."

// SUN: the 22-minute loop (real data from the rig)
WidgetCard {
    id: w
    title: "THE LOOP"
    designW: 276
    designH: 100

    property var cfg: ({ mode: "countdown", warnSec: 90, showBar: true, showSubtext: true,
                         barColor: "#D4AF37", warnColor: "#FF7A45", font: "monospace" })

    readonly property real lt: rig ? rig.loopTime : 0
    readonly property real novaAt: 1290
    readonly property real total: rig ? rig.maxLoopTime : 1320
    readonly property bool warning: (novaAt - lt) <= (cfg.warnSec !== undefined ? cfg.warnSec : 90)
    readonly property string leadLabel: cfg.mode === "elapsed" ? "ELAPSED" : (cfg.mode === "percent" ? "LOOP PROGRESS" : "SUPERNOVA IN")
    readonly property string mainValue: {
        if (cfg.mode === "elapsed") return WidgetData.formatMinSec(lt);
        if (cfg.mode === "percent") return Math.min(100, Math.round(lt / Math.max(1, total) * 100)) + "%";
        return lt < novaAt ? WidgetData.formatMinSec(novaAt - lt) : "--:--";
    }

    Column {
        anchors.fill: parent
        spacing: 5 * w.ui

        Row {
            spacing: 8 * w.ui
            Text {
                text: w.leadLabel
                color: w.cDim
                font.family: w.cfg.font || "monospace"
                font.pixelSize: Math.max(7, Math.round(11 * w.ui))
                font.letterSpacing: 1.5 * w.ui
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: w.mainValue
                color: w.warning ? (w.cfg.warnColor || "#FF7A45") : w.cCream
                font.family: w.cfg.font || "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(26 * w.ui))
            }
        }

        Rectangle {
            visible: w.cfg.showBar !== false
            width: parent.width
            height: Math.max(3, Math.round(5 * w.ui))
            radius: height / 2
            color: "#33D4AF37"
            Rectangle {
                width: parent.width * Math.min(1, w.lt / Math.max(1, w.total))
                height: parent.height
                radius: parent.radius
                color: w.warning ? (w.cfg.warnColor || "#FF7A45") : (w.cfg.barColor || w.cGold)
            }
        }

        Text {
            visible: w.cfg.showSubtext !== false
            text: WidgetData.formatMinSec(w.lt) + " / " + WidgetData.formatMinSec(w.total)
            color: w.cDim
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(7, Math.round(11 * w.ui))
        }
    }
}
