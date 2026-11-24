import QtQuick
import Quickshell
import Quickshell.Io
import "../../.."

// IPC + psutil feed + signal runner for the 3D BubbleField3D inside CameraRig.
//   toggle:  qs -c outerwilds ipc call bubble toggle
Scope {
    id: root

    IpcHandler {
        target: "bubble"
        function toggle(): void { BubbleState.open = !BubbleState.open; }
        function show(): void { BubbleState.open = true; }
        function hide(): void { BubbleState.open = false; }
        function recenter(): void { BubbleState.recenterSeq++; }
    }

    Connections {
        target: BubbleState
        function onSignalProcess(pids, sig, label) {
            const validSig = (sig === "TERM" || sig === "KILL" || sig === "STOP" || sig === "CONT") ? sig : "TERM";
            const cleanPids = pids.map(p => String(Math.floor(Number(p)))).filter(s => /^\d+$/.test(s) && Number(s) > 1);
            if (cleanPids.length === 0) return;
            sigProc.command = ["kill", "-s", validSig].concat(cleanPids);
            sigProc.running = true;
            BubbleState.statusMsg = validSig + " → " + (label || ("PID " + cleanPids[0]));
            statusClear.restart();
        }
    }

    Process {
        id: sigProc
    }

    Timer {
        id: statusClear
        interval: 2800
        onTriggered: BubbleState.statusMsg = ""
    }

    Process {
        id: feed
        running: BubbleState.open
        onExited: if (BubbleState.open) feedRestart.restart()
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("bubble/bubble-feed.py").toString().replace("file://", "")), "1"]
        stdout: SplitParser {
            onRead: (line) => {
                let snap = null;
                try { snap = JSON.parse(line); } catch (e) { return; }
                if (snap && !snap.error) BubbleState.pushSnap(snap);
            }
        }
    }

    Timer {
        id: feedRestart
        interval: 1000
        onTriggered: if (BubbleState.open && !feed.running) feed.running = true
    }
}
