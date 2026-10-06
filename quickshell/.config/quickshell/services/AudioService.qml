import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../theme/Theme.js" as Theme

Item {
    id: root

    property var defaultSink: Pipewire.defaultAudioSink
    property var sinkAudio: (defaultSink && defaultSink.ready) ? defaultSink.audio : null
    property var sinkMetadata: ({
    })
    property var sinks: []
    property var outputChoices: []
    property string outputChoicesKey: ""
    property string pendingSinkName: ""
    property var pendingSinkInputIds: []
    property int pipewireVolume: sinkAudio ? Math.min(100, Math.round(sinkAudio.volume * 100)) : -1
    property int polledVolume: 0
    property bool polledMuted: false
    property int optimisticVolumePercent: -1
    property bool optimisticMuted: false
    readonly property int volumeStepPercent: 2
    readonly property int volumeFeedbackDelayMs: 28
    readonly property int volumeFeedbackQuietMs: 180
    readonly property bool hasDirectSinkControl: !!sinkAudio
    readonly property bool optimisticStateActive: optimisticVolumePercent >= 0
    readonly property var currentSink: defaultSink
    readonly property string currentSinkName: sinkDisplayName(currentSink)
    readonly property string currentSinkIcon: sinkIconText(currentSink)
    readonly property string currentSinkOsdLabel: sinkOsdLabel(currentSink)
    readonly property int actualVolumePercent: pipewireVolume >= 0 ? pipewireVolume : polledVolume
    readonly property bool actualMuted: sinkAudio ? sinkAudio.muted : polledMuted
    readonly property int volumePercent: optimisticStateActive ? optimisticVolumePercent : actualVolumePercent
    readonly property bool muted: optimisticStateActive ? optimisticMuted : actualMuted
    readonly property string volumeIcon: {
        if (muted || volumePercent <= 0)
            return "󰖁";

        if (volumePercent < 13)
            return "󰕿";

        if (volumePercent < 40)
            return "󰖀";

        if (volumePercent < 70)
            return "󰕾";

        return "";
    }

    signal volumeLimitReached()

    function sinkDisplayName(node) {
        if (!node)
            return "";

        const metadata = sinkMetadataFor(node);
        if (metadata && metadata.displayName)
            return metadata.displayName;

        const properties = node.properties || {
        };
        const alsaName = (properties["alsa.name"] || "").trim();
        return node.nickname || alsaName || properties["device.profile.description"] || node.description || properties["device.nick"] || node.name || "Unknown Output";
    }

    function sinkSecondaryName(node) {
        if (!node)
            return "";

        const metadata = sinkMetadataFor(node);
        if (metadata && metadata.secondaryName)
            return metadata.secondaryName;

        const properties = node.properties || {
        };
        const primary = sinkDisplayName(node);
        const candidates = [(properties["device.profile.description"] || "").trim(), node.description, properties["device.nick"], node.name];
        for (const candidate of candidates) {
            if (candidate && candidate !== primary)
                return candidate;

        }
        return "";
    }

    function sinkIconText(node) {
        if (!node)
            return "󰓃";

        const metadata = sinkMetadataFor(node);
        if (metadata && metadata.portType === "Headphones")
            return "󰋋";

        if (metadata && metadata.portType === "HDMI")
            return "󰍹";

        if (metadata && metadata.portType === "Speaker")
            return "󰓃";

        const properties = node.properties || {
        };
        const haystack = [node.description || "", node.nickname || "", node.name || "", properties["device.icon-name"] || "", properties["node.name"] || "", properties["device.bus"] || ""].join(" ").toLowerCase();
        if (haystack.includes("bluetooth") || haystack.includes("bluez"))
            return "󰂯";

        if (haystack.includes("headphone") || haystack.includes("headset"))
            return "󰋋";

        if (haystack.includes("hdmi") || haystack.includes("displayport") || haystack.includes("display"))
            return "󰍹";

        return "󰓃";
    }

    function sinkOsdLabel(node) {
        if (!node)
            return "";

        const metadata = sinkMetadataFor(node);
        const properties = node.properties || {
        };
        const portType = String(metadata && metadata.portType || "").toLowerCase();
        const portName = String(metadata && metadata.portName || "").toLowerCase();
        const formFactor = String(metadata && metadata.formFactor || properties["device.form_factor"] || properties["device.form-factor"] || "").toLowerCase();
        const deviceBus = String(metadata && metadata.deviceBus || properties["device.bus"] || "").toLowerCase();
        const haystack = [portType, portName, formFactor, deviceBus, node.description || "", node.nickname || "", node.name || "", properties["device.icon-name"] || "", properties["device.icon_name"] || "", properties["device.description"] || "", properties["node.name"] || ""].join(" ").toLowerCase();
        const isHeadphones = portType === "headphones" || haystack.includes("headphone") || haystack.includes("headset") || haystack.includes("earbud") || haystack.includes("earphone");
        const isHdmi = portType === "hdmi" || haystack.includes("hdmi") || haystack.includes("displayport");
        const isLineOut = portType === "line" || portName.includes("lineout") || portName.includes("line-out");
        const isBluetooth = deviceBus === "bluetooth" || haystack.includes("bluetooth") || haystack.includes("bluez");
        const isUsb = deviceBus === "usb";
        const isSpeaker = portType === "speaker" || formFactor === "speaker" || haystack.includes("external speaker");
        const isInternal = formFactor === "internal" || deviceBus === "pci" || haystack.includes("built-in") || haystack.includes("internal audio");

        if (isHeadphones)
            return "Headphones";

        if (isHdmi)
            return "HDMI";

        if (isLineOut)
            return "Speakers";

        if (isSpeaker)
            return isInternal && !isBluetooth && !isUsb ? "" : "Speakers";

        if (isBluetooth || isUsb)
            return sinkDisplayName(node);

        return "";
    }

    function sinkMetadataFor(node) {
        if (!node || !node.name)
            return null;

        return sinkMetadata[node.name] || null;
    }

    function sinkSortRank(node) {
        if (!node)
            return -1;

        if (root.defaultSink && node.id === root.defaultSink.id)
            return 3000;

        const metadata = sinkMetadataFor(node);
        if (!metadata)
            return 1000;

        let availabilityRank = 1;
        if (metadata.availability === "available")
            availabilityRank = 2;
        else if (metadata.availability === "not available")
            availabilityRank = 0;
        return availabilityRank * 1000 + metadata.priority;
    }

    function sortSinks(next) {
        next.sort((a, b) => {
            const rankDiff = sinkSortRank(b) - sinkSortRank(a);
            if (rankDiff !== 0)
                return rankDiff;

            const left = sinkDisplayName(a);
            const right = sinkDisplayName(b);
            if (left < right)
                return -1;

            if (left > right)
                return 1;

            return a.id - b.id;
        });
    }

    function updateSinkMetadata(text) {
        let parsed = [];
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            parsed = [];
        }
        const next = {
        };
        if (Array.isArray(parsed)) {
            for (const entry of parsed) {
                if (!entry || !entry.name)
                    continue;

                const properties = entry.properties || {
                };
                const ports = Array.isArray(entry.ports) ? entry.ports : [];
                let activePort = null;
                for (const port of ports) {
                    if (port && port.name === entry.active_port) {
                        activePort = port;
                        break;
                    }
                }
                if (!activePort && ports.length > 0)
                    activePort = ports[0];

                const alsaName = typeof properties["alsa.name"] === "string" ? properties["alsa.name"].trim() : "";
                const portDescription = activePort && activePort.description ? activePort.description : "";
                const displayName = portDescription || properties["node.nick"] || alsaName || properties["device.profile.description"] || entry.description || entry.name;
                const secondaryName = portDescription && portDescription !== displayName ? portDescription : "";
                next[entry.name] = {
                    "availability": activePort && activePort.availability ? activePort.availability : "availability unknown",
                    "displayName": displayName,
                    "secondaryName": secondaryName,
                    "portName": activePort && activePort.name ? activePort.name : "",
                    "portType": activePort && activePort.type ? activePort.type : "",
                    "ports": ports.map(port => ({
                        "name": port && port.name ? port.name : "",
                        "description": port && port.description ? port.description : "",
                        "availability": port && port.availability ? port.availability : "availability unknown",
                        "type": port && port.type ? port.type : ""
                    })).filter(port => port.name.length > 0),
                    "formFactor": properties["device.form_factor"] || properties["device.form-factor"] || "",
                    "deviceBus": properties["device.bus"] || "",
                    "priority": Number(properties["priority.session"] || 0)
                };
            }
        }
        root.sinkMetadata = next;
        root.updateSinks();
    }

    function updateSinks() {
        const all = [];
        if (!Pipewire.nodes || !Pipewire.nodes.values) {
            root.sinks = [];
            root.outputChoices = [];
            root.outputChoicesKey = "";
            return ;
        }
        for (const node of Pipewire.nodes.values) {
            if (!node || node.isStream || !node.isSink || !node.audio)
                continue;

            all.push(node);
        }
        sortSinks(all);
        // Keep the ListView model intact during unchanged metadata polls so
        // an in-progress scroll is not reset every polling interval.
        if (all.length !== root.sinks.length || all.some((node, index) => node !== root.sinks[index]))
            root.sinks = all;

        root.updateOutputChoices();
    }

    function outputDeviceName(node) {
        if (!node)
            return "";

        const properties = node.properties || {
        };
        return properties["node.nick"] || properties["device.profile.description"] || node.description || properties["device.nick"] || node.name || "";
    }

    function outputDisplayName(choice) {
        if (!choice)
            return "";

        return choice.portDescription || sinkDisplayName(choice.node);
    }

    function outputSecondaryName(choice) {
        if (!choice)
            return "";

        if (choice.portName) {
            const deviceName = outputDeviceName(choice.node);
            const detail = deviceName !== outputDisplayName(choice) ? deviceName : "";
            return choice.availability === "not available" ? (detail ? "Unavailable · " + detail : "Unavailable") : detail;
        }
        return sinkSecondaryName(choice.node);
    }

    function outputSelectable(choice) {
        return !!choice && choice.availability !== "not available";
    }

    function outputIconText(choice) {
        const portType = String(choice && choice.portType || "").toLowerCase();
        if (portType === "headphones")
            return "󰋋";

        if (portType === "speaker")
            return "󰓃";

        if (portType === "hdmi")
            return "󰍹";

        return choice ? sinkIconText(choice.node) : "󰓃";
    }

    function outputIsActive(choice) {
        if (!choice || !choice.node || !root.defaultSink || choice.node.id !== root.defaultSink.id)
            return false;

        if (!choice.portName)
            return true;

        const metadata = sinkMetadataFor(choice.node);
        return metadata && metadata.portName === choice.portName;
    }

    function updateOutputChoices() {
        const next = [];
        for (const node of root.sinks) {
            const metadata = sinkMetadataFor(node);
            const ports = metadata && Array.isArray(metadata.ports) ? metadata.ports : [];
            if (!ports.length) {
                next.push({
                    "node": node,
                    "portName": "",
                    "portDescription": "",
                    "portType": "",
                    "availability": "availability unknown"
                });
                continue;
            }

            for (const port of ports) {
                // Match GNOME's output picker: retain the active port, but
                // do not offer disconnected/inactive hardware ports.
                if (port.availability === "not available" && port.name !== metadata.portName)
                    continue;

                next.push({
                    "node": node,
                    "portName": port.name,
                    "portDescription": port.description,
                    "portType": port.type,
                    "availability": port.availability
                });
            }
        }

        next.sort((left, right) => {
            const activeDiff = Number(root.outputIsActive(right)) - Number(root.outputIsActive(left));
            if (activeDiff !== 0)
                return activeDiff;

            const sinkDiff = sinkSortRank(right.node) - sinkSortRank(left.node);
            if (sinkDiff !== 0)
                return sinkDiff;

            const availableDiff = Number(right.availability === "available") - Number(left.availability === "available");
            if (availableDiff !== 0)
                return availableDiff;

            return outputDisplayName(left).localeCompare(outputDisplayName(right));
        });

        const key = next.map(choice => [choice.node.id, choice.portName, choice.portDescription, choice.portType, choice.availability, root.outputIsActive(choice)].join("\u0000")).join("\u0001");
        if (key !== root.outputChoicesKey) {
            root.outputChoices = next;
            root.outputChoicesKey = key;
        }
    }

    function refresh() {
        if (root.hasDirectSinkControl)
            return ;

        if (!volumePoll.running)
            volumePoll.running = true;

    }

    function refreshSinks() {
        if (!sinkPoll.running)
            sinkPoll.running = true;
    }

    function setOptimisticState(nextPercent, nextMuted) {
        root.optimisticVolumePercent = Math.max(0, Math.min(100, Math.round(nextPercent)));
        root.optimisticMuted = !!nextMuted;
        optimisticStateReset.restart();
    }

    function clearOptimisticState() {
        optimisticStateReset.stop();
        root.optimisticVolumePercent = -1;
        root.optimisticMuted = false;
    }

    function snapVolumePercent(percent) {
        const nextPercent = Number(percent);
        if (isNaN(nextPercent))
            return 0;

        return Math.max(0, Math.min(100, Math.round(nextPercent / root.volumeStepPercent) * root.volumeStepPercent));
    }

    function requestVolumeFeedback() {
        if (root.muted || root.volumePercent <= 0)
            return ;

        if (volumeFeedbackDelay.running || volumeFeedbackQuiet.running || volumeFeedback.running) {
            volumeFeedbackQuiet.restart();
            return ;
        }
        volumeFeedbackDelay.restart();
        volumeFeedbackQuiet.restart();
    }

    function playVolumeFeedback() {
        if (root.muted || root.volumePercent <= 0 || volumeFeedback.running)
            return ;

        volumeFeedback.running = true;
    }

    function setVolumePercent(percent) {
        const nextPercent = Number(percent);
        if (isNaN(nextPercent))
            return ;

        const previousPercent = root.volumePercent;
        const previousMuted = root.muted;
        const clamped = root.snapVolumePercent(nextPercent);
        const shouldPlayFeedback = clamped > 0 && (clamped !== previousPercent || previousMuted);
        root.setOptimisticState(clamped, false);
        if (root.hasDirectSinkControl) {
            sinkAudio.muted = false;
            sinkAudio.volume = clamped / 100;
            if (shouldPlayFeedback)
                root.requestVolumeFeedback();

            return ;
        }
        setVolume.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", clamped + "%"];
        setVolume.running = true;
        if (shouldPlayFeedback)
            root.requestVolumeFeedback();

        refreshSoon.restart();
    }

    function adjustVolume(deltaPercent) {
        const delta = Number(deltaPercent);
        if (!delta)
            return ;

        const basePercent = root.optimisticStateActive ? root.optimisticVolumePercent : root.actualVolumePercent;
        const currentPercent = root.snapVolumePercent(basePercent);
        const targetPercent = root.snapVolumePercent(basePercent + delta);
        root.setVolumePercent(basePercent + delta);
        if (targetPercent === currentPercent) {
            root.volumeLimitReached();
            if (targetPercent > 0)
                root.requestVolumeFeedback();

        }

    }

    function toggleMute() {
        const nextMuted = !root.muted;
        root.setOptimisticState(root.volumePercent, nextMuted);
        if (root.hasDirectSinkControl) {
            sinkAudio.muted = nextMuted;
            return ;
        }
        muteToggle.running = true;
        refreshSoon.restart();
    }

    function adjustVolumeStep(stepPercent) {
        const parsed = Number(stepPercent);
        if (!isNaN(parsed) && parsed !== 0)
            root.adjustVolume(parsed);
        else
            root.adjustVolume(2);
    }

    function setAudioSink(node) {
        if (!node)
            return ;

        pendingSinkName = node.name || "";
        pendingSinkInputIds = [];
        setDefaultSink.command = ["wpctl", "set-default", String(node.id)];
        setDefaultSink.running = true;
        listSinkInputs.running = true;
        refreshSoon.restart();
        refreshSinksSoon.restart();
    }

    function setAudioOutput(choice) {
        if (!choice || !choice.node)
            return ;

        if (!root.currentSink || root.currentSink.id !== choice.node.id)
            root.setAudioSink(choice.node);

        if (choice.portName) {
            setSinkPort.command = ["pactl", "set-sink-port", choice.node.name, choice.portName];
            setSinkPort.running = true;
        }
        refreshSinksSoon.restart();
    }

    function updateSinkInputsToMove(text) {
        if (!pendingSinkName) {
            pendingSinkInputIds = [];
            return ;
        }
        const nextIds = [];
        const lines = text.split(/\r?\n/);
        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed)
                continue;

            const columns = trimmed.split(/\s+/);
            const id = parseInt(columns[0], 10);
            if (!isNaN(id))
                nextIds.push(id);

        }
        pendingSinkInputIds = nextIds;
        moveNextSinkInput();
    }

    function moveNextSinkInput() {
        if (!pendingSinkName || moveSinkInput.running)
            return ;

        if (!pendingSinkInputIds.length) {
            pendingSinkName = "";
            return ;
        }
        const nextId = pendingSinkInputIds[0];
        pendingSinkInputIds = pendingSinkInputIds.slice(1);
        moveSinkInput.command = ["pactl", "move-sink-input", String(nextId), pendingSinkName];
        moveSinkInput.running = true;
    }

    Component.onCompleted: root.updateSinks()

    Timer {
        interval: Theme.audioPollFastInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: Theme.audioPollSlowInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSinks()
    }

    Timer {
        id: refreshSoon

        interval: Theme.audioRefreshDelay
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSinksSoon

        interval: Theme.audioRefreshDelay
        repeat: false
        onTriggered: root.refreshSinks()
    }

    Timer {
        id: optimisticStateReset

        interval: Theme.audioOptimisticReset
        repeat: false
        onTriggered: root.clearOptimisticState()
    }

    Timer {
        id: volumeFeedbackDelay

        interval: root.volumeFeedbackDelayMs
        repeat: false
        onTriggered: root.playVolumeFeedback()
    }

    Timer {
        id: volumeFeedbackQuiet

        interval: root.volumeFeedbackQuietMs
        repeat: false
    }

    Connections {
        function onDefaultAudioSinkChanged() {
            root.clearOptimisticState();
            root.updateSinks();
            refreshSoon.restart();
        }

        target: Pipewire
    }

    Connections {
        function onValuesChanged() {
            root.updateSinks();
        }

        target: Pipewire.nodes
    }

    Process {
        id: volumePoll

        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]

        stdout: StdioCollector {
            id: volumeOut

            onStreamFinished: {
                const match = volumeOut.text.match(/[\d.]+/);
                if (match)
                    root.polledVolume = Math.min(100, Math.round(parseFloat(match[0]) * 100));

                root.polledMuted = volumeOut.text.includes("[MUTED]");
            }
        }

    }

    Process {
        id: sinkPoll

        command: ["pactl", "-f", "json", "list", "sinks"]

        stdout: StdioCollector {
            id: sinkPollOut

            onStreamFinished: root.updateSinkMetadata(sinkPollOut.text)
        }

    }

    Process {
        id: listSinkInputs

        command: ["pactl", "list", "short", "sink-inputs"]

        stdout: StdioCollector {
            id: sinkInputsOut

            onStreamFinished: root.updateSinkInputsToMove(sinkInputsOut.text)
        }

    }

    Process {
        id: moveSinkInput

        command: ["echo"]
        onExited: {
            if (pendingSinkInputIds.length)
                root.moveNextSinkInput();
            else
                pendingSinkName = "";
        }
    }

    Process {
        id: volumeUp

        command: ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "2%+"]
    }

    Process {
        id: volumeDown

        command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "2%-"]
    }

    Process {
        id: muteToggle

        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
    }

    Process {
        id: setDefaultSink

        command: ["echo"]
    }

    Process {
        id: setSinkPort

        command: ["echo"]
    }

    Process {
        id: setVolume

        command: ["echo"]
    }

    Process {
        id: volumeFeedback

        command: ["bash", "-c", "canberra-gtk-play -i audio-volume-change -d 'Volume changed' 2>/dev/null || paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null || true"]
    }

    IpcHandler {
        function increase(stepPercent: string) {
            root.adjustVolumeStep(stepPercent);
        }

        function decrease(stepPercent: string) {
            const parsed = Number(stepPercent);
            root.adjustVolume(!isNaN(parsed) && parsed !== 0 ? -parsed : -2);
        }

        function set(percent: string) {
            root.setVolumePercent(percent);
        }

        function toggleMute() {
            root.toggleMute();
        }

        target: "audio"
    }

}
