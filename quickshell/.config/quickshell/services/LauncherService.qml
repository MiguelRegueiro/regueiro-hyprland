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
    // 0 means unlimited; the app drawer should be able to show every installed app.
    property int maxResults: 0
    property int statsRevision: 0
    property var launchCounts: ({
    })
    property var lastLaunchTimes: ({
    })
    property int entriesRevision: 0
    property var usageOrderedCache: []
    property var searchResultCache: ({
    })
    property var iconPathCache: ({
    })
    property var iconRasterCache: ({
    })
    property var pendingIconRasterCache: null
    property var pendingIconRasterizations: []
    property bool iconRasterizationRunning: false
    property bool iconRasterApplyBlocked: false
    readonly property string genericIconFallback: "application-x-executable"
    readonly property string iconRasterCachePath: Quickshell.statePath("launcher-icon-cache")
    readonly property url launcherIconCacheLocation: Qt.resolvedUrl(Quickshell.statePath("launcher-icon-cache.ini"))
    readonly property string fallbackIconSourcePath: {
        const resolved = Quickshell.iconPath("", root.genericIconFallback);
        return typeof resolved === "string" && resolved.length > 0 ? resolved : root.genericIconFallback;
    }
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

    function idShortText(idLower) {
        if (idLower.length === 0)
            return "";

        const lastDot = idLower.lastIndexOf(".");
        if (lastDot < 0 || lastDot === idLower.length - 1)
            return idLower;

        return idLower.slice(lastDot + 1);
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

    function tokensForText(value) {
        const text = root.normalizedSearchText(value);
        if (text.length === 0)
            return [];

        return text.split(" ").filter((token) => {
            return token.length > 0;
        });
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
        root.rebuildUsageOrderedCache();
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

    function compareEntryIdentity(left, right) {
        return left.sortKey.localeCompare(right.sortKey) || left.name.localeCompare(right.name);
    }

    function compareUsage(left, right) {
        return root.launchCountForId(right.statsId) - root.launchCountForId(left.statsId) || root.lastLaunchForId(right.statsId) - root.lastLaunchForId(left.statsId) || root.frecencyScore(right.statsId) - root.frecencyScore(left.statsId);
    }

    function compareDefaultEntries(left, right) {
        return root.compareUsage(left, right) || root.compareEntryIdentity(left, right);
    }

    function usageOrderedEntries() {
        if (root.usageOrderedCache.length > 0 || root.entries.length === 0)
            return root.usageOrderedCache;

        return root.entries;
    }

    function rebuildUsageOrderedCache() {
        const rankedEntries = root.entries.slice();
        rankedEntries.sort((left, right) => {
            return root.compareDefaultEntries(left, right);
        });
        root.usageOrderedCache = rankedEntries;
        root.searchResultCache = ({
        });
    }

    function limitedResults(values) {
        if (root.maxResults <= 0)
            return values;

        return values.slice(0, root.maxResults);
    }

    function iconDisplaySource(iconName, resolvedSource) {
        const rasterSource = root.iconRasterSource(iconName, resolvedSource);
        if (rasterSource.length > 0)
            return rasterSource;

        if (typeof iconName === "string") {
            const normalizedIcon = iconName.trim();
            if (normalizedIcon.length > 0 && normalizedIcon.charAt(0) !== "/")
                return `image://icon/${normalizedIcon}`;

        }
        if (typeof resolvedSource === "string" && resolvedSource.length > 0)
            return resolvedSource;

        return root.fallbackIconSourcePath;
    }

    function iconRasterKey(iconName, resolvedSource) {
        if (typeof iconName === "string") {
            const normalizedIcon = iconName.trim();
            if (normalizedIcon.length > 0) {
                if (normalizedIcon.charAt(0) === "/")
                    return normalizedIcon;

                return `icon:${normalizedIcon}`;
            }

        }
        if (typeof resolvedSource === "string" && resolvedSource.length > 0 && resolvedSource.charAt(0) === "/")
            return resolvedSource;

        return "";
    }

    function iconRasterSource(iconName, resolvedSource) {
        const key = root.iconRasterKey(iconName, resolvedSource);
        if (key.length === 0)
            return "";

        const cached = root.iconRasterCache[key];
        return typeof cached === "string" && cached.length > 0 ? cached : "";
    }

    function loadIconRasterCache() {
        const rawCache = launcherIconCache.value("entries", "{}");
        let parsed = ({
        });
        try {
            parsed = JSON.parse(String(rawCache || "{}"));
        } catch (error) {
            parsed = ({
            });
        }

        const loaded = ({
        });
        for (const cacheKey in parsed) {
            const source = parsed[cacheKey];
            if (typeof cacheKey === "string" && cacheKey.length > 0 && typeof source === "string" && source.length > 0)
                loaded[cacheKey] = source;

        }
        root.iconRasterCache = loaded;
    }

    function saveIconRasterCache(cache) {
        launcherIconCache.setValue("entries", JSON.stringify(cache));
        launcherIconCache.sync();
    }

    function applyIconRasterCache(cache) {
        if (root.iconRasterApplyBlocked) {
            root.pendingIconRasterCache = cache;
            return;
        }

        root.pendingIconRasterCache = null;
        root.iconRasterCache = cache;
        root.saveIconRasterCache(cache);
    }

    function flushPendingIconRasterCache() {
        if (root.iconRasterApplyBlocked || root.pendingIconRasterCache === null)
            return;

        root.applyIconRasterCache(root.pendingIconRasterCache);
    }

    function canRasterizeIcon(iconName, source) {
        return root.iconRasterKey(iconName, source).length > 0;
    }

    function hasPendingIconRasterization(key) {
        for (const item of root.pendingIconRasterizations) {
            if (item && item.key === key)
                return true;

        }
        return false;
    }

    function queueIconRasterization(iconName, source) {
        if (!root.canRasterizeIcon(iconName, source))
            return;

        const key = root.iconRasterKey(iconName, source);
        if (root.iconRasterCache[key] !== undefined)
            return;

        if (root.hasPendingIconRasterization(key))
            return;

        root.pendingIconRasterizations = root.pendingIconRasterizations.concat([{
            "key": key,
            "icon": typeof iconName === "string" ? iconName.trim() : "",
            "source": typeof source === "string" ? source : ""
        }]);
        root.processNextIconRasterization();
    }

    function queueIconRasterizations(entries) {
        const values = Array.isArray(entries) ? entries : [];
        for (const entry of values)
            root.queueIconRasterization(entry.icon, entry.iconSource);

    }

    function processNextIconRasterization() {
        if (root.iconRasterizationRunning || root.pendingIconRasterizations.length === 0)
            return;

        const items = root.pendingIconRasterizations.filter((item) => {
            return item && typeof item.key === "string" && item.key.length > 0 && root.iconRasterCache[item.key] === undefined;
        });
        root.pendingIconRasterizations = [];
        if (items.length === 0) {
            Qt.callLater(root.processNextIconRasterization);
            return;
        }
        if (typeof iconRasterProc === "undefined") {
            Qt.callLater(root.processNextIconRasterization);
            return;
        }

        const command = ["sh", Quickshell.shellPath("scripts/launcher-rasterize-icons.sh"), root.iconRasterCachePath];
        for (const item of items) {
            command.push(item.key);
            command.push(item.icon);
            command.push(item.source);
        }
        iconRasterProc.command = command;
        root.iconRasterizationRunning = true;
        iconRasterProc.running = true;
    }

    function iconSourceForName(iconName) {
        const fallback = root.fallbackIconSourcePath;
        if (typeof iconName !== "string")
            return fallback;

        const normalizedIcon = iconName.trim();
        if (normalizedIcon.length === 0)
            return fallback;

        if (normalizedIcon.charAt(0) === "/")
            return normalizedIcon;

        const cached = root.iconPathCache[normalizedIcon];
        if (cached !== undefined)
            return cached;

        const resolved = Quickshell.iconPath(normalizedIcon, root.genericIconFallback);
        const source = typeof resolved === "string" && resolved.length > 0 ? resolved : fallback;
        root.iconPathCache[normalizedIcon] = source;
        return source;
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
        const nameSearchText = root.normalizedSearchText(name);
        const genericNameSearchText = root.normalizedSearchText(genericName);
        const commentSearchText = root.normalizedSearchText(comment);
        const idSearchText = root.normalizedSearchText(id);
        const primarySearchText = [nameSearchText, genericNameSearchText, idSearchText].filter((value) => {
            return value.length > 0;
        }).join(" ");
        const secondarySearchText = [commentSearchText, keywordsLower, categoriesLower].filter((value) => {
            return value.length > 0;
        }).join(" ");
        const searchText = [primarySearchText, secondarySearchText].filter((value) => {
            return value.length > 0;
        }).join(" ");
        const statsId = id.length > 0 ? id : nameLower;
        root.ensureStatsLoaded(statsId);
        return {
            "entry": entry,
            "id": id,
            "statsId": statsId,
            "icon": icon,
            "iconSource": root.iconSourceForName(icon),
            "name": name,
            "subtitle": subtitle,
            "runInTerminal": !!entry.runInTerminal,
            "nameLower": nameLower,
            "genericNameLower": genericNameLower,
            "commentLower": commentLower,
            "idLower": idLower,
            "idShortLower": root.idShortText(idLower),
            "keywordsLower": keywordsLower,
            "categoriesLower": categoriesLower,
            "nameInitials": root.initialsText(name),
            "genericNameInitials": root.initialsText(genericName),
            "idInitials": root.initialsText(id),
            "nameCompact": root.compactText(name),
            "genericNameCompact": root.compactText(genericName),
            "idCompact": root.compactText(id),
            "commentCompact": root.compactText(comment),
            "keywordsCompact": root.compactText(keywordsLower),
            "categoriesCompact": root.compactText(categoriesLower),
            "primarySearchText": primarySearchText,
            "secondarySearchText": secondarySearchText,
            "searchText": searchText,
            "primarySearchTokens": root.tokensForText(primarySearchText),
            "secondarySearchTokens": root.tokensForText(secondarySearchText),
            "searchTokens": root.tokensForText(searchText),
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
        root.entriesRevision += 1;
        root.rebuildUsageOrderedCache();
        Qt.callLater(function() {
            root.queueIconRasterizations(root.usageOrderedEntries());
        });
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

    function allWordsHaveTokenPrefix(tokens, words) {
        for (const word of words) {
            let matched = false;
            for (const token of tokens) {
                if (token.startsWith(word)) {
                    matched = true;
                    break;
                }
            }
            if (!matched)
                return false;

        }
        return true;
    }

    function hasPrimaryCompactMatch(entry, compactQuery) {
        if (compactQuery.length === 0)
            return false;

        return entry.nameCompact.includes(compactQuery) || entry.genericNameCompact.includes(compactQuery) || entry.idCompact.includes(compactQuery);
    }

    function hasSecondaryCompactMatch(entry, compactQuery) {
        if (compactQuery.length === 0)
            return false;

        return entry.commentCompact.includes(compactQuery) || entry.keywordsCompact.includes(compactQuery) || entry.categoriesCompact.includes(compactQuery);
    }

    function isSubsequence(needle, haystack) {
        if (needle.length < 2 || haystack.length === 0 || needle.length > haystack.length)
            return false;

        let cursor = 0;
        for (let index = 0; index < haystack.length && cursor < needle.length; index += 1) {
            if (haystack[index] === needle[cursor])
                cursor += 1;
        }
        return cursor === needle.length;
    }

    function hasSubsequenceMatch(entry, compactQuery) {
        if (compactQuery.length < 2)
            return false;

        return root.isSubsequence(compactQuery, entry.nameCompact) || root.isSubsequence(compactQuery, entry.genericNameCompact) || root.isSubsequence(compactQuery, entry.idCompact);
    }

    function searchMatchTier(entry, normalizedQuery, words, compactQuery) {
        const exactPrimaryMatch = entry.nameLower === normalizedQuery || entry.genericNameLower === normalizedQuery || entry.idShortLower === normalizedQuery || entry.nameCompact === compactQuery || entry.genericNameCompact === compactQuery || entry.idCompact === compactQuery;
        if (exactPrimaryMatch)
            return 0;

        const primaryPrefixMatch = entry.nameLower.startsWith(normalizedQuery) || entry.genericNameLower.startsWith(normalizedQuery) || entry.idShortLower.startsWith(normalizedQuery) || entry.nameCompact.startsWith(compactQuery) || entry.genericNameCompact.startsWith(compactQuery) || entry.idCompact.startsWith(compactQuery);
        if (primaryPrefixMatch)
            return 1;

        const primaryTokenMatch = entry.nameInitials.startsWith(compactQuery) || entry.genericNameInitials.startsWith(compactQuery) || entry.idInitials.startsWith(compactQuery) || root.allWordsHaveTokenPrefix(entry.primarySearchTokens, words);
        if (primaryTokenMatch)
            return 2;

        if (root.allWordsMatch(entry.primarySearchText, words) || root.hasPrimaryCompactMatch(entry, compactQuery))
            return 3;

        if (root.allWordsHaveTokenPrefix(entry.secondarySearchTokens, words) || root.allWordsMatch(entry.secondarySearchText, words) || root.hasSecondaryCompactMatch(entry, compactQuery))
            return 4;

        if (compactQuery.length >= 2 && root.hasSubsequenceMatch(entry, compactQuery))
            return 5;

        return -1;
    }

    function searchEntries(query) {
        const statsRevision = root.statsRevision;
        const normalizedQuery = root.normalizedSearchText(query);
        const cachedResults = root.searchResultCache[normalizedQuery];
        if (cachedResults !== undefined)
            return cachedResults;

        if (normalizedQuery.length === 0) {
            const results = root.limitedResults(root.usageOrderedEntries());
            root.searchResultCache[normalizedQuery] = results;
            return results;
        }

        const words = normalizedQuery.split(/\s+/).filter((word) => {
            return word.length > 0;
        });
        const compactQuery = words.join("");
        const buckets = [[], [], [], [], [], []];
        const sourceEntries = root.usageOrderedEntries();

        for (const entry of sourceEntries) {
            const tier = root.searchMatchTier(entry, normalizedQuery, words, compactQuery);
            if (tier >= 0)
                buckets[tier].push(entry);
        }
        const results = root.limitedResults([].concat(buckets[0], buckets[1], buckets[2], buckets[3], buckets[4], buckets[5]));
        root.searchResultCache[normalizedQuery] = results;
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

    Component.onCompleted: {
        root.loadIconRasterCache();
        root.refreshVisibility();
    }

    Settings {
        id: launcherStats

        category: "LauncherUsage"
        location: root.launcherStatsLocation
    }

    Settings {
        id: launcherIconCache

        category: "LauncherIconCache"
        location: root.launcherIconCacheLocation
    }

    Connections {
        function onApplicationsChanged() {
            root.refreshVisibility();
        }

        target: DesktopEntries
    }

    Item {
        id: iconWarmup

        x: -10000
        y: -10000
        width: 1
        height: 1
        opacity: 0
        enabled: false

        Repeater {
            model: root.entries

            delegate: Image {
                required property var modelData

                width: 1
                height: 1
                sourceSize.width: 256
                sourceSize.height: 256
                asynchronous: true
                cache: true
                source: root.iconDisplaySource(modelData.icon, modelData.iconSource)
            }
        }
    }

    Process {
        id: iconRasterProc

        onExited: {
            const updated = ({
            });
            for (const cacheKey in root.iconRasterCache) updated[cacheKey] = root.iconRasterCache[cacheKey];

            const lines = iconRasterOut.text.split(/\r?\n/);
            let changed = false;
            for (const line of lines) {
                const separator = line.indexOf("\t");
                if (separator <= 0)
                    continue;

                const key = line.slice(0, separator);
                const output = line.slice(separator + 1).trim();
                if (key.length === 0 || output.length === 0)
                    continue;

                updated[key] = output;
                changed = true;
            }
            if (changed)
                root.applyIconRasterCache(updated);

            root.iconRasterizationRunning = false;
            Qt.callLater(root.processNextIconRasterization);
        }

        stdout: StdioCollector {
            id: iconRasterOut

            waitForEnd: true
        }
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
