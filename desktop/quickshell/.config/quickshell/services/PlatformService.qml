import QtQuick

QtObject {
    readonly property string name: Qt.platform.os === "linux" ? "linux"
        : (Qt.platform.os === "freebsd" ? "freebsd" : "unknown")
    readonly property bool isLinux: name === "linux"
    readonly property bool isFreeBSD: name === "freebsd"

    // Capabilities describe implemented adapters, not merely OS support.
    readonly property bool hasNetworkAdapter: isLinux
    readonly property bool hasBrightnessAdapter: isLinux
    readonly property bool hasBatteryAdapter: isLinux
    readonly property bool hasPowerProfilesAdapter: isLinux
}
