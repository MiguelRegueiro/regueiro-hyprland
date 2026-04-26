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
    property bool ready: false
    property string lastError: ""

    readonly property bool busy: statusProc.running || switchProc.running
    readonly property bool isAvailable: backendState === "ok" || backendState === "closed"
    readonly property int activeIndex: {
        var index = root._findMethodIndex(currentIM)
        return index >= 0 ? index : (methods.length > 0 ? 0 : -1)
    }
    readonly property var currentMethod: {
        if (activeIndex >= 0)
            return methods[activeIndex]
        if (methods.length > 0)
            return methods[0]
        return InputMethodMetadata.metadataFor(currentIM)
    }
    readonly property string currentLabel: currentMethod.label
    readonly property string currentName: currentMethod.name
    readonly property string backendScript: Quickshell.env("HOME") + "/.config/hypr/scripts/fcitx-toggle.sh"

    signal imChanged(string newIM)

    function refresh() {
        if (busy || statusProc.running)
            return

        statusProc.command = [backendScript, "describe"]
        statusProc.running = true
    }

    function toggle() {
        cycleNext()
    }

    function cycleNext() {
        _runCommand(["cycle-next"])
    }

    function switchToMethod(methodId) {
        var targetMethod = (methodId || "").trim()
        if (targetMethod.length === 0) {
            lastError = "Missing input method name"
            return
        }

        _runCommand(["switch", targetMethod])
    }

    function _runCommand(commandArgs) {
        if (busy) {
            lastError = "Another input method request is still running"
            return
        }

        lastError = ""
        switchProc.command = [backendScript].concat(commandArgs)
        switchProc.running = true
    }

    function _parseBackendOutput(rawText) {
        var data = {
            backend: "unknown",
            fcitxState: "unknown",
            group: "",
            current: "",
            methods: []
        }
        var lines = (rawText || "").split(/\r?\n/)
        var i

        for (i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (!line)
                continue

            var separatorIndex = line.indexOf("=")
            if (separatorIndex <= 0)
                continue

            var key = line.slice(0, separatorIndex)
            var value = line.slice(separatorIndex + 1)

            if (key === "backend")
                data.backend = value
            else if (key === "fcitx_state")
                data.fcitxState = value
            else if (key === "group")
                data.group = value
            else if (key === "current")
                data.current = value
            else if (key === "method" && value.length > 0)
                data.methods.push(value)
        }

        return data
    }

    function _backendMessage(backend) {
        if (backend === "ok" || backend === "closed")
            return ""
        if (backend === "missing")
            return "fcitx5-remote is not installed"
        if (backend === "unavailable")
            return "fcitx5 is not running"

        return "Unexpected input backend status: " + backend
    }

    function _containsMethodId(methodId) {
        if (!methodId || methodId.length === 0)
            return false

        for (var i = 0; i < methods.length; i++) {
            if (methods[i].id === methodId)
                return true
        }

        return false
    }

    function _findMethodIndex(methodId) {
        if (!methodId || methodId.length === 0)
            return -1

        for (var i = 0; i < methods.length; i++) {
            if (methods[i].id === methodId)
                return i
        }

        return -1
    }

    function _setMethods(methodIds, fallbackCurrent) {
        if (methodIds.length > 0) {
            methods = InputMethodMetadata.buildMethods(methodIds, fallbackCurrent)
            return
        }

        if (fallbackCurrent && fallbackCurrent.length > 0) {
            methods = InputMethodMetadata.buildMethods([], fallbackCurrent)
            return
        }
    }

    function _preferredCurrentIM(parsedCurrent) {
        if (parsedCurrent && parsedCurrent.length > 0)
            return parsedCurrent

        if (root._containsMethodId(currentIM))
            return currentIM

        if (methods.length > 0)
            return methods[0].id

        return currentIM
    }

    function _setCurrentIM(nextIM, emitChange) {
        if (!nextIM || nextIM.length === 0)
            return

        if (nextIM !== currentIM) {
            currentIM = nextIM
            if (emitChange)
                imChanged(nextIM)
        }
    }

    function _applyBackendOutput(rawText, stderrText, exitCode, emitChanges) {
        var wasReady = ready
        ready = true

        if (exitCode !== 0) {
            backendState = "error"
            fcitxState = "unknown"
            lastError = (stderrText || "").trim() || "Failed to query input method backend"
            return
        }

        var parsed = _parseBackendOutput(rawText)
        backendState = parsed.backend
        fcitxState = parsed.fcitxState
        currentGroup = parsed.group
        _setMethods(parsed.methods, parsed.current)
        lastError = _backendMessage(parsed.backend)

        if (lastError.length > 0 && parsed.backend !== "missing" && parsed.backend !== "unavailable")
            lastError = (stderrText || "").trim() || lastError

        _setCurrentIM(
            _preferredCurrentIM(parsed.current),
            wasReady && emitChanges && parsed.backend === "ok"
        )
    }

    Process {
        id: statusProc
        command: [root.backendScript, "describe"]
        stdout: StdioCollector {
            id: statusStdout
        }
        stderr: StdioCollector {
            id: statusStderr
        }
        onExited: code => {
            root._applyBackendOutput(statusStdout.text, statusStderr.text, code, true)
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
        stdout: StdioCollector {
            id: switchStdout
        }
        stderr: StdioCollector {
            id: switchStderr
        }
        onExited: code => {
            root._applyBackendOutput(switchStdout.text, switchStderr.text, code, true)
            root.refresh()
        }
    }

    IpcHandler {
        target: "input"

        function refresh() {
            root.refresh()
        }

        function toggle() {
            root.toggle()
        }

        function cycleNext() {
            root.cycleNext()
        }

        function switchToMethod(methodId: string) {
            root.switchToMethod(methodId)
        }
    }
}
