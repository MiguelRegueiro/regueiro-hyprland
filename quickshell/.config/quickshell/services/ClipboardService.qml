import QtQuick
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property string lastListOutput: ""
    property bool loading: listProc.running
    property bool mutating: copyProc.running || deleteProc.running || wipeProc.running || imagePathCopyProc.running
    property string lastError: ""
    property var imagePreviewCache: ({})
    property var imagePreviewOrder: []
    property var imagePreviewPending: ({})
    property var imagePreviewQueue: []
    property string imagePreviewCurrentId: ""
    // Support the documented cargo install path, manual /usr/local installs, and PATH installs.
    property string mimeclipLauncher: 'cmd="$HOME/.cargo/bin/mimeclip"; if [ ! -x "$cmd" ]; then if [ -x /usr/local/bin/mimeclip ]; then cmd=/usr/local/bin/mimeclip; else cmd="$(command -v mimeclip 2>/dev/null || true)"; fi; fi; if [ -z "$cmd" ] || [ ! -x "$cmd" ]; then echo "mimeclip not found in $HOME/.cargo/bin, /usr/local/bin, or PATH" >&2; exit 127; fi; exec "$cmd" "$@"'

    signal copyCompleted(bool success)
    signal deleteCompleted(bool success)
    signal wipeCompleted(bool success)
    signal imagePathCopyCompleted(bool success)

    function normalizeKind(kind) {
        return typeof kind === "string" && kind.length > 0 ? kind.toLowerCase() : "other";
    }

    function mimeclipCommand(args) {
        return ["bash", "-lc", root.mimeclipLauncher, "mimeclip"].concat(args);
    }

    function imagePreviewSource(entryId) {
        return root.imagePreviewCache[String(entryId)] || "";
    }

    function imagePreviewCommand(entryId) {
        const script = "set -euo pipefail\n"
            + "cmd=\"$HOME/.cargo/bin/mimeclip\"\n"
            + "if [ ! -x \"$cmd\" ]; then\n"
            + "  if [ -x /usr/local/bin/mimeclip ]; then cmd=/usr/local/bin/mimeclip; else cmd=\"$(command -v mimeclip 2>/dev/null || true)\"; fi\n"
            + "fi\n"
            + "[ -n \"$cmd\" ] && [ -x \"$cmd\" ]\n"
            + "cache_dir=\"$HOME/.cache/quickshell/clipboard-thumbnails\"\n"
            + "mkdir -p \"$cache_dir\"\n"
            + "target=\"$cache_dir/$1.png\"\n"
            + "if [ ! -s \"$target\" ]; then\n"
            + "  tmp=\"$target.tmp\"\n"
            + "  trap 'rm -f \"$tmp\"' EXIT\n"
            + "  \"$cmd\" decode \"$1\" | jq -r '.[] | select(.mime_type | startswith(\"image/\")) | .data_b64' | head -n 1 | base64 -d | magick - -auto-orient -thumbnail '128x128^' -gravity center -extent 128x128 \"png:$tmp\"\n"
            + "  mv \"$tmp\" \"$target\"\n"
            + "fi\n"
            + "printf '%s' \"$target\"";
        return ["bash", "-lc", script, "clipboard-thumbnail", entryId];
    }

    function requestImagePreview(entry) {
        if (!entry || root.normalizeKind(entry.kind) !== "image")
            return;

        const entryId = String(entry.id);
        if (!/^\d+$/.test(entryId) || Object.prototype.hasOwnProperty.call(root.imagePreviewCache, entryId) || root.imagePreviewPending[entryId])
            return;

        const pending = Object.assign({}, root.imagePreviewPending);
        pending[entryId] = true;
        root.imagePreviewPending = pending;
        root.imagePreviewQueue = root.imagePreviewQueue.concat([entryId]);
        root.startNextImagePreview();
    }

    function startNextImagePreview() {
        if (imagePreviewProc.running || root.imagePreviewCurrentId.length > 0 || root.imagePreviewQueue.length === 0)
            return;

        const entryId = root.imagePreviewQueue[0];
        root.imagePreviewQueue = root.imagePreviewQueue.slice(1);
        root.imagePreviewCurrentId = entryId;
        imagePreviewProc.command = root.imagePreviewCommand(entryId);
        imagePreviewProc.running = true;
    }

    function finishImagePreview(entryId, source) {
        if (root.imagePreviewCurrentId !== entryId)
            return;

        const pending = Object.assign({}, root.imagePreviewPending);
        delete pending[entryId];
        root.imagePreviewPending = pending;

        const cache = Object.assign({}, root.imagePreviewCache);
        cache[entryId] = source;
        const order = root.imagePreviewOrder.filter((id) => id !== entryId);
        order.push(entryId);
        while (order.length > 32)
            delete cache[order.shift()];

        root.imagePreviewCache = cache;
        root.imagePreviewOrder = order;
        root.imagePreviewCurrentId = "";
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

    function copyImagePath(entry) {
        if (!entry || root.normalizeKind(entry.kind) !== "image" || imagePathCopyProc.running)
            return;

        const entryId = String(entry.id);
        if (!/^\d+$/.test(entryId))
            return;

        const script = "set -euo pipefail\n"
            + "cmd=\"$HOME/.cargo/bin/mimeclip\"\n"
            + "if [ ! -x \"$cmd\" ]; then\n"
            + "  if [ -x /usr/local/bin/mimeclip ]; then cmd=/usr/local/bin/mimeclip; else cmd=\"$(command -v mimeclip 2>/dev/null || true)\"; fi\n"
            + "fi\n"
            + "[ -n \"$cmd\" ] && [ -x \"$cmd\" ]\n"
            + "cache_dir=\"$HOME/.cache/quickshell/clipboard-images\"\n"
            + "mkdir -p \"$cache_dir\"\n"
            + "mime=\"$(\"$cmd\" decode \"$1\" | jq -r '.[] | select(.mime_type | startswith(\"image/\")) | .mime_type' | head -n 1)\"\n"
            + "case \"$mime\" in\n"
            + "  image/png) extension=png ;;\n"
            + "  image/jpeg) extension=jpg ;;\n"
            + "  image/webp) extension=webp ;;\n"
            + "  image/gif) extension=gif ;;\n"
            + "  *) extension=img ;;\n"
            + "esac\n"
            + "path=\"$cache_dir/$1.$extension\"\n"
            + "\"$cmd\" decode \"$1\" | jq -r '.[] | select(.mime_type | startswith(\"image/\")) | .data_b64' | head -n 1 | base64 -d > \"$path\"\n"
            + "wl-copy --type \"text/plain;charset=utf-8\" -- \"$path\"";
        lastError = "";
        imagePathCopyProc.command = ["bash", "-lc", script, "clipboard-image-path", entryId];
        imagePathCopyProc.running = true;
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
        id: imagePreviewProc

        command: root.mimeclipCommand(["decode", "0"])
        stdout: StdioCollector {
            id: imagePreviewOut
            waitForEnd: true
        }
        onExited: (exitCode) => {
            const entryId = root.imagePreviewCurrentId;
            Qt.callLater(function() {
                if (entryId.length === 0 || root.imagePreviewCurrentId !== entryId)
                    return;
                root.finishImagePreview(entryId, exitCode === 0 ? imagePreviewOut.text.trim() : "");
                root.startNextImagePreview();
            });
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
        id: imagePathCopyProc

        command: ["echo"]
        onExited: (exitCode) => {
            const success = exitCode === 0;
            if (success)
                root.refresh();
            else
                root.lastError = "Failed to copy image path";
            root.imagePathCopyCompleted(success);
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
