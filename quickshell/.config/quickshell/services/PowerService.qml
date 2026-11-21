import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int screenOff: 0
    property int lock: 20
    property int suspend: 0
    property string powerButton: "system"
    property bool keepAwake: false
    property bool active: false
    property bool busy: false
    property string lastError: ""
    readonly property string commandPath: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/powerctl"

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function run() {
        if (actionProc.running)
            return;
        actionProc.command = [commandPath].concat(Array.prototype.slice.call(arguments));
        lastError = "";
        busy = true;
        actionProc.running = true;
    }

    function setTimer(key, minutes) {
        run("set", key, String(minutes));
    }

    function setPowerButton(action) {
        run("set", "powerButton", action);
    }

    function toggleKeepAwake() {
        run("awake", keepAwake ? "off" : "on");
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc
        command: [root.commandPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const next = JSON.parse(text);
                    root.screenOff = next.screenOff;
                    root.lock = next.lock;
                    root.suspend = next.suspend;
                    root.powerButton = next.powerButton;
                    root.keepAwake = next.keepAwake === true;
                    root.active = next.active === true;
                } catch (error) {
                    root.lastError = "Could not read power settings";
                }
            }
        }
    }

    Process {
        id: actionProc
        command: ["true"]
        stderr: StdioCollector { id: actionError }
        onExited: code => {
            if (code !== 0)
                root.lastError = actionError.text.trim() || "Could not apply power settings";
        }
        onRunningChanged: {
            if (!running && root.busy) {
                root.busy = false;
                refreshDelay.restart();
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 250
        onTriggered: root.refresh()
    }
}
