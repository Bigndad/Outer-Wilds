import QtQuick
import ".."

// TIMBER HEARTH: workspaces (click to switch)
WidgetCard {
    id: w
    title: "WORKSPACES"
    designW: 300
    designH: 128

    Grid {
        anchors.centerIn: parent
        columns: 5
        spacing: 10 * w.ui

        Repeater {
            model: WidgetData.workspaces

            Rectangle {
                id: pill
                required property var modelData
                readonly property bool active: modelData.id === WidgetData.activeWorkspace
                readonly property bool occupied: modelData.windows > 0

                width: 40 * w.ui
                height: width
                radius: width / 2
                color: active ? w.cGold : (hover.containsMouse ? "#33D4AF37" : (occupied ? "#22E6D5B8" : "transparent"))
                border.width: Math.max(1, Math.round(w.ui * 1.5))
                border.color: active ? w.cGold : (occupied ? w.cCream : "#55D4AF37")

                Text {
                    anchors.centerIn: parent
                    text: pill.modelData.id
                    color: pill.active ? "#07080C" : (pill.occupied ? w.cCream : w.cDim)
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round(16 * w.ui))
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WidgetData.switchWorkspace(pill.modelData.id)
                }
            }
        }
    }
}
