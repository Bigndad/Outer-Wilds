import QtQuick

// Simple drawn weather glyph: sun/moon disc, cloud of circles, rain/snow dots.
Item {
    id: wi
    property string kind: "clear"
    property real size: 48
    property color tint: Theme.accent
    property color cloudColor: Theme.text
    property bool animate: false

    width: size
    height: size

    readonly property bool hasSun: kind === "clear" || kind === "partly"
    readonly property bool hasMoon: kind === "clear-night" || kind === "partly-night"
    readonly property bool hasCloud: kind !== "clear" && kind !== "clear-night"
    readonly property bool wet: kind === "rain" || kind === "drizzle" || kind === "storm"
    readonly property bool snowy: kind === "snow"

    MaterialShape {
        visible: wi.hasSun
        width: wi.size * (wi.hasCloud ? 0.52 : 0.78)
        height: width
        x: wi.hasCloud ? wi.size * 0.04 : (wi.size - width) / 2
        y: wi.hasCloud ? wi.size * 0.02 : (wi.size - height) / 2
        shape: "cookie12"
        color: wi.tint
        RotationAnimation on rotation { from: 0; to: 360; duration: 24000; loops: Animation.Infinite; running: wi.animate && wi.hasSun }
    }
    Rectangle {
        visible: wi.hasMoon
        width: wi.size * (wi.hasCloud ? 0.46 : 0.62)
        height: width
        radius: width / 2
        x: wi.hasCloud ? wi.size * 0.06 : (wi.size - width) / 2
        y: wi.hasCloud ? wi.size * 0.04 : (wi.size - height) / 2
        color: wi.tint
        Rectangle { width: parent.width * 0.78; height: width; radius: width / 2; x: parent.width * 0.3; y: -parent.width * 0.06; color: Theme.bg }
    }
    Item {
        visible: wi.hasCloud
        width: wi.size
        height: wi.size * 0.6
        y: wi.size * (wi.hasSun || wi.hasMoon ? 0.34 : 0.2)
        Rectangle { x: wi.size * 0.06; y: wi.size * 0.2; width: wi.size * 0.88; height: wi.size * 0.3; radius: height / 2; color: wi.cloudColor }
        Rectangle { x: wi.size * 0.2; y: wi.size * 0.06; width: wi.size * 0.34; height: width; radius: width / 2; color: wi.cloudColor }
        Rectangle { x: wi.size * 0.44; y: 0; width: wi.size * 0.42; height: width; radius: width / 2; color: wi.cloudColor }
    }
    Repeater {
        model: wi.wet || wi.snowy ? 3 : 0
        Rectangle {
            required property int index
            x: wi.size * (0.26 + index * 0.22)
            y: wi.size * 0.78
            width: wi.snowy ? wi.size * 0.07 : wi.size * 0.05
            height: wi.snowy ? width : wi.size * 0.14
            radius: width / 2
            color: wi.tint
        }
    }
    Repeater {
        model: wi.kind === "fog" ? 3 : 0
        Rectangle {
            required property int index
            x: wi.size * (0.12 + index * 0.04)
            y: wi.size * (0.7 + index * 0.1)
            width: wi.size * (0.76 - index * 0.08)
            height: wi.size * 0.05
            radius: height / 2
            color: Qt.rgba(wi.cloudColor.r, wi.cloudColor.g, wi.cloudColor.b, 0.6)
        }
    }
}
