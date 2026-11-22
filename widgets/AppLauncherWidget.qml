import QtQuick
import ".."

// Small app launcher: a grid of app tiles. Click it to open the big launcher (LauncherWindow). The tiles come from MapData.apps
// (the same list the Map View uses); with no list yet they show as empty slots.
WidgetCard {
    id: w
    title: "APPS"
    designW: 250
    designH: 132

    readonly property bool hot: ma.containsMouse
    readonly property int cols: 6
    readonly property int shown: 12

    Grid {
        id: grid
        columns: w.cols
        spacing: Math.round(6 * w.ui)
        readonly property real tile: Math.floor((parent.width - (w.cols - 1) * spacing) / w.cols)

        Repeater {
            model: w.shown
            Rectangle {
                id: tile
                required property int index
                readonly property var app: index < MapData.apps.length ? MapData.apps[index] : null
                width: grid.tile; height: Math.round(grid.tile * 0.78)
                radius: Math.round(3 * w.ui)
                color: app ? "#26E6D5B8" : "transparent"
                border.width: Math.max(1, Math.round(w.ui))
                border.color: w.hot ? "#88D4AF37" : "#33D4AF37"
                Text {
                    anchors.centerIn: parent
                    visible: tile.app !== null
                    text: tile.app ? MapData.initials(tile.app.name) : ""
                    color: w.hot ? w.cGold : w.cCream
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round(11 * w.ui))
                }
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        elide: Text.ElideRight
        text: "OPEN LAUNCHER  " + (Keybinds.seq("launcher") !== "" ? "[" + Keybinds.pretty(Keybinds.seq("launcher")) + "]" : "▸")
        color: w.hot ? w.cGold : w.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(8, Math.round(10 * w.ui))
        font.letterSpacing: 2 * w.ui
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: WidgetConfig.launcherRequested()
    }
}
