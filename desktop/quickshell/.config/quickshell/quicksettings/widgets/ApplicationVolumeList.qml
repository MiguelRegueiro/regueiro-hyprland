import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell.Io
import "../../theme/Theme.js" as Theme

ListView {
    id: root

    required property real maximumHeight
    property var streams: []
    property var streamState: ({})
    property string streamsKey: ""
    property int activeDragCount: 0

    function displayText(value) {
        var text = String(value || "").trim();
        return text === "(null)" || text.toLowerCase() === "null" ? "" : text;
    }

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
                    return Math.max(0, Math.min(1.5, pct / 100));

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
                root.streamState = ({});
                root.streamsKey = "";
                return ;
            }
            for (var i = 0; i < parsed.length; ++i) {
                var entry = parsed[i];
                var props = entry.properties || {
                };
                var mediaName = root.displayText(props["media.name"]);
                // Manager/control streams without a media label are not
                // user-adjustable playback streams.
                if (String(props["media.category"] || "").toLowerCase() === "manager" && !mediaName)
                    continue;

                next.push({
                    "id": entry.index,
                    "appName": root.displayText(props["application.name"] || props["application.process.binary"] || props["node.nick"]),
                    "mediaName": mediaName,
                    "nodeName": root.displayText(props["node.name"]),
                    "volume": root.firstPercent(entry.volume),
                    "muted": entry.mute === true
                });
            }
        } catch (e) {
            next = [];
        }
        var nextState = ({ });
        var topology = [];
        for (var j = 0; j < next.length; ++j) {
            var stream = next[j];
            nextState[String(stream.id)] = stream;
            topology.push({
                "id": stream.id,
                "appName": stream.appName,
                "mediaName": stream.mediaName,
                "nodeName": stream.nodeName
            });
        }
        root.streamState = nextState;

        var nextKey = JSON.stringify(topology);
        if (nextKey !== root.streamsKey) {
            root.streams = next;
            root.streamsKey = nextKey;
        }
    }

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: Math.min(Math.max(0, contentHeight), maximumHeight)
    spacing: 8
    model: root.streams
    clip: true
    boundsBehavior: Flickable.StopAtBounds

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

    ScrollBar.vertical: ScrollBar {
        width: 4
        policy: ScrollBar.AsNeeded
        background: null

        contentItem: Rectangle {
            implicitWidth: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.2)
        }

    }

    delegate: QuickSettingsSliderRow {
        required property var modelData
        property bool _countedDrag: false
        property var stream: root.streamState[String(modelData.id)] || modelData

        width: ListView.view.width
        backgroundRadius: 16
        surfaceVisible: false
        iconText: "󰎇"
        label: root.streamLabel(stream)
        value: stream.volume
        maxValue: Math.max(1, stream.volume)
        stepSize: 0.02
        muted: stream.muted
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
            setAppVolProc.command = ["pactl", "set-sink-input-volume", String(stream.id), Math.round(val * 100) + "%"];
            setAppVolProc.running = true;
        }
        onMuteClicked: {
            setAppMuteProc.command = ["pactl", "set-sink-input-mute", String(stream.id), "toggle"];
            setAppMuteProc.running = true;
        }
        Component.onDestruction: {
            if (_countedDrag)
                root.activeDragCount = Math.max(0, root.activeDragCount - 1);

        }
    }

}
