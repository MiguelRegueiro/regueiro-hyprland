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

    signal clicked()

    property var batteryDevice: UPower.displayDevice
    property int batteryPercent: batteryDevice ? Math.min(100, Math.round(batteryDevice.percentage * 100)) : -1
    property bool batteryCharging: batteryDevice && (batteryDevice.state === UPowerDeviceState.Charging
        || batteryDevice.state === UPowerDeviceState.FullyCharged)
    property bool batteryFull: batteryDevice && batteryDevice.state === UPowerDeviceState.FullyCharged

    property string networkIcon: "󰤭"

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
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!networkPoll.running)
                networkPoll.running = true
        }
    }

    Process {
        id: networkPoll
        command: ["bash", "-c",
            "eth=$(nmcli -t -f DEVICE,TYPE,STATE dev 2>/dev/null | " +
            "awk -F: '$2==\"ethernet\" && $1!~/^(docker|br[0-9]|virbr|veth)/ {print $3; exit}'); " +
            "if [ \"$eth\" = 'connected' ]; then echo eth; " +
            "else w=$(nmcli radio wifi 2>/dev/null); " +
            "s=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1); " +
            "if [ \"$w\" = 'enabled' ] && [ -n \"$s\" ]; then echo wifi_up; " +
            "elif [ \"$w\" = 'enabled' ]; then echo wifi_off; " +
            "else echo off; fi; fi"
        ]
        stdout: StdioCollector {
            id: networkOut
            onStreamFinished: {
                const state = networkOut.text.trim()
                if (state === "eth")
                    root.networkIcon = "󰌗"
                else if (state === "wifi_up")
                    root.networkIcon = "󰤨"
                else
                    root.networkIcon = "󰤭"
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
            iconColor: root.audioService.muted ? Theme.textDisabled : Theme.textPrimary
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

            Item {
                width: 24
                height: 12
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 21
                    height: 12
                    radius: 3
                    color: "transparent"
                    border.width: 1.5
                    border.color: root.batteryPercent <= 15 ? Theme.red : (root.batteryCharging || root.batteryFull) ? Theme.green : Qt.rgba(1, 1, 1, 0.85)

                    Item {
                        anchors {
                            fill: parent
                            margins: 2.5
                        }
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 1
                            visible: root.batteryCharging && !root.batteryFull
                            color: Qt.rgba(0.18, 0.72, 0.36, 0.26)
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            width: parent.width * root.batteryPercent / 100
                            radius: 1
                            color: root.batteryCharging || root.batteryFull ? Theme.green : root.batteryPercent <= 15 ? Theme.red : Theme.textPrimary

                            Behavior on width {
                                NumberAnimation { duration: 200 }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.batteryCharging && !root.batteryFull
                        text: "󱐋"
                        font.family: Theme.fontIcons
                        font.pixelSize: 8
                        color: Qt.rgba(0, 0, 0, 0.9)
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 5
                    radius: 1
                    color: root.batteryPercent <= 15 ? Theme.red : (root.batteryCharging || root.batteryFull) ? Theme.green : Qt.rgba(1, 1, 1, 0.85)
                }
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
        onWheel: wheel => root.audioService.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5)
    }
}
