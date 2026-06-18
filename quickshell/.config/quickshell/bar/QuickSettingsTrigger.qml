import QtQuick
import Quickshell
import Quickshell.Io
import "../components" as Components
import "../theme/Theme.js" as Theme

Rectangle {
    id: root

    required property var audioService
    required property var batteryService
    property int barHeight: 34
    property bool menuOpen: false
    readonly property bool hovered: triggerHover.hovered
    property int batteryPercent: batteryService ? batteryService.percent : -1
    property bool batteryCharging: batteryService && batteryService.charging
    property bool batteryFull: batteryService && batteryService.full
    property string networkIcon: "󰤭"

    signal clicked()

    height: Math.min(barHeight, Theme.barItemHeight)
    implicitWidth: contentRow.implicitWidth + 28
    radius: Theme.radiusSmall
    color: hovered && !menuOpen ? Theme.hoverBg : "transparent"

    HoverHandler {
        id: triggerHover

        blocking: false
        cursorShape: Qt.ArrowCursor
    }

    Timer {
        interval: Theme.networkPollInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!networkPoll.running)
                networkPoll.running = true;

        }
    }

    Process {
        id: networkPoll

        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/freebsd-wifi.sh", "network-state"]

        stdout: StdioCollector {
            id: networkOut

            onStreamFinished: {
                const state = networkOut.text.trim();
                if (state === "eth")
                    root.networkIcon = "󰌗";
                else if (state === "wifi_up")
                    root.networkIcon = "󰤨";
                else
                    root.networkIcon = "󰤭";
            }
        }

    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.networkIcon
            font.family: Theme.fontIcons
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 1
            height: 14
            color: Theme.barBorder
            anchors.verticalCenter: parent.verticalCenter
        }

        Components.VolumeIcon {
            muted: root.audioService.muted
            volumePercent: root.audioService.volumePercent
            iconColor: Theme.textPrimary
            height: 13
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.audioService.volumePercent + "%"
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: root.audioService.muted ? Theme.textDisabled : Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            visible: root.batteryPercent >= 0
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: 1
                height: 14
                color: Theme.barBorder
                anchors.verticalCenter: parent.verticalCenter
            }

            Components.BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                percent: root.batteryPercent
                charging: root.batteryCharging
                full: root.batteryFull
            }

            Text {
                text: root.batteryPercent + "%"
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.ArrowCursor
        onClicked: root.clicked()
        onWheel: (wheel) => {
            return root.audioService.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5);
        }
    }

    Behavior on color {
        enabled: !root.menuOpen

        ColorAnimation {
            duration: Theme.hoverAnimDuration
        }

    }

}
