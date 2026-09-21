import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

// Read-only state shared by all lock surfaces. No control or unlock IPC.
Item {
    id: root
    property int volume: -1
    property bool muted: false
    property int brightness: -1
    property string osdMode: ""
    readonly property var battery: UPower.displayDevice
    readonly property int batteryPercent: battery && battery.isPresent ? Math.round(battery.percentage * 100) : -1
    readonly property bool charging: battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool full: battery && battery.state === UPowerDeviceState.FullyCharged

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
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo unavailable; for dev in /sys/class/backlight/*; do if [[ -r $dev/brightness && -r $dev/max_brightness ]]; then read -r b < \"$dev/brightness\"; read -r m < \"$dev/max_brightness\"; if ((m > 0)); then echo $(((b * 100 + m / 2) / m)); exit; fi; fi; done; echo -1"]
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
