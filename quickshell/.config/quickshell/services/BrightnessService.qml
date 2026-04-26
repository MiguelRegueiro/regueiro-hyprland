import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property int percent: 0
    property int rawValue: 0
    property int maxValue: 0
    readonly property bool available: maxValue > 0
    // Edit this list to change the brightness stops.
    // All values are percentages (0–100). Tune freely.
    readonly property var stops: [2, 4, 8, 12, 18, 26, 36, 50, 66, 80, 90, 100]
    readonly property string iconText: {
        if (percent < 34)
            return "󰃞";

        if (percent < 67)
            return "󰃟";

        return "󰃠";
    }

    signal adjusted()

    function refresh() {
        if (!brightnessPoll.running)
            brightnessPoll.running = true;

    }

    function setPercent(nextPercent) {
        const clamped = Math.max(0, Math.min(100, Math.round(nextPercent)));
        root.percent = clamped;
        root.rawValue = root.maxValue > 0 ? Math.round(clamped * root.maxValue / 100) : 0;
        setBrightness.command = ["brightnessctl", "set", clamped + "%"];
        setBrightness.running = true;
        root.adjusted();
        refreshSoon.restart();
    }

    function adjust(direction) {
        if (root.maxValue <= 0)
            return ;

        const current = root.percent;
        let target;
        if (direction > 0) {
            target = root.stops.find((s) => {
                return s > current;
            });
        } else {
            const below = root.stops.filter((s) => {
                return s < current;
            });
            target = below.length > 0 ? below[below.length - 1] : undefined;
        }
        if (target === undefined)
            return ;

        root.percent = target;
        root.rawValue = Math.round(target * root.maxValue / 100);
        setBrightness.command = ["brightnessctl", "set", target + "%"];
        setBrightness.running = true;
        root.adjusted();
        refreshSoon.restart();
    }

    Timer {
        interval: Theme.brightnessPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon

        interval: Theme.brightnessRefreshDelay
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: brightnessPoll

        command: ["bash", "-c", "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1); m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); echo \"${b:-0} ${m:-0}\""]

        stdout: StdioCollector {
            id: brightnessOut

            onStreamFinished: {
                const parts = brightnessOut.text.trim().split(" ");
                const current = parseInt(parts[0]) || 0;
                const max = parseInt(parts[1]) || 0;
                root.maxValue = max;
                root.rawValue = current;
                root.percent = max > 0 ? Math.round(current * 100 / max) : 0;
            }
        }

    }

    Process {
        id: setBrightness

        command: ["echo"]
    }

    IpcHandler {
        function increase() {
            root.adjust(1);
        }

        function decrease() {
            root.adjust(-1);
        }

        function set(percent: string) {
            root.setPercent(Number(percent));
        }

        target: "brightness"
    }

}
