import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool busy: false
    property bool configured: false
    readonly property int displayCount: monitors.length
    property string lastError: ""
    property string mode: "extend"
    readonly property string modeLabel: mode === "duplicate" ? "Duplicate" : "Extend"
    property var monitors: []
    property string primary: ""
    property var positions: ({})

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true;
    }
    function rotate(output, transform) {
        run("transform", output, String(transform));
    }

    function setLayout(positions) {
        run("layout", JSON.stringify(positions));
    }
    function run() {
        if (arguments.length === 0 || actionProc.running)
            return;
        actionProc.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/displayctl"].concat(Array.prototype.slice.call(arguments));
        lastError = "";
        busy = true;
        actionProc.running = true;
    }
    function setMode(nextMode) {
        run("mode", nextMode);
    }
    function setPrimary(output) {
        run("primary", output);
    }
    function toggleDpms() {
        run("dpms", "toggle");
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: root.refresh()
    }
    Process {
        id: statusProc

        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/displayctl", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text);
                    const previousOutputs = root.monitors.map(monitor => monitor.name).sort().join(",");
                    const nextMonitors = state.monitors || [];
                    const nextOutputs = nextMonitors.map(monitor => monitor.name).sort().join(",");
                    root.configured = state.configured === true;
                    root.mode = state.mode === "duplicate" ? "duplicate" : "extend";
                    root.primary = state.primary || "";
                    root.positions = state.positions || {};
                    root.monitors = nextMonitors;
                    if (root.configured && previousOutputs.length > 0 && previousOutputs !== nextOutputs && !root.busy)
                        root.run("apply");
                } catch (error) {
                    root.lastError = "Could not read display state";
                }
            }
        }
    }
    Process {
        id: actionProc

        command: ["true"]

        stderr: StdioCollector { id: actionStderr }

        onExited: code => {
            if (code !== 0)
                root.lastError = actionStderr.text.trim() || "Could not apply display settings";
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

        interval: 350

        onTriggered: root.refresh()
    }
}
