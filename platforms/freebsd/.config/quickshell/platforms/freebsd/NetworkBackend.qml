import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string networkState: "off"
    property string ethernetState: "unavailable"
    readonly property bool ethernetAvailable: ethernetState === "connected" || ethernetState === "available"
    readonly property bool ethernetConnected: ethernetState === "connected"
    readonly property bool ethernetBusy: ethernetAction.running
    readonly property bool ethernetCanToggle: ethernetAvailable && !ethernetBusy
    readonly property bool wifiConnected: networkState === "wifi_up"
    readonly property string networkIcon: ethernetConnected ? "󰌗" : (wifiConnected ? "󰤨" : "󰤭")

    function refresh() {
        if (!statusPoll.running)
            statusPoll.running = true;
    }

    function toggleEthernet() {
        if (ethernetCanToggle)
            ethernetAction.running = true;
    }

    function updateStatus(output) {
        const lines = String(output || "").trim().split(/\r?\n/);
        networkState = lines[0] || "off";
        ethernetState = lines[1] || (networkState === "eth" ? "connected" : "unavailable");
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statusPoll
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.updateStatus(text)
        }
    }

    Process {
        id: ethernetAction
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", "toggle-ethernet"]
        onExited: root.refresh()
    }
}
