import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property string networkState: "off"
    property string ethernetState: "unavailable"
    readonly property string helperPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/freebsd-wifi.sh"
    readonly property bool ethernetAvailable: ethernetState === "connected" || ethernetState === "available"
    readonly property bool ethernetConnected: ethernetState === "connected"
    readonly property bool ethernetCanToggle: ethernetAvailable && !ethernetAction.running
    readonly property bool wifiConnected: networkState === "wifi_up"
    readonly property string networkIcon: ethernetConnected ? "󰌗" : (wifiConnected ? "󰤨" : "󰤭")

    function refresh() {
        if (!networkPoll.running)
            networkPoll.running = true;

    }

    function updateStatus(text) {
        const lines = text.trim().split(/\r?\n/);
        const nextNetworkState = lines.length > 0 && lines[0].length > 0 ? lines[0] : "off";
        const nextEthernetState = lines.length > 1 && lines[1].length > 0 ? lines[1] : (nextNetworkState === "eth" ? "connected" : "unavailable");
        root.networkState = nextNetworkState;
        root.ethernetState = nextEthernetState;
    }

    function toggleEthernet() {
        if (!root.ethernetCanToggle)
            return ;

        ethernetAction.running = true;
    }

    Timer {
        interval: Theme.networkPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: networkPoll

        command: [root.helperPath, "status"]

        stdout: StdioCollector {
            id: networkOut

            onStreamFinished: root.updateStatus(networkOut.text)
        }

    }

    Process {
        id: ethernetAction

        command: [root.helperPath, "toggle-ethernet"]
        onExited: root.refresh()
    }
}
