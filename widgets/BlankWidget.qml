import QtQuick
import ".."

// Placeholder for planets whose role is not decided yet. Give it a name from the registry:
//   { id: "gd_a", host: "giants_deep", source: "BlankWidget.qml", title: "GIANT'S DEEP A", ... }
// Later, point `source` at the real widget file and delete this entry's title.
WidgetCard {
    id: w
    title: "UNASSIGNED"
    designW: 240
    designH: 110

    Text {
        anchors.centerIn: parent
        text: "NO ROLE ASSIGNED"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(7, Math.round(12 * w.ui))
        font.letterSpacing: 1.5 * w.ui
    }
}
