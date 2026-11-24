import QtQuick
import ".."

// SUN: the 22-minute loop (real data from the rig)
WidgetCard {
    id: w
    title: "THE LOOP"
    designW: 276
    designH: 108

    property var cfg: ({ mode: "countdown", warnSec: 90, showBar: true, showSubtext: true,
                         barColor: "#D4AF37", warnColor: "#FF7A45", font: "monospace" })

    readonly property real lt: rig ? rig.loopTime : 0
    readonly property real novaAt: 1290
    readonly property real total: rig ? rig.maxLoopTime : 1320
    readonly property bool warning: (novaAt - lt) <= (cfg.warnSec !== undefined ? cfg.warnSec : 90)
    readonly property color effBarColor: (cfg.barColor && cfg.barColor.toUpperCase() !== "#D4AF37") ? cfg.barColor : w.accent
    readonly property color effWarnColor: cfg.warnColor || "#FF7A45"
    readonly property string effLoopFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont
    readonly property string leadLabel: cfg.mode === "elapsed" ? "ELAPSED" : (cfg.mode === "percent" ? "LOOP PROGRESS" : "SUPERNOVA IN")
    readonly property string mainValue: {
        if (cfg.mode === "elapsed") return WidgetData.formatMinSec(lt);
        if (cfg.mode === "percent") return Math.min(100, Math.round(lt / Math.max(1, total) * 100)) + "%";
        return lt < novaAt ? WidgetData.formatMinSec(novaAt - lt) : "--:--";
    }

    Column {
        anchors.fill: parent
        spacing: 6 * w.ui

        Item {
            width: parent.width
            height: Math.max(valTxt.implicitHeight, 24 * w.ui)

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: leadTxt.implicitWidth + 10 * w.ui
                height: leadTxt.implicitHeight + 5 * w.ui
                radius: 3 * w.ui
                color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.12)
                border.width: Math.max(1, Math.round(w.ui))
                border.color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.25)

                Text {
                    id: leadTxt
                    anchors.centerIn: parent
                    text: w.leadLabel
                    color: w.cDim
                    font.family: w.effLoopFont
                    font.pixelSize: Math.max(7, Math.round(9 * w.ui))
                    font.bold: true
                    font.letterSpacing: 1.4 * w.ui
                }
            }

            Text {
                id: valTxt
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: w.mainValue
                color: w.warning ? w.effWarnColor : w.cCream
                font.family: w.effLoopFont
                font.bold: true
                font.pixelSize: Math.max(9, Math.round(24 * w.ui))
            }
        }

        Rectangle {
            visible: w.cfg.showBar !== false
            width: parent.width
            height: Math.max(6, Math.round(8 * w.ui))
            radius: 3 * w.ui
            color: "#33000000"
            border.width: Math.max(1, Math.round(w.ui))
            border.color: Qt.rgba(w.effBarColor.r, w.effBarColor.g, w.effBarColor.b, 0.24)
            clip: true

            Rectangle {
                x: Math.max(1, Math.round(w.ui))
                y: Math.max(1, Math.round(w.ui))
                width: Math.max(0, (parent.width - 2 * x) * Math.min(1, w.lt / Math.max(1, w.total)))
                height: parent.height - 2 * y
                radius: 2 * w.ui
                color: w.warning ? w.effWarnColor : w.effBarColor
            }

            Row {
                anchors.fill: parent
                Repeater {
                    model: 11
                    Item {
                        width: parent.width / 11
                        height: parent.height
                        Rectangle {
                            visible: index > 0
                            x: 0; y: 0; width: Math.max(1, Math.round(w.ui)); height: parent.height
                            color: "#55000000"
                        }
                    }
                }
            }
        }

        Item {
            visible: w.cfg.showSubtext !== false
            width: parent.width
            height: subTxt.implicitHeight

            Text {
                id: subTxt
                anchors.left: parent.left
                text: WidgetData.formatMinSec(w.lt) + " / " + WidgetData.formatMinSec(w.total)
                color: w.cDim
                font.family: w.effLoopFont
                font.pixelSize: Math.max(7, Math.round(10 * w.ui))
            }
            Text {
                anchors.right: parent.right
                text: w.warning ? "CRITICAL" : "NOMINAL"
                color: w.warning ? w.effWarnColor : w.accent
                opacity: 0.85
                font.family: w.effLoopFont
                font.bold: true
                font.pixelSize: Math.max(7, Math.round(9 * w.ui))
                font.letterSpacing: 1.5 * w.ui
            }
        }
    }
}
