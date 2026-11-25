import QtQuick
import Quickshell

// Stable interface consumed by the shared shell. Backend-specific IPC stays
// behind the loaded compositor adapter.
Item {
    id: root

    readonly property string backendName: Quickshell.env("TRITON_COMPOSITOR") || "hyprland"
    readonly property string backendPath: backendName === "hyprland" ? Quickshell.shellPath("compositors/HyprlandBackend.qml") : ""
    readonly property var backend: backendLoader.item
    readonly property string powerCommandPath: backend ? backend.powerCommandPath : ""
    readonly property var workspaceModel: backend ? backend.workspaceModel : []
    readonly property var focusedWorkspace: backend ? backend.focusedWorkspace : null
    readonly property var focusedMonitor: backend ? backend.focusedMonitor : null

    signal clientsListed(var clients)

    function monitorFor(screen) {
        return backend ? backend.monitorFor(screen) : null;
    }

    function monitorName(monitor) {
        return backend ? backend.monitorName(monitor) : "";
    }

    function sameMonitor(first, second) {
        return backend ? backend.sameMonitor(first, second) : false;
    }

    function activeWorkspaceFor(screen) {
        return backend ? backend.activeWorkspaceFor(screen) : null;
    }

    function workspaceId(workspace) {
        return backend ? backend.workspaceId(workspace) : -1;
    }

    function workspaceName(workspace) {
        return backend ? backend.workspaceName(workspace) : "";
    }

    function workspaceBelongsTo(workspace, screenName) {
        return backend ? backend.workspaceBelongsTo(workspace, screenName) : false;
    }

    function workspaceOccupied(workspace) {
        return backend ? backend.workspaceOccupied(workspace) : false;
    }

    function workspaceHasFullscreen(workspace) {
        return backend ? backend.workspaceHasFullscreen(workspace) : false;
    }

    function focusWorkspace(workspace) {
        if (backend)
            backend.focusWorkspace(workspace);
    }

    function focusWindow(address) {
        if (backend)
            backend.focusWindow(address);
    }

    function requestClients() {
        if (backend)
            backend.requestClients();
    }

    Loader {
        id: backendLoader

        source: root.backendPath

        onStatusChanged: {
            if (status === Loader.Error)
                console.error("Could not load compositor backend:", root.backendPath);
        }
    }

    Connections {
        function onClientsListed(clients) {
            root.clientsListed(clients);
        }

        ignoreUnknownSignals: true
        target: root.backend
    }
}
