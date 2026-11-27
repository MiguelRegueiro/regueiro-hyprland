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

        // PowerProfiles can wait for a system D-Bus activation during startup.
        // Keep that optional lookup from delaying the shell's first render.
        asynchronous: true
        active: root.platformService.hasPowerProfilesAdapter
        source: !active ? "" : root.platformService.isLinux
            ? Qt.resolvedUrl("backends/power-profile/linux/PowerProfileBackend.qml")
            : Qt.resolvedUrl("backends/power-profile/freebsd/PowerProfileBackend.qml")
    }
}
// qmllint enable missing-property
