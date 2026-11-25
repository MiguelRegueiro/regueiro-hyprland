import QtQuick
import Quickshell.Io
import "../theme/Theme.js" as Theme

Item {
    id: root

    required property var platformService

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

        root.lastError = "";
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
        const sections = String(output || "").split(/\n(?=\/org\/freedesktop\/UDisks2\/)/);

        function fieldValue(line, key) {
            const index = line.indexOf(key + ":");
            return index < 0 ? "" : line.slice(index + key.length + 1).trim();
        }

        for (const rawSection of sections) {
            const lines = rawSection.trim().split(/\r?\n/);
            if (!lines.length || !lines[0].startsWith("/org/freedesktop/UDisks2/"))
                continue;
            const path = lines[0].replace(/:$/, "");
            const entry = { path: path, mountpoints: [] };
            for (const line of lines.slice(1)) {
                if (line.includes("PreferredDevice:")) entry.preferredDevice = fieldValue(line, "PreferredDevice");
                else if (line.includes("Device:")) entry.device = fieldValue(line, "Device");
                else if (line.includes("Drive:")) entry.drive = fieldValue(line, "Drive").replace(/^'|'$/g, "");
                else if (line.includes("HintName:")) entry.hintName = fieldValue(line, "HintName");
                else if (line.includes("HintIgnore:")) entry.hintIgnore = fieldValue(line, "HintIgnore") === "true";
                else if (line.includes("IdLabel:")) entry.idLabel = fieldValue(line, "IdLabel");
                else if (line.includes("IdType:")) entry.idType = fieldValue(line, "IdType");
                else if (line.includes("IdUsage:")) entry.idUsage = fieldValue(line, "IdUsage");
                else if (line.includes("Size:")) entry.size = fieldValue(line, "Size");
                else if (line.includes("MountPoints:")) {
                    const value = fieldValue(line, "MountPoints");
                    entry.mountpoints = Array.from(value.matchAll(/'([^']+)'/g), (match) => match[1]);
                } else if (line.includes("CanPowerOff:")) entry.canPowerOff = fieldValue(line, "CanPowerOff") === "true";
                else if (line.includes("ConnectionBus:")) entry.connectionBus = fieldValue(line, "ConnectionBus");
                else if (line.includes("Model:")) entry.model = fieldValue(line, "Model");
                else if (line.includes("Removable:")) entry.removable = fieldValue(line, "Removable") === "true";
                else if (line.includes("bsdisks_IsHotpluggable:")) entry.hotpluggable = fieldValue(line, "bsdisks_IsHotpluggable") === "true";
            }
            if (path.includes("/block_devices/")) blocks[path] = entry;
            else if (path.includes("/drives/")) drives[path] = entry;
        }

        const diskByDrive = {};
        for (const path in blocks) {
            const block = blocks[path];
            if (block.drive && !block.idUsage)
                diskByDrive[block.drive] = block.preferredDevice || block.device || "";
        }

        const found = [];
        for (const path in blocks) {
            const block = blocks[path];
            const drive = drives[block.drive] || {};
            const device = block.preferredDevice || block.device || "";
            const mounts = root.cleanMountpoints(block.mountpoints);
            const mountPath = mounts.length ? mounts[0] : "";
            const external = drive.connectionBus === "usb" || drive.removable || drive.hotpluggable || drive.canPowerOff;
            const systemMount = mountPath === "/" || mountPath.startsWith("/boot") || mountPath.startsWith("/compat");
            const mountable = block.idUsage === "filesystem" && block.idType && block.idType !== "swap";
            if (!external || block.hintIgnore || !mountable || systemMount)
                continue;
            found.push({
                name: device.replace(/^\/dev\//, ""),
                label: block.idLabel || block.hintName || drive.model || device || "External drive",
                size: root.formatBytes(block.size),
                path: device,
                diskPath: diskByDrive[block.drive] || device,
                fstype: block.idType,
                mountPath: mountPath,
                mounted: mountPath.length > 0
            });
        }
        root.lastError = "";
        return found;
    }

    function refresh() {
        if (platformService.externalDrivesCommandPath.length > 0 && !listProc.running)
            listProc.running = true;
    }

    function openDrive(drive) {
        if (platformService.externalDrivesCommandPath.length === 0 || actionProc.running || !drive || !drive.mounted || drive.mountPath.length === 0)
            return;

        root.lastError = "";
        actionProc.command = [platformService.externalDrivesCommandPath, "open", drive.mountPath];
        actionProc.running = true;
    }

    function mountDrive(drive) {
        if (platformService.externalDrivesCommandPath.length === 0 || actionProc.running || !drive || drive.path.length === 0)
            return;

        root.lastError = "";
        actionProc.command = [platformService.externalDrivesCommandPath, "mount", drive.path];
        actionProc.running = true;
    }

    function unmountDrive(drive) {
        if (platformService.externalDrivesCommandPath.length === 0 || actionProc.running || !drive || drive.path.length === 0)
            return;

        root.lastError = "";
        actionProc.command = platformService.isFreeBSD
            ? [platformService.externalDrivesCommandPath, "unmount", drive.path, drive.mountPath]
            : [platformService.externalDrivesCommandPath, "unmount", drive.path];
        actionProc.running = true;
    }

    function ejectDrive(drive) {
        if (platformService.externalDrivesCommandPath.length === 0 || actionProc.running || !drive || drive.diskPath.length === 0)
            return;

        root.lastError = "";
        actionProc.command = platformService.isFreeBSD
            ? [platformService.externalDrivesCommandPath, "eject", drive.path, drive.mountPath, drive.diskPath]
            : [platformService.externalDrivesCommandPath, "eject", drive.path, drive.diskPath];
        actionProc.running = true;
    }

    Timer {
        interval: Theme.slowPollInterval
        running: root.platformService.externalDrivesCommandPath.length > 0
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

        command: [root.platformService.externalDrivesCommandPath, "list"]

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
