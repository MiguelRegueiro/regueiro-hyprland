import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: controller

    required property var wifiService

    property bool wifiOn: false
    property string connectedSsid: ""
    property bool needsFocus: false
    property var networks: []

    property string connectSsid: ""
    property string connectSecurity: ""
    property bool connectSecure: false
    property bool showPassword: false
    property bool connecting: false
    property bool awaitingActivation: false
    property string connectMode: ""
    property int activationChecks: 0
    property string connectError: ""
    property string forgetConfirmSsid: ""
    property string forgetBusySsid: ""
    property string forgetResultSsid: ""
    property bool forgetResultOk: false
    readonly property bool showStatus: connecting || connectError !== ""

    signal passwordClearRequested()
    signal passwordFocusRequested()

    function promptOpen() {
        return connectSsid !== "" && connectSecure
    }

    function statusText() {
        if (connecting)
            return connectSsid !== "" ? "Connecting to " + connectSsid + "…" : "Connecting…"
        return connectError
    }

    function toggle() {
        wifiOn = !wifiOn
        wifiToggleProc.running = true
        afterToggle.start()
    }

    function openPasswordPrompt(ssid, security) {
        _stopActivationCheck()
        _clearForgetState()
        connectSsid = ssid
        connectSecurity = security || ""
        connectSecure = true
        showPassword = false
        connecting = false
        connectMode = "password"
        connectError = ""
        passwordClearRequested()
        focusTimer.restart()
    }

    function sigIcon(pct) {
        if (pct < 25) return "󰤟"
        if (pct < 50) return "󰤢"
        if (pct < 75) return "󰤥"
        return "󰤨"
    }

    function hasSavedProfile(ssid) {
        return wifiService.findSavedProfileName(ssid) !== ""
    }

    function networkStatusText(network) {
        if (network.active) return "Connected"
        if (hasSavedProfile(network.ssid)) return "Saved network"
        return ((network.security || "") !== "") ? "Secured network" : "Open network"
    }

    function onMenuOpen(isOpen) {
        if (isOpen) {
            pollProc.running = true
            wifiService.refreshSavedProfiles()
        }
    }

    function connectOpenNetwork(ssid) {
        _beginInlineConnect(ssid, "")
        connectMode = "open"
        if (!wifiService.connect(ssid, "", function(result) {
            if (result && result.success) {
                _startActivationCheck("open")
                return
            }
            _stopActivationCheck()
            connecting = false
            connectError = wifiService.describeFailure(result, false)
        })) {
            connecting = false
            connectError = "Another Wi-Fi request is still running"
        }
    }

    function connectSavedSecureNetwork(network) {
        _beginInlineConnect(network.ssid, network.security || "")
        connectMode = "saved"
        if (!wifiService.connect(network.ssid, "", function(result) {
            if (result && result.success) {
                _startActivationCheck("saved")
                return
            }
            _stopActivationCheck()
            connecting = false
            if (result && result.needsPassword) {
                openPasswordPrompt(network.ssid, network.security || "")
                connectError = "Saved password was rejected. Enter it again."
                return
            }
            connectError = wifiService.describeFailure(result, false)
        })) {
            connecting = false
            connectError = "Another Wi-Fi request is still running"
        }
    }

    function doConnect(pwd) {
        if (connecting) return
        connectError = _validatePassword(pwd)
        if (connectError !== "") {
            passwordFocusRequested()
            return
        }
        connecting = true
        connectMode = "password"
        if (!wifiService.connect(connectSsid, pwd, function(result) {
            if (result && result.success) {
                _startActivationCheck("password")
                return
            }
            _stopActivationCheck()
            connecting = false
            if (result && (result.needsPassword || wifiService.detectAuthenticationError(result.error || "")))
                passwordClearRequested()
            connectError = wifiService.describeFailure(result, true)
            passwordFocusRequested()
        })) {
            connecting = false
            connectError = "Another Wi-Fi request is still running"
        }
    }

    function cancel() {
        _stopActivationCheck()
        passwordClearRequested()
        connectSsid = ""
        connectSecurity = ""
        connectSecure = false
        showPassword = false
        connecting = false
        connectMode = ""
        connectError = ""
        needsFocus = false
    }

    function confirmForget(ssid) {
        if (connecting || forgetBusySsid !== "" || ssid === "") return
        forgetResultSsid = ""
        forgetResultOk = false
        forgetConfirmSsid = ssid
    }

    function cancelForget(ssid) {
        if (forgetConfirmSsid === ssid) forgetConfirmSsid = ""
    }

    function forgetNetwork(ssid) {
        const target = (ssid || "").trim()
        if (target.length === 0 || forgetBusySsid !== "") return
        forgetConfirmSsid = ""
        forgetResultSsid = ""
        forgetResultOk = false
        forgetBusySsid = target
        if (!wifiService.forgetNetwork(target, function(result) {
            forgetBusySsid = ""
            forgetResultSsid = target
            forgetResultOk = !!(result && result.success)
            pollProc.running = true
            forgetResultClearTimer.restart()
        })) {
            forgetBusySsid = ""
            forgetResultSsid = target
            forgetResultOk = false
            forgetResultClearTimer.restart()
        }
    }

    function _beginInlineConnect(ssid, security) {
        _stopActivationCheck()
        _clearForgetState()
        connectSsid = ssid || ""
        connectSecurity = security || ""
        connectSecure = false
        showPassword = false
        connecting = true
        connectError = ""
    }

    function _clearForgetState() {
        forgetConfirmSsid = ""
        forgetBusySsid = ""
        forgetResultSsid = ""
        forgetResultOk = false
    }

    function _ssidMatches(left, right) {
        return (left || "").trim().toLowerCase() === (right || "").trim().toLowerCase()
    }

    function _startActivationCheck(mode) {
        connectMode = mode || connectMode
        awaitingActivation = true
        activationChecks = 0
        if (!pollProc.running) pollProc.running = true
        activationTimer.start()
    }

    function _stopActivationCheck() {
        awaitingActivation = false
        activationChecks = 0
        activationTimer.stop()
    }

    function _forgetFailedTarget() {
        wifiService.forgetNetwork(connectSsid)
    }

    function _handleActivationTimeout() {
        const failedSsid = connectSsid
        const failedSecurity = connectSecurity
        const failedMode = connectMode
        _stopActivationCheck()
        connecting = false
        if (failedMode === "saved") {
            _forgetFailedTarget()
            openPasswordPrompt(failedSsid, failedSecurity)
            connectError = "Saved password was rejected. Enter it again."
            return
        }
        if (failedMode === "password") {
            _forgetFailedTarget()
            passwordClearRequested()
            connectError = "Password rejected. Try again."
            passwordFocusRequested()
            return
        }
        connectError = "Connection timed out"
    }

    function _finishConnectSuccess() {
        _stopActivationCheck()
        passwordClearRequested()
        connectSsid = ""
        connectSecurity = ""
        connectSecure = false
        showPassword = false
        connecting = false
        connectMode = ""
        connectError = ""
        needsFocus = false
        wifiService.refreshSavedProfiles()
        afterConnect.start()
    }

    function _isWpaSecurity(security) {
        var sec = (security || "").toUpperCase()
        return sec.indexOf("WPA") >= 0 || sec.indexOf("PSK") >= 0 || sec.indexOf("SAE") >= 0
    }

    function _validatePassword(pwd) {
        if (pwd.length === 0) return "Enter a password"
        if (!_isWpaSecurity(connectSecurity)) return ""
        if (pwd.length < 8) return "WPA password must be at least 8 characters"
        if (pwd.length > 64) return "WPA password must be 8-63 chars, or 64 hex digits"
        if (pwd.length === 64 && !/^[0-9A-Fa-f]{64}$/.test(pwd))
            return "A 64-character WPA key must use only 0-9 and A-F"
        return ""
    }

    Timer { id: focusTimer;   interval: 80;   onTriggered: passwordFocusRequested() }
    Timer { id: afterToggle;  interval: 700;  onTriggered: pollProc.running = true }
    Timer { id: afterConnect; interval: 3500; onTriggered: pollProc.running = true }

    Timer {
        id: forgetResultClearTimer
        interval: 2200
        onTriggered: {
            forgetResultSsid = ""
            forgetResultOk = false
            pollProc.running = true
        }
    }

    Timer {
        id: activationTimer
        interval: 900
        repeat: true
        onTriggered: {
            if (!awaitingActivation) { stop(); return }
            if (_ssidMatches(connectedSsid, connectSsid)) { _finishConnectSuccess(); return }
            activationChecks += 1
            if (activationChecks >= 8) { _handleActivationTimeout(); return }
            if (!pollProc.running) pollProc.running = true
        }
    }

    Timer {
        interval: 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pollProc.running = true
    }

    Process {
        id: pollProc
        command: ["bash", "-c",
            "echo \"wifi:$(nmcli radio wifi 2>/dev/null)\";" +
            "echo \"ssid:$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -1)\";" +
            "nmcli -t -m multiline -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list 2>/dev/null | sed 's/^/NET:/'"
        ]
        environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
        stdout: StdioCollector {
            id: pollData
            onStreamFinished: {
                var lines = pollData.text.split("\n")
                var list = [], cur = null
                for (var i = 0; i < lines.length; i++) {
                    var raw = lines[i]
                    if (raw.startsWith("wifi:")) {
                        controller.wifiOn = raw.slice(5).trim() === "enabled"; continue
                    }
                    if (raw.startsWith("ssid:")) {
                        controller.connectedSsid = raw.slice(5).trim(); continue
                    }
                    if (!raw.startsWith("NET:")) continue
                    var line = raw.slice(4)
                    var ci = line.indexOf(":")
                    if (ci < 0) continue
                    var key = line.slice(0, ci).replace(/\[\d+\]$/, "")
                    var val = line.slice(ci + 1).replace(/\\:/g, ":")
                    if (key === "IN-USE") {
                        if (cur && cur.ssid !== undefined) list.push(cur)
                        cur = { active: val.trim() === "*" }
                    } else if (cur) {
                        if      (key === "SSID")     cur.ssid     = val
                        else if (key === "SECURITY") cur.security = val
                        else if (key === "SIGNAL")   cur.signal   = parseInt(val) || 0
                    }
                }
                if (cur && cur.ssid !== undefined) list.push(cur)
                var seen = {}
                list.forEach(n => {
                    if (!n.ssid) return
                    if (!seen[n.ssid] || n.active || n.signal > (seen[n.ssid].signal || 0))
                        seen[n.ssid] = n
                })
                controller.networks = Object.values(seen).sort((a, b) => {
                    if (a.active && !b.active) return -1
                    if (!a.active && b.active) return 1
                    return (b.signal || 0) - (a.signal || 0)
                })
                if (controller.awaitingActivation && _ssidMatches(controller.connectedSsid, controller.connectSsid))
                    _finishConnectSuccess()
            }
        }
    }

    Process {
        id: wifiToggleProc
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/wifi-toggle.sh"]
    }
}
