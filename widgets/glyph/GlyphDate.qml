import QtQuick
import "../.."
import "."

// Date tile: month, day number in dots, weekday strip with today underlined.
GlyphCard {
    id: w
    designW: 220
    designH: 220
    readonly property var now: WidgetData.now
    readonly property bool sunFirst: cfg.sundayFirst === true
    readonly property int todayCol: sunFirst ? now.getDay() : ((now.getDay() + 6) % 7)
    readonly property color digCol: (cfg.dotColor && cfg.dotColor !== "") ? cfg.dotColor : GlyphTheme.fg
    readonly property color accCol: (cfg.accentColor && cfg.accentColor !== "") ? cfg.accentColor : GlyphTheme.red

    GlyphLabel { x: 24; y: 22; text: Qt.formatDate(w.now, "MMMM") }
    GlyphLabel { visible: w.cfg.showYear !== false; x: parent.width - 24 - implicitWidth; y: 22; text: Qt.formatDate(w.now, "yyyy") }
    GlyphDots {
        x: 24; y: 58
        text: String(w.now.getDate())
        cell: 13
        on: w.digCol
    }
    Row {
        visible: w.cfg.showWeekdays !== false
        x: 24; y: 168
        Repeater {
            model: w.sunFirst ? ["S", "M", "T", "W", "T", "F", "S"] : ["M", "T", "W", "T", "F", "S", "S"]
            Item {
                required property string modelData
                required property int index
                readonly property bool today: w.todayCol === index
                width: (w.designW - 48) / 7
                height: 30
                GlyphLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData
                    color: parent.today ? GlyphTheme.fg : GlyphTheme.mute
                }
                Rectangle {
                    visible: parent.today
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20; width: 6; height: 6; radius: 3
                    color: w.accCol
                }
            }
        }
    }
}
