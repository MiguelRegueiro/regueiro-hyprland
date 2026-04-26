import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme
import "InputMethodMetadata.js" as InputMethodMetadata

Item {
    id: root

    property var methods: []
    property string currentIM: ""
    property string currentGroup: ""
    property string backendState: "unknown"
    property string fcitxState: "unknown"
    property int configuredMethodCount: -1
    property bool ready: false
    property string lastError: ""
    readonly property bool busy: statusProc.running || switchProc.running
    readonly property bool hasMethods: methods.length > 0
    readonly property bool hasConfiguredMethods: configuredMethodCount > 0
    readonly property bool isAvailable: backendState === "ok" || backendState === "closed"
    readonly property bool hasBackendError: ready && (backendState === "missing" || backendState === "unavailable" || backendState === "error")
    readonly property bool hasConfigurationWarning: ready && !hasBackendError && !busy && configuredMethodCount === 0
    readonly property bool hasProblem: hasBackendError || hasConfigurationWarning
    readonly property bool canCycle: !busy && isAvailable && hasConfiguredMethods
    readonly property int activeIndex: {
        var index = root._findMethodIndex(currentIM);
        return index >= 0 ? index : (methods.length > 0 ? 0 : -1);
    }
    readonly property var currentMethod: {
        if (activeIndex >= 0)
            return methods[activeIndex];

        if (methods.length > 0)
            return methods[0];

        return InputMethodMetadata.metadataFor(currentIM);
    }
    readonly property string currentLabel: currentMethod.label
    readonly property string currentName: currentMethod.name
    readonly property string indicatorLabel: {
        if (!ready)
            return "…";

        if (hasBackendError)
            return "IM";

        if (hasConfigurationWarning)
            return "--";

        return currentLabel;
    }
    readonly property string statusTitle: _statusTitle()
    readonly property string statusDetail: _statusDetail()
    readonly property string backendScript: Quickshell.env("HOME") + "/.config/hypr/scripts/fcitx-toggle.sh"

    signal imChanged(string newIM)

    function refresh() {
        if (busy || statusProc.running)
            return ;

        statusProc.command = [backendScript, "describe"];
        statusProc.running = true;
    }

    function toggle() {
        cycleNext();
    }

    function cycleNext() {
        _runCommand(["cycle-next"]);
    }

    function switchToMethod(methodId) {
        var targetMethod = (methodId || "").trim();
        if (targetMethod.length === 0) {
            lastError = "Missing input method name";
            return ;
        }
        _runCommand(["switch", targetMethod]);
    }

    function _runCommand(commandArgs) {
        if (busy) {
            lastError = "Another input method request is still running";
            return ;
        }
        lastError = "";
        switchProc.command = [backendScript].concat(commandArgs);
        switchProc.running = true;
    }

    function _parseBackendOutput(rawText) {
        var data = {
            "backend": "unknown",
            "fcitxState": "unknown",
            "configuredMethodCount": -1,
            "group": "",
            "current": "",
            "methods": []
        };
        var lines = (rawText || "").split(/\r?\n/);
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (!line)
                continue;

            var separatorIndex = line.indexOf("=");
            if (separatorIndex <= 0)
                continue;

            var key = line.slice(0, separatorIndex);
            var value = line.slice(separatorIndex + 1);
            if (key === "backend")
                data.backend = value;
            else if (key === "fcitx_state")
                data.fcitxState = value;
            else if (key === "configured_methods")
                data.configuredMethodCount = Math.max(0, Number(value));
            else if (key === "group")
                data.group = value;
            else if (key === "current")
                data.current = value;
            else if (key === "method" && value.length > 0)
                data.methods.push(value);
        }
        return data;
    }

    function _backendMessage(backend) {
        if (backend === "ok" || backend === "closed")
            return "";

        if (backend === "missing")
            return "fcitx5-remote is not installed";

        if (backend === "unavailable")
            return "fcitx5 is not running";

        return "Unexpected input backend status: " + backend;
    }

    function _statusTitle() {
        if (!ready)
            return "Loading input methods";

        if (backendState === "missing")
            return "fcitx5-remote missing";

        if (backendState === "unavailable")
            return "Fcitx not running";

        if (backendState === "error")
            return "Input backend error";

        if (!hasConfiguredMethods)
            return "No methods configured";

        return currentName || "Input method";
    }

    function _statusDetail() {
        if (!ready)
            return "Waiting for the Fcitx backend state.";

        if (backendState === "missing")
            return "Install fcitx5-remote to enable the indicator and method switching.";

        if (backendState === "unavailable")
            return "Start fcitx5 to enable the indicator and method switching.";

        if (backendState === "error")
            return lastError.length > 0 ? lastError : "Failed to query the Fcitx backend.";

        if (!hasConfiguredMethods) {
            if (currentGroup.length > 0)
                return "Group \"" + currentGroup + "\" has no configured methods.";

            return "Add at least one method in Fcitx 5 configuration.";
        }
        if (currentGroup.length > 0)
            return "Group: " + currentGroup;

        if (fcitxState === "closed")
            return "Input method is currently closed.";

        return "Click to cycle methods.";
    }

    function _containsMethodId(methodId) {
        if (!methodId || methodId.length === 0)
            return false;

        for (var i = 0; i < methods.length; i++) {
            if (methods[i].id === methodId)
                return true;

        }
        return false;
    }

    function _findMethodIndex(methodId) {
        if (!methodId || methodId.length === 0)
            return -1;

        for (var i = 0; i < methods.length; i++) {
            if (methods[i].id === methodId)
                return i;

        }
        return -1;
    }

    function _setMethods(methodIds, fallbackCurrent) {
        if (methodIds.length > 0) {
            methods = InputMethodMetadata.buildMethods(methodIds, fallbackCurrent);
            return ;
        }
        if (fallbackCurrent && fallbackCurrent.length > 0) {
            methods = InputMethodMetadata.buildMethods([], fallbackCurrent);
            return ;
        }
        methods = [];
    }

    function _preferredCurrentIM(parsedCurrent) {
        if (parsedCurrent && parsedCurrent.length > 0)
            return parsedCurrent;

        if (methods.length > 0)
            return root._containsMethodId(currentIM) ? currentIM : methods[0].id;

        return "";
    }

    function _setCurrentIM(nextIM, emitChange) {
        var nextValue = nextIM || "";
        if (nextValue === currentIM)
            return ;

        currentIM = nextValue;
        if (emitChange && nextValue.length > 0)
            imChanged(nextValue);

    }

    function _applyBackendOutput(rawText, stderrText, exitCode, emitChanges) {
        var wasReady = ready;
        ready = true;
        if (exitCode !== 0) {
            backendState = "error";
            fcitxState = "unknown";
            lastError = (stderrText || "").trim() || "Failed to query input method backend";
            return ;
        }
        var parsed = _parseBackendOutput(rawText);
        backendState = parsed.backend;
        fcitxState = parsed.fcitxState;
        configuredMethodCount = parsed.configuredMethodCount;
        currentGroup = parsed.group;
        _setMethods(parsed.methods, parsed.current);
        lastError = _backendMessage(parsed.backend);
        if (lastError.length > 0 && parsed.backend !== "missing" && parsed.backend !== "unavailable")
            lastError = (stderrText || "").trim() || lastError;

        _setCurrentIM(_preferredCurrentIM(parsed.current), wasReady && emitChanges && parsed.backend === "ok");
    }

    Process {
        id: statusProc

        command: [root.backendScript, "describe"]
        onExited: (code) => {
            root._applyBackendOutput(statusStdout.text, statusStderr.text, code, true);
        }

        stdout: StdioCollector {
            id: statusStdout
        }

        stderr: StdioCollector {
            id: statusStderr
        }

    }

    Timer {
        interval: Theme.inputPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: switchProc

        command: ["echo"]
        onExited: (code) => {
            root._applyBackendOutput(switchStdout.text, switchStderr.text, code, true);
            root.refresh();
        }

        stdout: StdioCollector {
            id: switchStdout
        }

        stderr: StdioCollector {
            id: switchStderr
        }

    }

    IpcHandler {
        function refresh() {
            root.refresh();
        }

        function toggle() {
            root.toggle();
        }

        function cycleNext() {
            root.cycleNext();
        }

        function switchToMethod(methodId: string) {
            root.switchToMethod(methodId);
        }

        target: "input"
    }

}
