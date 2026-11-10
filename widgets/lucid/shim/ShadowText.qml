import QtQuick

// Text with a soft drop shadow, for the bare clock variants.
Text {
    id: t
    property real pixelSize: 16
    property int weight: 500
    property var rounded: false
    property bool shadow: true

    font.family: Theme.fontFamily
    font.pixelSize: Math.round(t.pixelSize)
    font.weight: t.weight

    Text {
        visible: t.shadow
        z: -1
        x: 0
        y: 1.5
        text: t.text
        color: "#99000000"
        font: t.font
        opacity: 0.6
    }
}
