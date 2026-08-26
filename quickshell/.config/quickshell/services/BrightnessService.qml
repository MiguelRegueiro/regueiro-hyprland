import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property var hardwareService: null
    property int percent: 0
    property int rawValue: 0
    property int maxValue: 0
    property bool brightnessInitialized: false
    readonly property bool available: hardwareService && hardwareService.brightnessAvailable
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

    function applyHardwareBrightness(nextPercent) {
        const next = Math.max(0, Math.min(100, Math.round(Number(nextPercent))));
        const brightnessChanged = root.brightnessInitialized && next !== root.percent;
        root.maxValue = 100;
        root.rawValue = next;
        root.percent = next;
        root.brightnessInitialized = true;
        if (brightnessChanged) {
            root.adjusted();
            brightnessStoreDelay.restart();
        }
    }

    function refresh() {
        if (root.hardwareService)
            root.hardwareService.refresh();
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
        if (root.hardwareService)
            root.hardwareService.setBrightness(clamped);

        root.adjusted();
        brightnessStoreDelay.restart();
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

        root.setPercent(target);
    }

    Connections {
        target: root.hardwareService

        function onBrightnessUpdated(percent) {
            root.applyHardwareBrightness(percent);
        }
    }

    Timer {
        id: refreshSoon

        interval: Theme.brightnessRefreshDelay
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: brightnessStoreDelay

        interval: Theme.brightnessStoreDelay
        repeat: false
        onTriggered: {
            storeBrightness.command = [
                Quickshell.env("HOME") + "/.config/hypr/scripts/brightness-store.sh",
                "save",
                String(root.percent)
            ];
            storeBrightness.running = true;
        }
    }

    Process {
        id: storeBrightness

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

        function osd(percent: string) {
            root.requestBrightnessOsd(percent);
        }

        target: "brightness"
    }
}
