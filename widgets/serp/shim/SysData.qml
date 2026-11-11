pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../.."

// Serpantinum's SysData, fed by the config's own Sensors singleton (CPU, RAM, CPU temperature).
// Disk usage of / comes from `df`, polled only while a face is visible.
Singleton {
    id: root

    readonly property int cpu: Sensors.cpuPercent
    readonly property int ramPercent: Sensors.ramPercent
    readonly property real ramGb: Sensors.ramUsedGb
    readonly property int temp: Math.round(Sensors.cpuTempC)
    property real netRx: 0
    property real netTx: 0
    property int diskPercent: 0
    property real diskGb: 0.0
    property real diskTotalGb: 0.0

    property int subscribers: 0
    function subscribe() { subscribers++; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    Timer {
        interval: 30000
        running: root.subscribers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -B1 --output=used,size / | tail -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                const used = parseFloat(p[0]) || 0, total = parseFloat(p[1]) || 0;
                if (total > 0) {
                    root.diskGb = used / 1073741824;
                    root.diskTotalGb = total / 1073741824;
                    root.diskPercent = Math.round(used / total * 100);
                }
            }
        }
    }
}
