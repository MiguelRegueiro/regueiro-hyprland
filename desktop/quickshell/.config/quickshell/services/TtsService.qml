import QtQuick
import Quickshell.Io

Item {
    id: root

    required property var compositorService

    readonly property string commandPath: compositorService.ttsCommandPath

    property string status: "idle"
    property string text: ""
    property string detail: ""
    property real position: 0
    property real duration: 0
    property bool replayReady: false
    property string provider: "kokoro"
    property string voice: "kokoro-michael"
    property string rate: "+50%"
    property bool preferencesPending: false
    property string pendingVoice: ""
    property string pendingRate: ""
    property string pendingProvider: ""
    property bool errorDismissed: false
    property int fastRefreshesRemaining: 0
    readonly property bool hasStatus: status !== "idle" && !errorDismissed
    readonly property bool busy: status === "generating" || status === "playing"

    function refresh() {
        if (!statusProcess.running)
            statusProcess.running = true;
    }

    function startFastRefresh() {
        fastRefreshesRemaining = Math.max(fastRefreshesRemaining, 34);
        refresh();
        statusTimer.restart();
    }

    Timer {
        id: statusTimer

        // Playback/progress stays as responsive as before. The long idle
        // period is deliberately cheaper: status invokes an external client.
        interval: root.busy || root.fastRefreshesRemaining > 0 ? 180 : 1500
        running: root.commandPath.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.fastRefreshesRemaining > 0)
                root.fastRefreshesRemaining--;
            root.refresh();
        }
    }

    Process {
        id: statusProcess
        command: [root.commandPath, "status"]
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
                    const nextProvider = next.provider || root.provider;
                    const nextVoice = next.voice || root.voice;
                    const nextRate = next.rate || root.rate;
                    if (root.preferencesPending && nextProvider === root.pendingProvider && nextVoice === root.pendingVoice && nextRate === root.pendingRate) {
                        root.preferencesPending = false;
                        preferenceTimer.stop();
                    }
                    if (!root.preferencesPending) {
                        root.provider = nextProvider;
                        root.voice = nextVoice;
                        root.rate = nextRate;
                    }
                } catch (error) {
                    root.status = "error";
                    root.replayReady = false;
                    root.text = "";
                    root.detail = "Triton TTS status could not be read";
                }
            }
        }
    }

    function speakClipboard(provider, voice, rate) {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        speakProcess.command = [commandPath, "speak-clipboard", provider, voice, rate];
        speakProcess.running = true;
    }

    function setPreferences(provider, voice, rate) {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        root.provider = provider;
        root.voice = voice;
        root.rate = rate;
        root.pendingVoice = voice;
        root.pendingRate = rate;
        root.pendingProvider = provider;
        root.preferencesPending = true;
        preferenceTimer.restart();
        settingsProcess.command = [commandPath, "settings", provider, voice, rate];
        settingsProcess.running = true;
    }

    function toggle() {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        controlProcess.command = [commandPath, "toggle"];
        controlProcess.running = true;
    }
    function cancel() {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        controlProcess.command = [commandPath, "cancel"];
        controlProcess.running = true;
    }
    function reset() {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        controlProcess.command = [commandPath, "reset"];
        controlProcess.running = true;
    }
    function seek(seconds) {
        if (commandPath.length === 0)
            return;
        startFastRefresh();
        controlProcess.command = [commandPath, "seek", String(seconds)];
        controlProcess.running = true;
    }

    IpcHandler {
        target: "tts"

        function refresh() {
            root.startFastRefresh();
        }
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
