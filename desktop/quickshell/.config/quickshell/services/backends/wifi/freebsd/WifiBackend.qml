import QtQuick
import Quickshell
import Quickshell.Io

// Adapts the FreeBSD helper's scan/profile commands to the shared Wi-Fi model.
Item {
    id: root

    property bool wifiEnabled: false
    property bool scannerEnabled: false
    property var _networks: []
    property var savedProfiles: []
    property var connectedNetwork: null
    property var pendingConnection: null
    property string pendingPassword: ""
    readonly property var wifiDevice: root
    readonly property var networks: networkCollection

    function setScannerEnabled(enabled) {
        scannerEnabled = enabled;
        if (enabled)
            refresh();
    }

    function toggleWifi() {
        if (!toggleProc.running)
            toggleProc.running = true;
    }

    function refresh() {
        if (!scanProc.running)
            scanProc.running = true;
        if (!profilesProc.running)
            profilesProc.running = true;
    }

    function securityText(security) {
        return String(security || "Open");
    }

    function isOpen(security) {
        return !security || String(security).toLowerCase() === "open";
    }

    function isPsk(security) {
        const value = String(security || "").toUpperCase();
        return value.includes("WPA") || value.includes("RSN");
    }

    function failureKind(reason) {
        return String(reason || "other");
    }

    function decodeEscapes(value) {
        return String(value || "").replace(/\\(.)/g, "$1");
    }

    function updateProfiles(output) {
        const next = [];
        const lines = String(output || "").split(/\r?\n/);
        for (const line of lines) {
            const separator = line.lastIndexOf(":");
            if (separator >= 0 && line.slice(separator + 1).trim() === "wifi")
                next.push(root.decodeEscapes(line.slice(0, separator).trim()).toLowerCase());
        }
        root.savedProfiles = next;
        for (const network of root._networks)
            network.known = next.includes(network.name.toLowerCase());
    }

    function updateScan(output) {
        const lines = String(output || "").split(/\r?\n/);
        let connectedSsid = "";
        let nextWifiEnabled = false;
        const rows = [];
        let row = null;
        for (const rawLine of lines) {
            const line = rawLine.trim();
            if (line.startsWith("wifi:")) {
                nextWifiEnabled = line.slice(5) === "enabled";
            } else if (line.startsWith("ssid:")) {
                connectedSsid = line.slice(5);
            } else if (line.startsWith("NET:IN-USE:")) {
                if (row && row.name)
                    rows.push(row);
                row = { connected: line.slice(11) === "*", name: "", security: "Open", signalStrength: 0 };
            } else if (line.startsWith("NET:SSID:") && row) {
                row.name = root.decodeEscapes(line.slice(9));
            } else if (line.startsWith("NET:SECURITY:") && row) {
                row.security = line.slice(13).trim() || "Open";
            } else if (line.startsWith("NET:SIGNAL:") && row) {
                row.signalStrength = Math.max(0, Math.min(1, (Number(line.slice(11)) || 0) / 100));
            }
        }
        if (row && row.name)
            rows.push(row);

        root.wifiEnabled = nextWifiEnabled;
        const knownNames = root.savedProfiles;
        const nextNetworks = [];
        for (const info of rows) {
            let network = root._networks.find((candidate) => candidate.name === info.name);
            if (!network)
                network = networkComponent.createObject(root, { name: info.name });
            if (!network)
                continue;
            network.security = info.security;
            network.signalStrength = info.signalStrength;
            network.connected = info.connected || info.name === connectedSsid;
            network.known = knownNames.includes(info.name.toLowerCase());
            nextNetworks.push(network);
        }
        for (const previous of root._networks) {
            if (!nextNetworks.includes(previous) && previous !== root.actionTarget && previous !== root.pendingConnection)
                previous.destroy();
        }
        root._networks = nextNetworks;
        root.connectedNetwork = nextNetworks.find((network) => network.connected) || null;
        if (root.pendingConnection && root.pendingConnection.connected) {
            connectionProbe.stop();
            connectionTimeout.stop();
            root.pendingConnection = null;
        }
    }

    function runNetworkAction(network, action, password) {
        if (actionProc.running)
            return;
        actionTarget = network;
        actionKind = action;
        pendingPassword = action === "password" ? (password || "") : "";
        const args = [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", action === "forget" ? "forget" : "connect", network.name];
        actionProc.stdinEnabled = action === "password";
        actionProc.command = args;
        actionProc.running = true;
    }

    property var actionTarget: null
    property string actionKind: ""

    QtObject {
        id: networkCollection
        property var values: root._networks
    }

    Component {
        id: networkComponent

        QtObject {
            id: network
            property var service: root
            property string name: ""
            property string security: "Open"
            property real signalStrength: 0
            property bool connected: false
            property bool known: false
            signal connectionFailed(var reason)

            function connect() { network.service.runNetworkAction(network, "saved", ""); }
            function connectWithPsk(password) { network.service.runNetworkAction(network, "password", password); }
            function forget() { network.service.runNetworkAction(network, "forget", ""); }
        }
    }

    Timer {
        interval: 10000
        running: root.scannerEnabled
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: connectionProbe
        interval: 1800
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: connectionTimeout
        interval: 25000
        repeat: false
        onTriggered: {
            const target = root.pendingConnection;
            root.pendingConnection = null;
            connectionProbe.stop();
            if (target)
                target.connectionFailed("auth-timeout");
        }
    }

    Process {
        id: scanProc
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", "scan"]
        stdout: StdioCollector { onStreamFinished: root.updateScan(text) }
    }

    Process {
        id: profilesProc
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", "profiles"]
        stdout: StdioCollector { onStreamFinished: root.updateProfiles(text) }
    }

    Process {
        id: toggleProc
        command: [Quickshell.env("HOME") + "/.local/bin/triton-freebsd-network", "toggle"]
        onExited: root.refresh()
    }

    Process {
        id: actionProc
        command: ["true"]
        onStarted: {
            if (root.actionKind === "password") {
                write(root.pendingPassword + "\n");
                root.pendingPassword = "";
                stdinEnabled = false;
            }
        }
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode) => {
            root.pendingPassword = "";
            const target = root.actionTarget;
            const action = root.actionKind;
            root.actionTarget = null;
            root.actionKind = "";
            if (!target)
                return;
            if (action === "forget") {
                if (exitCode === 0)
                    target.known = false;
                root.refresh();
                return;
            }
            if (exitCode === 0) {
                root.pendingConnection = target;
                connectionProbe.start();
                connectionTimeout.restart();
                root.refresh();
            } else {
                const error = String(actionError.text || "").toLowerCase();
                const reason = error.includes("password") || error.includes("psk") ? "no-secrets"
                    : (error.includes("timed out") ? "auth-timeout"
                        : (error.includes("not found") || error.includes("no network") ? "network-lost" : "other"));
                target.connectionFailed(reason);
            }
            root.refresh();
        }
    }
}
