import QtQuick
import ".."

// SUN: smaller system uptime
WidgetCard {
    id: w
    title: "SYSTEM UPTIME"
    designW: 236
    designH: 74

    Text {
        anchors.centerIn: parent
        text: WidgetData.formatUptime(WidgetData.uptimeSeconds)
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.max(9, Math.round(24 * w.ui))
    }
}
