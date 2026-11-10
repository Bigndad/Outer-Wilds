import QtQuick
import ".."

// SUN: the 22-minute loop (real data from the rig)
WidgetCard {
    id: w
    title: "THE LOOP"
    designW: 276
    designH: 100

    readonly property real lt: rig ? rig.loopTime : 0
    readonly property real novaAt: 1290
    readonly property real total: rig ? rig.maxLoopTime : 1320

    Column {
        anchors.fill: parent
        spacing: 5 * w.ui

        Row {
            spacing: 8 * w.ui
            Text {
                text: "SUPERNOVA IN"
                color: w.cDim
                font.family: "monospace"
                font.pixelSize: Math.max(7, Math.round(11 * w.ui))
                font.letterSpacing: 1.5 * w.ui
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: w.lt < w.novaAt ? WidgetData.formatMinSec(w.novaAt - w.lt) : "--:--"
                color: w.lt > 1200 ? "#FF7A45" : w.cCream
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(26 * w.ui))
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(3, Math.round(5 * w.ui))
            radius: height / 2
            color: "#33D4AF37"
            Rectangle {
                width: parent.width * Math.min(1, w.lt / w.total)
                height: parent.height
                radius: parent.radius
                color: w.lt > 1200 ? "#FF7A45" : w.cGold
            }
        }

        Text {
            text: WidgetData.formatMinSec(w.lt) + " / " + WidgetData.formatMinSec(w.total)
            color: w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(7, Math.round(11 * w.ui))
        }
    }
}
