import QtQuick
import Quickshell.Io

Item {
    id: root

    property int percent: 0
    property int maxValue: 0
    readonly property bool available: maxValue > 0
    readonly property string iconText: {
        if (percent < 34)
            return "󰃞"
        if (percent < 67)
            return "󰃟"
        return "󰃠"
    }

    function refresh() {
        if (!brightnessPoll.running)
            brightnessPoll.running = true
    }

    function setPercent(nextPercent) {
        setBrightness.command = ["brightnessctl", "set", Math.max(0, Math.min(100, nextPercent)) + "%"]
        setBrightness.running = true
        refreshSoon.restart()
    }

    function adjust(stepPercent) {
        if (stepPercent > 0)
            brightnessUp.running = true
        else
            brightnessDown.running = true

        refreshSoon.restart()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon
        interval: 160
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: brightnessPoll
        command: ["bash", "-c", "b=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1); m=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); echo \"${b:-0} ${m:-0}\""]
        stdout: StdioCollector {
            id: brightnessOut
            onStreamFinished: {
                const parts = brightnessOut.text.trim().split(" ")
                const current = parseInt(parts[0]) || 0
                const max = parseInt(parts[1]) || 0

                root.maxValue = max
                if (max > 0)
                    root.percent = Math.round(current * 100 / max)
                else
                    root.percent = 0
            }
        }
    }

    Process { id: brightnessUp; command: ["brightnessctl", "set", "5%+"] }
    Process { id: brightnessDown; command: ["brightnessctl", "set", "5%-"] }
    Process { id: setBrightness; command: ["echo"] }
}
