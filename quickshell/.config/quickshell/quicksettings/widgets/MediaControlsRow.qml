import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../theme/Theme.js" as Theme

Rectangle {
    id: row

    property bool playerctlAvailable: false
    property string playerId: ""
    property string playerName: ""
    property string title: ""
    property string artist: ""
    property bool playing: false
    readonly property bool hasPlayer: playerId.length > 0
    readonly property string titleText: hasPlayer ? (title.length > 0 ? title : "Unknown title") : "No media playing"
    readonly property string subtitleText: {
        if (!hasPlayer)
            return playerctlAvailable ? "Start something and it will show up here" : "playerctl is not available";

        if (artist.length > 0 && playerName.length > 0)
            return artist + " • " + playerName;

        if (artist.length > 0)
            return artist;

        if (playerName.length > 0)
            return playerName;

        return "Media";
    }

    Layout.fillWidth: true
    implicitHeight: 102
    radius: 18
    color: Theme.qsCardBg
    border.width: 1
    border.color: Theme.qsCardBorder

    Timer {
        interval: Theme.audioPollSlowInterval
        running: row.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pollProc.running)
                pollProc.running = true;

        }
    }

    Timer {
        id: actionRefresh

        interval: Theme.mediaActionRefreshDelay
        repeat: false
        onTriggered: {
            if (!pollProc.running)
                pollProc.running = true;

        }
    }

    Process {
        id: pollProc

        command: ["bash", "-lc", "if ! command -v playerctl >/dev/null 2>&1; then printf 'no\\037\\n'; exit 0; fi; player=''; for p in $(playerctl -l 2>/dev/null); do status=$(playerctl -p \"$p\" status 2>/dev/null || true); if [ \"$status\" = 'Playing' ]; then player=$p; break; fi; done; if [ -z \"$player\" ]; then player=$(playerctl -l 2>/dev/null | head -n1); fi; if [ -n \"$player\" ]; then status=$(playerctl -p \"$player\" status 2>/dev/null || true); title=$(playerctl -p \"$player\" metadata --format '{{ title }}' 2>/dev/null || true); artist=$(playerctl -p \"$player\" metadata --format '{{ artist }}' 2>/dev/null || true); app=$(playerctl -p \"$player\" metadata --format '{{ playerName }}' 2>/dev/null || true); else status=''; title=''; artist=''; app=''; fi; printf 'yes\\037%s\\037%s\\037%s\\037%s\\037%s\\n' \"$player\" \"$status\" \"$title\" \"$artist\" \"$app\""]

        stdout: StdioCollector {
            id: pollOut

            onStreamFinished: {
                var parts = pollOut.text.replace(/\n$/, "").split("\u001f");
                row.playerctlAvailable = parts.length > 0 && parts[0] === "yes";
                row.playerId = parts.length > 1 ? parts[1] : "";
                row.playing = parts.length > 2 && parts[2] === "Playing";
                row.title = parts.length > 3 ? parts[3] : "";
                row.artist = parts.length > 4 ? parts[4] : "";
                row.playerName = parts.length > 5 ? parts[5] : "";
            }
        }

    }

    Process {
        id: prevProc

        command: ["echo"]
    }

    Process {
        id: toggleProc

        command: ["echo"]
    }

    Process {
        id: nextProc

        command: ["echo"]
    }

    RowLayout {
        spacing: 14

        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
            topMargin: 14
            bottomMargin: 18
        }

        Rectangle {
            id: mediaBadge

            Layout.alignment: Qt.AlignTop
            width: 36
            height: 36
            radius: 14
            color: row.hasPlayer ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
            border.width: 1
            border.color: row.hasPlayer ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder

            Text {
                anchors.centerIn: parent
                text: "󰎈"
                font.family: Theme.fontIcons
                font.pixelSize: 17
                color: row.hasPlayer ? Theme.textPrimary : Theme.textDim
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: row.titleText
                    color: Theme.textPrimary
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: row.subtitleText
                    color: Theme.textDim
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

            }

            Item {
                Layout.fillWidth: true
                implicitHeight: controlsRow.height

                Row {
                    id: controlsRow

                    anchors.centerIn: parent
                    spacing: 10

                    ControlButton {
                        iconText: "󰒮"
                        enabled: row.hasPlayer
                        onClicked: {
                            prevProc.command = ["playerctl", "-p", row.playerId, "previous"];
                            prevProc.running = true;
                            actionRefresh.restart();
                        }
                    }

                    ControlButton {
                        iconText: row.playing ? "󰏤" : "󰐊"
                        glyphOffsetX: row.playing ? 0 : 1
                        enabled: row.hasPlayer
                        onClicked: {
                            toggleProc.command = ["playerctl", "-p", row.playerId, "play-pause"];
                            toggleProc.running = true;
                            actionRefresh.restart();
                        }
                    }

                    ControlButton {
                        iconText: "󰒭"
                        enabled: row.hasPlayer
                        onClicked: {
                            nextProc.command = ["playerctl", "-p", row.playerId, "next"];
                            nextProc.running = true;
                            actionRefresh.restart();
                        }
                    }

                }

            }

        }

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: mediaBadge.width
            Layout.preferredHeight: mediaBadge.height
        }

    }

    component ControlButton: Rectangle {
        id: btn

        required property string iconText
        property real glyphOffsetX: 0
        readonly property bool hovered: mouse.containsMouse

        signal clicked()

        width: 38
        height: 38
        radius: 19
        color: btn.hovered && btn.enabled ? Theme.qsCardChipBgHover : Theme.qsCardChipBg
        border.width: 1
        border.color: btn.hovered && btn.enabled ? Theme.qsCardChipBorderHover : Theme.qsCardChipBorder
        opacity: btn.enabled ? 1 : 0.45

        Text {
            x: btn.glyphOffsetX
            width: parent.width
            height: parent.height
            text: btn.iconText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.fontIcons
            font.pixelSize: 15
            color: Theme.textPrimary
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.ArrowCursor
            onClicked: btn.clicked()
        }

    }

}
