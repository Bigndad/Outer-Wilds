import QtQuick
import ".."

// Placeholder / custom text label card.
WidgetCard {
    id: w
    title: "UNASSIGNED"
    designW: 240
    designH: 110

    property var cfg: ({ label: "NO ROLE ASSIGNED", sublabel: "", textSize: 12,
                         align: "center", textColor: "#8A7F66", font: "monospace" })

    readonly property int hAlign: cfg.align === "left" ? Text.AlignLeft : (cfg.align === "right" ? Text.AlignRight : Text.AlignHCenter)

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * w.ui

        Text {
            width: parent.width
            horizontalAlignment: w.hAlign
            wrapMode: Text.Wrap
            text: w.cfg.label !== undefined ? w.cfg.label : "NO ROLE ASSIGNED"
            color: w.cfg.textColor || w.cDim
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(7, Math.round((w.cfg.textSize || 12) * w.ui))
            font.letterSpacing: 1.5 * w.ui
        }
        Text {
            visible: (w.cfg.sublabel || "") !== ""
            width: parent.width
            horizontalAlignment: w.hAlign
            wrapMode: Text.Wrap
            text: w.cfg.sublabel || ""
            color: w.cDim
            font.family: w.cfg.font || "monospace"
            font.pixelSize: Math.max(7, Math.round(10 * w.ui))
        }
    }
}
