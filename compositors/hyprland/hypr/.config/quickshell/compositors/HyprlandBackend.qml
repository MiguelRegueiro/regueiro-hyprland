import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    readonly property var workspaceModel: Hyprland.workspaces
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var focusedMonitor: Hyprland.focusedMonitor
    readonly property string powerCommandPath: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/powerctl"

    signal clientsListed(var clients)

    function monitorFor(screen) {
        return Hyprland.monitorFor(screen);
    }

    function monitorName(monitor) {
        return monitor ? monitor.name : "";
    }

    function sameMonitor(first, second) {
        return !!first && !!second && first.name === second.name;
    }

    function activeWorkspaceFor(screen) {
        const monitor = Hyprland.monitorFor(screen);
        return monitor ? monitor.activeWorkspace : null;
    }

    function workspaceId(workspace) {
        return workspace ? Number(workspace.id) : -1;
    }

    function workspaceName(workspace) {
        return workspace ? workspace.name : "";
    }

    function workspaceBelongsTo(workspace, screenName) {
        return !!workspace && !!workspace.monitor && workspace.monitor.name === screenName;
    }

    function workspaceOccupied(workspace) {
        return !!workspace && !!workspace.toplevels && workspace.toplevels.values.length > 0;
    }

    function workspaceHasFullscreen(workspace) {
        return !!workspace && !!workspace.hasFullscreen;
    }

    function focusWorkspace(workspace) {
        if (typeof workspace === "number")
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace + " })");
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + JSON.stringify(String(workspace)) + " })");
    }

    function focusWindow(address) {
        if (/^0x[0-9a-f]+$/i.test(String(address)))
            Hyprland.dispatch("hl.dsp.focus({ window = " + JSON.stringify("address:" + address) + " })");
    }

    function requestClients() {
        if (!clientsProcess.running)
            clientsProcess.running = true;
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.clientsListed(JSON.parse(text));
                } catch (error) {
                    console.warn("Could not read compositor clients:", error);
                    root.clientsListed([]);
                }
            }
        }

        onExited: function(exitCode) {
            if (exitCode !== 0)
                root.clientsListed([]);
        }
    }
}
