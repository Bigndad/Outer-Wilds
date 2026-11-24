import QtQuick
import "../.."
import "."

// cpu / ram / gpu temp / vram as dot numbers, plus CPU history dot grid.
GlyphCard {
    id: w
    designW: 440
    designH: 190

    readonly property int pollSec: Math.max(1, Math.round(cfg.pollSec || 2))
    readonly property color dotCol: (cfg.dotColor && cfg.dotColor !== "") ? cfg.dotColor : GlyphTheme.fg
    readonly property real gpuTempVal: cfg.tempUnit === "F" ? (Sensors.gpuTempC * 9 / 5 + 32) : Sensors.gpuTempC

    property var hist: new Array(34).fill(0)
    Timer {
        interval: w.pollSec * 1000
        running: w.visible && w.cfg.showGraph !== false
        repeat: true
        onTriggered: {
            const h = w.hist.slice(1);
            h.push(Sensors.cpuPercent / 100);
            w.hist = h;
        }
    }

    component Stat: Column {
        property string label
        property string value
        spacing: 8
        GlyphLabel { text: parent.label }
        GlyphDots { text: parent.value; cell: 4.5; on: w.dotCol }
    }

    Grid {
        x: 26
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        columnSpacing: 22
        rowSpacing: 22
        Stat { label: "cpu";  value: Sensors.cpuPercent + "%" }
        Stat { label: "ram gb"; value: Sensors.ramUsedGb.toFixed(1) }
        Stat { label: "gpu temp"; value: Math.round(w.gpuTempVal) + "\u00B0" }
        Stat { label: "vram";  value: Sensors.vramPercent + "%" }
    }

    Column {
        visible: w.cfg.showGraph !== false
        x: 250
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        GlyphLabel { text: "cpu \u00B7 " + (34 * w.pollSec) + " s" }
        Item {
            width: 34 * 5
            height: 8 * 5
            Repeater {
                model: 34
                Item {
                    id: sc
                    required property int index
                    readonly property int h: Math.round(1 + 6 * (w.hist[index] ?? 0))
                    x: index * 5
                    width: 5
                    height: 8 * 5
                    Repeater {
                        model: 8
                        Rectangle {
                            required property int index
                            readonly property int up: 8 - index
                            width: 3.6
                            height: 3.6
                            radius: 1.8
                            x: 0.7
                            y: index * 5 + 0.7
                            color: up === sc.h ? w.dotCol : up < sc.h ? GlyphTheme.grey : GlyphTheme.s2
                        }
                    }
                }
            }
        }
    }
}
