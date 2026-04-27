import QtQuick
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property var screenshotMeta: ({})
    property string lastListOutput: ""
    property bool loading: listProc.running
    property bool mutating: copyProc.running || copyPathProc.running || deleteProc.running || wipeProc.running
    property string lastError: ""

    signal copyCompleted(bool success)
    signal copyPathCompleted(bool success)
    signal deleteCompleted(bool success)
    signal wipeCompleted(bool success)

    function parseScreenshotMeta(output) {
        const meta = {};
        output.split(/\r?\n/).forEach((line) => {
            if (line.length === 0)
                return;
            const parts = line.split("\t");
            if (parts.length < 2)
                return;
            const id = (parts[0] || "").trim();
            const label = (parts[1] || "").trim();
            const path = parts.length >= 3 ? parts.slice(2).join("\t").trim() : "";
            if (id.length === 0 || label.length === 0)
                return;
            meta[id] = {
                label: label,
                path: path
            };
        });
        return meta;
    }

    function screenshotLabel(id) {
        const entry = root.screenshotMeta[id];
        return entry ? (entry.label || "") : "";
    }

    function screenshotPath(id) {
        const entry = root.screenshotMeta[id];
        return entry ? (entry.path || "") : "";
    }

    function rebuildEntries() {
        root.entries = root.parseEntries(root.lastListOutput);
    }

    function formatDisplayPreview(id, preview, isImage) {
        const genericBinaryMatch = preview.match(/^\[\[\s*binary data\s+\.\.\.\s+([a-z0-9.+-]+)\s+\.\.\.\s*\]\]$/i);
        if (genericBinaryMatch)
            return "";

        if (!isImage)
            return preview;

        const label = root.screenshotLabel(id) || "Image";

        const imageBinaryMatch = preview.match(/^\[\[\s*binary data\s+(.+?)\s+([a-z0-9.+-]+)\s+(\d+x\d+)\s*\]\]$/i);
        if (imageBinaryMatch)
            return `${label}\n${imageBinaryMatch[2].toUpperCase()} ${imageBinaryMatch[3]} ${imageBinaryMatch[1]}`;

        if (/^\[\[\s*binary data/i.test(preview))
            return label;

        return preview;
    }

    function parseEntries(output) {
        return output.split(/\r?\n/).filter((line) => line.length > 0).map((line) => {
            const tabIndex = line.indexOf("\t");
            const id = tabIndex >= 0 ? line.slice(0, tabIndex) : "";
            const preview = tabIndex >= 0 ? line.slice(tabIndex + 1) : line;
            const normalizedPreview = preview.length > 0 ? preview : "(empty)";
            const lowered = normalizedPreview.toLowerCase();
            const isImage = lowered.includes("image") || lowered.includes("png") || lowered.includes("jpg") || lowered.includes("jpeg") || lowered.includes("gif") || lowered.includes("webp");
            const displayPreview = root.formatDisplayPreview(id, normalizedPreview, isImage);
            if (displayPreview.length === 0)
                return null;
            return {
                raw: line,
                id: id,
                preview: normalizedPreview,
                displayPreview: displayPreview,
                searchText: `${id} ${normalizedPreview} ${displayPreview}`.toLowerCase(),
                isImage: isImage,
                path: root.screenshotPath(id)
            };
        }).filter((entry) => entry !== null);
    }

    function refresh() {
        lastError = "";
        if (!labelsProc.running)
            labelsProc.running = true;
        if (!listProc.running)
            listProc.running = true;
    }

    function copyEntry(entry) {
        if (!entry || copyProc.running)
            return;
        lastError = "";
        copyProc.environment = {
            CLIPHIST_ENTRY_ID: entry.id
        };
        copyProc.running = true;
    }

    function copyPath(entry) {
        if (!entry || !entry.path || copyPathProc.running)
            return;
        lastError = "";
        copyPathProc.environment = {
            CLIPBOARD_PATH: entry.path
        };
        copyPathProc.running = true;
    }

    function deleteEntry(entry) {
        if (!entry || deleteProc.running)
            return;
        lastError = "";
        deleteProc.environment = {
            CLIPHIST_ENTRY: entry.raw
        };
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

        command: ["cliphist", "list"]
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
        id: labelsProc

        command: ["bash", "-lc", "cat \"${XDG_CACHE_HOME:-$HOME/.cache}/hypr-screenshot-labels.tsv\" 2>/dev/null || true"]
        stdout: StdioCollector {
            id: labelsOut
            waitForEnd: true
            onStreamFinished: {
                root.screenshotMeta = root.parseScreenshotMeta(labelsOut.text);
                if (root.lastListOutput.length > 0)
                    root.rebuildEntries();
            }
        }
    }

    Process {
        id: copyProc

        command: ["bash", "-lc", "tmp=\"$(mktemp)\"; trap 'rm -f \"$tmp\"' EXIT; printf '%s' \"$CLIPHIST_ENTRY_ID\" | cliphist decode > \"$tmp\" || exit 1; mime=\"$(file --brief --mime-type \"$tmp\")\"; if [ \"$mime\" = \"inode/x-empty\" ]; then mime=\"text/plain\"; fi; wl-copy --type \"$mime\" < \"$tmp\""]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (!success)
                root.lastError = "Failed to copy clipboard entry";
            root.copyCompleted(success);
        }
    }

    Process {
        id: copyPathProc

        command: ["bash", "-lc", "ignore_file=\"${XDG_CACHE_HOME:-$HOME/.cache}/hypr-clipboard-ignore-once\"; mkdir -p \"$(dirname \"$ignore_file\")\"; printf '%s' \"$CLIPBOARD_PATH\" > \"$ignore_file\"; printf '%s' \"$CLIPBOARD_PATH\" | wl-copy --type text/plain"]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (!success)
                root.lastError = "Failed to copy screenshot path";
            root.copyPathCompleted(success);
        }
    }

    Process {
        id: deleteProc

        command: ["bash", "-lc", "printf '%s' \"$CLIPHIST_ENTRY\" | cliphist delete"]
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

        command: ["cliphist", "wipe"]
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
