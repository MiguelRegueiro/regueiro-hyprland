import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property var drives: []
    property string lastError: ""
    readonly property bool loading: listProc.running
    readonly property bool mutating: actionProc.running

    function cleanMountpoints(points) {
        if (!Array.isArray(points))
            return [];

        return points.filter((point) => {
            return typeof point === "string" && point.length > 0 && point !== "[SWAP]";
        });
    }

    function displayName(block, parentLabel) {
        if (typeof block.label === "string" && block.label.length > 0)
            return block.label;

        if (typeof parentLabel === "string" && parentLabel.length > 0)
            return parentLabel;

        if (typeof block.model === "string" && block.model.length > 0)
            return block.model.trim();

        return block.name || block.path || "External drive";
    }

    function parseBlockDevices(output) {
        let parsed;
        try {
            parsed = JSON.parse(output);
        } catch (error) {
            root.lastError = "Failed to read drives";
            return [];
        }

        const found = [];
        const devices = Array.isArray(parsed.blockdevices) ? parsed.blockdevices : [];

        function walk(block, parent) {
            if (!block)
                return;

            const parentExternal = parent ? parent.external : false;
            const external = parentExternal || block.tran === "usb" || block.hotplug === true || block.rm === true;
            const parentDiskPath = parent ? parent.diskPath : "";
            const diskPath = block.type === "disk" ? block.path : parentDiskPath;
            const parentLabel = parent ? parent.label : "";
            const label = root.displayName(block, parentLabel);
            const mounts = root.cleanMountpoints(block.mountpoints);
            const fstype = typeof block.fstype === "string" ? block.fstype : "";
            const hasFilesystem = fstype.length > 0 && fstype !== "swap";
            const usableType = block.type === "part" || block.type === "disk" || block.type === "crypt";

            if (external && usableType && (hasFilesystem || mounts.length > 0)) {
                found.push({
                    name: block.name || "",
                    label: label,
                    size: block.size || "",
                    path: block.path || "",
                    diskPath: diskPath || block.path || "",
                    fstype: fstype,
                    mountPath: mounts.length > 0 ? mounts[0] : "",
                    mounted: mounts.length > 0
                });
            }

            const children = Array.isArray(block.children) ? block.children : [];
            for (let i = 0; i < children.length; i++) {
                walk(children[i], {
                    external: external,
                    diskPath: diskPath || block.path || "",
                    label: label
                });
            }
        }

        for (let i = 0; i < devices.length; i++)
            walk(devices[i], null);

        root.lastError = "";
        return found;
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function openDrive(drive) {
        if (actionProc.running || !drive || !drive.mounted || drive.mountPath.length === 0)
            return;

        root.lastError = "";
        actionProc.command = ["gio", "open", drive.mountPath];
        actionProc.running = true;
    }

    function mountDrive(drive) {
        if (actionProc.running || !drive || drive.path.length === 0)
            return;

        root.lastError = "";
        actionProc.command = ["udisksctl", "mount", "-b", drive.path];
        actionProc.running = true;
    }

    function unmountDrive(drive) {
        if (actionProc.running || !drive || drive.path.length === 0)
            return;

        root.lastError = "";
        actionProc.command = ["udisksctl", "unmount", "-b", drive.path];
        actionProc.running = true;
    }

    function ejectDrive(drive) {
        if (actionProc.running || !drive || drive.diskPath.length === 0)
            return;

        root.lastError = "";
        actionProc.command = ["bash", "-lc", "udisksctl unmount -b \"$1\" >/dev/null 2>&1 || true; udisksctl power-off -b \"$2\"", "external-drive", drive.path, drive.diskPath];
        actionProc.running = true;
    }

    Timer {
        interval: Theme.slowPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon

        interval: 600
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: listProc

        command: ["lsblk", "-J", "-o", "NAME,KNAME,TYPE,SIZE,LABEL,MODEL,TRAN,HOTPLUG,RM,MOUNTPOINTS,PATH,FSTYPE,UUID"]

        stdout: StdioCollector {
            id: listOut

            waitForEnd: true
            onStreamFinished: root.drives = root.parseBlockDevices(listOut.text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to list drives";
        }
    }

    Process {
        id: actionProc

        command: ["echo"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Drive action failed";

            refreshSoon.restart();
        }
    }

}
