import QtQuick
import ".."

// Small map: the whole system as a strip of planets. Click it to open the big Map View.
WidgetCard {
    id: w
    title: "MAP"
    designW: 250
    designH: 132

    property var cfg: ({ showAxis: true, showSelectionRing: true, showPlanetName: true,
                         showKeyHint: true, ringColor: "#D4AF37" })

    readonly property real unit: 22 * w.ui
    readonly property real x0: 1.25
    readonly property bool hot: ma.containsMouse

    Item {
        id: strip
        width: parent.width
        height: Math.round(50 * w.ui)

        Rectangle {
            visible: w.cfg.showAxis !== false
            y: Math.round(24 * w.ui)
            width: parent.width
            height: Math.max(1, Math.round(w.ui))
            color: "#22E6D5B8"
        }

        Repeater {
            model: MapData.catalog
            Item {
                id: node
                required property var modelData
                readonly property real dpx: Math.max(Math.round(4 * w.ui), modelData.d * w.unit)
                readonly property bool sel: MapData.selectedId === modelData.id
                width: dpx; height: dpx
                x: Math.round((modelData.x + w.x0) * w.unit - dpx / 2)
                y: Math.round(24 * w.ui + modelData.y * w.unit - dpx / 2)

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: node.modelData.fill
                    border.width: Math.max(1, Math.round(w.ui))
                    border.color: node.modelData.ring
                }
                Rectangle {
                    visible: node.sel && w.cfg.showSelectionRing !== false
                    anchors.centerIn: parent
                    width: node.dpx + Math.round(8 * w.ui)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, Math.round(1.5 * w.ui))
                    border.color: w.cfg.ringColor || w.cGold
                }
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: Math.round(2 * w.ui)
        Text {
            visible: w.cfg.showPlanetName !== false
            width: parent.width
            elide: Text.ElideRight
            text: MapData.nameOf(MapData.selectedId).toUpperCase()
            color: w.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * w.ui))
            font.letterSpacing: 2 * w.ui
        }
        Text {
            visible: w.cfg.showKeyHint !== false
            width: parent.width
            elide: Text.ElideRight
            text: "OPEN MAP  [" + MapData.toggleKey + "]"
            color: w.hot ? (w.cfg.ringColor || w.cGold) : w.cDim
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(9 * w.ui))
            font.letterSpacing: 1 * w.ui
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: MapData.show()
    }
}
