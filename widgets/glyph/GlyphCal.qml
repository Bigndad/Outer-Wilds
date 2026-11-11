import QtQuick
import "../.."
import "."

// Month calendar, Monday first. Today = the one red dot. Arrows change month, click the title to come back.
GlyphCard {
    id: w
    designW: 320
    designH: 340

    readonly property var now: WidgetData.now
    property int offset: 0
    readonly property var first: new Date(now.getFullYear(), now.getMonth() + offset, 1)
    readonly property int lead: (first.getDay() + 6) % 7
    readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
    readonly property bool thisMonth: first.getFullYear() === now.getFullYear() && first.getMonth() === now.getMonth()

    // header
    Text {
        id: prev
        x: 20; y: 14; width: 30; height: 30
        text: "\u2039"; color: GlyphTheme.grey
        font.pixelSize: 24; font.family: GlyphTheme.mono
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        MouseArea { anchors.fill: parent; onClicked: w.offset-- }
    }
    Text {
        id: next
        x: parent.width - 50; y: 14; width: 30; height: 30
        text: "\u203A"; color: GlyphTheme.grey
        font.pixelSize: 24; font.family: GlyphTheme.mono
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        MouseArea { anchors.fill: parent; onClicked: w.offset++ }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        spacing: 3
        GlyphLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(w.first, "MMMM")
            color: GlyphTheme.fg
            font.pixelSize: 13
        }
        GlyphLabel { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(w.first, "yyyy") }
    }
    MouseArea {
        x: 60; y: 10; width: parent.width - 120; height: 38
        onClicked: w.offset = 0
    }

    // weekday row
    Row {
        x: 16; y: 60
        Repeater {
            model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
            GlyphLabel {
                required property string modelData
                required property int index
                width: 40
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: w.thisMonth && (w.now.getDay() + 6) % 7 === index ? GlyphTheme.fg : GlyphTheme.mute
            }
        }
    }
    Rectangle { x: 20; y: 80; width: parent.width - 40; height: 1; color: GlyphTheme.s2 }

    // day grid, 7 x 6
    Repeater {
        model: 42
        Item {
            required property int index
            readonly property int day: index - w.lead + 1
            readonly property bool inMonth: day >= 1 && day <= w.days
            readonly property bool today: inMonth && w.thisMonth && day === w.now.getDate()
            x: 16 + (index % 7) * 40
            y: 92 + Math.floor(index / 7) * 40
            width: 40
            height: 40
            visible: inMonth
            Rectangle {
                anchors.centerIn: parent
                width: 30; height: 30; radius: 15
                color: parent.today ? GlyphTheme.red : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: parent.day
                color: parent.today ? GlyphTheme.fg : (index % 7 >= 5 ? GlyphTheme.grey : GlyphTheme.fg)
                font.family: GlyphTheme.mono
                font.pixelSize: 14
                font.bold: parent.today
            }
        }
    }
}
