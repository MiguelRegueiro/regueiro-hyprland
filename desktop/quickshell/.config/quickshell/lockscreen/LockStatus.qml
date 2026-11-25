import QtQuick
import Quickshell.Io

// Read-only state shared by all lock surfaces. No control or unlock IPC.
Item {
    id: root
    required property var batteryService
    required property var platformService
    property int volume: -1
    property bool muted: false
    property int brightness: -1
    property string osdMode: ""
    readonly property int batteryPercent: batteryService.percent
    readonly property bool charging: batteryService.charging
    readonly property bool full: batteryService.full

    function updateState(nextVolume, nextMuted, nextBrightness) {
        // The first reading establishes a baseline without flashing an OSD.
        if (nextVolume >= 0) {
            if (volume >= 0 && (volume !== nextVolume || muted !== nextMuted)) {
                osdMode = "volume";
                hideTimer.restart();
            }
            volume = nextVolume;
            muted = nextMuted;
        }
        if (nextBrightness >= 0) {
            if (brightness >= 0 && brightness !== nextBrightness) {
                osdMode = "brightness";
                hideTimer.restart();
            }
            brightness = nextBrightness;
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.osdMode = ""
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { if (!poll.running) poll.running = true; }
    }
    Process {
        id: poll
        command: [root.platformService.systemDetailsCommandPath, "lock"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const match = /^Volume:\s+([0-9.]+)/.exec(lines[0] || "");
                const volume = match ? Math.min(100, Math.round(Number(match[1]) * 100)) : -1;
                const brightness = Number(lines[1]);
                root.updateState(volume, (lines[0] || "").includes("[MUTED]"), Number.isFinite(brightness) ? brightness : -1);
            }
        }
    }
}
