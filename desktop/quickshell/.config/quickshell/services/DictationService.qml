import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string status: "idle"
    property string text: ""
    property string detail: ""
    property bool readyDismissed: false
    // External keybindings still use dictationctl directly. They notify this
    // service over IPC, which gives us the old fast response without polling
    // a shell process constantly while dictation is idle.
    property int fastRefreshesRemaining: 0
    readonly property bool hasStatus: status !== "idle" && !readyDismissed
    readonly property bool busy: status === "listening" || status === "transcribing"

    function startFastRefresh() {
        fastRefreshesRemaining = Math.max(fastRefreshesRemaining, 34);
        refresh();
        statusTimer.restart();
    }

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    Timer {
        id: statusTimer

        // Preserve the 180 ms cadence while the worker is active, plus a
        // short burst after a key/button action. Idle state needs no such
        // urgency, so avoid repeatedly spawning dictationctl in the background.
        interval: root.busy || root.fastRefreshesRemaining > 0 ? 180 : 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.fastRefreshesRemaining > 0)
                root.fastRefreshesRemaining--;
            root.refresh();
        }
    }

    IpcHandler {
        target: "dictation"

        function refresh() {
            root.startFastRefresh();
        }
    }

    Process {
        id: statusProcess

        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/dictationctl", "status"]
        stdout: StdioCollector {
            id: statusOutput

            onStreamFinished: {
                try {
                    const next = JSON.parse(statusOutput.text);
                    if (next.state !== "ready")
                        root.readyDismissed = false;
                    else if (root.status !== "ready")
                        readyTimer.restart();
                    root.status = next.state || "idle";
                    root.text = next.text || "";
                    root.detail = next.detail || "";
                } catch (error) {
                    root.status = "error";
                    root.text = "";
                    root.detail = "Dictation status could not be read";
                }
            }
        }
    }

    Timer {
        id: readyTimer

        interval: 3500
        repeat: false
        onTriggered: root.readyDismissed = true
    }

}
