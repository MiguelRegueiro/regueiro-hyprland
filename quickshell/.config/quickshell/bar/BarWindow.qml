import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme/Theme.js" as Theme

PanelWindow {
    id: bar

    required property var targetScreen
    required property var notificationStore
    required property var audioService
    required property var batteryService
    required property var brightnessService
    required property var externalDrivesService
    required property var sshSessionsService
    property bool externalConnected: false
    readonly property var externalDrives: externalDrivesService && externalDrivesService.drives ? externalDrivesService.drives : []
    property bool showBar: true
    property bool forceOverlay: false
    property bool quickSettingsOpen: false
    property bool notificationCenterOpen: false
    property bool cpuStatsOpen: false
    property bool ramStatsOpen: false

    signal quickSettingsClicked()
    signal notificationCenterClicked()
    signal clipboardClicked()
    signal externalDrivesClicked()
    signal sshSessionsClicked()
    signal cpuStatsClicked()
    signal ramStatsClicked()
    signal quickSettingsHoveredChanged(bool hovered)
    signal notificationCenterHoveredChanged(bool hovered)

    screen: targetScreen
    visible: showBar
    exclusiveZone: Theme.barHeight - Theme.borderSize
    WlrLayershell.layer: bar.forceOverlay ? WlrLayer.Overlay : WlrLayer.Top
    implicitHeight: Theme.barHeight
    color: Theme.barBg

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        anchors.fill: parent

        Row {
            id: leftRow

            spacing: 0

            anchors {
                left: parent.left
                top: parent.top
            }

            WorkspaceStrip {
                screenName: bar.targetScreen.name
                barHeight: Theme.barHeight
                externalConnected: bar.externalConnected
            }

            SystemStats {
                barHeight: Theme.barHeight
                cpuMenuOpen: bar.cpuStatsOpen
                ramMenuOpen: bar.ramStatsOpen
                onCpuClicked: bar.cpuStatsClicked()
                onRamClicked: bar.ramStatsClicked()
            }

        }

        DateTimeNotificationTrigger {
            id: dateTimeTrigger

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }

            barHeight: Theme.barHeight
            menuOpen: bar.notificationCenterOpen
            notificationStore: bar.notificationStore
            onNotificationCenterClicked: bar.notificationCenterClicked()
            onHoveredChanged: bar.notificationCenterHoveredChanged(hovered)
        }

        RowLayout {
            id: rightRow

            spacing: 0

            anchors {
                right: parent.right
                top: parent.top
            }

            SshSessionsButton {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                sshService: bar.sshSessionsService
                onClicked: bar.sshSessionsClicked()
                onRightClicked: {
                    if (bar.sshSessionsService)
                        bar.sshSessionsService.refresh();

                }
            }

            ExternalDriveButton {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                onClicked: bar.externalDrivesClicked()
                onRightClicked: {
                    if (bar.externalDrivesService)
                        bar.externalDrivesService.refresh();

                }
            }

            BarIconButton {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                iconText: "󰅌"
                iconSize: 15 + Theme.fontSizeDelta
                padH: 7
                onClicked: bar.clipboardClicked()
            }

            SystemTrayItems {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
            }

            QuickSettingsTrigger {
                id: quickSettingsTrigger

                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                menuOpen: bar.quickSettingsOpen
                audioService: bar.audioService
                batteryService: bar.batteryService
                onClicked: bar.quickSettingsClicked()
            }

        }

    }

}
