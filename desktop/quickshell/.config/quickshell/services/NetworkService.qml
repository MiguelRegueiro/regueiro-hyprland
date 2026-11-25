import QtQuick

// Loader exposes the platform backend as QObject, so its stable service
// contract is accessed dynamically below.
// qmllint disable missing-property
Item {
    id: root

    required property var platformService

    readonly property bool adapterAvailable: platformService.hasNetworkAdapter && backend.status === Loader.Ready
    readonly property var ethernetDevice: adapterAvailable ? backend.item["ethernetDevice"] : null
    readonly property bool ethernetAvailable: adapterAvailable && backend.item["ethernetAvailable"]
    readonly property bool ethernetConnected: adapterAvailable && backend.item["ethernetConnected"]
    readonly property bool ethernetBusy: adapterAvailable && backend.item["ethernetBusy"]
    readonly property bool ethernetCanToggle: adapterAvailable && backend.item["ethernetCanToggle"]
    readonly property bool wifiConnected: adapterAvailable && backend.item["wifiConnected"]
    readonly property string networkIcon: adapterAvailable ? backend.item["networkIcon"] : "󰤭"

    function toggleEthernet() {
        if (ethernetCanToggle)
            backend.item["toggleEthernet"]();
    }

    Loader {
        id: backend
        active: root.platformService.hasNetworkAdapter
        source: !active ? "" : root.platformService.isLinux
            ? Qt.resolvedUrl("../platforms/linux/NetworkBackend.qml")
            : Qt.resolvedUrl("../platforms/freebsd/NetworkBackend.qml")
    }
}
// qmllint enable missing-property
