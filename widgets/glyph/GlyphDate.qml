import QtQuick
import "../.."
import "."

// Date tile: month, the day number in dots, weekday strip with today underlined (red dot).
GlyphCard {
    id: w
    designW: 220
    designH: 220
    readonly property var now: WidgetData.now

    GlyphLabel { x: 24; y: 22; text: Qt.formatDate(w.now, "MMMM") }
    GlyphLabel { x: parent.width - 24 - implicitWidth; y: 22; text: Qt.formatDate(w.now, "yyyy") }
    GlyphDots {
        x: 24; y: 58
        text: String(w.now.getDate())
        cell: 13
    }
    Row {
        x: 24; y: 168
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            Item {
                required property string modelData
                required property int index
                readonly property bool today: (w.now.getDay() + 6) % 7 === index
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
                    color: GlyphTheme.red
                }
            }
        }
    }
}
