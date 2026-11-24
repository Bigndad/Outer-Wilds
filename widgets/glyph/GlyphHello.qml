import QtQuick
import "../.."
import "."

// Greeting tile: time-based or custom greeting, date, and unread rumors.
GlyphCard {
    id: w
    designW: 300
    designH: 150
    readonly property var now: WidgetData.now
    readonly property int h: now.getHours()
    readonly property string autoHello: (h < 5 ? "good night" : h < 12 ? "good morning" : h < 18 ? "good afternoon" : "good evening") + "."
    readonly property string hello: (cfg.customGreeting && cfg.customGreeting !== "") ? cfg.customGreeting : autoHello
    readonly property color accCol: (cfg.accentColor && cfg.accentColor !== "") ? cfg.accentColor : GlyphTheme.red

    GlyphLabel { visible: w.cfg.showDate !== false; x: 26; y: 24; text: Qt.formatDate(w.now, "dddd \u00B7 d MMMM") }
    Text {
        x: 26; y: w.cfg.showDate !== false ? 52 : 42
        width: w.designW - 52
        elide: Text.ElideRight
        text: w.hello
        color: GlyphTheme.fg
        font.pixelSize: 34
        font.weight: Font.Light
    }
    Row {
        visible: w.cfg.showUnread !== false
        x: 26; y: 112
        spacing: 8
        Rectangle {
            width: 8; height: 8; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: RumorData.unreadCount > 0 ? w.accCol : GlyphTheme.s3
        }
        GlyphLabel { text: RumorData.unreadCount + " unread" }
    }
}
