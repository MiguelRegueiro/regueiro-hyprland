import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property var hiddenEntryIds: ({})
    property bool loading: true
    property bool visibilityRefreshPending: false
    property string lastError: ""
    property int maxResults: 30
    // Matches the repo's current Hyprland terminal command.
    property var terminalCommand: ["kitty"]

    function clearError() {
        root.lastError = "";
    }

    function normalizeText(value) {
        if (value === undefined || value === null)
            return "";

        return String(value).trim().toLowerCase();
    }

    function stringList(values) {
        const items = [];
        if (values === undefined || values === null)
            return items;

        const length = typeof values.length === "number" ? values.length : 0;
        for (let index = 0; index < length; index += 1) {
            const value = values[index];
            if (value === undefined || value === null)
                continue;

            const text = String(value).trim();
            if (text.length > 0)
                items.push(text);
        }

        return items;
    }

    function listToText(values) {
        return root.stringList(values).join(" ").toLowerCase();
    }

    function buildSubtitle(comment, genericName, categories) {
        if (comment.length > 0)
            return comment;

        if (genericName.length > 0)
            return genericName;

        if (Array.isArray(categories) && categories.length > 0)
            return categories.slice(0, 2).join(" · ");

        return "";
    }

    function mapEntry(entry) {
        if (!entry || entry.noDisplay)
            return null;

        const name = typeof entry.name === "string" ? entry.name.trim() : "";
        if (name.length === 0)
            return null;

        const genericName = typeof entry.genericName === "string" ? entry.genericName.trim() : "";
        const comment = typeof entry.comment === "string" ? entry.comment.trim() : "";
        const id = typeof entry.id === "string" ? entry.id.trim() : "";
        const icon = typeof entry.icon === "string" ? entry.icon.trim() : "";
        const keywords = root.stringList(entry.keywords);
        const categories = root.stringList(entry.categories);
        const subtitle = root.buildSubtitle(comment, genericName, categories);
        const nameLower = root.normalizeText(name);
        const genericNameLower = root.normalizeText(genericName);
        const commentLower = root.normalizeText(comment);
        const idLower = root.normalizeText(id);
        const keywordsLower = root.listToText(keywords);
        const categoriesLower = root.listToText(categories);

        return {
            entry: entry,
            id: id,
            icon: icon,
            name: name,
            subtitle: subtitle,
            runInTerminal: !!entry.runInTerminal,
            nameLower: nameLower,
            genericNameLower: genericNameLower,
            commentLower: commentLower,
            idLower: idLower,
            keywordsLower: keywordsLower,
            categoriesLower: categoriesLower,
            searchText: [nameLower, genericNameLower, commentLower, idLower, keywordsLower, categoriesLower].filter((value) => value.length > 0).join(" "),
            sortKey: `${nameLower}\u0000${idLower}`
        };
    }

    function rebuildEntries() {
        root.loading = true;
        root.lastError = "";

        const nextEntries = [];
        const sourceEntries = DesktopEntries.applications.values || [];

        for (const entry of sourceEntries) {
            const mapped = root.mapEntry(entry);
            if (mapped !== null && !root.isHiddenEntry(mapped.id))
                nextEntries.push(mapped);
        }

        nextEntries.sort((left, right) => left.sortKey.localeCompare(right.sortKey) || left.name.localeCompare(right.name));

        root.entries = nextEntries;
        root.loading = false;
    }

    function parseHiddenEntryIds(output) {
        const hiddenIds = ({});
        const lines = String(output || "").split(/\r?\n/);
        for (const line of lines) {
            const normalizedId = typeof line === "string" ? line.trim() : "";
            if (normalizedId.length === 0)
                continue;

            hiddenIds[normalizedId] = true;
            if (normalizedId.endsWith(".desktop"))
                hiddenIds[normalizedId.slice(0, -8)] = true;
        }

        return hiddenIds;
    }

    function isHiddenEntry(id) {
        const normalizedId = typeof id === "string" ? id.trim() : "";
        if (normalizedId.length === 0)
            return false;

        if (root.hiddenEntryIds[normalizedId])
            return true;

        if (normalizedId.endsWith(".desktop"))
            return !!root.hiddenEntryIds[normalizedId.slice(0, -8)];

        return !!root.hiddenEntryIds[`${normalizedId}.desktop`];
    }

    function refreshVisibility() {
        if (visibilityProc.running) {
            root.visibilityRefreshPending = true;
            return;
        }

        root.loading = true;
        root.lastError = "";
        visibilityProc.running = true;
    }

    function allWordsMatch(text, words) {
        for (const word of words) {
            if (!text.includes(word))
                return false;
        }

        return true;
    }

    function fieldScore(haystack, word, prefixWeight, containsWeight) {
        if (haystack.length === 0)
            return 0;

        const index = haystack.indexOf(word);
        if (index < 0)
            return 0;

        if (index === 0)
            return prefixWeight;

        if (haystack[index - 1] === " ")
            return Math.max(prefixWeight - 24, containsWeight + 28);

        return Math.max(containsWeight - Math.min(index, 56), 8);
    }

    function rankEntry(entry, query, words) {
        let score = 0;

        if (entry.nameLower === query)
            score += 2600;

        if (entry.idLower === query)
            score += 2400;

        if (entry.nameLower.startsWith(query))
            score += 1800 - Math.min(200, entry.nameLower.length - query.length);

        if (entry.genericNameLower.startsWith(query))
            score += 1200;

        if (entry.idLower.startsWith(query))
            score += 1100;

        if (entry.commentLower.startsWith(query))
            score += 520;

        if (entry.searchText.includes(query))
            score += Math.max(420 - entry.searchText.indexOf(query), 120);

        for (const word of words) {
            score += root.fieldScore(entry.nameLower, word, 240, 88);
            score += root.fieldScore(entry.genericNameLower, word, 150, 52);
            score += root.fieldScore(entry.idLower, word, 150, 46);
            score += root.fieldScore(entry.commentLower, word, 90, 34);
            score += root.fieldScore(entry.keywordsLower, word, 84, 30);
            score += root.fieldScore(entry.categoriesLower, word, 54, 24);
        }

        if (entry.runInTerminal)
            score -= 5;

        return score;
    }

    function searchEntries(query) {
        const normalizedQuery = root.normalizeText(query);

        if (normalizedQuery.length === 0)
            return root.entries.slice(0, root.maxResults);

        const words = normalizedQuery.split(/\s+/).filter((word) => word.length > 0);
        const matches = [];

        for (const entry of root.entries) {
            if (!root.allWordsMatch(entry.searchText, words))
                continue;

            matches.push({
                entry: entry,
                score: root.rankEntry(entry, normalizedQuery, words)
            });
        }

        matches.sort((left, right) => right.score - left.score || left.entry.sortKey.localeCompare(right.entry.sortKey) || left.entry.name.localeCompare(right.entry.name));
        return matches.slice(0, root.maxResults).map((item) => item.entry);
    }

    function commandList(values) {
        const command = [];
        if (values === undefined || values === null)
            return command;

        const length = typeof values.length === "number" ? values.length : 0;
        for (let index = 0; index < length; index += 1) {
            const value = values[index];
            if (value !== undefined && value !== null && String(value).length > 0)
                command.push(String(value));
        }

        return command;
    }

    function launchCommand(entry) {
        const baseCommand = root.commandList(entry.entry.command);
        if (baseCommand.length === 0)
            return [];

        if (!entry.runInTerminal)
            return baseCommand;

        const terminalPrefix = root.commandList(root.terminalCommand);
        if (terminalPrefix.length === 0)
            return baseCommand;

        return terminalPrefix.concat(["-e"], baseCommand);
    }

    function launchEntry(entry) {
        if (!entry || !entry.entry)
            return false;

        root.lastError = "";

        try {
            const command = root.launchCommand(entry);
            if (command.length > 0) {
                Quickshell.execDetached({
                    command: command,
                    workingDirectory: entry.entry.workingDirectory
                });
                return true;
            }

            entry.entry.execute();
            return true;
        } catch (error) {
            root.lastError = `Failed to launch ${entry.name}`;
            return false;
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.refreshVisibility();
        }
    }

    Process {
        id: visibilityProc

        command: ["sh", Quickshell.shellPath("scripts/launcher-hidden-entries.sh")]
        stdout: StdioCollector {
            id: visibilityOut

            waitForEnd: true
            onStreamFinished: {
                root.hiddenEntryIds = root.parseHiddenEntryIds(visibilityOut.text);
            }
        }
        onExited: (exitCode) => {
            root.rebuildEntries();

            if (exitCode !== 0)
                root.lastError = "Failed to evaluate launcher visibility rules";

            if (root.visibilityRefreshPending) {
                root.visibilityRefreshPending = false;
                root.refreshVisibility();
            }
        }
    }

    Component.onCompleted: root.refreshVisibility()
}
