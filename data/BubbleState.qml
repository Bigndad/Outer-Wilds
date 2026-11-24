pragma Singleton
import QtQuick

QtObject {
    id: st
    property bool open: false
    property var snap: null
    property int snapSeq: 0
    property string mode: "both"      // "procs" | "apps" | "both"
    property int recenterSeq: 0
    property string statusMsg: ""

    signal signalProcess(var pids, string sig, string label)

    function pushSnap(s) {
        snap = s;
        snapSeq++;
    }

    function sendSignal(pids, sig, label) {
        const list = Array.isArray(pids) ? pids.filter(p => Number(p) > 0) : (Number(pids) > 0 ? [Number(pids)] : []);
        if (list.length === 0) return;
        signalProcess(list, sig, label || "");
    }
}
