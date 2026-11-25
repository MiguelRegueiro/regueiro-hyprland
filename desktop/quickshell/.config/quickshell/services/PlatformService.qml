import QtQuick
import Quickshell

QtObject {
    readonly property string name: Qt.platform.os === "linux" ? "linux"
        : (Qt.platform.os === "freebsd" ? "freebsd" : "unknown")
    readonly property bool isLinux: name === "linux"
    readonly property bool isFreeBSD: name === "freebsd"

    // Capabilities describe implemented adapters, not merely OS support.
    readonly property bool hasNetworkAdapter: isLinux
    readonly property bool hasWifiAdapter: isLinux
    readonly property bool hasBrightnessAdapter: isLinux
    readonly property bool hasBatteryAdapter: isLinux
    readonly property bool hasPowerProfilesAdapter: isLinux
    readonly property string inputMethodCommandPath: isLinux ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-fcitx-toggle" : ""
    readonly property string bluetoothCommandPath: isLinux ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-bluetooth" : ""
    readonly property string systemDetailsCommandPath: isLinux ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-system-details" : ""
    readonly property string externalDrivesCommandPath: isLinux ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-drives" : ""
}
