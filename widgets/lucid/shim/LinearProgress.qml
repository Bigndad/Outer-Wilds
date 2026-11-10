import QtQuick

// wavy / amplitude / wavelength / flowing are accepted but drawn as a plain bar.
Item {
    id: p
    property real value: 0
    property real thickness: 6
    property color color: Theme.accent
    property color trackColor: Theme.alpha(Theme.text, 0.12)
    property bool wavy: false
    property real amplitude: 0
    property real wavelength: 0
    property bool flowing: false
    property bool valueAnimated: false

    implicitHeight: thickness
    height: thickness

    Rectangle { anchors.fill: parent; radius: height / 2; color: p.trackColor }
    Rectangle {
        width: Math.max(p.thickness, parent.width * Math.max(0, Math.min(1, p.value)))
        height: parent.height
        radius: height / 2
        color: p.color
        visible: p.value > 0
        Behavior on width { enabled: p.valueAnimated; NumberAnimation { duration: Theme.durShort } }
    }
}
