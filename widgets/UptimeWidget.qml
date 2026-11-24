import QtQuick
import ".."

// SUN: smaller system uptime
WidgetCard {
    id: w
    title: "SYSTEM UPTIME"
    designW: 244
    designH: 82

    property var cfg: ({ prefix: "", showSeconds: false, textSize: 22, textColor: "#E6D5B8", font: "monospace" })
    readonly property color effTextColor: (cfg.textColor && cfg.textColor.toUpperCase() !== "#E6D5B8") ? cfg.textColor : w.cCream
    readonly property string effUpFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont

    Row {
        anchors.centerIn: parent
        spacing: 10 * w.ui

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: badgeRow.implicitWidth + 10 * w.ui
            height: badgeRow.implicitHeight + 6 * w.ui
            radius: 4 * w.ui
            color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.14)
            border.width: Math.max(1, Math.round(w.ui))
            border.color: Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.34)

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 4 * w.ui
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(4, Math.round(5 * w.ui)); height: width; radius: width / 2
                    color: w.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "UP"
                    color: w.accent
                    font.family: w.effUpFont
                    font.bold: true
                    font.pixelSize: Math.max(7, Math.round(9 * w.ui))
                    font.letterSpacing: 1.2 * w.ui
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (w.cfg.prefix || "") + WidgetData.formatUptime(WidgetData.uptimeSeconds)
                  + (w.cfg.showSeconds ? (":" + String(Math.floor(WidgetData.uptimeSeconds) % 60).padStart(2, "0")) : "")
            color: w.effTextColor
            font.family: w.effUpFont
            font.bold: true
            font.pixelSize: Math.max(9, Math.round((w.cfg.textSize || 22) * w.ui))
        }
    }
}
