import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// SUN STATION: today's screen time (fed by serp/scripts/screentime.py). Click opens the full panel.
WidgetCard {
    id: w
    title: "SCREEN TIME"
    designW: 250
    designH: 150

    property int total: 0
    property var apps: []

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
                w.apps = (d.apps || []).slice(0, 3);
            } catch (e) {}
        }
    }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: live.reload() }

    Text {
        id: big
        anchors.top: parent.top
        anchors.left: parent.left
        text: w.fmt(w.total)
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.round(30 * w.ui)
    }
    Text {
        anchors.left: big.right
        anchors.leftMargin: 8 * w.ui
        anchors.baseline: big.baseline
        text: "TODAY"
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(11 * w.ui)
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
                height: 22 * w.ui
                Text {
                    text: modelData.name
                    color: w.cCream
                    elide: Text.ElideRight
                    width: parent.width - 56 * w.ui
                    font.family: "monospace"
                    font.pixelSize: Math.round(11 * w.ui)
                }
                Text {
                    anchors.right: parent.right
                    text: w.fmt(modelData.seconds)
                    color: w.cDim
                    font.family: "monospace"
                    font.pixelSize: Math.round(11 * w.ui)
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    height: Math.max(2, Math.round(3 * w.ui))
                    width: Math.max(3 * w.ui, parent.width * modelData.percent / 100)
                    radius: height / 2
                    color: w.cGold
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
        font.pixelSize: Math.round(11 * w.ui)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "screentime", "toggle"])
    }
}
