import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string status: "idle"
    property string text: ""
    property string detail: ""
    property real position: 0
    property real duration: 0
    property bool replayReady: false
    property string voice: "en-US-AndrewMultilingualNeural"
    property string rate: "+50%"
    property bool preferencesPending: false
    property string pendingVoice: ""
    property string pendingRate: ""
    property bool errorDismissed: false
    readonly property bool hasStatus: status !== "idle" && !errorDismissed

    Timer {
        interval: 180
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running)
                statusProcess.running = true;
        }
    }

    Process {
        id: statusProcess
        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "status"]
        stdout: StdioCollector {
            id: statusOutput
            onStreamFinished: {
                try {
                    const next = JSON.parse(statusOutput.text);
                    if (next.state !== "error")
                        root.errorDismissed = false;
                    else if (root.status !== "error")
                        errorTimer.restart();
                    root.text = next.text || "";
                    root.detail = next.detail || "";
                    root.position = Number(next.position) || 0;
                    root.duration = Number(next.duration) || 0;
                    // Set this before status so the OSD never mistakes a
                    // completed reading for a manual pause.
                    root.replayReady = Boolean(next.replayReady);
                    root.status = next.state || "idle";
                    const nextVoice = next.voice || root.voice;
                    const nextRate = next.rate || root.rate;
                    if (root.preferencesPending && nextVoice === root.pendingVoice && nextRate === root.pendingRate) {
                        root.preferencesPending = false;
                        preferenceTimer.stop();
                    }
                    if (!root.preferencesPending) {
                        root.voice = nextVoice;
                        root.rate = nextRate;
                    }
                } catch (error) {
                    root.status = "error";
                    root.replayReady = false;
                    root.text = "";
                    root.detail = "EasyTTS status could not be read";
                }
            }
        }
    }

    function speakClipboard(voice, rate) {
        speakProcess.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "speak-clipboard", voice, rate];
        speakProcess.running = true;
    }

    function setPreferences(voice, rate) {
        root.voice = voice;
        root.rate = rate;
        root.pendingVoice = voice;
        root.pendingRate = rate;
        root.preferencesPending = true;
        preferenceTimer.restart();
        settingsProcess.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "settings", voice, rate];
        settingsProcess.running = true;
    }

    function toggle() {
        controlProcess.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "toggle"];
        controlProcess.running = true;
    }
    function reset() {
        controlProcess.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "reset"];
        controlProcess.running = true;
    }
    function seek(seconds) {
        controlProcess.command = [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ttsctl", "seek", String(seconds)];
        controlProcess.running = true;
    }

    Process {
        id: speakProcess
    }
    Process {
        id: controlProcess
    }
    Process {
        id: settingsProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.preferencesPending = false;
                preferenceTimer.stop();
            }
        }
    }

    Timer {
        id: preferenceTimer
        interval: 3000
        repeat: false
        onTriggered: root.preferencesPending = false
    }

    // A failed request should be visible, but must not remain on screen after
    // Quickshell restarts or when the server is intentionally unavailable.
    Timer {
        id: errorTimer
        interval: 5000
        repeat: false
        onTriggered: root.errorDismissed = true
    }
}
