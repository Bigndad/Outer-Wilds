pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root

    property int cpuPercent: 0
    property real cpuTempC: 0.0
    property int ramPercent: 0
    property real ramUsedGb: 0.0
    property real ramTotalGb: 0.0
    property int gpuPercent: 0
    property real gpuTempC: 0.0
    property real vramUsedGb: 0.0
    property real vramTotalGb: 0.0
    property int vramPercent: 0
    property real swapUsedGb: 0.0
    property real swapTotalGb: 0.0
    property real nvmeTempC: 0.0
    property var disks: []              // [{ mount, totalGb, usedGb }]  refreshed every 30 s and when the Map View opens

    property real _prevIdle: 0
    property real _prevTotal: 0

    Timer {
        interval: 2000
        running: NoctaliaBridge.desktopVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: sensorProc.running = true
    }

    Process {
        id: sensorProc
        command: ["sh", "-c", "
            head -n1 /proc/stat;
            awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/ {print $1, $2}' /proc/meminfo;
            for h in /sys/class/hwmon/hwmon*; do
                n=$(cat \"$h/name\" 2>/dev/null)
                if [ \"$n\" = \"k10temp\" ]; then echo \"CPU_T $(cat $h/temp1_input 2>/dev/null)\"; fi
                if [ \"$n\" = \"amdgpu\" ]; then echo \"GPU_T $(cat $h/temp1_input 2>/dev/null)\"; fi
                if [ \"$n\" = \"nvme\" ] && [ -z \"$NV\" ]; then NV=1; echo \"NVME_T $(cat $h/temp1_input 2>/dev/null)\"; fi
            done
            for d in /sys/class/drm/card*/device; do
                if [ -f \"$d/gpu_busy_percent\" ]; then
                    echo \"GPU_BUSY $(cat $d/gpu_busy_percent 2>/dev/null)\"
                    echo \"VRAM_U $(cat $d/mem_info_vram_used 2>/dev/null)\"
                    echo \"VRAM_T $(cat $d/mem_info_vram_total 2>/dev/null)\"
                    break
                fi
            done
        "]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(raw) {
        const lines = raw.trim().split("\n");
        let memTotal = 0, memAvail = 0, swTotal = 0, swFree = 0;

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/);
            if (parts[0] === "cpu") {
                let user = parseFloat(parts[1]) || 0, nice = parseFloat(parts[2]) || 0,
                    system = parseFloat(parts[3]) || 0, idle = parseFloat(parts[4]) || 0,
                    iowait = parseFloat(parts[5]) || 0, irq = parseFloat(parts[6]) || 0,
                    softirq = parseFloat(parts[7]) || 0, steal = parseFloat(parts[8]) || 0;
                let idleAll = idle + iowait;
                let total = user + nice + system + idleAll + irq + softirq + steal;
                if (root._prevTotal > 0 && total > root._prevTotal) {
                    root.cpuPercent = Math.round((1.0 - (idleAll - root._prevIdle) / (total - root._prevTotal)) * 100);
                }
                root._prevIdle = idleAll;
                root._prevTotal = total;
            } else if (parts[0] === "MemTotal:") {
                memTotal = parseFloat(parts[1]) || 0;
            } else if (parts[0] === "MemAvailable:") {
                memAvail = parseFloat(parts[1]) || 0;
            } else if (parts[0] === "SwapTotal:") {
                swTotal = parseFloat(parts[1]) || 0;
            } else if (parts[0] === "SwapFree:") {
                swFree = parseFloat(parts[1]) || 0;
            } else if (parts[0] === "NVME_T") {
                root.nvmeTempC = Math.round((parseFloat(parts[1]) || 0) / 100) / 10;
            } else if (parts[0] === "CPU_T") {
                root.cpuTempC = Math.round((parseFloat(parts[1]) || 0) / 100) / 10;
            } else if (parts[0] === "GPU_T") {
                root.gpuTempC = Math.round((parseFloat(parts[1]) || 0) / 100) / 10;
            } else if (parts[0] === "GPU_BUSY") {
                root.gpuPercent = parseInt(parts[1]) || 0;
            } else if (parts[0] === "VRAM_U") {
                root.vramUsedGb = Math.round(((parseFloat(parts[1]) || 0) / 1073741824) * 100) / 100;
            } else if (parts[0] === "VRAM_T") {
                root.vramTotalGb = Math.round(((parseFloat(parts[1]) || 0) / 1073741824) * 100) / 100;
            }
        }

        if (memTotal > 0) {
            let used = memTotal - memAvail;
            root.ramPercent = Math.round((used / memTotal) * 100);
            root.ramUsedGb = Math.round((used / 1048576) * 10) / 10;
            root.ramTotalGb = Math.round((memTotal / 1048576) * 10) / 10;
        }
        root.swapTotalGb = Math.round(swTotal / 104857.6) / 10;
        root.swapUsedGb = Math.round((swTotal - swFree) / 104857.6) / 10;
        if (root.vramTotalGb > 0) {
            root.vramPercent = Math.round((root.vramUsedGb / root.vramTotalGb) * 100);
        }
    }

    // ---------------- disks (cheap: one df every 30 s, only while the scene is visible) ----------------
    function refreshDisks() { diskProc.running = true; }
    Timer {
        interval: 30000
        running: NoctaliaBridge.desktopVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshDisks()
    }
    Process {
        id: diskProc
        command: ["sh", "-c", "df -B1 --output=size,used,target -x tmpfs -x devtmpfs -x efivarfs -x squashfs -x overlay 2>/dev/null | tail -n +2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = ({}), out = [];
                const lines = String(text).trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].trim().match(/^(\d+)\s+(\d+)\s+(.+)$/);
                    if (!m) continue;
                    const mount = m[3];
                    if (mount.indexOf("/boot") === 0 || mount.indexOf("/efi") === 0 || mount.indexOf("/var/lib") === 0 || mount.indexOf("/run/user") === 0) continue;
                    const key = m[1] + ":" + m[2];                     // btrfs subvolumes repeat the same numbers: keep the first
                    if (seen[key]) continue;
                    seen[key] = true;
                    out.push({ mount: mount, totalGb: parseFloat(m[1]) / 1073741824, usedGb: parseFloat(m[2]) / 1073741824 });
                }
                root.disks = out;
            }
        }
    }
}
