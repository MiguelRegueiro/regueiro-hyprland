import QtQuick
import Quickshell
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
    readonly property var stops: [2, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]
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

    function requestBrightnessOsd(percent) {
        const nextPercent = Number(percent);
        if (!isNaN(nextPercent)) {
            const clamped = Math.max(0, Math.min(100, Math.round(nextPercent)));
            root.percent = clamped;
            root.maxValue = 100;
            root.rawValue = clamped;
        }

        root.adjusted();
        refreshSoon.restart();
    }

    function setPercent(nextPercent) {
        const clamped = Math.max(0, Math.min(100, Math.round(nextPercent)));
        root.percent = clamped;
        root.maxValue = 100;
        root.rawValue = clamped;
        setBrightness.command = [
            Quickshell.env("HOME") + "/.config/hypr/scripts/brightness-set.sh",
            String(clamped)
        ];
        setBrightness.running = true;
        root.adjusted();
        refreshSoon.restart();
    }

    function adjust(direction) {
        if (root.maxValue <= 0)
            root.maxValue = 100;

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
        root.rawValue = target;
        setBrightness.command = [
            Quickshell.env("HOME") + "/.config/hypr/scripts/brightness-set.sh",
            String(target)
        ];
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

        command: [
            "sh",
            "-c",
            "if [ -x /usr/bin/backlight ]; then /usr/bin/backlight -q 2>/dev/null; else printf 'brightness: 0\\n'; fi"
        ]

        stdout: StdioCollector {
            id: brightnessOut

            onStreamFinished: {
                const text = brightnessOut.text.trim();
                let current = 0;
                if (/^[0-9]+$/.test(text)) {
                    current = parseInt(text) || 0;
                } else {
                    const match = text.match(/brightness:\s*([0-9]+)/i);
                    current = match ? (parseInt(match[1]) || 0) : 0;
                }
                root.maxValue = 100;
                root.rawValue = current;
                root.percent = Math.max(0, Math.min(100, current));
            }
        }

    }

    Process {
        id: setBrightness

        command: ["echo"]
        onExited: root.refresh()
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

        function osd(percent: string) {
            root.requestBrightnessOsd(percent);
        }

        target: "brightness"
    }

}
