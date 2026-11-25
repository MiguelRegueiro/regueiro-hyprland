import QtQuick

// The implementation is loaded from the selected platform package.
// qmllint disable missing-property
Item {
    id: root

    required property var platformService

    readonly property bool available: platformService.hasBrightnessAdapter && backend.status === Loader.Ready && backend.item["available"]
    readonly property int percent: backend.status === Loader.Ready ? backend.item["percent"] : 0
    readonly property string iconText: backend.status === Loader.Ready ? backend.item["iconText"] : "󰃞"

    signal adjusted()

    function refresh() {
        if (backend.status === Loader.Ready)
            backend.item["refresh"]();
    }

    function setPercent(value) {
        if (available)
            backend.item["setPercent"](value);
    }

    function adjust(direction) {
        if (available)
            backend.item["adjust"](direction);
    }

    Loader {
        id: backend

        active: root.platformService.hasBrightnessAdapter
        source: !active ? "" : root.platformService.isLinux
            ? Qt.resolvedUrl("../platforms/linux/BrightnessBackend.qml")
            : Qt.resolvedUrl("../platforms/freebsd/BrightnessBackend.qml")
    }

    Connections {
        function onAdjusted() {
            root.adjusted();
        }

        target: backend.status === Loader.Ready ? backend.item : null
    }
}
// qmllint enable missing-property
