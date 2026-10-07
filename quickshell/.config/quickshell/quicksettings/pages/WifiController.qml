import QtQuick
import Quickshell.Networking

Item {
    id: controller

    // Kept as part of the page boundary while the controller moves to the
    // native Networking model. The dashboard still supplies this service.
    required property var wifiService
    readonly property var wifiDevice: findWifiDevice()
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var networks: wifiDevice ? wifiDevice.networks : null
    readonly property var connectedNetwork: findConnectedNetwork()
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

    function findWifiDevice() {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    function findConnectedNetwork() {
        const device = wifiDevice;
        if (!device)
            return null;

        const available = device.networks.values;
        for (let i = 0; i < available.length; ++i) {
            if (available[i].connected)
                return available[i];
        }
        return null;
    }

    function networkFor(networkOrSsid) {
        if (networkOrSsid && typeof networkOrSsid !== "string")
            return networkOrSsid;

        const wanted = (networkOrSsid || "").trim();
        const device = wifiDevice;
        if (!device || wanted === "")
            return null;

        const available = device.networks.values;
        for (let i = 0; i < available.length; ++i) {
            if (available[i].name === wanted)
                return available[i];
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
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function onMenuOpen(isOpen) {
        menuOpen = isOpen;
    }

    function securityText(networkOrSecurity) {
        const security = networkOrSecurity && typeof networkOrSecurity !== "number" && typeof networkOrSecurity !== "string"
            ? networkOrSecurity.security : networkOrSecurity;
        return typeof security === "string" ? security : WifiSecurityType.toString(security);
    }

    function isSecureNetwork(networkOrSecurity) {
        const security = networkOrSecurity && typeof networkOrSecurity !== "number" && typeof networkOrSecurity !== "string"
            ? networkOrSecurity.security : networkOrSecurity;
        return security !== WifiSecurityType.Open;
    }

    function isPskNetwork(network) {
        return network && (network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae);
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

        if (reason === ConnectionFailReason.NoSecrets && mode === "saved") {
            openPasswordPrompt(network);
            connectError = "Saved password was rejected. Enter it again.";
            return;
        }
        if (reason === ConnectionFailReason.NoSecrets && mode === "password") {
            passwordClearRequested();
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
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "Network is no longer available";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "Connection timed out";
        if (reason === ConnectionFailReason.WifiClientDisconnected)
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
        if (wifiDevice)
            wifiDevice.scannerEnabled = menuOpen;
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
