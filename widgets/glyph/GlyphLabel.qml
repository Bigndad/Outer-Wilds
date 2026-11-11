import QtQuick
import "."

// small spaced mono caption, like the labels on the Nothing widgets
Text {
    textFormat: Text.PlainText
    color: GlyphTheme.grey
    font.family: GlyphTheme.mono
    font.pixelSize: 11
    font.letterSpacing: 1.6
    font.capitalization: Font.AllUppercase
}
