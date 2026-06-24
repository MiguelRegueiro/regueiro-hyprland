import QtQuick
import Quickshell.Io

Item {
    id: root

    property string cpuCores: ""
    property string cpuModel: ""
    property string cpuTemp: ""
    property int cpuOverallPct: 0
    property var cpuCorePcts: []
    property var topCpu: []
    property real ramTotalGb: 0
    property real ramUsedGb: 0
    property real ramAvailableGb: 0
    property real ramCachedGb: 0
    property real ramFreeGb: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property int swapPct: 0
    property var topMem: []
    property string lastError: ""
    readonly property bool cpuLoading: cpuProc.running
    readonly property bool ramLoading: ramProc.running
    property var _prevCpuTotals: []
    property var _prevCpuIdles: []
    property bool _cpuCountersReady: false

    function gib(bytes) {
        const value = Number(bytes);
        if (!Number.isFinite(value) || value <= 0)
            return 0;

        return value / 1073741824;
    }

    function formatGb(value) {
        return `${Number(value || 0).toFixed(1)} GB`;
    }

    function parseTopRows(lines, startIndex, normalizeCpu) {
        const rows = [];
        for (let i = startIndex; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0)
                continue;

            const parts = line.split(/\s+/);
            if (parts.length < 5)
                continue;

            const rawValue = Number(parts[0]) || 0;
            rows.push({
                value: parts[0],
                totalPct: normalizeCpu && Number(root.cpuCores) > 0 ? rawValue / Number(root.cpuCores) : rawValue,
                rssKb: Number(parts[1]) || 0,
                pid: parts[2],
                user: parts[3],
                command: parts.slice(4).join(" ")
            });
        }

        return rows;
    }

    function parseCpuTimes(text) {
        const values = String(text || "").trim().split(/\s+/).map((part) => Number(part)).filter((value) => Number.isFinite(value));
        const corePcts = [];
        let totalDelta = 0;
        let idleDelta = 0;

        for (let i = 0; i + 6 < values.length; i += 7) {
            const user = values[i];
            const nice = values[i + 1];
            const sys = values[i + 2];
            const idle = values[i + 3];
            const iowait = values[i + 4];
            const irq = values[i + 5];
            const softirq = values[i + 6];
            const total = user + nice + sys + idle + iowait + irq + softirq;
            const idleAll = idle + iowait;
            const coreIndex = i / 7;
            const hasPrevious = root._prevCpuTotals[coreIndex] !== undefined && root._prevCpuIdles[coreIndex] !== undefined;
            const previousTotal = root._prevCpuTotals[coreIndex] || 0;
            const previousIdle = root._prevCpuIdles[coreIndex] || 0;
            const dTotal = total - previousTotal;
            const dIdle = idleAll - previousIdle;

            if (hasPrevious && dTotal > 0) {
                const busy = Math.max(0, Math.min(100, Math.round(100 * (dTotal - dIdle) / dTotal)));
                corePcts.push(busy);
                totalDelta += dTotal;
                idleDelta += dIdle;
            } else if (root.cpuCorePcts.length > coreIndex) {
                corePcts.push(root.cpuCorePcts[coreIndex]);
            } else {
                corePcts.push(0);
            }

            root._prevCpuTotals[coreIndex] = total;
            root._prevCpuIdles[coreIndex] = idleAll;
        }

        if (corePcts.length > 0)
            root.cpuCorePcts = corePcts;
        if (totalDelta > 0)
            root.cpuOverallPct = Math.max(0, Math.min(100, Math.round(100 * (totalDelta - idleDelta) / totalDelta)));
        if (!root._cpuCountersReady) {
            root._cpuCountersReady = true;
            cpuWarmup.restart();
        }
    }

    function parseCpu(output) {
        const lines = String(output || "").split(/\r?\n/);
        let topStart = lines.length;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf("model\t") === 0) {
                root.cpuModel = line.slice(6).trim();
            } else if (line.indexOf("cores\t") === 0) {
                root.cpuCores = line.slice(6).trim();
            } else if (line.indexOf("temp\t") === 0) {
                root.cpuTemp = line.slice(5).trim();
            } else if (line.indexOf("times\t") === 0) {
                root.parseCpuTimes(line.slice(6));
            } else if (line === "top") {
                topStart = i + 1;
                break;
            }
        }

        root.topCpu = root.parseTopRows(lines, topStart, true).slice(0, 3);
        root.lastError = "";
    }

    function parseRam(output) {
        const lines = String(output || "").split(/\r?\n/);
        let topStart = lines.length;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf("mem\t") === 0) {
                const parts = line.split(/\s+/);
                if (parts.length >= 6) {
                    root.ramTotalGb = root.gib(Number(parts[1]));
                    root.ramUsedGb = root.gib(Number(parts[2]));
                    root.ramCachedGb = root.gib(Number(parts[3]));
                    root.ramAvailableGb = root.gib(Number(parts[4]));
                    root.ramFreeGb = root.gib(Number(parts[5]));
                }
            } else if (line.indexOf("swap\t") === 0) {
                const parts = line.split(/\s+/);
                if (parts.length >= 4) {
                    root.swapUsedGb = root.gib(Number(parts[1]) || 0);
                    root.swapTotalGb = root.gib(Number(parts[2]) || 0);
                    root.swapPct = Math.max(0, Math.min(100, Math.round(Number(parts[3]) || 0)));
                } else {
                    root.swapUsedGb = 0;
                    root.swapTotalGb = 0;
                    root.swapPct = 0;
                }
            } else if (line === "top") {
                topStart = i + 1;
                break;
            }
        }

        root.topMem = root.parseTopRows(lines, topStart, false);
        root.lastError = "";
    }

    function refreshCpu() {
        if (!cpuProc.running)
            cpuProc.running = true;
    }

    function refreshRam() {
        if (!ramProc.running)
            ramProc.running = true;
    }

    Process {
        id: cpuProc

        command: ["bash", "-lc", "printf 'model\\t'; awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo; printf 'cores\\t'; nproc; temp=$(for f in /sys/class/thermal/thermal_zone*/temp; do [ -r \"$f\" ] || continue; v=$(cat \"$f\"); [ \"$v\" -gt 0 ] 2>/dev/null || continue; awk -v v=\"$v\" 'BEGIN { printf \"%.0f°C\", v / 1000 }'; break; done); printf 'temp\\t%s\\n' \"$temp\"; printf 'times\\t'; awk '/^cpu[0-9]+ / { printf \"%s %s %s %s %s %s %s \", $2, $3, $4, $5, $6, $7, $8 } END { print \"\" }' /proc/stat; printf 'top\\n'; ps -eo pcpu,rss,pid,user,comm --no-headers | sort -nr | head -3"]

        stdout: StdioCollector {
            id: cpuOut
            waitForEnd: true
            onStreamFinished: root.parseCpu(cpuOut.text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to load CPU details";
        }
    }

    Timer {
        id: cpuWarmup

        interval: 350
        repeat: false
        onTriggered: root.refreshCpu()
    }

    Process {
        id: ramProc

        command: ["bash", "-lc", "awk '/MemTotal:/ { total=$2 } /MemAvailable:/ { available=$2 } /MemFree:/ { free=$2 } /^Cached:/ { cached=$2 } END { used=total-available; printf \"mem\\t%d\\t%d\\t%d\\t%d\\t%d\\n\", total*1024, used*1024, cached*1024, available*1024, free*1024 }' /proc/meminfo; awk '/SwapTotal:/ { total=$2 } /SwapFree:/ { free=$2 } END { used=total-free; pct=total > 0 ? used * 100 / total : 0; printf \"swap\\t%d\\t%d\\t%.0f\\n\", used*1024, total*1024, pct }' /proc/meminfo; printf 'top\\n'; ps -eo rss,pcpu,pid,user,comm --no-headers | sort -nr | head -5"]

        stdout: StdioCollector {
            id: ramOut
            waitForEnd: true
            onStreamFinished: root.parseRam(ramOut.text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to load RAM details";
        }
    }
}
