import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    // "inactive" = mozc off, ES pass-through via XKB
    // "active"   = mozc on, Japanese input
    readonly property var methods: [
        { id: "inactive", label: "es", name: "Español" },
        { id: "active",   label: "あ", name: "日本語" }
    ]

    property string currentIM: "inactive"
    property bool ready: false

    readonly property int activeIndex: currentIM === "active" ? 1 : 0

    signal imChanged(string newIM)

    function toggle() {
        toggleProc.running = true
    }

    property string _lastIM: ""

    Process {
        id: imProc
        command: ["bash", "-c",
            "if ! fcitx5-remote --check >/dev/null 2>&1; then echo inactive; " +
            "else s=$(fcitx5-remote 2>/dev/null); " +
            "if [ \"$s\" = '2' ]; then echo active; else echo inactive; fi; fi"]
        stdout: StdioCollector {
            id: imOut
            onStreamFinished: {
                var s = imOut.text.trim()
                if (!s) return
                if (!root.ready) {
                    root._lastIM = s
                    root.currentIM = s
                    root.ready = true
                    return
                }
                if (s !== root._lastIM) {
                    root._lastIM = s
                    root.currentIM = s
                    root.imChanged(s)
                }
            }
        }
    }

    Timer {
        interval: Theme.inputPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!imProc.running) imProc.running = true
    }

    Process {
        id: toggleProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/fcitx-toggle.sh"]
    }

    IpcHandler {
        target: "input"
        function toggle() { root.toggle() }
    }
}
