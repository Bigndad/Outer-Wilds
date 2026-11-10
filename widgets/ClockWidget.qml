import QtQuick
import ".."

// SUN: big clock
WidgetCard {
    id: w
    title: "LOCAL TIME"
    designW: 300
    designH: 150

    readonly property var d: WidgetData.now

    Column {
        anchors.centerIn: parent
        spacing: 4 * w.ui

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hm.width + secs.width + 8 * w.ui
            height: hm.height

            Text {
                id: hm
                text: Qt.formatTime(w.d, "HH:mm")
                color: w.cCream
                font.family: "monospace"
                font.bold: true
                font.pixelSize: Math.max(10, Math.round(62 * w.ui))
            }
            Text {
                id: secs
                anchors.left: hm.right
                anchors.leftMargin: 8 * w.ui
                anchors.baseline: hm.baseline
                text: Qt.formatTime(w.d, "ss")
                color: w.cGold
                font.family: "monospace"
                font.pixelSize: Math.max(8, Math.round(24 * w.ui))
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(w.d, "dddd, d MMMM yyyy").toUpperCase()
            color: w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            font.letterSpacing: 1.5 * w.ui
        }
    }
}
