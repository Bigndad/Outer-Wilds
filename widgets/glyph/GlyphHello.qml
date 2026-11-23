import QtQuick
import "../.."
import "."

// Greeting tile: "good evening." by the hour, the date, and how many ship-log notifications are unread.
GlyphCard {
    id: w
    designW: 300
    designH: 150
    readonly property var now: WidgetData.now
    readonly property int h: now.getHours()
    readonly property string hello: h < 5 ? "good night" : h < 12 ? "good morning" : h < 18 ? "good afternoon" : "good evening"

    GlyphLabel { x: 26; y: 24; text: Qt.formatDate(w.now, "dddd \u00B7 d MMMM") }
    Text {
        x: 26; y: 52
        text: w.hello + "."
        color: GlyphTheme.fg
        font.pixelSize: 34
        font.weight: Font.Light
    }
    Row {
        x: 26; y: 112
        spacing: 8
        Rectangle {
            width: 8; height: 8; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: RumorData.unreadCount > 0 ? GlyphTheme.red : GlyphTheme.s3
        }
        GlyphLabel { text: RumorData.unreadCount + " unread" }
    }
}
