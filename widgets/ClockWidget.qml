import QtQuick
import ".."

// SUN: big clock
WidgetCard {
    id: w
    title: "LOCAL TIME"
    designW: 300
    designH: 158

    readonly property var d: WidgetData.now

    property var cfg: ({ hour24: true, showSeconds: true, showDate: true, dateFormat: "dddd, d MMMM yyyy",
                         timeColor: "#E6D5B8", secondsColor: "#D4AF37", font: "monospace" })

    readonly property color effTimeColor: (cfg.timeColor && cfg.timeColor.toUpperCase() !== "#E6D5B8") ? cfg.timeColor : w.cCream
    readonly property color effSecColor: (cfg.secondsColor && cfg.secondsColor.toUpperCase() !== "#D4AF37") ? cfg.secondsColor : w.accent
    readonly property string effClockFont: (cfg.font && cfg.font !== "monospace") ? cfg.font : w.effFont

    Column {
        anchors.centerIn: parent
        width: w.innerW
        spacing: 6 * w.ui

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(w.innerW, Math.min(hm.width, hm.contentWidth) + (secPill.visible ? secPill.width + 8 * w.ui : 0))
            height: hm.height

            CardText {
                id: hm
                ui: w.ui; px: 56; bold: true
                maxW: w.innerW - (secPill.visible ? secPill.width + 8 * w.ui : 0)
                text: Qt.formatTime(w.d, w.cfg.hour24 ? "HH:mm" : "h:mm AP")
                color: w.effTimeColor
                font.family: w.effClockFont
            }

            Rectangle {
                id: secPill
                visible: w.cfg.showSeconds
                anchors.left: hm.left
                anchors.leftMargin: Math.min(hm.width, hm.contentWidth) + 8 * w.ui
                anchors.bottom: hm.bottom
                anchors.bottomMargin: 8 * w.ui
                width: secs.implicitWidth + 10 * w.ui
                height: secs.implicitHeight + 4 * w.ui
                radius: 4 * w.ui
                color: Qt.rgba(w.effSecColor.r, w.effSecColor.g, w.effSecColor.b, 0.14)
                border.width: Math.max(1, Math.round(w.ui))
                border.color: Qt.rgba(w.effSecColor.r, w.effSecColor.g, w.effSecColor.b, 0.35)

                CardText {
                    id: secs
                    anchors.centerIn: parent
                    ui: w.ui; px: 19; bold: true
                    text: Qt.formatTime(w.d, "ss")
                    color: w.effSecColor
                    font.family: w.effClockFont
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: w.cfg.showSeconds
            spacing: 4 * w.ui
            Repeater {
                model: 12
                Rectangle {
                    readonly property int curIdx: Math.floor(w.d.getSeconds() / 5)
                    readonly property bool lit: curIdx >= index
                    readonly property bool head: curIdx === index
                    width: Math.max(4, Math.round(12 * w.ui))
                    height: Math.max(2, Math.round(3 * w.ui))
                    radius: height / 2
                    color: head ? w.effTimeColor : (lit ? w.effSecColor : Qt.rgba(w.cCream.r, w.cCream.g, w.cCream.b, 0.14))
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: w.cfg.showDate
            width: Math.min(w.innerW, dateTxt.implicitWidth + 14 * w.ui)
            height: dateTxt.implicitHeight + 5 * w.ui
            radius: 4 * w.ui
            color: "#18000000"
            border.width: Math.max(1, Math.round(w.ui))
            border.color: Qt.rgba(w.cDim.r, w.cDim.g, w.cDim.b, 0.2)

            CardText {
                id: dateTxt
                anchors.centerIn: parent
                ui: w.ui; px: 10; tracking: 1.5
                maxW: w.innerW - 14 * w.ui
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(w.d, w.cfg.dateFormat).toUpperCase()
                color: w.cDim
                font.family: w.effClockFont
            }
        }
    }
}
