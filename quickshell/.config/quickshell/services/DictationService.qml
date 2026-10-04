import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string status: "idle"
    property string text: ""
    property string detail: ""
    property bool readyDismissed: false
    readonly property bool hasStatus: status !== "idle" && !readyDismissed
    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    Timer {
        interval: 180
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
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
