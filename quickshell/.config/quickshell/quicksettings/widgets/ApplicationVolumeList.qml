import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme/Theme.js" as Theme

ColumnLayout {
    id: root

    property var streams: []
    property string streamsKey: ""
    property int activeDragCount: 0

    function streamLabel(stream) {
        if (!stream)
            return "";

        if (stream.mediaName && stream.appName)
            return stream.appName === stream.mediaName ? stream.appName : stream.appName + " - " + stream.mediaName;

        return stream.mediaName || stream.appName || stream.nodeName || ("Stream " + stream.id);
    }

    function firstPercent(volume) {
        if (!volume)
            return 1;

        var keys = Object.keys(volume);
        for (var i = 0; i < keys.length; ++i) {
            var key = keys[i];
            if (key === "balance")
                continue;

            var channel = volume[key];
            if (!channel)
                continue;

            if (typeof channel.value_percent === "string") {
                var pct = parseFloat(channel.value_percent);
                if (!isNaN(pct))
                    return Math.max(0, Math.min(1, pct / 100));

            }
            if (typeof channel.value === "number")
                return Math.max(0, Math.min(1.5, channel.value / 65536));

        }
        return 1;
    }

    function updateStreams(text) {
        var next = [];
        try {
            var parsed = JSON.parse(text);
            if (!Array.isArray(parsed)) {
                root.streams = [];
                root.streamsKey = "";
                return ;
            }
            for (var i = 0; i < parsed.length; ++i) {
                var entry = parsed[i];
                var props = entry.properties || {
                };
                next.push({
                    "id": entry.index,
                    "appName": props["application.name"] || props["application.process.binary"] || props["node.nick"] || "",
                    "mediaName": props["media.name"] || "",
                    "nodeName": props["node.name"] || "",
                    "volume": root.firstPercent(entry.volume),
                    "muted": entry.mute === true
                });
            }
        } catch (e) {
            next = [];
        }
        var nextKey = JSON.stringify(next);
        if (nextKey === root.streamsKey)
            return ;

        root.streams = next;
        root.streamsKey = nextKey;
    }

    Layout.fillWidth: true
    spacing: 8

    Timer {
        id: pollTimer

        interval: Theme.appVolumePollInterval
        running: root.visible && root.activeDragCount === 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pollProc.running)
                pollProc.running = true;

        }
    }

    Timer {
        id: refreshSoon

        interval: Theme.audioRefreshDelay
        repeat: false
        onTriggered: {
            if (!pollProc.running)
                pollProc.running = true;

        }
    }

    Process {
        id: pollProc

        command: ["pactl", "-f", "json", "list", "sink-inputs"]

        stdout: StdioCollector {
            id: pollOut

            onStreamFinished: root.updateStreams(pollOut.text)
        }

    }

    Process {
        id: setAppVolProc

        command: ["echo"]
    }

    Process {
        id: setAppMuteProc

        command: ["echo"]
    }

    Repeater {
        model: root.streams

        delegate: QuickSettingsSliderRow {
            required property var modelData
            property bool _countedDrag: false

            Layout.fillWidth: true
            backgroundRadius: 16
            iconText: "󰎇"
            label: root.streamLabel(modelData)
            value: modelData.volume
            muted: modelData.muted
            onDraggingChanged: {
                if (dragging && !_countedDrag) {
                    root.activeDragCount += 1;
                    _countedDrag = true;
                    return ;
                }
                if (!dragging && _countedDrag) {
                    root.activeDragCount = Math.max(0, root.activeDragCount - 1);
                    _countedDrag = false;
                    refreshSoon.restart();
                }
            }
            onSliderMoved: function(val) {
                setAppVolProc.command = ["pactl", "set-sink-input-volume", String(modelData.id), Math.round(val * 100) + "%"];
                setAppVolProc.running = true;
            }
            onMuteClicked: {
                setAppMuteProc.command = ["pactl", "set-sink-input-mute", String(modelData.id), "toggle"];
                setAppMuteProc.running = true;
            }
            Component.onDestruction: {
                if (_countedDrag)
                    root.activeDragCount = Math.max(0, root.activeDragCount - 1);

            }
        }

    }

}
