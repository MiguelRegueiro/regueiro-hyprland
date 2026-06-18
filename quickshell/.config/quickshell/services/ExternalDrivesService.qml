import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    property var drives: []
    property string lastError: ""
    property string lastErrorSource: ""
    readonly property bool loading: listProc.running
    readonly property bool mutating: actionProc.running
    readonly property string driveHelper: Qt.resolvedUrl("../scripts/freebsd-drive-eject.sh").toString().replace("file://", "")

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
            return root.parseUdisksDump(output);
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

        root.clearListError();
        return found;
    }

    function formatBytes(size) {
        const bytes = Number(size);
        if (!Number.isFinite(bytes) || bytes <= 0)
            return "";

        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }

        return value.toFixed(value >= 10 || unit === 0 ? 0 : 1) + units[unit];
    }

    function parseUdisksDump(output) {
        const blocks = {};
        const drives = {};
        const sections = output.split(/\n(?=\/org\/freedesktop\/UDisks2\/)/);

        function valueAfter(line, key) {
            const index = line.indexOf(key + ":");
            if (index < 0)
                return "";

            return line.slice(index + key.length + 1).trim();
        }

        for (let i = 0; i < sections.length; i++) {
            const section = sections[i].trim();
            if (section.length === 0)
                continue;

            const lines = section.split(/\r?\n/);
            const path = lines[0].replace(/:$/, "");
            const entry = {
                path: path,
                mountpoints: []
            };

            for (let j = 1; j < lines.length; j++) {
                const line = lines[j];
                if (line.indexOf("Device:") >= 0)
                    entry.device = valueAfter(line, "Device");
                else if (line.indexOf("PreferredDevice:") >= 0)
                    entry.preferredDevice = valueAfter(line, "PreferredDevice");
                else if (line.indexOf("Drive:") >= 0)
                    entry.drive = valueAfter(line, "Drive").replace(/^'|'$/g, "");
                else if (line.indexOf("HintName:") >= 0)
                    entry.hintName = valueAfter(line, "HintName");
                else if (line.indexOf("HintIgnore:") >= 0)
                    entry.hintIgnore = valueAfter(line, "HintIgnore") === "true";
                else if (line.indexOf("IdLabel:") >= 0)
                    entry.idLabel = valueAfter(line, "IdLabel");
                else if (line.indexOf("IdType:") >= 0)
                    entry.idType = valueAfter(line, "IdType");
                else if (line.indexOf("IdUsage:") >= 0)
                    entry.idUsage = valueAfter(line, "IdUsage");
                else if (line.indexOf("Size:") >= 0)
                    entry.size = valueAfter(line, "Size");
                else if (line.indexOf("MountPoints:") >= 0)
                    entry.mountpoints = valueAfter(line, "MountPoints").split(/\s+/).filter((point) => point.length > 0);
                else if (line.indexOf("CanPowerOff:") >= 0)
                    entry.canPowerOff = valueAfter(line, "CanPowerOff") === "true";
                else if (line.indexOf("ConnectionBus:") >= 0)
                    entry.connectionBus = valueAfter(line, "ConnectionBus");
                else if (line.indexOf("Model:") >= 0)
                    entry.model = valueAfter(line, "Model");
                else if (line.indexOf("Removable:") >= 0)
                    entry.removable = valueAfter(line, "Removable") === "true";
                else if (line.indexOf("bsdisks_IsHotpluggable:") >= 0)
                    entry.hotpluggable = valueAfter(line, "bsdisks_IsHotpluggable") === "true";
            }

            if (path.indexOf("/block_devices/") >= 0)
                blocks[path] = entry;
            else if (path.indexOf("/drives/") >= 0)
                drives[path] = entry;
        }

        const diskDeviceByDrive = {};
        for (const path in blocks) {
            const block = blocks[path];
            if (block.drive && (!block.idUsage || block.idUsage.length === 0))
                diskDeviceByDrive[block.drive] = block.preferredDevice || block.device || "";
        }

        const found = [];
        for (const path in blocks) {
            const block = blocks[path];
            const drive = drives[block.drive] || {};
            const device = block.preferredDevice || block.device || "";
            const mounts = root.cleanMountpoints(block.mountpoints);
            const mountPath = mounts.length > 0 ? mounts[0] : "";
            const external = drive.connectionBus === "usb" || drive.removable || drive.hotpluggable || drive.canPowerOff;
            const systemMount = mountPath === "/" || mountPath.indexOf("/boot") === 0 || mountPath.indexOf("/compat") === 0;
            const mountable = block.idUsage === "filesystem" && block.idType !== "swap" && block.idType !== "";

            if (!external || block.hintIgnore || !mountable || systemMount)
                continue;

            found.push({
                name: device.replace(/^\/dev\//, ""),
                label: block.idLabel || block.hintName || drive.model || device || "External drive",
                size: root.formatBytes(block.size),
                path: device,
                diskPath: diskDeviceByDrive[block.drive] || device,
                fstype: block.idType || "",
                mountPath: mountPath,
                mounted: mountPath.length > 0
            });
        }

        root.clearListError();
        return found;
    }

    function clearError() {
        root.lastError = "";
        root.lastErrorSource = "";
    }

    function clearListError() {
        if (root.lastErrorSource === "list")
            root.clearError();
    }

    function setError(message, source) {
        root.lastError = message;
        root.lastErrorSource = source;
    }

    function cleanActionError(output) {
        const text = String(output || "").trim().replace(/\s+/g, " ");
        if (text.length === 0)
            return "Drive action failed";

        const parts = text.split(": ");
        const useful = parts.length > 1 ? parts.slice(Math.max(0, parts.length - 2)).join(": ") : text;
        return useful.length > 0 ? useful : "Drive action failed";
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function openDrive(drive) {
        if (actionProc.running || !drive || !drive.mounted || drive.mountPath.length === 0)
            return;

        root.clearError();
        actionProc.command = ["env", "-u", "NO_COLOR", "COLORTERM=truecolor", "kitty", "-e", "elio", drive.mountPath];
        actionProc.running = true;
    }

    function mountDrive(drive) {
        if (actionProc.running || !drive || drive.path.length === 0)
            return;

        root.clearError();
        actionProc.command = ["udisksctl", "mount", "-b", drive.path];
        actionProc.running = true;
    }

    function unmountDrive(drive) {
        if (actionProc.running || !drive || drive.path.length === 0)
            return;

        root.clearError();
        actionProc.command = [root.driveHelper, "unmount", drive.path, drive.mountPath || "", drive.diskPath || ""];
        actionProc.running = true;
    }

    function ejectDrive(drive) {
        if (actionProc.running || !drive || drive.diskPath.length === 0)
            return;

        root.clearError();
        actionProc.command = [root.driveHelper, "eject", drive.path, drive.mountPath || "", drive.diskPath];
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

        command: ["udisksctl", "dump"]

        stdout: StdioCollector {
            id: listOut

            waitForEnd: true
            onStreamFinished: root.drives = root.parseBlockDevices(listOut.text)
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setError("Failed to list drives", "list");
        }
    }

    Process {
        id: actionProc

        command: ["echo"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.setError(root.cleanActionError(actionErr.text || actionOut.text), "action");
            else
                root.clearError();

            refreshSoon.restart();
        }

        stdout: StdioCollector {
            id: actionOut
        }

        stderr: StdioCollector {
            id: actionErr
        }
    }

}
