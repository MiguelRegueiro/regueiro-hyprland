import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../components" as Components
import "../theme/Theme.js" as Theme

Rectangle {
    id: root

    required property var audioService
    property int barHeight: 34
    readonly property bool hovered: triggerHover.hovered
    property var batteryDevice: UPower.displayDevice
    property int batteryPercent: batteryDevice ? Math.min(100, Math.round(batteryDevice.percentage * 100)) : -1
    property bool batteryCharging: batteryDevice && (batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.FullyCharged)
    property bool batteryFull: batteryDevice && batteryDevice.state === UPowerDeviceState.FullyCharged
    property string networkIcon: "󰤭"

    signal clicked()

    height: barHeight - 6
    implicitWidth: contentRow.implicitWidth + 28
    radius: Theme.radiusSmall
    color: Theme.barBg

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

        command: ["bash", "-c", "eth=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | " + "awk -F: '$2==\"ethernet\" && $1!~/^(docker|br[0-9]|virbr|veth)/ {print $3; exit}'); " + "if [ \"$eth\" = 'connected' ]; then echo eth; " + "else w=$(nmcli radio wifi 2>/dev/null); " + "s=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1); " + "if [ \"$w\" = 'enabled' ] && [ -n \"$s\" ]; then echo wifi_up; " + "elif [ \"$w\" = 'enabled' ]; then echo wifi_off; " + "else echo off; fi; fi"]

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

}
