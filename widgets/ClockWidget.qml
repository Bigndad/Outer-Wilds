import QtQuick
import ".."

// SUN: big clock
WidgetCard {
    id: w
    title: "LOCAL TIME"
    designW: 300
    designH: 150

    readonly property var d: WidgetData.now

    // Options: the schema lives in WidgetConfig.builtinCatalog (the "Clock" entry, `settings: [...]`); a drop-in widget puts
    // the same array in its widget.json. The slot replaces this object with the live values (defaults + the user's edits).
    // The values below are only what shows for the instant before that happens: keep them equal to the schema defaults.
    property var cfg: ({ hour24: true, showSeconds: true, showDate: true, dateFormat: "dddd, d MMMM yyyy",
                         timeColor: "#E6D5B8", secondsColor: "#D4AF37", font: "monospace" })

    Column {
        anchors.centerIn: parent
        spacing: 4 * w.ui

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hm.width + (secs.visible ? secs.width + 8 * w.ui : 0)
            height: hm.height

            Text {
                id: hm
                text: Qt.formatTime(w.d, w.cfg.hour24 ? "HH:mm" : "h:mm AP")
                color: w.cfg.timeColor
                font.family: w.cfg.font
                font.bold: true
                font.pixelSize: Math.max(10, Math.round(62 * w.ui))
            }
            Text {
                id: secs
                anchors.left: hm.right
                anchors.leftMargin: 8 * w.ui
                anchors.baseline: hm.baseline
                visible: w.cfg.showSeconds
                text: Qt.formatTime(w.d, "ss")
                color: w.cfg.secondsColor
                font.family: w.cfg.font
                font.pixelSize: Math.max(8, Math.round(24 * w.ui))
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: w.cfg.showDate
            text: Qt.formatDate(w.d, w.cfg.dateFormat).toUpperCase()
            color: w.cDim
            font.family: w.cfg.font
            font.pixelSize: Math.max(7, Math.round(12 * w.ui))
            font.letterSpacing: 1.5 * w.ui
        }
    }
}
