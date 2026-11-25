import QtQuick
import Quickshell

QtObject {
    readonly property string name: Qt.platform.os === "linux" ? "linux"
        : (Qt.platform.os === "freebsd" ? "freebsd" : "unknown")
    readonly property bool isLinux: name === "linux"
    readonly property bool isFreeBSD: name === "freebsd"

    // Capabilities describe implemented adapters, not merely OS support.
    readonly property bool hasNetworkAdapter: isLinux || isFreeBSD
    readonly property bool hasWifiAdapter: isLinux || isFreeBSD
    readonly property bool hasBrightnessAdapter: isLinux || isFreeBSD
    readonly property bool hasBatteryAdapter: isLinux || isFreeBSD
    readonly property bool hasPowerProfilesAdapter: isLinux || isFreeBSD
    readonly property bool hasPowerPolicyAdapter: isLinux
    readonly property bool hasSuspendAdapter: isLinux
    readonly property string systemPowerCommandPath: isLinux
        ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-power"
        : (isFreeBSD ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-freebsd-power" : "")
    readonly property string inputMethodCommandPath: isLinux ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-fcitx-toggle" : ""
    readonly property string bluetoothCommandPath: isLinux
        ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-bluetooth"
        : (isFreeBSD ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-freebsd-bluetooth" : "")
    readonly property string systemDetailsCommandPath: isLinux
        ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-system-details"
        : (isFreeBSD ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-freebsd-system-details" : "")
    readonly property string externalDrivesCommandPath: isLinux
        ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-linux-drives"
        : (isFreeBSD ? (Quickshell.env("HOME") || "") + "/.local/bin/triton-freebsd-drives" : "")
}
