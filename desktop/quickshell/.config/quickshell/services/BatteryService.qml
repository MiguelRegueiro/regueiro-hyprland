import QtQuick

// qmllint disable missing-property
Item {
    id: root

    required property var platformService

    readonly property var device: backend.status === Loader.Ready ? backend.item["device"] : null
    readonly property bool present: backend.status === Loader.Ready && backend.item["present"]
    readonly property int percent: backend.status === Loader.Ready ? backend.item["percent"] : -1
    readonly property bool charging: backend.status === Loader.Ready && backend.item["charging"]
    readonly property bool full: backend.status === Loader.Ready && backend.item["full"]
    readonly property bool discharging: backend.status === Loader.Ready && backend.item["discharging"]
    readonly property bool onBattery: backend.status === Loader.Ready && backend.item["onBattery"]
    readonly property real secondsLeft: backend.status === Loader.Ready ? backend.item["secondsLeft"] : 0

    Loader {
        id: backend

        active: root.platformService.hasBatteryAdapter
        source: active ? Qt.resolvedUrl("../platforms/linux/BatteryBackend.qml") : ""
    }
}
// qmllint enable missing-property
