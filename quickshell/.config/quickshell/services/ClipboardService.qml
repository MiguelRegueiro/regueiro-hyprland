import QtQuick
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property string lastListOutput: ""
    property bool loading: listProc.running
    property bool mutating: copyProc.running || deleteProc.running || wipeProc.running
    property string lastError: ""
    // Support the documented cargo install path, manual /usr/local installs, and PATH installs.
    property string mimeclipLauncher: 'cmd="$HOME/.cargo/bin/mimeclip"; if [ ! -x "$cmd" ]; then if [ -x /usr/local/bin/mimeclip ]; then cmd=/usr/local/bin/mimeclip; else cmd="$(command -v mimeclip 2>/dev/null || true)"; fi; fi; if [ -z "$cmd" ] || [ ! -x "$cmd" ]; then echo "mimeclip not found in $HOME/.cargo/bin, /usr/local/bin, or PATH" >&2; exit 127; fi; exec "$cmd" "$@"'

    signal copyCompleted(bool success)
    signal deleteCompleted(bool success)
    signal wipeCompleted(bool success)

    function normalizeKind(kind) {
        return typeof kind === "string" && kind.length > 0 ? kind.toLowerCase() : "other";
    }

    function mimeclipCommand(args) {
        return ["bash", "-lc", root.mimeclipLauncher, "mimeclip"].concat(args);
    }

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

        let parsed;
        try {
            parsed = JSON.parse(output);
        } catch (error) {
            root.lastError = "Failed to parse clipboard history";
            return [];
        }

        if (!Array.isArray(parsed)) {
            root.lastError = "Clipboard history returned an unexpected format";
            return [];
        }

        return parsed.map((entry) => {
            const id = entry.id;
            const kind = root.normalizeKind(entry.kind);
            const label = typeof entry.label === "string" ? entry.label : "";
            const preview = typeof entry.preview === "string" ? entry.preview : "";
            const createdAt = typeof entry.created_at === "string"
                ? entry.created_at
                : (typeof entry.timestamp === "string" ? entry.timestamp : "");
            const lastUsedAt = typeof entry.last_used_at === "string" ? entry.last_used_at : createdAt;
            const mimeTypes = Array.isArray(entry.mime_types) ? entry.mime_types : [];
            const displayPreview = root.formatDisplayPreview(label, preview, kind, createdAt);

            return {
                id: id,
                kind: kind,
                label: label,
                preview: preview,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                displayPreview: displayPreview,
                mimeTypes: mimeTypes,
                searchText: `${id} ${kind} ${label} ${preview} ${createdAt} ${lastUsedAt} ${displayPreview} ${mimeTypes.join(" ")}`.toLowerCase()
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
        copyProc.command = root.mimeclipCommand(["restore", String(entry.id)]);
        copyProc.running = true;
    }

    function deleteEntry(entry) {
        if (!entry || deleteProc.running)
            return;
        lastError = "";
        deleteProc.command = root.mimeclipCommand(["delete", String(entry.id)]);
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

        command: root.mimeclipCommand(["list", "--json", "--limit", "200"])
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

        command: root.mimeclipCommand(["restore", "0"])
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (!success)
                root.lastError = "Failed to restore clipboard entry";
            root.copyCompleted(success);
        }
    }

    Process {
        id: deleteProc

        command: root.mimeclipCommand(["delete", "0"])
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

        command: root.mimeclipCommand(["clear"])
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
