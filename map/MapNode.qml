import QtQuick
import ".."

// One planet on the Map View grid. Placeholder art only: a flat disc (or a PNG once map_icons/ is filled).
// An outline circle replaces the disc while the planet has no live data, and cross-fades to the disc when data arrives.
// The real shaded planets in the rig are NOT touched or reused here.
Item {
    id: node

    property var info: null             // MapData.catalog entry
    property real px: 40                // drawn diameter
    property real bu: 1.0
    property bool selected: false
    property bool hovered: false
    property bool live: false
    property real zoom: 1.0             // 1 = close view, 0 = overview (labels of every planet show when zoomed out)
    property url iconUrl: ""            // "" = placeholder disc
    property bool labelAbove: false     // planets that have a moon keep their name above, so it does not run into the moon

    signal clicked()
    signal doubleClicked()
    signal hoverChanged(bool over)

    readonly property color cCream: "#E6D5B8"
    readonly property color cGold: "#D4AF37"
    readonly property real hitSize: Math.max(px, 28 * bu)

    width: hitSize
    height: hitSize

    Item {
        id: art
        anchors.centerIn: parent
        width: node.px
        height: node.px

        // glow ring, like the soft halo around each planet in the game's map
        Rectangle {
            anchors.centerIn: parent
            width: art.width + Math.max(6, art.width * 0.08)
            height: width
            radius: width / 2
            color: "transparent"
            border.color: node.info ? node.info.ring : node.cCream
            border.width: Math.max(2, 2.5 * node.bu)
            opacity: node.live ? (node.selected || node.hovered ? 0.85 : 0.45) : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        // placeholder disc: base, a lighter spot for volume, a rim
        Item {
            anchors.fill: parent
            opacity: node.live && img.status !== Image.Ready ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 600 } }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: node.info ? node.info.fill : "#555"
            }
            Rectangle {
                width: parent.width * 0.62
                height: width
                radius: width / 2
                x: parent.width * 0.5 - width * 0.5 - parent.width * 0.12
                y: parent.height * 0.5 - height * 0.5 - parent.height * 0.12
                color: node.info ? Qt.lighter(node.info.fill, 1.6) : "#888"
                opacity: 0.35
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: node.info ? node.info.ring : node.cCream
                border.width: Math.max(1.5, art.width * 0.025)
                opacity: 0.8
            }
        }

        Image {
            id: img
            anchors.fill: parent
            source: node.iconUrl
            asynchronous: true
            smooth: true
            mipmap: true
            fillMode: Image.PreserveAspectFit
            opacity: node.live ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 600 } }
        }

        // unexplored: outline only
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: node.cCream
            border.width: Math.max(1.5, 2 * node.bu)
            opacity: node.live ? 0 : (node.selected || node.hovered ? 1 : 0.8)
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: node.labelAbove ? parent.height / 2 - node.px / 2 - height - 6 * node.bu : parent.height / 2 + node.px / 2 + 6 * node.bu
        text: node.info ? node.info.name : ""
        color: node.selected ? node.cGold : node.cCream
        font.family: "monospace"
        font.pixelSize: Math.max(9, Math.round(13 * node.bu))
        font.letterSpacing: 1.5 * node.bu
        opacity: node.hovered ? 1 : (node.selected ? 0 : (1 - node.zoom) * 0.7)
        visible: opacity > 0.02 && node.info && node.info.id !== "sun"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: node.hoverChanged(true)
        onExited: node.hoverChanged(false)
        onClicked: node.clicked()
        onDoubleClicked: node.doubleClicked()
    }
}
