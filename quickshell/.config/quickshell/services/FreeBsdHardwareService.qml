import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int brightnessPercent: 0
    property int volumePercent: 0
    property bool muted: false
    property bool brightnessAvailable: false
    property bool audioAvailable: false
    readonly property bool running: hardwareBridge.running

    signal brightnessUpdated(int percent)
    signal audioUpdated(int percent, bool muted)

    function parseLine(line) {
        const fields = String(line).trim().split(/\s+/);
        if (fields[0] === "brightness" && fields.length >= 2) {
            const value = Number(fields[1]);
            if (!isNaN(value)) {
                root.brightnessPercent = Math.max(0, Math.min(100, Math.round(value)));
                root.brightnessAvailable = true;
                root.brightnessUpdated(root.brightnessPercent);
            }
        } else if (fields[0] === "audio" && fields.length >= 3) {
            const value = Number(fields[1]);
            if (!isNaN(value)) {
                root.volumePercent = Math.max(0, Math.min(100, Math.round(value)));
                root.muted = fields[2] === "1";
                root.audioAvailable = true;
                root.audioUpdated(root.volumePercent, root.muted);
            }
        }
    }

    function send(command) {
        if (hardwareBridge.running)
            hardwareBridge.write(command + "\n");
        else
            restartTimer.restart();
    }

    function setBrightness(percent) {
        root.send("brightness " + Math.max(0, Math.min(100, Math.round(percent))));
    }

    function setVolume(percent) {
        root.send("volume " + Math.max(0, Math.min(100, Math.round(percent))));
    }

    function toggleMute() {
        root.send("mute toggle");
    }

    function refresh() {
        root.send("refresh");
    }

    Process {
        id: hardwareBridge

        command: [Quickshell.shellPath("helpers/qs-freebsd-hardware")]
        running: true
        stdinEnabled: true
        onExited: restartTimer.restart()

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseLine(data)
        }
    }

    Timer {
        id: restartTimer

        interval: 2000
        repeat: false
        onTriggered: hardwareBridge.running = true
    }
}
