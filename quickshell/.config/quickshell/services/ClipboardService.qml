import QtQuick
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property string lastListOutput: ""
    property bool loading: listProc.running
    property bool mutating: copyProc.running || deleteProc.running || wipeProc.running
    property string lastError: ""

    signal copyCompleted(bool success)
    signal deleteCompleted(bool success)
    signal wipeCompleted(bool success)

    function titleCaseKind(kind) {
        if (!kind || kind.length === 0)
            return "Item";
        return kind.charAt(0).toUpperCase() + kind.slice(1);
    }

    function formatDisplayTime(timestamp) {
        if (typeof timestamp !== "string" || timestamp.length === 0)
            return "";

        const date = new Date(timestamp);
        if (isNaN(date.getTime()))
            return "";

        const hh = String(date.getHours()).padStart(2, "0");
        const mm = String(date.getMinutes()).padStart(2, "0");
        const ss = String(date.getSeconds()).padStart(2, "0");
        return `${hh}:${mm}:${ss}`;
    }

    function formatDisplayPreview(label, preview, kind, createdAt) {
        const previewText = (preview || "").trim();
        let baseText = "";

        if (previewText.length > 0 && previewText.toLowerCase() !== kind) {
            baseText = previewText;
        } else {
            const labelText = (label || "").trim();
            if (labelText.length > 0 && labelText.toLowerCase() !== kind)
                baseText = labelText;
        }

        if (baseText.length === 0)
            baseText = kind === "other" ? "Binary" : root.titleCaseKind(kind);

        if (kind !== "image")
            return baseText;

        const timeText = root.formatDisplayTime(createdAt);
        return timeText.length > 0 ? `${baseText} · ${timeText}` : baseText;
    }

    function rebuildEntries() {
        root.entries = root.parseEntries(root.lastListOutput);
    }

    function parseEntries(output) {
        if (output.trim().length === 0)
            return [];

        const lines = output.split(/\r?\n/).filter((line) => {
            return line.trim().length > 0;
        });

        return lines.map((line) => {
            const parts = line.split("\t");
            const id = parts[0] || "";
            const preview = parts.slice(1).join("\t").trim();
            const kind = "text";
            const label = preview;
            const createdAt = "";
            const lastUsedAt = "";
            const mimeTypes = [];
            const displayPreview = preview.length > 0 ? preview : "Clipboard item";

            return {
                id: id,
                kind: kind,
                label: label,
                preview: preview,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                displayPreview: displayPreview,
                mimeTypes: mimeTypes,
                rawEntry: line,
                searchText: `${id} ${label} ${preview} ${displayPreview}`.toLowerCase()
            };
        });
    }

    function refresh() {
        lastError = "";
        if (!listProc.running)
            listProc.running = true;
    }

    function copyEntry(entry) {
        if (!entry || copyProc.running)
            return;
        lastError = "";
        copyProc.command = ["sh", "-c", "/usr/local/bin/cliphist decode \"$1\" | /usr/local/bin/wl-copy", "cliphist-copy", String(entry.id)];
        copyProc.running = true;
    }

    function deleteEntry(entry) {
        if (!entry || deleteProc.running)
            return;
        lastError = "";
        deleteProc.command = ["/usr/local/bin/cliphist", "delete", String(entry.rawEntry || "")];
        deleteProc.running = true;
    }

    function wipe() {
        if (wipeProc.running)
            return;
        lastError = "";
        wipeProc.running = true;
    }

    Process {
        id: listProc

        command: ["sh", "-c", "/usr/local/bin/cliphist list | sed -n '1,200p'"]
        stdout: StdioCollector {
            id: listOut
            waitForEnd: true
            onStreamFinished: {
                root.lastListOutput = listOut.text;
                root.rebuildEntries();
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root.lastError = "Failed to load clipboard history";
        }
    }

    Process {
        id: copyProc

        command: ["sh", "-c", "/usr/local/bin/cliphist decode \"$1\" | /usr/local/bin/wl-copy", "cliphist-copy", "0"]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (!success)
                root.lastError = "Failed to restore clipboard entry";
            root.copyCompleted(success);
        }
    }

    Process {
        id: deleteProc

        command: ["/usr/local/bin/cliphist", "delete", ""]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (success)
                root.refresh();
            else
                root.lastError = "Failed to delete clipboard entry";
            root.deleteCompleted(success);
        }
    }

    Process {
        id: wipeProc

        command: ["/usr/local/bin/cliphist", "wipe"]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (success)
                root.refresh();
            else
                root.lastError = "Failed to clear clipboard history";
            root.wipeCompleted(success);
        }
    }

}
