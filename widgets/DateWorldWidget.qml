import QtQuick
import ".."

// SUN: calendar bits + world clocks
WidgetCard {
    id: w
    title: "CALENDAR / WORLD"
    designW: 276
    designH: 132

    property var cfg: ({ showWeek: true, showDayOfYear: true, showMonth: true, showWorldClocks: true,
                         customZones: "", accentColor: "#D4AF37", font: "monospace" })

    function resolvedZones() {
        const s = (cfg.customZones || "").trim();
        if (!s) return WidgetData.worldZones;
        const out = [], parts = s.split(",");
        for (let i = 0; i < parts.length; i++) {
            const kv = parts[i].split(":");
            if (kv.length < 2) continue;
            const off = parseInt(kv[1].trim(), 10);
            if (isFinite(off)) out.push({ label: kv[0].trim().toUpperCase(), offsetMin: off });
        }
        return out.length > 0 ? out : WidgetData.worldZones;
    }

    Row {
        anchors.fill: parent
        spacing: 16 * w.ui

        Column {
            visible: w.cfg.showWeek !== false || w.cfg.showDayOfYear !== false || w.cfg.showMonth !== false
            spacing: 4 * w.ui
            Text {
                visible: w.cfg.showWeek !== false
                text: "WEEK " + WidgetData.isoWeek()
                color: w.cCream
                font.family: w.cfg.font || "monospace"
                font.bold: true
                font.pixelSize: Math.max(8, Math.round(17 * w.ui))
            }
            Text {
                visible: w.cfg.showDayOfYear !== false
                text: "DAY " + WidgetData.dayOfYear() + " / 365"
                color: w.cDim
                font.family: w.cfg.font || "monospace"
                font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            }
            Text {
                visible: w.cfg.showMonth !== false
                text: Qt.formatDate(WidgetData.now, "MMM yyyy").toUpperCase()
                color: w.cfg.accentColor || w.cGold
                font.family: w.cfg.font || "monospace"
                font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            }
        }

        Column {
            visible: w.cfg.showWorldClocks !== false
            spacing: 4 * w.ui
            Repeater {
                model: w.resolvedZones()
                Row {
                    required property var modelData
                    spacing: 10 * w.ui
                    Text {
                        width: 56 * w.ui
                        elide: Text.ElideRight
                        text: modelData.label
                        color: w.cDim
                        font.family: w.cfg.font || "monospace"
                        font.pixelSize: Math.max(7, Math.round(12 * w.ui))
                    }
                    Text {
                        text: { WidgetData.now; return WidgetData.zoneTime(modelData.offsetMin); }
                        color: w.cCream
                        font.family: w.cfg.font || "monospace"
                        font.bold: true
                        font.pixelSize: Math.max(8, Math.round(14 * w.ui))
                    }
                }
            }
        }
    }
}
