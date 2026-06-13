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
    required property var brightnessService
    required property var inputService
    required property var externalDrivesService
    readonly property var externalDrives: externalDrivesService && externalDrivesService.drives ? externalDrivesService.drives : []
    property bool showBar: true
    property bool forceOverlay: false
    property bool quickSettingsOpen: false
    property bool notificationCenterOpen: false

    signal quickSettingsClicked()
    signal notificationCenterClicked()
    signal clipboardClicked()
    signal externalDrivesClicked()
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
                leftMargin: 4
            }

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
                onClicked: bar.clipboardClicked()
            }

            SystemTrayItems {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
            }

            InputLanguageIndicator {
                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                inputService: bar.inputService
            }

            QuickSettingsTrigger {
                id: quickSettingsTrigger

                Layout.alignment: Qt.AlignVCenter
                barHeight: Theme.barHeight
                menuOpen: bar.quickSettingsOpen
                audioService: bar.audioService
                onClicked: bar.quickSettingsClicked()
            }

        }

    }

}
