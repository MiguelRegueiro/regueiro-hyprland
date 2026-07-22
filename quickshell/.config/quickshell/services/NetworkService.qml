import QtQuick
import Quickshell.Networking

Item {
    id: root

    readonly property var ethernetDevice: findEthernetDevice()
    readonly property bool ethernetAvailable: ethernetDevice !== null
    readonly property bool ethernetConnected: ethernetAvailable && ethernetDevice.connected
    readonly property bool ethernetBusy: ethernetAvailable && (ethernetDevice.state === ConnectionState.Connecting || ethernetDevice.state === ConnectionState.Disconnecting)
    readonly property bool ethernetCanToggle: ethernetAvailable && ethernetDevice.hasLink && ethernetDevice.network !== null && !ethernetBusy
    readonly property bool wifiConnected: hasConnectedWifi()
    readonly property string networkIcon: ethernetConnected ? "󰌗" : (wifiConnected ? "󰤨" : "󰤭")

    function isPhysicalEthernet(device) {
        return device.name.length > 0 && !/^(docker|br[0-9]|virbr|veth)/.test(device.name);
    }

    function findEthernetDevice() {
        const devices = Networking.devices.values;
        let fallback = null;
        for (let i = 0; i < devices.length; ++i) {
            const device = devices[i];
            if (device.type !== DeviceType.Wired || !isPhysicalEthernet(device))
                continue;

            if (device.connected)
                return device;

            if (fallback === null)
                fallback = device;
        }
        return fallback;
    }

    function hasConnectedWifi() {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wifi && devices[i].connected)
                return true;
        }
        return false;
    }

    function toggleEthernet() {
        if (!ethernetCanToggle)
            return ;

        if (ethernetConnected)
            ethernetDevice.disconnect();
        else
            ethernetDevice.network.connect();
    }
}
