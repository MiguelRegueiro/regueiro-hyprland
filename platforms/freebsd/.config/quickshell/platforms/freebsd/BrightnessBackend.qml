import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int percent: 0
    property bool brightnessKnown: false
    readonly property bool available: brightnessKnown && bridge.running
    readonly property string iconText: percent < 34 ? "󰃞" : percent < 67 ? "󰃟" : "󰃠"
    readonly property var stops: [2, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]

    signal adjusted()

    function refresh() {
        send("refresh");
    }

    function setPercent(value) {
        const next = Math.max(0, Math.min(100, Math.round(Number(value))));
        if (!Number.isFinite(next))
            return;
        percent = next;
        send("brightness " + next);
        adjusted();
    }

    function adjust(direction) {
        const next = direction > 0
            ? stops.find((stop) => stop > percent)
            : stops.filter((stop) => stop < percent).slice(-1)[0];
        if (next !== undefined)
            setPercent(next);
    }

    function send(message) {
        if (bridge.running)
            bridge.write(message + "\n");
    }

    Process {
        id: bridge

        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-hardware"]
        running: true
        stdinEnabled: true
        onExited: restartTimer.restart()

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const fields = String(line).trim().split(/\s+/);
                if (fields[0] !== "brightness" || fields.length < 2)
                    return;
                const value = Number(fields[1]);
                if (!Number.isFinite(value))
                    return;
                root.percent = Math.max(0, Math.min(100, Math.round(value)));
                root.brightnessKnown = true;
                root.adjusted();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        repeat: false
        onTriggered: bridge.running = true
    }
}
