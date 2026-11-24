import QtQuick
import ".."

// SUN: smaller system uptime
WidgetCard {
    id: w
    title: "SYSTEM UPTIME"
    designW: 236
    designH: 74

    property var cfg: ({ prefix: "", showSeconds: false, textSize: 24, textColor: "#E6D5B8", font: "monospace" })

    Text {
        anchors.centerIn: parent
        text: (w.cfg.prefix || "") + WidgetData.formatUptime(WidgetData.uptimeSeconds)
              + (w.cfg.showSeconds ? (":" + String(Math.floor(WidgetData.uptimeSeconds) % 60).padStart(2, "0")) : "")
        color: w.cfg.textColor || w.cCream
        font.family: w.cfg.font || "monospace"
        font.bold: true
        font.pixelSize: Math.max(9, Math.round((w.cfg.textSize || 24) * w.ui))
    }
}
