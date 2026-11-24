import QtQuick
import "../shim"
import QtQuick.Effects

Item {
    id: root
    anchors.fill: parent
    clip: true

    property bool previewMode: false

    property real minWidth: 60
    property real minHeight: 30
    property real maxWidth: 2000
    property real maxHeight: 800
    property real minAspect: 0.2
    property real maxAspect: 20.0
    property bool isRound: false

    property string textContent: ""
    property string fontFamily: ""
    property string textHex: ""
    property bool showShadow: true
    property string align: "center"

    readonly property string fontPath: root.fontFamily !== "" && ThemeBackend.availableFontPaths ? (ThemeBackend.availableFontPaths[root.fontFamily.toLowerCase()] || "") : ""

    readonly property bool isEmpty: root.textContent.trim() === ""

    FontLoader {
        source: root.fontPath !== "" ? ("file://" + root.fontPath) : ""
    }

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: root.isEmpty ? "Enter text" : root.textContent
        font.family: root.fontFamily !== "" ? root.fontFamily : ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        font.weight: Font.Bold
        color: root.textHex !== "" ? root.textHex : ThemeBackend.text
        opacity: root.isEmpty ? 0.4 : 1.0
        wrapMode: Text.WordWrap
        horizontalAlignment: root.align === "left" ? Text.AlignLeft : (root.align === "right" ? Text.AlignRight : Text.AlignHCenter)
        verticalAlignment: Text.AlignVCenter

        layer.enabled: root.showShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }
    }
}
