import QtQuick

Item {
    id: controller

    required property var platformService
    readonly property bool wifiAdapterAvailable: platformService.hasWifiAdapter && wifiBackend.status === Loader.Ready
    readonly property var wifiDevice: wifiAdapterAvailable ? wifiBackend.item["wifiDevice"] : null
    readonly property bool wifiOn: wifiAdapterAvailable && wifiBackend.item["wifiEnabled"]
    readonly property var networks: wifiAdapterAvailable ? wifiBackend.item["networks"] : null
    readonly property var connectedNetwork: wifiAdapterAvailable ? wifiBackend.item["connectedNetwork"] : null
    readonly property string connectedSsid: connectedNetwork ? connectedNetwork.name : ""

    property bool needsFocus: false
    property string connectSsid: ""
    property string connectSecurity: ""
    property bool connectSecure: false
    property bool showPassword: false
    property bool connecting: false
    property bool menuOpen: false
    property string connectMode: ""
    property string connectError: ""
    property var targetNetwork: null
    property var forgetTarget: null
    property string forgetConfirmSsid: ""
    property string forgetBusySsid: ""
    property string forgetResultSsid: ""
    property bool forgetResultOk: false
    readonly property bool showStatus: connecting || connectError !== ""

    signal passwordClearRequested()
    signal passwordFocusRequested()

    onMenuOpenChanged: syncScanner()
    onWifiDeviceChanged: syncScanner()

    function networkFor(networkOrSsid) {
        if (networkOrSsid && typeof networkOrSsid !== "string")
            return networkOrSsid;

        const wanted = (networkOrSsid || "").trim();
        const available = networks;
        if (!available || wanted === "")
            return null;

        const values = available.values;
        for (let i = 0; i < values.length; ++i) {
            if (values[i].name === wanted)
                return values[i];
        }
        return null;
    }

    function promptOpen() {
        return connectSsid !== "" && connectSecure;
    }

    function statusText() {
        if (connecting)
            return connectSsid !== "" ? "Connecting to " + connectSsid + "…" : "Connecting…";
        return connectError;
    }

    function toggle() {
        if (wifiAdapterAvailable)
            wifiBackend.item["toggleWifi"]();
    }

    function onMenuOpen(isOpen) {
        menuOpen = isOpen;
    }

    function securityText(networkOrSecurity) {
        const security = networkOrSecurity && typeof networkOrSecurity !== "number" && typeof networkOrSecurity !== "string"
            ? networkOrSecurity.security : networkOrSecurity;
        return wifiAdapterAvailable ? wifiBackend.item["securityText"](security) : String(security || "");
    }

    function isSecureNetwork(networkOrSecurity) {
        const security = networkOrSecurity && typeof networkOrSecurity !== "number" && typeof networkOrSecurity !== "string"
            ? networkOrSecurity.security : networkOrSecurity;
        return !wifiAdapterAvailable || !wifiBackend.item["isOpen"](security);
    }

    function isPskNetwork(network) {
        return network && wifiAdapterAvailable && wifiBackend.item["isPsk"](network.security);
    }

    function hasSavedProfile(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        return !!(network && network.known);
    }

    function networkStatusText(network) {
        if (network.connected)
            return "Connected";
        if (network.known)
            return "Saved network";
        return isSecureNetwork(network) ? "Secured network" : "Open network";
    }

    function signalPercent(network) {
        return network ? Math.round(network.signalStrength * 100) : 0;
    }

    function openPasswordPrompt(networkOrSsid, security) {
        const network = networkFor(networkOrSsid);
        if (!network)
            return;

        _clearForgetState();
        targetNetwork = network;
        connectSsid = network.name;
        connectSecurity = security || securityText(network);
        connectSecure = true;
        showPassword = false;
        connecting = false;
        connectMode = "password";
        connectError = "";
        passwordClearRequested();
        focusTimer.restart();
    }

    function connectOpenNetwork(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        if (!network)
            return;

        _beginConnect(network, "open");
        network.connect();
    }

    function connectSavedSecureNetwork(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        if (!network)
            return;

        _beginConnect(network, "saved");
        network.connect();
    }

    function doConnect(pwd) {
        if (connecting || !targetNetwork)
            return;

        connectError = _validatePassword(pwd);
        if (connectError !== "") {
            passwordFocusRequested();
            return;
        }
        if (!isPskNetwork(targetNetwork)) {
            connectError = "This network requires a security method that is not supported here";
            passwordFocusRequested();
            return;
        }

        connecting = true;
        connectMode = "password";
        targetNetwork.connectWithPsk(pwd);
    }

    function cancel() {
        passwordClearRequested();
        targetNetwork = null;
        connectSsid = "";
        connectSecurity = "";
        connectSecure = false;
        showPassword = false;
        connecting = false;
        connectMode = "";
        connectError = "";
        needsFocus = false;
    }

    function confirmForget(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        if (connecting || forgetBusySsid !== "" || !network)
            return;

        forgetResultSsid = "";
        forgetResultOk = false;
        forgetConfirmSsid = network.name;
    }

    function cancelForget(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        if (network && forgetConfirmSsid === network.name)
            forgetConfirmSsid = "";
    }

    function forgetNetwork(networkOrSsid) {
        const network = networkFor(networkOrSsid);
        if (!network || forgetBusySsid !== "")
            return;

        forgetConfirmSsid = "";
        forgetResultSsid = "";
        forgetResultOk = false;
        forgetTarget = network;
        forgetBusySsid = network.name;
        network.forget();
    }

    function _beginConnect(network, mode) {
        _clearForgetState();
        targetNetwork = network;
        connectSsid = network.name;
        connectSecurity = securityText(network);
        connectSecure = false;
        showPassword = false;
        connecting = true;
        connectMode = mode;
        connectError = "";
    }

    function _clearForgetState() {
        forgetTarget = null;
        forgetConfirmSsid = "";
        forgetBusySsid = "";
        forgetResultSsid = "";
        forgetResultOk = false;
    }

    function _finishConnectSuccess() {
        passwordClearRequested();
        targetNetwork = null;
        connectSsid = "";
        connectSecurity = "";
        connectSecure = false;
        showPassword = false;
        connecting = false;
        connectMode = "";
        connectError = "";
        needsFocus = false;
    }

    function _handleConnectionFailure(reason) {
        const network = targetNetwork;
        const mode = connectMode;
        connecting = false;

        const kind = wifiAdapterAvailable ? wifiBackend.item["failureKind"](reason) : "other";
        if (kind === "no-secrets" && mode === "saved") {
            openPasswordPrompt(network);
            connectError = "Saved password was rejected. Enter it again.";
            return;
        }
        if (kind === "no-secrets" && mode === "password") {
            connectError = "Password rejected. Try again.";
            passwordFocusRequested();
            return;
        }

        connectError = _failureText(reason);
        if (mode === "password")
            passwordFocusRequested();
        else
            targetNetwork = null;
    }

    function _failureText(reason) {
        if (!wifiAdapterAvailable)
            return "Could not connect to this network";
        const kind = wifiBackend.item["failureKind"](reason);
        if (kind === "network-lost")
            return "Network is no longer available";
        if (kind === "auth-timeout")
            return "Connection timed out";
        if (kind === "client-disconnected")
            return "Wi-Fi disconnected while connecting";
        return "Could not connect to this network";
    }

    function _validatePassword(pwd) {
        if (pwd.length === 0)
            return "Enter a password";
        if (pwd.length < 8)
            return "WPA password must be at least 8 characters";
        if (pwd.length > 64)
            return "WPA password must be 8-63 chars, or 64 hex digits";
        if (pwd.length === 64 && !/^[0-9A-Fa-f]{64}$/.test(pwd))
            return "A 64-character WPA key must use only 0-9 and A-F";
        return "";
    }

    function syncScanner() {
        if (wifiAdapterAvailable)
            wifiBackend.item["setScannerEnabled"](menuOpen);
    }

    Loader {
        id: wifiBackend
        active: controller.platformService.hasWifiAdapter
        source: !active ? "" : controller.platformService.isLinux
            ? Qt.resolvedUrl("../../platforms/linux/WifiBackend.qml")
            : Qt.resolvedUrl("../../platforms/freebsd/WifiBackend.qml")
    }

    Timer {
        id: focusTimer
        interval: 80
        onTriggered: passwordFocusRequested()
    }

    // This only clears the UI acknowledgement; it never drives network state.
    Timer {
        id: forgetResultClearTimer
        interval: 2200
        onTriggered: {
            forgetResultSsid = "";
            forgetResultOk = false;
        }
    }

    Connections {
        target: controller.targetNetwork

        function onConnectedChanged() {
            if (target.connected && controller.connecting)
                controller._finishConnectSuccess();
        }

        function onConnectionFailed(reason) {
            controller._handleConnectionFailure(reason);
        }
    }

    Connections {
        target: controller.forgetTarget

        function onKnownChanged() {
            if (controller.forgetBusySsid === "")
                return;

            controller.forgetBusySsid = "";
            controller.forgetResultSsid = target.name;
            controller.forgetResultOk = !target.known;
            controller.forgetTarget = null;
            forgetResultClearTimer.restart();
        }
    }
}
