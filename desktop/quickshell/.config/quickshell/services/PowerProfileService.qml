import QtQuick

// qmllint disable missing-property
Item {
    id: root

    required property var platformService

    readonly property string mode: backend.status === Loader.Ready ? backend.item["mode"] : ""
    readonly property bool hasPerformanceProfile: backend.status === Loader.Ready && backend.item["hasPerformanceProfile"]

    function setMode(nextMode) {
        if (backend.status === Loader.Ready)
            backend.item["setMode"](nextMode);
    }

    Loader {
        id: backend

        active: root.platformService.hasPowerProfilesAdapter
        source: active ? Qt.resolvedUrl("../platforms/linux/PowerProfileBackend.qml") : ""
    }
}
// qmllint enable missing-property
