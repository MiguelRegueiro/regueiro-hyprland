import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property bool hasBattery: false
    property int percent: -1
    property bool charging: false
    property bool full: false
    property int secondsLeft: 0
    property string stateText: ""

    function refresh() {
        if (!batteryPoll.running)
            batteryPoll.running = true;
    }

    function parseRemainingTime(raw) {
        const value = (raw || "").trim().toLowerCase();
        if (value.length === 0 || value === "unknown")
            return 0;

        const match = value.match(/^([0-9]+):([0-9]+)$/);
        if (!match)
            return 0;

        const hours = parseInt(match[1]) || 0;
        const minutes = parseInt(match[2]) || 0;
        return hours * 3600 + minutes * 60;
    }

    function formatTime(secs) {
        if (secs <= 0)
            return "";

        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        if (h > 0 && m > 0)
            return h + "h " + m + "m";

        if (h > 0)
            return h + "h";

        return m + "m";
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: batteryPoll

        command: [
            "sh",
            "-c",
            "pct=-1; ac=-1; state=unknown; rem=unknown; " +
            "if [ -x /usr/sbin/apm ]; then " +
            "pct=$(/usr/sbin/apm -l 2>/dev/null || echo -1); " +
            "ac=$(/usr/sbin/apm -a 2>/dev/null || echo -1); " +
            "info=$(/usr/sbin/acpiconf -i 0 2>/dev/null || true); " +
            "if [ -n \"$info\" ]; then " +
            "state=$(printf '%s\\n' \"$info\" | awk -F: '/State:/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "rem=$(printf '%s\\n' \"$info\" | awk -F: '/Remaining time:/ {sub(/^[ \\t]+/, \"\", $2); print $2; exit}'); " +
            "fi; " +
            "fi; " +
            "printf '%s\\037%s\\037%s\\037%s\\n' \"${pct:--1}\" \"${ac:--1}\" \"${state:-unknown}\" \"${rem:-unknown}\""
        ]

        stdout: StdioCollector {
            id: batteryOut

            onStreamFinished: {
                const lines = batteryOut.text.trim().split(/\r?\n/).filter((line) => {
                    return line.trim().length > 0;
                });
                const raw = lines.length > 0 ? lines[lines.length - 1].trim() : "";
                if (raw.length === 0) {
                    root.percent = -1;
                    root.hasBattery = false;
                    root.stateText = "";
                    root.full = false;
                    root.charging = false;
                    root.secondsLeft = 0;
                    return;
                }

                const parts = raw.split("\u001f");
                const nextPercent = parseInt(parts[0]);
                const ac = parseInt(parts[1]);
                const state = (parts[2] || "unknown").trim().toLowerCase();
                const remaining = (parts[3] || "unknown").trim();
                root.percent = isNaN(nextPercent) ? -1 : Math.max(-1, Math.min(100, nextPercent));
                root.hasBattery = root.percent >= 0;
                root.stateText = state;
                root.full = root.hasBattery && (root.percent === 100 || state === "high" || state === "charged");
                root.charging = root.hasBattery && (ac === 1 || state === "charging" || root.full);
                root.secondsLeft = !root.charging ? root.parseRemainingTime(remaining) : 0;
            }
        }
    }
}
