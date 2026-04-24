import QtQuick
import Quickshell
import Quickshell.Io
import "../theme/Theme.js" as Theme

PanelWindow {
    id: bar

    required property var targetScreen
    required property var notificationStore
    required property var audioService
    required property var brightnessService

    property bool showBar: true

    signal quickSettingsClicked()
    signal notificationCenterClicked()
    signal quickSettingsHoveredChanged(bool hovered)
    signal notificationCenterHoveredChanged(bool hovered)

    screen: targetScreen
    visible: showBar
    anchors {
        top: true
        left: true
        right: true
    }
    exclusiveZone: Theme.barHeight - Theme.borderSize
    implicitHeight: Theme.barHeight
    color: Theme.barBg

    Process {
        id: clipHistoryMenu
        command: [Quickshell.env("HOME") + "/.config/hypr/scripts/cliphist-menu"]
    }

    Item {
        anchors.fill: parent

        Row {
            id: leftRow
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 4
            }
            spacing: 0

            WorkspaceStrip {
                screenName: bar.targetScreen.name
                barHeight: Theme.barHeight
            }

            SystemStats {
                barHeight: Theme.barHeight
            }
        }

        DateTimeNotificationTrigger {
            id: dateTimeTrigger
            anchors.centerIn: parent
            barHeight: Theme.barHeight
            notificationStore: bar.notificationStore
            onNotificationCenterClicked: bar.notificationCenterClicked()
        }

        Item {
            id: notificationHotZone
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.ncWidth + Theme.barCornerRadius * 2
            x: Math.round((parent.width - width) / 2)

            HoverHandler {
                blocking: false
                onHoveredChanged: bar.notificationCenterHoveredChanged(hovered)
            }
        }

        Row {
            id: rightRow
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 4
            }
            spacing: 0

            Loader {
                active: bar.targetScreen.name === "eDP-1"
                height: Theme.barHeight
                width: active && item ? item.implicitWidth : 0
                sourceComponent: Component {
                    BrightnessIndicator {
                        barHeight: Theme.barHeight
                        brightnessService: bar.brightnessService
                    }
                }
            }

            BarIconButton {
                barHeight: Theme.barHeight
                iconText: "󰅌"
                onClicked: clipHistoryMenu.running = true
            }

            SystemTrayItems {
                barHeight: Theme.barHeight
            }

            InputLanguageIndicator {
                barHeight: Theme.barHeight
            }

            QuickSettingsTrigger {
                id: quickSettingsTrigger
                barHeight: Theme.barHeight
                audioService: bar.audioService
                onClicked: bar.quickSettingsClicked()
            }
        }

        Item {
            id: quickSettingsHotZone
            x: rightRow.x + quickSettingsTrigger.x
            width: parent.width - x
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 20

            HoverHandler {
                blocking: false
                onHoveredChanged: bar.quickSettingsHoveredChanged(hovered)
            }
        }
    }
}
