import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property var device: present ? root : null
    property bool present: false
    property int percent: -1
    property bool charging: false
    property bool full: false
    property bool discharging: false
    property bool onBattery: false
    property int secondsLeft: 0

    function parseRemainingTime(raw) {
        const match = String(raw || "").trim().match(/^([0-9]+):([0-9]+)$/);
        return match ? Number(match[1]) * 3600 + Number(match[2]) * 60 : 0;
    }

    function refresh() {
        if (!poll.running)
            poll.running = true;
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: poll

        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-battery"]

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("\u001f");
                if (fields.length < 4) {
                    root.present = false;
                    root.percent = -1;
                    root.charging = false;
                    root.full = false;
                    root.discharging = false;
                    root.onBattery = false;
                    root.secondsLeft = 0;
                    return;
                }

                const level = Number(fields[0]);
                const ac = Number(fields[1]);
                const state = String(fields[2] || "unknown").toLowerCase();
                root.percent = Number.isFinite(level) ? Math.max(-1, Math.min(100, level)) : -1;
                root.present = root.percent >= 0;
                root.full = root.present && (root.percent === 100 || state === "high" || state === "charged");
                root.charging = root.present && !root.full && (ac === 1 || state === "charging");
                root.discharging = root.present && !root.charging && !root.full;
                root.onBattery = root.present && ac === 0;
                root.secondsLeft = root.discharging ? root.parseRemainingTime(fields[3]) : 0;
            }
        }
    }
}
