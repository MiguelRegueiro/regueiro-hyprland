import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    property var defaultSink: Pipewire.defaultAudioSink
    property var sinkAudio: (defaultSink && defaultSink.ready) ? defaultSink.audio : null
    property var sinkMetadata: ({})
    property var sinks: []
    property string pendingSinkName: ""
    property var pendingSinkInputIds: []
    property int pipewireVolume: sinkAudio ? Math.min(100, Math.round(sinkAudio.volume * 100)) : -1
    property int polledVolume: 0
    property bool polledMuted: false
    readonly property var currentSink: defaultSink
    readonly property string currentSinkName: sinkDisplayName(currentSink)
    readonly property string currentSinkIcon: sinkIconText(currentSink)
    readonly property int volumePercent: pipewireVolume >= 0 ? pipewireVolume : polledVolume
    readonly property bool muted: sinkAudio ? (sinkAudio.muted || polledMuted) : polledMuted
    readonly property string volumeIcon: {
        if (muted || volumePercent <= 0)
            return "󰖁"
        if (volumePercent < 13)
            return "󰕿"
        if (volumePercent < 40)
            return "󰖀"
        if (volumePercent < 70)
            return "󰕾"
        return ""
    }

    function sinkDisplayName(node) {
        if (!node)
            return ""

        const metadata = sinkMetadataFor(node)
        if (metadata && metadata.displayName)
            return metadata.displayName

        const properties = node.properties || {}
        const alsaName = (properties["alsa.name"] || "").trim()
        return node.nickname
            || alsaName
            || properties["device.profile.description"]
            || node.description
            || properties["device.nick"]
            || node.name
            || "Unknown Output"
    }

    function sinkSecondaryName(node) {
        if (!node)
            return ""

        const metadata = sinkMetadataFor(node)
        if (metadata && metadata.secondaryName)
            return metadata.secondaryName

        const properties = node.properties || {}
        const primary = sinkDisplayName(node)
        const candidates = [
            (properties["device.profile.description"] || "").trim(),
            node.description,
            properties["device.nick"],
            node.name
        ]

        for (const candidate of candidates) {
            if (candidate && candidate !== primary)
                return candidate
        }

        return ""
    }

    function sinkIconText(node) {
        if (!node)
            return "󰓃"

        const metadata = sinkMetadataFor(node)
        if (metadata && metadata.portType === "Headphones")
            return "󰋋"
        if (metadata && metadata.portType === "HDMI")
            return "󰍹"
        if (metadata && metadata.portType === "Speaker")
            return "󰓃"

        const properties = node.properties || {}
        const haystack = [
            node.description || "",
            node.nickname || "",
            node.name || "",
            properties["device.icon-name"] || "",
            properties["node.name"] || "",
            properties["device.bus"] || ""
        ].join(" ").toLowerCase()

        if (haystack.includes("bluetooth") || haystack.includes("bluez"))
            return "󰂯"
        if (haystack.includes("headphone") || haystack.includes("headset"))
            return "󰋋"
        if (haystack.includes("hdmi") || haystack.includes("displayport") || haystack.includes("display"))
            return "󰍹"

        return "󰓃"
    }

    function sinkMetadataFor(node) {
        if (!node || !node.name)
            return null

        return sinkMetadata[node.name] || null
    }

    function sinkAvailabilityFor(node) {
        const metadata = sinkMetadataFor(node)
        return metadata ? metadata.availability : ""
    }

    function sinkVisible(node) {
        if (!node)
            return false

        const availability = sinkAvailabilityFor(node)
        return node === root.defaultSink || availability !== "not available"
    }

    function sinkSortRank(node) {
        if (!node)
            return -1

        if (root.defaultSink && node.id === root.defaultSink.id)
            return 3000

        const metadata = sinkMetadataFor(node)
        if (!metadata)
            return 1000

        let availabilityRank = 1
        if (metadata.availability === "available")
            availabilityRank = 2
        else if (metadata.availability === "not available")
            availabilityRank = 0

        return availabilityRank * 1000 + metadata.priority
    }

    function sortSinks(next) {
        next.sort((a, b) => {
            const rankDiff = sinkSortRank(b) - sinkSortRank(a)
            if (rankDiff !== 0)
                return rankDiff

            const left = sinkDisplayName(a)
            const right = sinkDisplayName(b)
            if (left < right)
                return -1
            if (left > right)
                return 1
            return a.id - b.id
        })
    }

    function updateSinkMetadata(text) {
        let parsed = []
        try {
            parsed = JSON.parse(text)
        } catch (error) {
            parsed = []
        }

        const next = {}
        if (Array.isArray(parsed)) {
            for (const entry of parsed) {
                if (!entry || !entry.name)
                    continue

                const properties = entry.properties || {}
                const ports = Array.isArray(entry.ports) ? entry.ports : []
                let activePort = null

                for (const port of ports) {
                    if (port && port.name === entry.active_port) {
                        activePort = port
                        break
                    }
                }

                if (!activePort && ports.length > 0)
                    activePort = ports[0]

                const alsaName = typeof properties["alsa.name"] === "string"
                    ? properties["alsa.name"].trim()
                    : ""
                const portDescription = activePort && activePort.description ? activePort.description : ""
                const displayName = alsaName
                    || properties["node.nick"]
                    || portDescription
                    || properties["device.profile.description"]
                    || entry.description
                    || entry.name
                const secondaryName = portDescription && portDescription !== displayName ? portDescription : ""

                next[entry.name] = {
                    availability: activePort && activePort.availability ? activePort.availability : "availability unknown",
                    displayName: displayName,
                    secondaryName: secondaryName,
                    portType: activePort && activePort.type ? activePort.type : "",
                    priority: Number(properties["priority.session"] || 0)
                }
            }
        }

        root.sinkMetadata = next
        root.updateSinks()
    }

    function updateSinks() {
        const next = []
        const all = []

        if (!Pipewire.nodes || !Pipewire.nodes.values) {
            root.sinks = next
            return
        }

        for (const node of Pipewire.nodes.values) {
            if (!node || node.isStream || !node.isSink || !node.audio)
                continue

            all.push(node)

            if (!sinkVisible(node))
                continue

            next.push(node)
        }

        const resolved = next.length > 0 ? next : all
        sortSinks(resolved)
        root.sinks = resolved
    }

    function refresh() {
        if (!volumePoll.running)
            volumePoll.running = true
    }

    function setVolumePercent(percent) {
        setVolume.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", Math.max(0, Math.min(100, percent)) + "%"]
        setVolume.running = true
        refreshSoon.restart()
    }

    function adjustVolume(deltaPercent) {
        if (deltaPercent > 0)
            volumeUp.running = true
        else
            volumeDown.running = true

        refreshSoon.restart()
    }

    function toggleMute() {
        muteToggle.running = true
        refreshSoon.restart()
    }

    function setAudioSink(node) {
        if (!node)
            return

        pendingSinkName = node.name || ""
        pendingSinkInputIds = []
        setDefaultSink.command = ["wpctl", "set-default", String(node.id)]
        setDefaultSink.running = true
        listSinkInputs.running = true
        refreshSoon.restart()
    }

    function updateSinkInputsToMove(text) {
        if (!pendingSinkName) {
            pendingSinkInputIds = []
            return
        }

        const nextIds = []
        const lines = text.split(/\r?\n/)
        for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed)
                continue

            const columns = trimmed.split(/\s+/)
            const id = parseInt(columns[0], 10)
            if (!isNaN(id))
                nextIds.push(id)
        }

        pendingSinkInputIds = nextIds
        moveNextSinkInput()
    }

    function moveNextSinkInput() {
        if (!pendingSinkName || moveSinkInput.running)
            return

        if (!pendingSinkInputIds.length) {
            pendingSinkName = ""
            return
        }

        const nextId = pendingSinkInputIds[0]
        pendingSinkInputIds = pendingSinkInputIds.slice(1)
        moveSinkInput.command = ["pactl", "move-sink-input", String(nextId), pendingSinkName]
        moveSinkInput.running = true
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sinkPoll.running)
                sinkPoll.running = true
        }
    }

    Timer {
        id: refreshSoon
        interval: 150
        repeat: false
        onTriggered: root.refresh()
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged() {
            root.updateSinks()
            refreshSoon.restart()
        }
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged() {
            root.updateSinks()
        }
    }

    Process {
        id: volumePoll
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: StdioCollector {
            id: volumeOut
            onStreamFinished: {
                const match = volumeOut.text.match(/[\d.]+/)
                if (match)
                    root.polledVolume = Math.min(100, Math.round(parseFloat(match[0]) * 100))
                root.polledMuted = volumeOut.text.includes("[MUTED]")
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
                root.moveNextSinkInput()
            else
                pendingSinkName = ""
        }
    }

    Process { id: volumeUp; command: ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"] }
    Process { id: volumeDown; command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] }
    Process { id: muteToggle; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: setDefaultSink; command: ["echo"] }
    Process { id: setVolume; command: ["echo"] }

    Component.onCompleted: root.updateSinks()
}
