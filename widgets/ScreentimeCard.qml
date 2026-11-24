import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// SUN STATION: today's screen time (fed by serp/scripts/screentime.py). Click opens the full panel.
WidgetCard {
    id: w
    title: "SCREEN TIME"
    designW: 260
    designH: 150

    property var cfg: ({ maxApps: 3, showBars: true, barColor: "#D4AF37", headerTag: "TODAY", pollSec: 3 })

    property int total: 0
    property var allApps: []
    readonly property var apps: allApps.slice(0, Math.max(1, Math.round(cfg.maxApps || 3)))

    function fmt(s) {
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h > 0 ? h + "h " + String(m).padStart(2, "0") + "m" : m + "m";
    }

    FileView {
        id: live
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/outerwilds/focustime/focustime_state.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                w.total = d.total || 0;
                w.allApps = d.apps || [];
            } catch (e) {}
        }
    }
    Timer {
        interval: Math.max(1000, Math.round((w.cfg.pollSec || 3) * 1000))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: live.reload()
    }

    Text {
        id: big
        anchors.top: parent.top
        anchors.left: parent.left
        text: w.fmt(w.total)
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.max(10, Math.round(30 * w.ui))
    }
    Text {
        anchors.left: big.right
        anchors.leftMargin: 8 * w.ui
        anchors.baseline: big.baseline
        text: w.cfg.headerTag !== undefined ? w.cfg.headerTag : "TODAY"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(7, Math.round(11 * w.ui))
    }

    Column {
        anchors.top: big.bottom
        anchors.topMargin: 8 * w.ui
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6 * w.ui
        Repeater {
            model: w.apps
            delegate: Item {
                width: parent.width
                height: (w.cfg.showBars !== false ? 22 : 16) * w.ui
                Text {
                    text: modelData.name
                    color: w.cCream
                    elide: Text.ElideRight
                    width: parent.width - 56 * w.ui
                    font.family: "monospace"
                    font.pixelSize: Math.max(7, Math.round(11 * w.ui))
                }
                Text {
                    anchors.right: parent.right
                    text: w.fmt(modelData.seconds)
                    color: w.cDim
                    font.family: "monospace"
                    font.pixelSize: Math.max(7, Math.round(11 * w.ui))
                }
                Rectangle {
                    visible: w.cfg.showBars !== false
                    anchors.bottom: parent.bottom
                    height: Math.max(2, Math.round(3 * w.ui))
                    width: Math.max(3 * w.ui, parent.width * modelData.percent / 100)
                    radius: height / 2
                    color: w.cfg.barColor || w.cGold
                }
            }
        }
    }
    Text {
        visible: w.apps.length === 0
        anchors.centerIn: parent
        text: "NO DATA YET"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.max(8, Math.round(11 * w.ui))
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "screentime", "toggle"])
    }
}
