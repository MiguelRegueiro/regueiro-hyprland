.pragma library

var knownMethods = {
    "keyboard-es": { label: "es", name: "Español" },
    "mozc": { label: "あ", name: "日本語" }
};

function _titleCase(text) {
    return text.replace(/\b[a-z]/g, function(match) {
        return match.toUpperCase();
    });
}

function _fallbackLabel(methodId) {
    if (!methodId || methodId.length === 0)
        return "--";

    if (methodId.indexOf("keyboard-") === 0)
        return methodId.slice("keyboard-".length).toUpperCase();

    return methodId.slice(0, 2).toUpperCase();
}

function _fallbackName(methodId) {
    if (!methodId || methodId.length === 0)
        return "Input";

    if (methodId.indexOf("keyboard-") === 0)
        return "Keyboard " + methodId.slice("keyboard-".length).toUpperCase();

    return _titleCase(methodId.replace(/[-_]+/g, " "));
}

function metadataFor(methodId) {
    var known = knownMethods[methodId];
    if (known) {
        return {
            id: methodId,
            label: known.label,
            name: known.name
        };
    }

    return {
        id: methodId,
        label: _fallbackLabel(methodId),
        name: _fallbackName(methodId)
    };
}

function buildMethods(methodIds, currentIM) {
    var seen = {};
    var orderedIds = [];
    var i;
    var methodId;

    for (i = 0; i < methodIds.length; i++) {
        methodId = methodIds[i];
        if (!methodId || seen[methodId])
            continue;

        seen[methodId] = true;
        orderedIds.push(methodId);
    }

    if (currentIM && !seen[currentIM])
        orderedIds.push(currentIM);

    var methods = [];

    for (i = 0; i < orderedIds.length; i++)
        methods.push(metadataFor(orderedIds[i]));

    return methods;
}
