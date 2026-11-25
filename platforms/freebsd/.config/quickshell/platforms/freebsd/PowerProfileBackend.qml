import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string mode: ""
    readonly property bool hasPerformanceProfile: true

    function setMode(nextMode) {
        if (["power-saver", "balanced", "performance"].includes(nextMode) && !setProc.running) {
            setProc.command = [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-power-profile", "set", nextMode];
            setProc.running = true;
        }
    }

    Component.onCompleted: getProc.running = true

    Process {
        id: getProc
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-power-profile", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.mode = String(text || "").trim()
        }
    }

    Process {
        id: setProc
        command: ["true"]
        stdout: StdioCollector {
            id: setOutput

            onStreamFinished: {
                const value = String(text || "").trim();
                if (value.length > 0)
                    root.mode = value;
            }
        }
        onExited: (exitCode) => {
            if (exitCode === 0 && String(setOutput.text || "").trim().length === 0)
                getProc.running = true;
        }
    }
}
