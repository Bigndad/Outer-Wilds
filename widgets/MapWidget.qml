import QtQuick
import ".."

// Small map: the whole system as a strip of planets (same positions / colours as the Map View). Click it to open the big Map View.
// Everything it shows comes from MapData (catalog, selected planet, toggle key).
WidgetCard {
    id: w
    title: "MAP"
    designW: 250
    designH: 132

    readonly property real unit: 22 * w.ui           // px per map column
    readonly property real x0: 1.25                  // the Sun's left edge, so the strip starts at x = 0
    readonly property bool hot: ma.containsMouse

    Item {
        id: strip
        width: parent.width
        height: Math.round(50 * w.ui)

        Rectangle {             // faint axis through the planets
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
                Rectangle {     // selection ring
                    visible: node.sel
                    anchors.centerIn: parent
                    width: node.dpx + Math.round(8 * w.ui)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1, Math.round(1.5 * w.ui))
                    border.color: w.cGold
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
            width: parent.width
            elide: Text.ElideRight
            text: MapData.nameOf(MapData.selectedId).toUpperCase()
            color: w.cCream
            font.family: "monospace"
            font.pixelSize: Math.max(8, Math.round(10 * w.ui))
            font.letterSpacing: 2 * w.ui
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: "OPEN MAP  [" + MapData.toggleKey + "]"
            color: w.hot ? w.cGold : w.cDim
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
