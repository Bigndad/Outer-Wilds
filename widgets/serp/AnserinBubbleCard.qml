import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

// Small process card (port_anserin_panels.py): the busiest processes as little shaded bubbles.
// Click opens Anserin's Bubble Monitor:  qs -c outerwilds ipc call bubble toggle
// Needs python-psutil (scripts/topprocs.py).
WidgetCard {
    id: w
    title: "PROCESSES"
    designW: 240
    designH: 130

    property var procs: []          // [{ name, cpu }]
    property bool missing: false

    function parse(txt) {
        const out = [];
        w.missing = false;
        for (const raw of txt.split("\n")) {
            if (raw.indexOf("!psutil") === 0) { w.missing = true; continue; }
            const m = raw.match(/^\s*([0-9.]+)\s+(.+)$/);
            if (m) out.push({ cpu: Number(m[1]), name: m[2] });
        }
        w.procs = out;
    }

    Process {
        id: proc
        command: ["python3", Qt.resolvedUrl("scripts/topprocs.py").toString().replace("file://", "")]
        stdout: StdioCollector { onStreamFinished: w.parse(text) }
    }
    Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!proc.running) proc.running = true }

    Text {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        text: "CPU " + Sensors.cpuPercent + "%   RAM " + Sensors.ramPercent + "%" + (Sensors.cpuTempC > 0 ? "   " + Math.round(Sensors.cpuTempC) + "\u00b0" : "")
        color: w.cCream
        font.family: "monospace"
        font.bold: true
        font.pixelSize: Math.round(12 * w.ui)
    }

    Row {
        anchors.top: head.bottom
        anchors.topMargin: 8 * w.ui
        anchors.left: parent.left
        anchors.right: parent.right
        height: 62 * w.ui
        spacing: 8 * w.ui
        Repeater {
            model: w.procs
            delegate: Item {
                id: cell
                width: (parent.width - 3 * 8 * w.ui) / 4
                height: parent.height
                readonly property real d: Math.min(width, (16 + Math.sqrt(Math.max(0, modelData.cpu)) * 5) * w.ui)
                readonly property color base: index === 0 && modelData.cpu > 25 ? w.cGold : w.cCream
                Rectangle {
                    id: ball
                    width: cell.d; height: cell.d; radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4 * w.ui + (36 * w.ui - cell.d) / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.lighter(cell.base, 1.25) }
                        GradientStop { position: 1.0; color: Qt.darker(cell.base, 1.9) }
                    }
                    Rectangle {
                        x: parent.width * 0.2; y: parent.height * 0.14
                        width: parent.width * 0.38; height: parent.height * 0.22; radius: height / 2
                        rotation: -28
                        color: "#55FFFFFF"
                    }
                }
                Text {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.name
                    elide: Text.ElideRight
                    color: w.cCream
                    font.family: "monospace"
                    font.pixelSize: Math.round(9 * w.ui)
                }
            }
        }
    }
    Text {
        visible: w.procs.length === 0
        anchors.centerIn: parent
        text: w.missing ? "NEEDS PYTHON-PSUTIL" : "READING..."
        color: w.cDim
        font.family: "monospace"
        font.pixelSize: Math.round(11 * w.ui)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["qs", "-c", "outerwilds", "ipc", "call", "bubble", "toggle"])
    }
}
