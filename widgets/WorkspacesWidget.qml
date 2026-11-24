import QtQuick
import ".."

// TIMBER HEARTH: workspaces (click to switch)
WidgetCard {
    id: w
    title: "WORKSPACES"
    designW: 300
    designH: 128

    property var cfg: ({ columns: 5, shape: "circle", pillSize: 40, hideEmpty: false,
                         activeColor: "#D4AF37", occupiedColor: "#E6D5B8" })

    function visibleWorkspaces() {
        const list = WidgetData.workspaces || [];
        if (!w.cfg.hideEmpty) return list;
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (list[i].windows > 0 || list[i].id === WidgetData.activeWorkspace) out.push(list[i]);
        return out.length > 0 ? out : list;
    }

    Grid {
        anchors.centerIn: parent
        columns: Math.max(1, Math.round(w.cfg.columns || 5))
        spacing: 10 * w.ui

        Repeater {
            model: w.visibleWorkspaces()

            Rectangle {
                id: pill
                required property var modelData
                readonly property bool active: modelData.id === WidgetData.activeWorkspace
                readonly property bool occupied: modelData.windows > 0
                readonly property color actCol: w.cfg.activeColor || w.cGold
                readonly property color occCol: w.cfg.occupiedColor || w.cCream

                width: Math.round((w.cfg.pillSize || 40) * w.ui)
                height: width
                radius: w.cfg.shape === "square" ? Math.round(2 * w.ui)
                      : (w.cfg.shape === "rounded" ? Math.round(8 * w.ui) : width / 2)
                color: active ? actCol : (hover.containsMouse ? "#33D4AF37" : (occupied ? "#22E6D5B8" : "transparent"))
                border.width: Math.max(1, Math.round(w.ui * 1.5))
                border.color: active ? actCol : (occupied ? occCol : "#55D4AF37")

                Text {
                    anchors.centerIn: parent
                    text: pill.modelData.id
                    color: pill.active ? "#07080C" : (pill.occupied ? pill.occCol : w.cDim)
                    font.family: "monospace"
                    font.bold: true
                    font.pixelSize: Math.max(8, Math.round((w.cfg.pillSize || 40) * 0.4 * w.ui))
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
