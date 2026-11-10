import QtQuick
import ".."

// SUN: calendar bits + world clocks
WidgetCard {
    id: w
    title: "CALENDAR / WORLD"
    designW: 276
    designH: 132

    Row {
        anchors.fill: parent
        spacing: 16 * w.ui

        Column {
            spacing: 4 * w.ui
            Text {
                text: "WEEK " + WidgetData.isoWeek()
                color: w.cCream
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(8, Math.round(17 * w.ui))
            }
            Text {
                text: "DAY " + WidgetData.dayOfYear() + " / 365"
                color: w.cDim
                font.family: "monospace"
                font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            }
            Text {
                text: Qt.formatDate(WidgetData.now, "MMM yyyy").toUpperCase()
                color: w.cGold
                font.family: "monospace"
                font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            }
        }

        Column {
            spacing: 4 * w.ui
            Repeater {
                model: WidgetData.worldZones
                Row {
                    required property var modelData
                    spacing: 10 * w.ui
                    Text {
                        width: 56 * w.ui
                        text: modelData.label
                        color: w.cDim
                        font.family: "monospace"
                        font.pixelSize: Math.max(7, Math.round(12 * w.ui))
                    }
                    Text {
                        text: { WidgetData.now; return WidgetData.zoneTime(modelData.offsetMin); }
                        color: w.cCream
                        font.family: "monospace"
                        font.bold: true
                        font.pixelSize: Math.max(8, Math.round(14 * w.ui))
                    }
                }
            }
        }
    }
}
