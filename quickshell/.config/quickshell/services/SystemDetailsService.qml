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
    property real ramActiveGb: 0
    property real ramWiredGb: 0
    property real ramInactiveGb: 0
    property real ramFreeGb: 0
    property string swapText: ""
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
        return `${Number(value || 0).toFixed(1)}G`;
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

        for (let i = 0; i + 4 < values.length; i += 5) {
            const user = values[i];
            const nice = values[i + 1];
            const sys = values[i + 2];
            const intr = values[i + 3];
            const idle = values[i + 4];
            const total = user + nice + sys + intr + idle;
            const coreIndex = i / 5;
            const hasPrevious = root._prevCpuTotals[coreIndex] !== undefined && root._prevCpuIdles[coreIndex] !== undefined;
            const previousTotal = root._prevCpuTotals[coreIndex] || 0;
            const previousIdle = root._prevCpuIdles[coreIndex] || 0;
            const dTotal = total - previousTotal;
            const dIdle = idle - previousIdle;

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
            root._prevCpuIdles[coreIndex] = idle;
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
                if (parts.length >= 7) {
                    const pageSize = Number(parts[6]) || 0;
                    root.ramTotalGb = root.gib(Number(parts[1]));
                    root.ramActiveGb = root.gib(Number(parts[2]) * pageSize);
                    root.ramWiredGb = root.gib(Number(parts[3]) * pageSize);
                    root.ramInactiveGb = root.gib(Number(parts[4]) * pageSize);
                    root.ramFreeGb = root.gib(Number(parts[5]) * pageSize);
                    root.ramUsedGb = root.ramActiveGb + root.ramWiredGb;
                }
            } else if (line.indexOf("swap\t") === 0) {
                root.swapText = line.slice(5).trim();
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

        command: ["sh", "-c", "printf 'model\\t'; sysctl -n hw.model 2>/dev/null; printf 'cores\\t'; sysctl -n hw.ncpu 2>/dev/null; temp=$(sysctl -n dev.cpu.0.temperature 2>/dev/null || true); printf 'temp\\t%s\\n' \"$temp\"; printf 'times\\t'; sysctl -n kern.cp_times 2>/dev/null; printf 'top\\n'; ps -axo pcpu,rss,pid,user,comm | awk 'NR > 1 && $5 !~ /^(idle|intr)$/ { print }' | sort -nr | head -3"]

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

        command: ["sh", "-c", "printf 'mem\\t'; printf '%s\\t' $(sysctl -n hw.physmem vm.stats.vm.v_active_count vm.stats.vm.v_wire_count vm.stats.vm.v_inactive_count vm.stats.vm.v_free_count hw.pagesize 2>/dev/null); printf '\\n'; printf 'swap\\t'; swapinfo -k 2>/dev/null | awk 'NR == 2 { printf \"%.1fG / %.1fG (%s)\", $3 / 1048576, $2 / 1048576, $5 }'; printf '\\n'; printf 'top\\n'; ps -axo rss,pcpu,pid,user,comm | awk 'NR > 1 { printf \"%s %s %s %s %s\\n\", $1, $2, $3, $4, $5 }' | sort -nr | head -5"]

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
