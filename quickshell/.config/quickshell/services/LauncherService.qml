import QtCore
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var entries: []
    property var hiddenEntryIds: ({
    })
    property bool loading: true
    property bool visibilityRefreshPending: false
    property string lastError: ""
    property int maxResults: 30
    property int statsRevision: 0
    property int minimumFuzzyQueryLength: 2
    property var launchCounts: ({
    })
    property var lastLaunchTimes: ({
    })
    readonly property url launcherStatsLocation: Qt.resolvedUrl(Quickshell.statePath("launcher-usage.ini"))
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

    function normalizedSearchText(value) {
        return root.normalizeText(value).replace(/[_./:+-]+/g, " ").replace(/\s+/g, " ").trim();
    }

    function compactText(value) {
        return root.normalizedSearchText(value).replace(/\s+/g, "");
    }

    function isBoundaryCharacter(character) {
        return character === " " || character === "-" || character === "_" || character === "." || character === "/" || character === ":" || character === "+" || character === "(" || character === ")";
    }

    function initialsText(value) {
        const text = root.normalizedSearchText(value);
        if (text.length === 0)
            return "";

        let initials = "";
        let takeNext = true;
        for (let index = 0; index < text.length; index += 1) {
            const currentCharacter = text[index];
            if (currentCharacter === " ") {
                takeNext = true;
                continue;
            }
            if (takeNext) {
                initials += currentCharacter;
                takeNext = false;
            }
        }
        return initials;
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
        return root.stringList(values).map((value) => {
            return root.normalizedSearchText(value);
        }).filter((value) => {
            return value.length > 0;
        }).join(" ");
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

    function numericSettingValue(value) {
        const number = Number(value);
        return Number.isFinite(number) && number > 0 ? number : 0;
    }

    function statsKeyId(value) {
        const text = typeof value === "string" ? value.trim() : "";
        if (text.length === 0)
            return "__unknown__";

        return text.replace(/\//g, "_");
    }

    function launchCountKey(statsId) {
        return `count/${root.statsKeyId(statsId)}`;
    }

    function lastLaunchKey(statsId) {
        return `last/${root.statsKeyId(statsId)}`;
    }

    function hasCachedStats(statsId) {
        return root.launchCounts[statsId] !== undefined && root.lastLaunchTimes[statsId] !== undefined;
    }

    function ensureStatsLoaded(statsId) {
        const normalizedId = typeof statsId === "string" ? statsId.trim() : "";
        if (normalizedId.length === 0 || root.hasCachedStats(normalizedId))
            return ;

        root.launchCounts[normalizedId] = Math.max(0, Math.floor(root.numericSettingValue(launcherStats.value(root.launchCountKey(normalizedId), 0))));
        root.lastLaunchTimes[normalizedId] = Math.max(0, Math.floor(root.numericSettingValue(launcherStats.value(root.lastLaunchKey(normalizedId), 0))));
    }

    function launchCountForId(statsId) {
        root.ensureStatsLoaded(statsId);
        const launchCount = root.launchCounts[statsId];
        return typeof launchCount === "number" && Number.isFinite(launchCount) && launchCount > 0 ? launchCount : 0;
    }

    function lastLaunchForId(statsId) {
        root.ensureStatsLoaded(statsId);
        const lastLaunchMs = root.lastLaunchTimes[statsId];
        return typeof lastLaunchMs === "number" && Number.isFinite(lastLaunchMs) && lastLaunchMs > 0 ? lastLaunchMs : 0;
    }

    function rememberLaunch(statsId) {
        const normalizedId = typeof statsId === "string" ? statsId.trim() : "";
        if (normalizedId.length === 0)
            return ;

        const nextLaunchCount = root.launchCountForId(normalizedId) + 1;
        const nextLaunchMs = Date.now();
        root.launchCounts[normalizedId] = nextLaunchCount;
        root.lastLaunchTimes[normalizedId] = nextLaunchMs;
        launcherStats.setValue(root.launchCountKey(normalizedId), nextLaunchCount);
        launcherStats.setValue(root.lastLaunchKey(normalizedId), nextLaunchMs);
        launcherStats.sync();
        root.statsRevision += 1;
    }

    function frecencyScore(statsId) {
        const launchCount = root.launchCountForId(statsId);
        if (launchCount === 0)
            return 0;

        const volumeScore = Math.log(launchCount + 1) * 150;
        const lastLaunchMs = root.lastLaunchForId(statsId);
        if (lastLaunchMs <= 0)
            return Math.round(volumeScore);

        const ageDays = Math.max(0, (Date.now() - lastLaunchMs) / 8.64e+07);
        const recencyScore = 420 * Math.exp(-ageDays / 6.5);
        return Math.round(volumeScore + recencyScore + 24);
    }

    function searchUsageBonus(statsId, limit, multiplier) {
        const frecency = root.frecencyScore(statsId);
        if (frecency <= 0)
            return 0;

        return Math.min(limit, Math.round(Math.sqrt(frecency) * multiplier));
    }

    function compareEntryIdentity(left, right) {
        return left.sortKey.localeCompare(right.sortKey) || left.name.localeCompare(right.name);
    }

    function compareUsage(left, right) {
        return root.frecencyScore(right.statsId) - root.frecencyScore(left.statsId) || root.launchCountForId(right.statsId) - root.launchCountForId(left.statsId) || root.lastLaunchForId(right.statsId) - root.lastLaunchForId(left.statsId);
    }

    function compareDefaultEntries(left, right) {
        return root.compareUsage(left, right) || root.compareEntryIdentity(left, right);
    }

    function compareScoredMatches(left, right) {
        return right.score - left.score || right.usageScore - left.usageScore || root.compareEntryIdentity(left.entry, right.entry);
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
        const statsId = id.length > 0 ? id : nameLower;
        root.ensureStatsLoaded(statsId);
        return {
            "entry": entry,
            "id": id,
            "statsId": statsId,
            "icon": icon,
            "name": name,
            "subtitle": subtitle,
            "runInTerminal": !!entry.runInTerminal,
            "nameLower": nameLower,
            "genericNameLower": genericNameLower,
            "commentLower": commentLower,
            "idLower": idLower,
            "keywordsLower": keywordsLower,
            "categoriesLower": categoriesLower,
            "nameInitials": root.initialsText(name),
            "genericNameInitials": root.initialsText(genericName),
            "idInitials": root.initialsText(id),
            "nameCompact": root.compactText(name),
            "genericNameCompact": root.compactText(genericName),
            "idCompact": root.compactText(id),
            "keywordsCompact": root.compactText(keywordsLower),
            "searchText": [root.normalizedSearchText(name), root.normalizedSearchText(genericName), root.normalizedSearchText(comment), root.normalizedSearchText(id), keywordsLower, categoriesLower].filter((value) => {
                return value.length > 0;
            }).join(" "),
            "sortKey": `${nameLower}\u0000${idLower}`
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
        nextEntries.sort((left, right) => {
            return root.compareEntryIdentity(left, right);
        });
        root.entries = nextEntries;
        root.loading = false;
    }

    function parseHiddenEntryIds(output) {
        const hiddenIds = ({
        });
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
            return ;
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

        if (root.isBoundaryCharacter(haystack[index - 1]))
            return Math.max(prefixWeight - 24, containsWeight + 28);

        return Math.max(containsWeight - Math.min(index, 56), 8);
    }

    function compactFieldScore(haystack, query, matchWeight) {
        if (haystack.length === 0 || query.length < root.minimumFuzzyQueryLength)
            return 0;

        const index = haystack.indexOf(query);
        if (index < 0)
            return 0;

        if (index === 0)
            return matchWeight;

        return Math.max(36, matchWeight - Math.min(matchWeight - 36, index * 6));
    }

    function rankEntry(entry, query, words, compactQuery) {
        let score = 0;
        if (entry.nameLower === query)
            score += 2600;

        if (entry.idLower === query)
            score += 2400;

        if (entry.nameCompact === compactQuery && compactQuery.length >= root.minimumFuzzyQueryLength)
            score += 2100;

        if (entry.nameLower.startsWith(query))
            score += 1800 - Math.min(200, entry.nameLower.length - query.length);

        if (entry.genericNameLower.startsWith(query))
            score += 1200;

        if (entry.idLower.startsWith(query))
            score += 1100;

        if (entry.commentLower.startsWith(query))
            score += 520;

        if (entry.nameInitials.startsWith(query))
            score += 960;

        if (entry.genericNameInitials.startsWith(query))
            score += 560;

        if (entry.idInitials.startsWith(query))
            score += 480;

        if (entry.searchText.includes(query))
            score += Math.max(420 - entry.searchText.indexOf(query), 120);

        score += root.compactFieldScore(entry.nameCompact, compactQuery, 760);
        score += root.compactFieldScore(entry.genericNameCompact, compactQuery, 420);
        score += root.compactFieldScore(entry.idCompact, compactQuery, 360);
        score += root.compactFieldScore(entry.keywordsCompact, compactQuery, 280);
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

        return score + root.searchUsageBonus(entry.statsId, 140, 4);
    }

    function canUseFuzzy(words) {
        if (words.length === 0)
            return false;

        for (const word of words) {
            if (word.length < root.minimumFuzzyQueryLength)
                return false;

        }
        return true;
    }

    function fuzzyFieldScore(haystack, needle, boundaryWeight, consecutiveWeight) {
        if (haystack.length === 0 || needle.length === 0 || needle.length > haystack.length)
            return 0;

        let score = 0;
        let previousIndex = -1;
        let firstIndex = -1;
        let consecutiveRun = 0;
        let boundaryHits = 0;
        for (let cursor = 0; cursor < needle.length; cursor += 1) {
            const index = haystack.indexOf(needle[cursor], previousIndex + 1);
            if (index < 0)
                return 0;

            if (firstIndex < 0) {
                firstIndex = index;
                score += Math.max(0, 42 - index * 4);
            }
            if (index === 0 || root.isBoundaryCharacter(haystack[index - 1])) {
                boundaryHits += 1;
                score += boundaryWeight;
            }
            if (previousIndex >= 0) {
                const gap = index - previousIndex - 1;
                if (gap === 0) {
                    consecutiveRun += 1;
                    score += consecutiveWeight + Math.min(24, consecutiveRun * 8);
                } else {
                    consecutiveRun = 0;
                    score -= Math.min(44, gap * 3);
                }
            }
            previousIndex = index;
        }
        score += Math.max(0, 24 - (haystack.length - needle.length));
        if (firstIndex > 0 && !root.isBoundaryCharacter(haystack[firstIndex - 1]))
            score -= Math.min(20, firstIndex * 2);

        if (needle.length <= 2 && boundaryHits === 0 && firstIndex > 0)
            score -= 20;

        const minimumScore = needle.length <= 2 ? 48 : 42 + needle.length * 8;
        return score >= minimumScore ? score : 0;
    }

    function bestFuzzyWordScore(entry, word) {
        let best = 0;
        const nameScore = root.fuzzyFieldScore(entry.nameLower, word, 34, 32);
        if (nameScore > 0)
            best = Math.max(best, nameScore + 220);

        const genericNameScore = root.fuzzyFieldScore(entry.genericNameLower, word, 30, 28);
        if (genericNameScore > 0)
            best = Math.max(best, genericNameScore + 150);

        const idScore = root.fuzzyFieldScore(entry.idLower, word, 28, 24);
        if (idScore > 0)
            best = Math.max(best, idScore + 132);

        const keywordsScore = root.fuzzyFieldScore(entry.keywordsLower, word, 26, 22);
        if (keywordsScore > 0)
            best = Math.max(best, keywordsScore + 116);

        const commentScore = root.fuzzyFieldScore(entry.commentLower, word, 18, 16);
        if (commentScore > 0)
            best = Math.max(best, commentScore + 56);

        return best;
    }

    function rankFuzzyEntry(entry, query, words, compactQuery) {
        let score = 0;
        for (const word of words) {
            const wordScore = root.bestFuzzyWordScore(entry, word);
            if (wordScore === 0)
                return 0;

            score += wordScore;
        }
        const wholeNameScore = root.fuzzyFieldScore(entry.nameCompact, compactQuery, 34, 30);
        if (wholeNameScore > 0)
            score += wholeNameScore + 180;

        const wholeGenericScore = root.fuzzyFieldScore(entry.genericNameCompact, compactQuery, 28, 24);
        if (wholeGenericScore > 0)
            score += wholeGenericScore + 112;

        const wholeIdScore = root.fuzzyFieldScore(entry.idCompact, compactQuery, 26, 22);
        if (wholeIdScore > 0)
            score += wholeIdScore + 96;

        if (entry.runInTerminal)
            score -= 5;

        return score + root.searchUsageBonus(entry.statsId, 96, 3);
    }

    function searchEntries(query) {
        const statsRevision = root.statsRevision;
        const normalizedQuery = root.normalizeText(query);
        if (normalizedQuery.length === 0) {
            const rankedEntries = root.entries.slice();
            rankedEntries.sort((left, right) => {
                return root.compareDefaultEntries(left, right);
            });
            return rankedEntries.slice(0, root.maxResults);
        }
        const words = normalizedQuery.split(/\s+/).filter((word) => {
            return word.length > 0;
        });
        const compactQuery = words.join("");
        const strictMatches = [];
        for (const entry of root.entries) {
            if (!root.allWordsMatch(entry.searchText, words))
                continue;

            strictMatches.push({
                "entry": entry,
                "score": root.rankEntry(entry, normalizedQuery, words, compactQuery),
                "usageScore": root.frecencyScore(entry.statsId)
            });
        }
        strictMatches.sort((left, right) => {
            return root.compareScoredMatches(left, right);
        });
        if (strictMatches.length >= root.maxResults || !root.canUseFuzzy(words))
            return strictMatches.slice(0, root.maxResults).map((item) => {
            return item.entry;
        });

        const strictIds = ({
        });
        for (const match of strictMatches) strictIds[match.entry.statsId] = true
        const fuzzyMatches = [];
        for (const entry of root.entries) {
            if (strictIds[entry.statsId])
                continue;

            const score = root.rankFuzzyEntry(entry, normalizedQuery, words, compactQuery);
            if (score <= 0)
                continue;

            fuzzyMatches.push({
                "entry": entry,
                "score": score,
                "usageScore": root.frecencyScore(entry.statsId)
            });
        }
        fuzzyMatches.sort((left, right) => {
            return root.compareScoredMatches(left, right);
        });
        const results = strictMatches.slice(0, root.maxResults).map((item) => {
            return item.entry;
        });
        for (const match of fuzzyMatches) {
            if (results.length >= root.maxResults)
                break;

            results.push(match.entry);
        }
        return results;
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
                    "command": command,
                    "workingDirectory": entry.entry.workingDirectory
                });
                root.rememberLaunch(entry.statsId);
                return true;
            }
            entry.entry.execute();
            root.rememberLaunch(entry.statsId);
            return true;
        } catch (error) {
            root.lastError = `Failed to launch ${entry.name}`;
            return false;
        }
    }

    Component.onCompleted: root.refreshVisibility()

    Settings {
        id: launcherStats

        category: "LauncherUsage"
        location: root.launcherStatsLocation
    }

    Connections {
        function onApplicationsChanged() {
            root.refreshVisibility();
        }

        target: DesktopEntries
    }

    Process {
        id: visibilityProc

        command: ["sh", Quickshell.shellPath("scripts/launcher-hidden-entries.sh")]
        onExited: (exitCode) => {
            root.rebuildEntries();
            if (exitCode !== 0)
                root.lastError = "Failed to evaluate launcher visibility rules";

            if (root.visibilityRefreshPending) {
                root.visibilityRefreshPending = false;
                root.refreshVisibility();
            }
        }

        stdout: StdioCollector {
            id: visibilityOut

            waitForEnd: true
            onStreamFinished: {
                root.hiddenEntryIds = root.parseHiddenEntryIds(visibilityOut.text);
            }
        }

    }

}
