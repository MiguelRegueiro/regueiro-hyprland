import QtQuick
import Quickshell.Networking

// Native Quickshell networking model adapter for the shared Wi-Fi page.
// qmllint disable missing-property
Item {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiDevice: findWifiDevice()
    readonly property var networks: wifiDevice ? wifiDevice.networks : null
    readonly property var connectedNetwork: findConnectedNetwork()

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

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setScannerEnabled(enabled) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = enabled;
    }

    function securityText(security) {
        return typeof security === "string" ? security : WifiSecurityType.toString(security);
    }

    function isOpen(security) {
        return security === WifiSecurityType.Open;
    }

    function isPsk(security) {
        return security === WifiSecurityType.WpaPsk
            || security === WifiSecurityType.Wpa2Psk
            || security === WifiSecurityType.Sae;
    }

    function failureKind(reason) {
        if (reason === ConnectionFailReason.NoSecrets)
            return "no-secrets";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "network-lost";
        if (reason === ConnectionFailReason.WifiAuthTimeout)
            return "auth-timeout";
        if (reason === ConnectionFailReason.WifiClientDisconnected)
            return "client-disconnected";
        return "other";
    }
}
// qmllint enable missing-property
